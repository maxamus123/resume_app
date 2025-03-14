import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chatPanel", "chatToggle", "chatToggleContainer", "chatClose"]
  
  connect() {
    this.isChatOpen = false
    this.handleResponsiveLayout()
    
    // Listen for window resize and adjust layout accordingly
    window.addEventListener('resize', this.handleResponsiveLayout.bind(this))
  }
  
  disconnect() {
    // Clean up event listener
    window.removeEventListener('resize', this.handleResponsiveLayout.bind(this))
  }
  
  // Function to handle responsive layout
  handleResponsiveLayout() {
    if (window.innerWidth >= 1024) { // lg breakpoint in Tailwind
      // On desktop: Always show chat panel
      this.chatPanelTarget.classList.remove('translate-y-full')
      // Hide toggle on desktop since chat is always visible
      if (this.hasChatToggleContainerTarget) {
        this.chatToggleContainerTarget.style.display = 'none'
      }
    } else {
      // On mobile: Hide by default unless explicitly opened
      if (!this.isChatOpen) {
        this.chatPanelTarget.classList.add('translate-y-full')
        // Show toggle when chat is closed
        if (this.hasChatToggleContainerTarget) {
          this.chatToggleContainerTarget.style.display = 'block'
        }
      } else {
        // Hide toggle when chat is open
        if (this.hasChatToggleContainerTarget) {
          this.chatToggleContainerTarget.style.display = 'none'
        }
      }
    }
  }
  
  // Toggle chat panel visibility
  toggleChat() {
    this.isChatOpen = !this.isChatOpen
    
    if (this.isChatOpen) {
      this.chatPanelTarget.classList.remove('translate-y-full')
      // Hide toggle when chat is open
      if (this.hasChatToggleContainerTarget) {
        this.chatToggleContainerTarget.style.display = 'none'
      }
    } else {
      this.chatPanelTarget.classList.add('translate-y-full')
      // Show toggle when chat is closed
      if (this.hasChatToggleContainerTarget) {
        this.chatToggleContainerTarget.style.display = 'block'
      }
    }
  }
  
  // Close chat panel
  closeChat() {
    this.isChatOpen = false
    this.chatPanelTarget.classList.add('translate-y-full')
    // Show toggle when chat is closed
    if (this.hasChatToggleContainerTarget) {
      this.chatToggleContainerTarget.style.display = 'block'
    }
  }
} 