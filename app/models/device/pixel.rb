# frozen_string_literal: true

module Device
  class Pixel < ApplicationRecord
    DEVICE_CERT = ENV['DEVICE_CERT']
    DEVICE_CERT_ARN = ENV['DEVICE_CERT_ARN']
    DEVICE_PRIVATE_KEY = ENV['DEVICE_PRIVATE_KEY']

    before_create :aws_iot_create_thing

    def off
      report_state(on: false)
    end

    def on
      report_state(on: true)
    end

    def receive_state_changes
      connect do |connected_client|
        connected_client.get('$aws/things/#') do |topic, payload|
          payload = JSON.parse(payload)
          log 'PIXEL', "message received on #{topic}", payload

          delta_topic = topic.end_with?('/shadow/update/delta')

          on(client) if delta_topic && payload['state']['on']
          off(client) if delta_topic && payload['state']['on'] == false
        end
      end
    end

    private

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

    def connect
      if @connected_client
        yield @connected_client
      else
        mqtt_client.connect(thing_name) do |connected_client|
          @connected_client = connected_client
          yield connected_client
          @connected_client = nil
        end
      end
    end

    def log(app, out, message = nil)
      message = message.presence && "\n\n#{JSON.pretty_generate(message)}\n\n"

      puts "#{app} -> #{out}#{message}"
    end

    def mqtt_client
      host =
        Aws::IoT::Client.new
          .describe_endpoint(endpoint_type: 'iot:Data-ATS')
          .endpoint_address

      MQTT::Client.new(
        host: host,
        ssl: true,
        # TODO: Verify server SSL cert
        # ca_file: path_to('root-ca.pem'),
        cert: DEVICE_CERT,
        key: DEVICE_PRIVATE_KEY
      )
    end

    def report_state(new_state)
      connect do |connected_client|
        topic = "$aws/things/#{thing_name}/shadow/update"
        message = {
          state: {
            desired: nil,
            reported: new_state
          },
          # If used, the Device Shadow service processes the update only if the
          # specified version matches the latest version it has.
          # version: ?,
          clientToken: "MQTT/#{MQTT::VERSION} pixel/0.1"
        }

        log 'PIXEL', "publishing message to #{topic}", message

        connected_client.publish(topic, message.to_json, false, 1)
      end
    end
  end
end
