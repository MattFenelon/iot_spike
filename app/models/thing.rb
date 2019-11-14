# frozen_string_literal: true

class Thing < ApplicationRecord
  before_create(
    :aws_iot_create_keys_and_certificate,
    :aws_iot_attach_policy,
    :aws_iot_create_thing
  )

  def aws_iot_attach_policy
    # TODO: Programatically create policy
    client = Aws::IoT::Client.new
    %w[PixelConnect PixelSubscribe PixelPublish PixelReceive].each do |name|
      client.attach_policy(
        policy_name: name,
        target: certificate_arn
      )
    end
  end

  def aws_iot_create_keys_and_certificate
    client = Aws::IoT::Client.new
    keys_and_cert = client.create_keys_and_certificate(
      # Can be used to check if a certificate is on a Certificate Revocation
      # List (CRL).
      #
      # 1. Create the certificate, deactivated
      # 2. Wait for the device to initiate connection
      # 3. Check the CRL
      #   a. If on the CRL - Go no further
      # 4. Activate the certificate
      set_as_active: true
    )

    self.certificate_arn = keys_and_cert.certificate_arn
    self.certificate_id = keys_and_cert.certificate_id
    self.certificate_pem = keys_and_cert.certificate_pem
    self.key_pair_public_key = keys_and_cert.key_pair.public_key
    self.key_pair_private_key = keys_and_cert.key_pair.private_key
  end

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
      principal: certificate_arn
    )
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
      cert: certificate_pem,
      key: key_pair_private_key
      # TODO: Verify server SSL cert
      # ca_file: path_to('root-ca.pem')
    )

    puts 'connecting...'
    client.connect(thing_name)
    puts 'publishing...'
    client.publish(
      "$aws/things/#{thing_name}/shadow/update",
      {
        state: {
          reported: {
            on: true
          }
        },
        clientToken: "MQTT/#{MQTT::VERSION} pixel/0.1"
      }.to_json
    )
    puts 'disconnecting...'
    client.disconnect
  end
end
