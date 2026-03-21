import { Controller } from "@hotwired/stimulus"

// Phone Reports Browse Controller
// Minimal controller for the phone view - video opening is handled by video-trigger
// This could be extended for phone-specific features in the future
//
export default class extends Controller {
  connect() {
    // Handle escape key to close the view gracefully
    this.boundEscapeHandler = this.handleEscape.bind(this)
    document.addEventListener("keydown", this.boundEscapeHandler)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundEscapeHandler)
  }

  handleEscape(event) {
    // Only if video modal is open
    const modal = document.getElementById("video-player-modal")
    if (event.key === "Escape" && modal && !modal.classList.contains("hidden")) {
      // Let video-player controller handle it
      const controller = this.application.getControllerForElementAndIdentifier(modal, "video-player")
      if (controller) {
        controller.close()
      }
    }
  }
}