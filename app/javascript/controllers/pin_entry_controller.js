import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="pin-entry"
export default class extends Controller {
  static targets = ["input", "submit", "dot1", "dot2", "dot3", "dot4"]
  
  connect() {
    console.log("🔢 PIN ENTRY CONTROLLER CONNECTED!")
    this.pin = ""
    this.updateDisplay()
  }
  
  addDigit(event) {
    event.preventDefault()
    const digit = event.currentTarget.dataset.digit
    console.log("Click detected! Digit:", digit)
    
    if (this.pin.length < 4) {
      this.pin += digit
      console.log("PIN is now:", this.pin)
      this.updateDisplay()
      
      if (this.pin.length === 4) {
        setTimeout(() => this.submitForm(), 300)
      }
    }
  }
  
  deleteDigit(event) {
    event.preventDefault()
    console.log("Delete clicked!")
    
    if (this.pin.length > 0) {
      this.pin = this.pin.slice(0, -1)
      console.log("PIN is now:", this.pin)
      this.updateDisplay()
    }
  }
  
  updateDisplay() {
    // Update hidden field
    if (this.hasInputTarget) {
      this.inputTarget.value = this.pin
    }
    
    // Update dots
    const dots = [
      this.hasDot1Target ? this.dot1Target : null,
      this.hasDot2Target ? this.dot2Target : null,
      this.hasDot3Target ? this.dot3Target : null,
      this.hasDot4Target ? this.dot4Target : null
    ]
    
    dots.forEach((dot, index) => {
      if (!dot) return
      
      if (index < this.pin.length) {
        dot.textContent = "●"
        dot.classList.remove("text-gray-400")
        dot.classList.add("text-ismf-primary")
      } else {
        dot.textContent = "•"
        dot.classList.remove("text-ismf-primary")
        dot.classList.add("text-gray-400")
      }
    })
    
    // Enable/disable submit
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = this.pin.length !== 4
    }
  }
  
  submitForm() {
    if (this.pin.length === 4) {
      console.log("Submitting form with PIN:", this.pin)
      const form = this.element.closest("form") || this.element.querySelector("form")
      if (form) {
        form.requestSubmit()
      }
    }
  }
}