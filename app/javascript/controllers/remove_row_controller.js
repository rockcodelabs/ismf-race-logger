// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="remove-row"
//
// Intercepts Turbo Stream remove actions to animate the row
// before actually removing it from the DOM.
//
// Usage:
//   <tr data-controller="remove-row" id="participation_123">
//     ...
//   </tr>
//
// When Turbo Stream tries to remove this element, it will:
// 1. Fade out with slide right animation
// 2. Flash red background
// 3. Collapse height to zero
// 4. Remove from DOM
//
export default class extends Controller {
  static values = {
    duration: { type: Number, default: 500 }
  }

  connect() {
    // Intercept Turbo Stream remove actions
    this.streamActionHandler = this.handleStreamAction.bind(this)
    document.addEventListener("turbo:before-stream-render", this.streamActionHandler)
  }

  disconnect() {
    document.removeEventListener("turbo:before-stream-render", this.streamActionHandler)
  }

  handleStreamAction(event) {
    const { target, action } = event.detail.newStream
    
    // Only intercept remove actions for this specific element
    if (action === "remove" && target === this.element.id) {
      // Prevent immediate removal
      event.preventDefault()
      
      // Animate out, then remove
      this.animateAndRemove()
    }
  }

  // Trigger removal animation manually (can be called via action)
  remove() {
    this.animateAndRemove()
  }

  animateAndRemove() {
    const row = this.element
    
    // Store original height for collapse animation
    const originalHeight = row.offsetHeight
    
    // Set up initial state for animation
    row.style.position = "relative"
    row.style.transition = "all 0.4s cubic-bezier(0.4, 0, 0.2, 1)"
    
    // Force reflow
    row.offsetHeight
    
    // Phase 1: Fade and slide out (400ms)
    requestAnimationFrame(() => {
      row.style.opacity = "0"
      row.style.transform = "translateX(20px)"
      row.style.backgroundColor = "#fee2e2" // Light red flash
    })
    
    // Phase 2: Collapse height (300ms, starts after phase 1)
    setTimeout(() => {
      row.style.height = `${originalHeight}px`
      row.style.overflow = "hidden"
      row.style.transition = "all 0.3s cubic-bezier(0.4, 0, 0.2, 1)"
      
      requestAnimationFrame(() => {
        row.style.height = "0"
        row.style.paddingTop = "0"
        row.style.paddingBottom = "0"
        row.style.borderTopWidth = "0"
        row.style.borderBottomWidth = "0"
      })
      
      // Phase 3: Remove from DOM (after collapse completes)
      setTimeout(() => {
        row.remove()
      }, 300)
    }, 400)
  }
}