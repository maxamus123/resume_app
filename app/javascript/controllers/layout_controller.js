import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chatPanel", "chatToggle", "chatToggleContainer", "chatClose"]

  connect() {
    this.isChatOpen = false
    this.boundUpdateDisplay = this.updateDisplay.bind(this)
    this.updateDisplay()
    window.addEventListener('resize', this.boundUpdateDisplay)
  }

  disconnect() {
    window.removeEventListener('resize', this.boundUpdateDisplay)
  }

  updateDisplay() {
    if (window.innerWidth >= 1024) { // Desktop
      this.chatPanelTarget.classList.remove('translate-y-full')
      this.setToggleDisplay('none')
    } else { // Mobile
      this.chatPanelTarget.classList.toggle('translate-y-full', !this.isChatOpen)
      this.setToggleDisplay(this.isChatOpen ? 'none' : 'block')
    }
  }

  setToggleDisplay(value) {
    if (this.hasChatToggleContainerTarget) {
      this.chatToggleContainerTarget.style.display = value
    }
  }

  toggleChat() {
    this.isChatOpen = !this.isChatOpen
    this.updateDisplay()
  }

  closeChat() {
    this.isChatOpen = false
    this.updateDisplay()
  }
}
