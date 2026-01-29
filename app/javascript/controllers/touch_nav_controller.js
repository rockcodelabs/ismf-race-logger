import { Controller } from "@hotwired/stimulus"

// Touch Navigation controller for collapsible navigation bar
//
// Handles navigation bar behavior on touch displays:
// - Collapsible hamburger menu
// - Auto-hide on scroll down
// - Auto-show on scroll up
//
// Usage:
//   <nav data-controller="touch-nav" data-touch-nav-target="navbar">
//     <button data-action="click->touch-nav#toggle">Menu</button>
//   </nav>
//
export default class extends Controller {
  static targets = ["navbar"]

  connect() {
    console.log("🧭 Touch navigation controller connected")
    
    this.isExpanded = true
    this.lastScrollY = window.scrollY
    
    this.setupScrollListener()
  }

  disconnect() {
    if (this.handleScroll) {
      window.removeEventListener("scroll", this.handleScroll)
    }
  }

  setupScrollListener() {
    this.handleScroll = this.handleScroll.bind(this)
    window.addEventListener("scroll", this.handleScroll, { passive: true })
  }

  handleScroll() {
    const currentScrollY = window.scrollY
    
    // Hide nav when scrolling down (after 100px)
    if (currentScrollY > 100 && currentScrollY > this.lastScrollY) {
      this.hideNav()
    }
    // Show nav when scrolling up
    else if (currentScrollY < this.lastScrollY) {
      this.showNav()
    }
    
    this.lastScrollY = currentScrollY
  }

  // Action to toggle navigation visibility
  // Usage: data-action="click->touch-nav#toggle"
  toggle(event) {
    if (event) {
      event.preventDefault()
    }
    
    this.isExpanded = !this.isExpanded
    
    if (this.isExpanded) {
      this.showNav()
    } else {
      this.hideNav()
    }
    
    console.log("🔄 Nav toggled:", this.isExpanded ? "expanded" : "collapsed")
  }

  showNav() {
    if (this.hasNavbarTarget) {
      this.navbarTarget.classList.remove("nav-hidden")
      this.isExpanded = true
    }
  }

  hideNav() {
    if (this.hasNavbarTarget) {
      this.navbarTarget.classList.add("nav-hidden")
      this.isExpanded = false
    }
  }

  // Action to go back
  // Usage: data-action="click->touch-nav#goBack"
  goBack(event) {
    event.preventDefault()
    console.log("⬅️ Going back...")
    window.history.back()
  }

  // Action to go home
  // Usage: data-action="click->touch-nav#goHome"
  goHome(event) {
    event.preventDefault()
    console.log("🏠 Going home...")
    window.location.href = "/"
  }
}