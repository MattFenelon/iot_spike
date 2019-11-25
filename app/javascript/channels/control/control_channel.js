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
    const name = data[0].name
    const state = data[0].state
    const container = document.getElementById('pixel-container')
    var pixel = container.querySelector(`[data-pixel-name='${name}']`)

    if (!pixel) {
      pixel = document.createElement('div')
      pixel.style.backgroundColor = 'grey'
      pixel.style.width = '50px'
      pixel.style.height = '50px'
      pixel.dataset.pixelName = name
      container.append(pixel)
    }

    pixel.style.backgroundColor = state.on ? 'yellow' : 'grey'
  }
});
