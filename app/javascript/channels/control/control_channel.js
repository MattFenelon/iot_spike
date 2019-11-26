import consumer from "../consumer"

consumer.subscriptions.create("Control::ControlChannel", {
  connected() {
    const pixelController = document.getElementById('pixel-controller')

    pixelController.disabled = false
    pixelController.dataset.action = true

    pixelController.addEventListener(
      "click",
      function(event) {
        const button = event.target
        const turningOn = button.dataset.action == 'true'

        this.perform('power', { on: turningOn })

        button.dataset.action = turningOn ? false : true
        button.innerText = turningOn ? 'Off' : 'On'
      }.bind(this)
    )
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
