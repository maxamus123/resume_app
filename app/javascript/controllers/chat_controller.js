import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "messages", 
    "question", 
    "form", 
    "carouselTrack", 
    "carouselDot", 
    "carouselPrev", 
    "carouselNext", 
    "suggestedQuestion"
  ]
  
  connect() {
    this.currentSlide = 0
    this.totalSlides = this.suggestedQuestionTargets.length
    this.updateCarousel()
  }
  
  // Form submission handling
  submit(event) {
    event.preventDefault()
    
    const question = this.questionTarget.value.trim()
    if (!question) return
    
    // Add user message to chat
    const messageId = this.addMessage('You', question, 'bg-gray-100')
    
    // Create a message bubble for the AI response
    const loadingId = this.addMessage('AI Assistant', '', 'bg-blue-50')
    
    // Get the current message element for streaming updates
    const loadingElement = document.getElementById(loadingId).querySelector('p:nth-child(2)')
    
    // Use Server-Sent Events for streaming
    const eventSource = new EventSource(`/chat/stream_message?question=${encodeURIComponent(question)}`)
    
    let responseText = ''
    
    eventSource.addEventListener('start', (e) => {
      // Initialize the streaming message
      loadingElement.textContent = ''
    })
    
    eventSource.addEventListener('message', (e) => {
      // Append the chunk to our accumulated response
      responseText += JSON.parse(e.data)
      loadingElement.textContent = responseText
      
      // Scroll to see new content
      this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    })
    
    eventSource.addEventListener('error', (e) => {
      console.error('SSE Error:', e)
      loadingElement.textContent = 'Sorry, I encountered an error processing your request.'
      eventSource.close()
    })
    
    eventSource.addEventListener('done', (e) => {
      // Complete the streaming response
      eventSource.close()
    })
    
    // Clear input
    this.questionTarget.value = ''
  }
  
  // Handle suggested question selection
  selectQuestion(event) {
    const questionText = event.currentTarget.textContent.trim()
    this.questionTarget.value = questionText
    
    // Automatically submit the form when clicking on a suggested question
    if (questionText) {
      // Trigger the form submission
      this.formTarget.dispatchEvent(new Event('submit', { cancelable: true }))
    }
  }
  
  // Carousel navigation methods
  prevSlide() {
    this.currentSlide = (this.currentSlide - 1 + this.totalSlides) % this.totalSlides
    this.updateCarousel()
  }
  
  nextSlide() {
    this.currentSlide = (this.currentSlide + 1) % this.totalSlides
    this.updateCarousel()
  }
  
  goToSlide(event) {
    const dotIndex = this.carouselDotTargets.indexOf(event.currentTarget)
    if (dotIndex !== -1) {
      this.currentSlide = dotIndex
      this.updateCarousel()
    }
  }
  
  // Update carousel position and indicators
  updateCarousel() {
    this.carouselTrackTarget.style.transform = `translateX(-${this.currentSlide * 100}%)`
    
    // Update indicators
    this.carouselDotTargets.forEach((dot, index) => {
      if (index === this.currentSlide) {
        dot.classList.remove('bg-gray-300')
        dot.classList.add('bg-blue-600')
      } else {
        dot.classList.remove('bg-blue-600')
        dot.classList.add('bg-gray-300')
      }
    })
  }
  
  // Helper to add a message to the chat
  addMessage(sender, content, bgClass) {
    const messageId = 'msg-' + Date.now()
    const messageDiv = document.createElement('div')
    messageDiv.id = messageId
    messageDiv.className = `${bgClass} p-2 sm:p-3 rounded-lg`
    
    // Create message content with proper escaping
    const senderElement = document.createElement('p')
    senderElement.className = 'font-medium text-gray-800 text-sm sm:text-base'
    senderElement.textContent = sender
    
    const contentElement = document.createElement('p')
    contentElement.className = 'text-sm sm:text-base'
    contentElement.textContent = content
    
    // Append elements to message div
    messageDiv.appendChild(senderElement)
    messageDiv.appendChild(contentElement)
    
    // Add message to container
    this.messagesTarget.appendChild(messageDiv)
    
    // Scroll to bottom
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    
    return messageId
  }
  
  removeMessage(messageId) {
    const message = document.getElementById(messageId)
    if (message) {
      message.remove()
    }
  }
} 