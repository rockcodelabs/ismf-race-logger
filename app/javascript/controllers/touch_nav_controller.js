import { Controller } from "@hotwired/stimulus"

// Touch Navigation controller for horizontal top navigation bar
export default class extends Controller {
  static targets = ["menu", "hamburger"]

  connect() {
    console.log("🧭 Touch nav connected")
    this.isOpen = false
    this.closeMenu()
    
    // Setup Turbo cleanup
    this.handleTurboBeforeVisit = this.handleTurboBeforeVisit.bind(this)
    document.addEventListener("turbo:before-visit", this.handleTurboBeforeVisit)
  }

  disconnect() {
    console.log("🧭 Touch nav disconnecting")
    this.closeMenu()
    document.removeEventListener("turbo:before-visit", this.handleTurboBeforeVisit)
  }

  handleTurboBeforeVisit() {
    // Close menu before navigation
    this.closeMenu()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    this.isOpen ? this.closeMenu() : this.openMenu()
  }

  openMenu() {
    if (!this.hasMenuTarget) return
    
    this.menuTarget.classList.add("touch-menu-open")
    this.isOpen = true
  }

  closeMenu() {
    if (!this.hasMenuTarget) return
    
    this.menuTarget.classList.remove("touch-menu-open")
    this.isOpen = false
  }

  closeIfOutside(event) {
    if (event.target === this.menuTarget && this.isOpen) {
      this.closeMenu()
    }
  }

  goBack(event) {
    event.preventDefault()
    window.history.back()
  }
}