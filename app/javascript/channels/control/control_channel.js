import consumer from "../consumer"

consumer.subscriptions.create("Control::ControlChannel", {
  connected() {
    // const addDevice = document.getElementById("add-device")
    //
    // addDevice.disabled = false
    //
    // addDevice.addEventListener(
    //   "click",
    //   function() {
    //     this.perform('add')
    //   }.bind(this)
    // )
  },

  disconnected() {
    // Called when the subscription has been terminated by the server
  },

  received(data) {
    console.log('control channel data received')
    console.log(data)
  }
});
