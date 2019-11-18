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

  def off
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
      puts 'publishing...'
      c.publish(
        "$aws/things/#{thing_name}/shadow/update",
        {
          state: {
            reported: {
              on: false
            }
          },
          # If used, the Device Shadow service processes the update only if the
          # specified version matches the latest version it has.
          # version: ?,
          clientToken: "MQTT/#{MQTT::VERSION} pixel/0.1"
        }.to_json,
        false,
        1
      )
    end
  end

  def on
    # TODO: Should the device make this call or have it baked in?
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
      puts 'publishing...'
      c.publish(
        "$aws/things/#{thing_name}/shadow/update",
        {
          state: {
            reported: {
              on: true
            }
          },
          # If used, the Device Shadow service processes the update only if the
          # specified version matches the latest version it has.
          # version: ?,
          clientToken: "MQTT/#{MQTT::VERSION} pixel/0.1"
        }.to_json,
        false,
        1
      )
    end
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

    puts 'connecting...'
    client.connect(thing_name) do |c|
      puts 'waiting for message...'
      c.get('$aws/things/#') do |topic, payload|
        payload = JSON.parse(payload)
        puts "message received on #{topic}:\n#{payload}"

        puts 'waiting for message...'
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
      puts 'publishing...'
      c.publish(
        "$aws/things/#{thing_name}/shadow/update",
        {
          state: {
            desired: {
              on: true
            }
          },
          # If used, the Device Shadow service processes the update only if the
          # specified version matches the latest version it has.
          # version: ?,
          clientToken: "MQTT/#{MQTT::VERSION} control_plane/0.1"
        }.to_json,
        false,
        1
      )
    end
  end
end
