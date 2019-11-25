# frozen_string_literal: true

module Control
  class ControlPlane
    CONTROL_PLANE_CERT = ENV['CONTROL_PLANE_CERT']
    CONTROL_PLANE_PRIVATE_KEY = ENV['CONTROL_PLANE_PRIVATE_KEY']
    CONTROL_PLANE_PUBLIC_KEY = ENV['CONTROL_PLANE_PUBLIC_KEY']

    def pixels_on
      pixels_change_state(on: true)
    end

    def pixels_off
      pixels_change_state(on: false)
    end

    def receive_state_changes
      connect do |connected_client|
        connected_client.get('$aws/things/#') do |topic, payload|
          payload = JSON.parse(payload)
          log 'CONTROL_PLANE', "message received on #{topic}", payload

          topic_parts = topic.split('/')
          accepted_topic = topic_parts[-2..-1] == %w[update accepted]
          thing_name = topic_parts[2]

          next if accepted_topic == false

          # TODO: Encapsulate this in the channel somehow (public methods are
          # made available as actions by default.)
          Control::ControlChannel.broadcast_to(
            self,
            [
              {
                name: thing_name,
                state: payload['state']['reported']
              }
            ]
          )
        end
      end
    end

    private

    def connect
      if @connected_client
        yield @connected_client
      else
        mqtt_client.connect('control_plane') do |connected_client|
          @connected_client = connected_client
          yield connected_client
          @connected_client = nil
        end
      end
    end

    def log(app, out, message = nil)
      message = message.presence && "\n#{JSON.pretty_generate(message)}\n\n"

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
        cert: CONTROL_PLANE_CERT,
        key: CONTROL_PLANE_PRIVATE_KEY
      )
    end

    def pixels_change_state(desired_state)
      connect do |c|
        Device::Pixel.each do |thing|
          topic = "$aws/things/#{thing.thing_name}/shadow/update"
          message = {
            state: {
              desired: desired_state
            },
            # If used, the Device Shadow service processes the update only if
            # the specified version matches the latest version it has.
            # version: ?,
            clientToken: "MQTT/#{MQTT::VERSION} control_plane/0.1"
          }

          log 'CONTROL_PLANE', "publishing message to #{topic}", message

          c.publish(topic, message.to_json, false, 1)
        end
      end
    end
  end
end
