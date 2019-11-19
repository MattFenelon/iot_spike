# frozen_string_literal: true

class Thing < ApplicationRecord
  CONTROL_PLANE_CERT = ENV['CONTROL_PLANE_CERT']
  CONTROL_PLANE_PRIVATE_KEY = ENV['CONTROL_PLANE_PRIVATE_KEY']
  CONTROL_PLANE_PUBLIC_KEY = ENV['CONTROL_PLANE_PUBLIC_KEY']

  DEVICE_CERT = ENV['DEVICE_CERT']
  DEVICE_CERT_ARN = ENV['DEVICE_CERT_ARN']
  DEVICE_PRIVATE_KEY = ENV['DEVICE_PRIVATE_KEY']

  before_create :aws_iot_create_thing

  def aws_iot_create_thing
    # TODO: Add attributes
    # TODO: Add Thing Type

    client = Aws::IoT::Client.new
    thing = client.create_thing(
      thing_name: "pixel_#{SecureRandom.base58}"
    )

    self.thing_name = thing.thing_name
    self.thing_arn = thing.thing_arn
    self.thing_id = thing.thing_id

    client.attach_thing_principal(
      thing_name: thing_name,
      principal: DEVICE_CERT_ARN
    )
  end

  def log(app, out, message = nil)
    message = message.presence && "\n\n#{JSON.pretty_generate(message)}\n\n"

    puts "#{app} -> #{out}#{message}"
  end

  def off(client)
    topic = "$aws/things/#{thing_name}/shadow/update"
    message = {
      state: {
        desired: nil,
        reported: {
          on: false
        }
      },
      # If used, the Device Shadow service processes the update only if the
      # specified version matches the latest version it has.
      # version: ?,
      clientToken: "MQTT/#{MQTT::VERSION} pixel/0.1"
    }

    log 'PIXEL', "publishing message to #{topic}", message

    client.publish(topic, message.to_json, false, 1)
  end

  def on(client)
    topic = "$aws/things/#{thing_name}/shadow/update"
    message = {
      state: {
        desired: nil,
        reported: {
          on: true
        }
      },
      # If used, the Device Shadow service processes the update only if the
      # specified version matches the latest version it has.
      # version: ?,
      clientToken: "MQTT/#{MQTT::VERSION} pixel/0.1"
    }

    log 'PIXEL', "publishing message to #{topic}", message

    client.publish(topic, message.to_json, false, 1)
  end

  def receive_state_changes
    host =
      Aws::IoT::Client.new
        .describe_endpoint(endpoint_type: 'iot:Data-ATS')
        .endpoint_address

    client = MQTT::Client.new(
      host: host,
      ssl: true,
      # TODO: Verify server SSL cert
      # ca_file: path_to('root-ca.pem'),
      cert: DEVICE_CERT,
      key: DEVICE_PRIVATE_KEY
    )

    client.connect(thing_name) do |c|
      c.get('$aws/things/#') do |topic, payload|
        payload = JSON.parse(payload)
        log 'PIXEL', "message received on #{topic}", payload

        delta_topic = topic.end_with?('/shadow/update/delta')

        on(client) if delta_topic && payload['state']['on']
        off(client) if delta_topic && payload['state']['on'] == false
      end
    end
  end

  def turn_on
    host =
      Aws::IoT::Client.new
        .describe_endpoint(endpoint_type: 'iot:Data-ATS')
        .endpoint_address

    client = MQTT::Client.new(
      host: host,
      ssl: true,
      # TODO: Verify server SSL cert
      # ca_file: path_to('root-ca.pem'),
      cert: CONTROL_PLANE_CERT,
      key: CONTROL_PLANE_PRIVATE_KEY
    )

    client.connect('control_plane') do |c|
      topic = "$aws/things/#{thing_name}/shadow/update"
      message = {
        state: {
          desired: {
            on: true
          }
        },
        # If used, the Device Shadow service processes the update only if the
        # specified version matches the latest version it has.
        # version: ?,
        clientToken: "MQTT/#{MQTT::VERSION} control_plane/0.1"
      }

      log 'CONTROL_PLANE', "publishing message to #{topic}", message

      c.publish(topic, message.to_json, false, 1)
    end
  end

  def turn_off
    host =
      Aws::IoT::Client.new
        .describe_endpoint(endpoint_type: 'iot:Data-ATS')
        .endpoint_address

    client = MQTT::Client.new(
      host: host,
      ssl: true,
      # TODO: Verify server SSL cert
      # ca_file: path_to('root-ca.pem'),
      cert: CONTROL_PLANE_CERT,
      key: CONTROL_PLANE_PRIVATE_KEY
    )

    client.connect('control_plane') do |c|
      topic = "$aws/things/#{thing_name}/shadow/update"
      message = {
        state: {
          desired: {
            on: false
          }
        },
        # If used, the Device Shadow service processes the update only if the
        # specified version matches the latest version it has.
        # version: ?,
        clientToken: "MQTT/#{MQTT::VERSION} control_plane/0.1"
      }

      log 'CONTROL_PLANE', "publishing message to #{topic}", message

      c.publish(topic, message.to_json, false, 1)
    end
  end
end
