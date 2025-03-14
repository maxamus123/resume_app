import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = [
    "messages",
    "question",
    "form",
    "carouselTrack",
    "carouselDot",
    "suggestedQuestion"
  ];

  initialize() {
    // Bind once for proper cleanup
    this.boundHandleKeydown = this.handleKeydown.bind(this);
  }

  connect() {
    this.currentSlide = 0;
    this.totalSlides = this.suggestedQuestionTargets.length;
    this.updateCarousel();
    this.currentEventSource = null;
    this.questionTarget.addEventListener("keydown", this.boundHandleKeydown);
  }

  disconnect() {
    this.closeCurrentEventSource();
    this.questionTarget.removeEventListener("keydown", this.boundHandleKeydown);
  }

  // --- Event Handlers ---

  handleKeydown(event) {
    if (event.key === "Enter" && !event.shiftKey) {
      event.preventDefault();
      this.formTarget.dispatchEvent(new Event("submit", { cancelable: true }));
    }
  }

  closeCurrentEventSource() {
    if (this.currentEventSource) {
      try {
        this.currentEventSource.close();
      } catch (e) {
        console.error(e);
      }
      this.currentEventSource = null;
    }
  }

  submit(event) {
    event.preventDefault();
    this.closeCurrentEventSource();

    const question = this.questionTarget.value.trim();
    if (!question) return;

    this.addMessage("You", question, "bg-gray-100");
    const loadingId = this.addMessage("AI Assistant", "Thinking...", "bg-blue-50");
    this.questionTarget.value = "";

    // Helper to get the AI message element
    const getMsgElem = () =>
        document.getElementById(loadingId)?.querySelector('p[data-sender="AI Assistant"]');

    const eventSource = new EventSource(
        `/chat/stream_message?question=${encodeURIComponent(question)}`
    );
    this.currentEventSource = eventSource;
    let responseText = "";

    eventSource.addEventListener("start", () => {
      const elem = getMsgElem();
      if (elem) {
        elem.textContent = "";
        responseText = "";
      }
    });

    eventSource.addEventListener("message", (e) => {
      try {
        const chunk = JSON.parse(e.data);
        responseText += chunk;
        const elem = getMsgElem();
        if (elem) {
          elem.textContent = responseText;
          this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
        }
      } catch (err) {
        const elem = getMsgElem();
        if (elem && elem.textContent === "Thinking...") {
          elem.textContent = "Sorry, an error occurred processing the response.";
        }
      }
    });

    eventSource.addEventListener("error", () => {
      const elem = getMsgElem();
      if (elem && elem.textContent === "Thinking...") {
        elem.textContent = "Sorry, an error occurred processing your request.";
      }
      eventSource.close();
      if (this.currentEventSource === eventSource) this.currentEventSource = null;
    });

    eventSource.addEventListener("end", () => {
      eventSource.close();
      if (this.currentEventSource === eventSource) this.currentEventSource = null;
      const elem = getMsgElem();
      if (elem && (!responseText.trim() || elem.textContent === "Thinking...")) {
        elem.textContent = "No response received. Please try again.";
      }
    });
  }

  selectQuestion(event) {
    this.closeCurrentEventSource();
    const text = event.currentTarget.textContent.trim();
    this.questionTarget.value = text;
    if (text) this.formTarget.dispatchEvent(new Event("submit", { cancelable: true }));
  }

  // --- Carousel Functions ---

  prevSlide() {
    this.currentSlide = (this.currentSlide - 1 + this.totalSlides) % this.totalSlides;
    this.updateCarousel();
  }

  nextSlide() {
    this.currentSlide = (this.currentSlide + 1) % this.totalSlides;
    this.updateCarousel();
  }

  goToSlide(event) {
    const index = this.carouselDotTargets.indexOf(event.currentTarget);
    if (index !== -1) {
      this.currentSlide = index;
      this.updateCarousel();
    }
  }

  updateCarousel() {
    this.carouselTrackTarget.style.transform = `translateX(-${this.currentSlide * 100}%)`;
    this.carouselDotTargets.forEach((dot, i) => {
      dot.classList.toggle("bg-blue-600", i === this.currentSlide);
      dot.classList.toggle("bg-gray-300", i !== this.currentSlide);
    });
  }

  // --- Message Management ---

  addMessage(sender, content, bgClass) {
    const id = `msg-${Date.now()}-${Math.floor(Math.random() * 1000)}`;
    const msgDiv = document.createElement("div");
    msgDiv.id = id;
    msgDiv.className = `${bgClass} p-3 sm:p-4 rounded-lg`;

    const senderElem = document.createElement("p");
    senderElem.className = "font-medium text-gray-800 text-sm sm:text-base";
    senderElem.textContent = sender;

    const contentElem = document.createElement("p");
    contentElem.className = "text-sm sm:text-base message-content";
    contentElem.dataset.sender = sender;
    contentElem.textContent = content;

    msgDiv.append(senderElem, contentElem);
    this.messagesTarget.appendChild(msgDiv);
    this.messagesTarget.scrollTop = this.messagesTarget.scrollHeight;
    return id;
  }

  removeMessage(id) {
    const msg = document.getElementById(id);
    if (msg) msg.remove();
  }
}
