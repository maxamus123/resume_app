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
    this.currentEventSource = null
  }

  disconnect() {
    this.closeCurrentEventSource()
  }

  // Helper to close any active EventSource connection
  closeCurrentEventSource() {
    if (this.currentEventSource) {
      console.log('Closing existing event source connection')
      try {
        this.currentEventSource.close()
      } catch (e) {
        console.error('Error closing event source:', e)
      }
      this.currentEventSource = null
    }
  }

  submit(event) {
    event.preventDefault()
    this.closeCurrentEventSource()

    const question = this.questionTarget.value.trim()
    if (!question) return

    // Add user message and a loading placeholder for the AI response
    this.addMessage('You', question, 'bg-gray-100')
    const loadingId = this.addMessage('AI Assistant', 'Thinking...', 'bg-blue-50')
    
    // Improved element selection with more specific logging
    const loadingElement = document.getElementById(loadingId)?.querySelector('p[data-sender="AI Assistant"]')
    if (!loadingElement) {
      console.error(`Could not find loading element with id ${loadingId}`)
    }

    const eventSource = new EventSource(`/chat/stream_message?question=${encodeURIComponent(question)}`)
    this.currentEventSource = eventSource
    let responseText = ''

    eventSource.addEventListener('start', () => {
      if (loadingElement) {
        loadingElement.textContent = ''
        responseText = ''
        console.log('Start event received, cleared response text')
      } else {
        console.error('Start event received but loading element not found')
      }
    })

    eventSource.addEventListener('message', (e) => {
      try {
        console.log('Message event received:', e.data)
        const chunk = JSON.parse(e.data)
        responseText += chunk
        
        // Re-query the element each time to ensure we have the current reference
        const messageElement = document.getElementById(loadingId)?.querySelector('p[data-sender="AI Assistant"]')
        if (messageElement) {
          messageElement.textContent = responseText
          this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
        } else {
          console.error(`Message element with id ${loadingId} not found during message event`)
        }
      } catch (error) {
        console.error('Error parsing stream data:', error, 'Raw data:', e.data)
        
        // Re-query the element
        const messageElement = document.getElementById(loadingId)?.querySelector('p[data-sender="AI Assistant"]')
        if (messageElement) {
          if (messageElement.textContent === 'Thinking...') {
            messageElement.textContent = 'Sorry, an error occurred processing the response.'
          }
        } else {
          console.error(`Message element with id ${loadingId} not found during error handling`)
        }
      }
    })

    eventSource.addEventListener('error', (e) => {
      console.error('SSE Error:', e)
      // Re-query the element
      const messageElement = document.getElementById(loadingId)?.querySelector('p[data-sender="AI Assistant"]')
      if (messageElement && messageElement.textContent === 'Thinking...') {
        messageElement.textContent = 'Sorry, an error occurred processing your request.'
      }
      eventSource.close()
      if (this.currentEventSource === eventSource) {
        this.currentEventSource = null
      }
    })

    eventSource.addEventListener('end', () => {
      console.log('End event received')
      eventSource.close()
      if (this.currentEventSource === eventSource) {
        this.currentEventSource = null
      }
      this.questionTarget.value = ''
      
      // Re-query the element
      const messageElement = document.getElementById(loadingId)?.querySelector('p[data-sender="AI Assistant"]')
      if (messageElement) {
        if (!responseText.trim() || messageElement.textContent === 'Thinking...') {
          messageElement.textContent = 'No response received. Please try again.'
        }
        // Log the response for debugging
        console.log('Final response text:', responseText || 'empty response')
      } else {
        console.error(`Message element with id ${loadingId} not found during end event`)
      }
    })
  }

  selectQuestion(event) {
    this.closeCurrentEventSource()
    const questionText = event.currentTarget.textContent.trim()
    this.questionTarget.value = questionText

    // Automatically submit if there is a suggested question
    if (questionText) {
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
    const index = this.carouselDotTargets.indexOf(event.currentTarget)
    if (index !== -1) {
      this.currentSlide = index
      this.updateCarousel()
    }
  }

  updateCarousel() {
    this.carouselTrackTarget.style.transform = `translateX(-${this.currentSlide * 100}%)`
    this.carouselDotTargets.forEach((dot, index) => {
      dot.classList.toggle('bg-blue-600', index === this.currentSlide)
      dot.classList.toggle('bg-gray-300', index !== this.currentSlide)
    })
  }

  // Adds a message to the chat container and scrolls to the bottom
  addMessage(sender, content, bgClass) {
    // Generate a unique ID for this message
    const messageId = `msg-${Date.now()}-${Math.floor(Math.random() * 1000)}`
    console.log(`Creating new message with ID: ${messageId}`)
    
    const messageDiv = document.createElement('div')
    messageDiv.id = messageId
    messageDiv.className = `${bgClass} p-3 sm:p-4 rounded-lg`

    const senderElement = document.createElement('p')
    senderElement.className = 'font-medium text-gray-800 text-sm sm:text-base'
    senderElement.textContent = sender

    const contentElement = document.createElement('p')
    contentElement.className = 'text-sm sm:text-base message-content'
    contentElement.dataset.sender = sender
    contentElement.textContent = content

    messageDiv.appendChild(senderElement)
    messageDiv.appendChild(contentElement)
    this.messagesTarget.appendChild(messageDiv)
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight
    
    // Verify the element was created successfully
    const addedElement = document.getElementById(messageId)
    if (!addedElement) {
      console.error(`Failed to add message with ID: ${messageId}`)
    }

    return messageId
  }

  removeMessage(messageId) {
    const message = document.getElementById(messageId)
    if (message) {
      message.remove()
    }
  }
}
