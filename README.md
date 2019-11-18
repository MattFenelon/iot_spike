# IOT Spike

An exploratory into the world of IoT.

## Getting started

* Create a certificate to be used by all devices and set `DEVICE_CERT`,
  `DEVICE_CERT_ARN`, `DEVICE_PUBLIC_KEY` and `DEVICE_PRIVATE_KEY`.
  * Activate
  * Attach policies:
    * `aws/policies/pixel_connect.json`
    * `aws/policies/pixel_subscribe.json`
    * `aws/policies/pixel_receive.json`
    * `aws/policies/pixel_publish.json`
* Create a control plane certificate and set
  `CONTROL_PLANE_CERT`,`CONTROL_PLANE_PUBLIC_KEY` and
  `CONTROL_PLANE_PRIVATE_KEY`.
  * Activate
