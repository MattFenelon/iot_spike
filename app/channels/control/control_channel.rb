# frozen_string_literal: true

module Control
  class ControlChannel < ApplicationCable::Channel
    def power(data)
      turning_on = data['on']
      Rails.logger.debug("power #{turning_on ? 'on' : 'off'}")

      if turning_on
        control_plane.pixels_on
      else
        control_plane.pixels_off
      end
    end

    def subscribed
      Rails.logger.debug "#{self} -> subscribed"

      @control_plane = Control::ControlPlane.new
      stream_for @control_plane

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

      @control_plane_thread = Thread.new do
        control_plane.receive_state_changes
      end
      # sleep 5
      @pixel_threads = Device::Pixel.all.map do |pixel|
        Thread.new do
          pixel.receive_state_changes
        end
      end
    end

    def unsubscribed
      control_plane_thread&.kill
      pixel_threads.to_a.each(&:kill)
    end

    private

    attr_accessor :control_plane
    attr_accessor :control_plane_thread
    attr_accessor :pixel_threads

    def serialise(name, state)
      {
        name: name,
        state: state
      }
    end
  end
end
