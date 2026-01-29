import { Controller } from "@hotwired/stimulus"

// Touch Navigation controller for horizontal top navigation bar
//
// Features:
// - Floating hamburger button (top-left)
// - Horizontal menu bar that slides down from top
// - Toggle menu open/closed
// - Menu items displayed horizontally in a row
//
// Usage:
//   <div data-controller="touch-nav">
//     <button data-action="click->touch-nav#toggle">Menu</button>
//     <div data-touch-nav-target="menu">...</div>
//   </div>
//
export default class extends Controller {
  static targets = ["menu", "hamburger"]

  connect() {
    console.log("🧭 Touch navigation controller connected")
    this.isOpen = false
  }

  disconnect() {
    // Cleanup if needed
  }

  // Toggle menu open/closed
  // Usage: data-action="click->touch-nav#toggle"
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    this.isOpen = !this.isOpen
    
    if (this.isOpen) {
      this.openMenu()
    } else {
      this.closeMenu()
    }
    
    console.log("🔄 Menu toggled:", this.isOpen ? "open" : "closed")
  }

  openMenu() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.add("touch-menu-open")
      this.isOpen = true
    }
  }

  closeMenu() {
    if (this.hasMenuTarget) {
      this.menuTarget.classList.remove("touch-menu-open")
      this.isOpen = false
    }
  }

  // Close menu if clicking outside (on the visible content area)
  // Usage: data-action="click->touch-nav#closeIfOutside"
  closeIfOutside(event) {
    // Check if click is on the menu panel itself (not the content inside)
    if (event.target === this.menuTarget && this.isOpen) {
      console.log("👆 Clicked outside menu, closing...")
      this.closeMenu()
    }
  }

  // Go back in browser history
  // Usage: data-action="click->touch-nav#goBack"
  goBack(event) {
    event.preventDefault()
    console.log("⬅️ Going back...")
    window.history.back()
  }
}