// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="swipe-delete"
//
// Provides iOS-style swipe-to-delete functionality for touch devices.
// Swipe right to reveal delete button, swipe further to trigger deletion.
//
// Usage:
//   <div data-controller="swipe-delete"
//        data-swipe-delete-url-value="/path/to/delete"
//        data-swipe-delete-name-value="Item Name">
//     <div data-swipe-delete-target="deleteBackground">Delete UI</div>
//     <div data-swipe-delete-target="card"
//          data-action="touchstart->swipe-delete#touchStart
//                      touchmove->swipe-delete#touchMove
//                      touchend->swipe-delete#touchEnd">
//       Card content
//     </div>
//   </div>
//
export default class extends Controller {
  static targets = ["card", "deleteBackground"]
  static values = {
    url: String,
    name: String,
    deleteThreshold: { type: Number, default: 100 }, // Pixels to swipe for delete
    openThreshold: { type: Number, default: 60 }     // Pixels to swipe to stay open
  }

  connect() {
    this.startX = 0
    this.currentX = 0
    this.isDragging = false
    this.isOpen = false
    this.isDeleting = false
  }

  disconnect() {
    // Clean up any ongoing animations
    this.reset()
  }

  touchStart(event) {
    if (this.isDeleting) return

    // Record the starting position
    this.startX = event.touches[0].clientX
    this.currentX = this.startX
    this.isDragging = true
    
    // Get current card position to track from there
    const currentTransform = this.cardTarget.style.transform
    const currentX = currentTransform ? 
      parseFloat(currentTransform.match(/translateX\(([-\d.]+)px\)/)?.[1] || 0) : 0
    this.startOffset = currentX

    // Remove transition for smooth dragging
    this.cardTarget.style.transition = "none"
  }

  touchMove(event) {
    if (!this.isDragging || this.isDeleting) return

    this.currentX = event.touches[0].clientX
    const deltaX = this.currentX - this.startX
    const totalX = this.startOffset + deltaX

    // Prevent scrolling while swiping
    event.preventDefault()

    // Allow movement in both directions
    // Clamp to 0 on the left, allow movement to the right
    let translateX = Math.max(0, totalX)
    
    // Apply rubber-band effect after delete threshold
    if (translateX > this.deleteThresholdValue) {
      const excess = translateX - this.deleteThresholdValue
      translateX = this.deleteThresholdValue + (excess * 0.3)
    }

    // Move the card
    this.cardTarget.style.transform = `translateX(${translateX}px)`

    // Visual feedback based on swipe distance
    if (translateX > this.deleteThresholdValue) {
      this.deleteBackgroundTarget.style.backgroundColor = "#dc2626" // Darker red
    } else if (translateX > this.openThresholdValue) {
      this.deleteBackgroundTarget.style.backgroundColor = "#ef4444" // Red
    } else if (translateX > 0) {
      this.deleteBackgroundTarget.style.backgroundColor = "#f87171" // Light red
    }

    // Haptic feedback at threshold
    if (translateX > this.deleteThresholdValue && !this.hasVibratedAtThreshold) {
      if (navigator.vibrate) {
        navigator.vibrate(30)
      }
      this.hasVibratedAtThreshold = true
    } else if (translateX <= this.deleteThresholdValue) {
      this.hasVibratedAtThreshold = false
    }
  }
  
  touchEnd(event) {
    if (!this.isDragging || this.isDeleting) return

    this.isDragging = false
    const deltaX = this.currentX - this.startX
    const totalX = this.startOffset + deltaX
    
    // Get final position
    const finalX = Math.max(0, totalX)

    // Re-enable transition for smooth animation
    this.cardTarget.style.transition = "transform 0.3s cubic-bezier(0.4, 0, 0.2, 1)"

    // Determine action based on final swipe position
    if (finalX > this.deleteThresholdValue) {
      // Swipe exceeded delete threshold - delete the item
      this.delete()
    } else if (finalX > this.openThresholdValue) {
      // Swipe exceeded open threshold - stay open
      this.open()
    } else {
      // Swipe was too short or went back - close
      this.close()
    }
  }
  
  open() {
    this.isOpen = true
    this.cardTarget.style.transform = `translateX(${this.openThresholdValue}px)`
    
    // Add click-outside listener to close
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
    setTimeout(() => {
      document.addEventListener("click", this.boundHandleClickOutside, true)
    }, 100)
  }

  close() {
    this.isOpen = false
    this.cardTarget.style.transform = "translateX(0)"
    
    // Remove click-outside listener
    if (this.boundHandleClickOutside) {
      document.removeEventListener("click", this.boundHandleClickOutside, true)
      this.boundHandleClickOutside = null
    }
  }

  reset() {
    this.close()
    this.isDragging = false
    this.isDeleting = false
    this.hasVibratedAtThreshold = false
  }

  handleClickOutside(event) {
    // Close if clicked outside the card
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  async delete() {
    if (this.isDeleting) return
    
    this.isDeleting = true

    // Haptic feedback
    if (navigator.vibrate) {
      navigator.vibrate([50, 100, 50])
    }

    // Animate card fully off screen to the right
    this.cardTarget.style.transition = "transform 0.4s cubic-bezier(0.4, 0, 0.2, 1)"
    this.cardTarget.style.transform = "translateX(100%)"
    this.deleteBackgroundTarget.style.backgroundColor = "#dc2626"

    // Wait for animation to complete
    await new Promise(resolve => setTimeout(resolve, 400))

    // Send DELETE request via Turbo
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      
      const response = await fetch(this.urlValue, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        }
      })

      if (response.ok) {
        // Always use manual removal to ensure animation completes first
        this.removeElement()
      } else {
        // Error - reset the card
        this.cardTarget.style.transform = "translateX(0)"
        this.isDeleting = false
        
        // Show error message
        alert(`Failed to delete ${this.nameValue}`)
      }
    } catch (error) {
      console.error("Delete failed:", error)
      
      // Reset on error
      this.cardTarget.style.transform = "translateX(0)"
      this.isDeleting = false
      
      alert(`Error deleting ${this.nameValue}`)
    }
  }

  removeElement() {
    const element = this.element
    const originalHeight = element.offsetHeight

    // Collapse animation
    element.style.height = `${originalHeight}px`
    element.style.overflow = "hidden"
    element.style.transition = "all 0.3s cubic-bezier(0.4, 0, 0.2, 1)"

    requestAnimationFrame(() => {
      element.style.height = "0"
      element.style.opacity = "0"
      element.style.paddingTop = "0"
      element.style.paddingBottom = "0"
      element.style.marginTop = "0"
      element.style.marginBottom = "0"
    })

    // Remove from DOM after collapse animation
    setTimeout(() => {
      // Use Turbo to remove if possible (for proper cleanup)
      const turboFrameId = element.id
      if (turboFrameId) {
        // Mark as deleted to prevent Turbo conflicts
        element.dataset.deleted = "true"
      }
      element.remove()
    }, 300)
  }
}