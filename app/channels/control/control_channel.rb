# frozen_string_literal: true

module Control
  class ControlChannel < ApplicationCable::Channel
    def subscribed
      Rails.logger.debug "#{self} -> subscribed"

      client = Aws::IoT::Client.new
      iot_endpoint =
        Aws::IoT::Client.new
          .describe_endpoint(endpoint_type: 'iot:Data-ATS')
          .endpoint_address

      data_plane_client = Aws::IoTDataPlane::Client.new(
        endpoint: "https://#{iot_endpoint}"
      )

      things = client.list_things.things.map do |thing|
        shadow = data_plane_client
          .get_thing_shadow(thing_name: thing.thing_name)
          .payload.string

        state = JSON.parse(shadow)['state']['reported']

        serialise(thing.thing_name, state)
      end

      transmit(things)

      control_plane = Control::ControlPlane.new
      control_plane.receive_state_changes do |thing_name, state|
        transmit([serialise(thing_name, state)])
      end
    end

    private

    def serialise(name, state)
      {
        name: name,
        state: state
      }
    end
  end
end
