import { Controller } from "@hotwired/stimulus"

// Flash controller for auto-dismissing flash messages
//
// Usage:
//   <div data-controller="flash" data-flash-dismiss-after-value="5000">
//     Flash message content
//   </div>
//
// Values:
//   dismiss-after: Time in milliseconds before auto-dismiss (default: 5000)
//
export default class extends Controller {
  static values = {
    dismissAfter: { type: Number, default: 5000 }
  }

  connect() {
    // Start auto-dismiss timer if dismiss-after value is set
    if (this.dismissAfterValue > 0) {
      this.autoDismissTimer = setTimeout(() => {
        this.dismiss()
      }, this.dismissAfterValue)
    }
  }

  disconnect() {
    // Clean up timer when controller disconnects
    if (this.autoDismissTimer) {
      clearTimeout(this.autoDismissTimer)
    }
  }

  // Dismiss the flash message with animation
  dismiss() {
    // Add fade-out animation
    this.element.style.transition = "opacity 300ms ease-out, transform 300ms ease-out"
    this.element.style.opacity = "0"
    this.element.style.transform = "translateX(100%)"

    // Remove element after animation completes
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }

  // Action to manually dismiss (e.g., click on close button)
  // Usage: data-action="click->flash#close"
  close(event) {
    event.preventDefault()
    this.dismiss()
  }
}