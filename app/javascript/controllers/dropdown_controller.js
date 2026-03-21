import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="dropdown"
// Toggles a dropdown panel open/closed on button click.
// Closes automatically when clicking outside the element.
//
// Usage:
//   <div data-controller="dropdown">
//     <button data-action="click->dropdown#toggle">Open</button>
//     <div data-dropdown-target="panel" class="hidden ...">...</div>
//   </div>
export default class extends Controller {
  static targets = ["panel"]

  connect() {
    this.boundClose = this.closeOnOutsideClick.bind(this)
  }

  disconnect() {
    document.removeEventListener("click", this.boundClose, true)
  }

  toggle(event) {
    event.stopPropagation()
    this.isOpen ? this.close() : this.open()
  }

  open() {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.remove("hidden")
    this.isOpen = true
    // Defer so this click doesn't immediately re-close the panel
    setTimeout(() => document.addEventListener("click", this.boundClose, true), 0)
  }

  close() {
    if (!this.hasPanelTarget) return
    this.panelTarget.classList.add("hidden")
    this.isOpen = false
    document.removeEventListener("click", this.boundClose, true)
  }

  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
}