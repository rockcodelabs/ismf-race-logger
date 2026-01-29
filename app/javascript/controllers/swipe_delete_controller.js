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
    this.undoTimeout = null
    this.deletedData = null
  }

  disconnect() {
    // Clean up any ongoing animations and undo timeout
    this.clearUndoTimeout()
    this.reset()
  }

  clearUndoTimeout() {
    if (this.undoTimeout) {
      clearTimeout(this.undoTimeout)
      this.undoTimeout = null
    }
  }

  touchStart(event) {
    if (this.isDeleting) return

    // Record the starting position
    this.startX = event.touches[0].clientX
    this.startY = event.touches[0].clientY
    this.currentX = this.startX
    this.currentY = this.startY
    this.isDragging = true
    this.isHorizontalSwipe = null // Will be determined on first move
    
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
    this.currentY = event.touches[0].clientY
    const deltaX = this.currentX - this.startX
    const deltaY = this.currentY - this.startY
    const totalX = this.startOffset + deltaX

    // Determine swipe direction on first move beyond threshold (5px)
    if (this.isHorizontalSwipe === null) {
      const moveDistance = Math.sqrt(deltaX * deltaX + deltaY * deltaY)
      
      if (moveDistance > 5) {
        // Determine if this is primarily horizontal or vertical movement
        this.isHorizontalSwipe = Math.abs(deltaX) > Math.abs(deltaY)
        
        // If it's vertical, stop tracking immediately to allow scroll
        if (!this.isHorizontalSwipe) {
          this.isDragging = false
          return
        }
      } else {
        // Not enough movement yet, don't do anything
        return
      }
    }

    // Confirmed horizontal swipe - prevent default to stop scrolling
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
    this.isHorizontalSwipe = null // Reset for next interaction
    
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

    // Store element height before collapsing
    const originalHeight = this.element.offsetHeight

    // Store data for undo - store parent reference and element reference
    const parent = this.element.parentElement
    const siblings = Array.from(parent.children)
    const index = siblings.indexOf(this.element)
    
    this.deletedData = {
      element: this.element, // Store the actual element, not a clone
      parent: parent,
      index: index,
      originalHeight: originalHeight,
      url: this.urlValue,
      name: this.nameValue
    }

    // Show undo button in the row first
    this.showUndoButton()
    
    // Hide element with collapse animation but don't remove from DOM yet
    this.hideElement()

    // Set timeout to perform actual deletion
    this.undoTimeout = setTimeout(() => {
      this.performDelete()
      this.hideUndoButton()
    }, 5000)
  }

  async performDelete() {
    // Store name for toast before clearing deletedData
    const deletedName = this.deletedData.name
    
    // Send DELETE request via Turbo
    try {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
      
      const response = await fetch(this.deletedData.url, {
        method: "DELETE",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        }
      })

      if (response.ok) {
        // Successfully deleted - now remove from DOM
        this.removeElement()
        
        // Show toast notification after hard delete
        this.showDeletedToast(deletedName)
      } else {
        console.error("Delete failed on server")
        // Optionally restore element on error
        this.undo()
        return
      }
    } catch (error) {
      console.error("Delete failed:", error)
      // Optionally restore element on error
      this.undo()
      return
    }

    // Clear stored data
    this.deletedData = null
    this.hideUndoButton()
  }

  undo() {
    // Cancel the deletion
    this.clearUndoTimeout()
    
    if (!this.deletedData) return

    // Hide undo button
    this.hideUndoButton()

    // Restore the element's visual state
    const element = this.deletedData.element
    const originalHeight = this.deletedData.originalHeight
    
    // Reverse the collapse animation
    element.style.transition = 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)'
    element.style.overflow = 'hidden'
    
    requestAnimationFrame(() => {
      // Expand back to original height
      element.style.height = `${originalHeight}px`
      element.style.opacity = '1'
      element.style.paddingTop = ''
      element.style.paddingBottom = ''
      element.style.marginTop = ''
      element.style.marginBottom = ''
      
      // Reset card position
      const card = element.querySelector('[data-swipe-delete-target="card"]')
      if (card) {
        card.style.transform = 'translateX(0)'
        card.style.transition = ''
      }
      
      // After animation completes, remove all inline styles
      setTimeout(() => {
        element.style.height = ''
        element.style.overflow = ''
        element.style.transition = ''
      }, 300)
    })
    
    // Reset state
    this.isDeleting = false
    this.isOpen = false
    
    // Clear stored data
    this.deletedData = null
    
    // Haptic feedback
    if (navigator.vibrate) {
      navigator.vibrate(50)
    }
  }

  showUndoButton() {
    const element = this.element
    const originalHeight = this.deletedData.originalHeight
    
    // Create undo button container that maintains height
    const undoContainer = document.createElement('div')
    undoContainer.className = 'bg-gray-900 flex items-center justify-center'
    undoContainer.style.height = `${Math.max(originalHeight, 80)}px`
    undoContainer.dataset.undoContainer = 'true'
    
    undoContainer.innerHTML = `
      <button class="px-8 py-4 bg-yellow-500 hover:bg-yellow-600 active:bg-yellow-700 text-gray-900 text-xl font-bold rounded-xl shadow-lg transition flex items-center gap-3">
        <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M3 10h10a8 8 0 018 8v2M3 10l6 6m-6-6l6-6" />
        </svg>
        <span>Undo Delete</span>
      </button>
    `
    
    // Replace element content with undo container
    element.style.overflow = 'visible'
    const originalContent = element.innerHTML
    element.dataset.originalContent = originalContent
    element.innerHTML = ''
    element.appendChild(undoContainer)
    
    // Bind click event
    const button = undoContainer.querySelector('button')
    button.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.undo()
    })
  }

  hideUndoButton() {
    const undoContainer = this.element.querySelector('[data-undo-container]')
    if (undoContainer) {
      // Restore original content
      const originalContent = this.element.dataset.originalContent
      if (originalContent) {
        this.element.innerHTML = originalContent
        delete this.element.dataset.originalContent
      }
    }
  }

  showDeletedToast(name) {
    // Remove any existing toast
    const existingToast = document.getElementById('deleted-toast')
    if (existingToast) {
      existingToast.remove()
    }

    // Create toast element
    const toast = document.createElement('div')
    toast.id = 'deleted-toast'
    toast.className = 'fixed top-3 right-6 bg-gray-900 text-white px-6 py-4 rounded-xl shadow-2xl flex items-center gap-3 z-50'
    toast.style.opacity = '0'
    toast.style.transform = 'translateX(20px)'
    toast.innerHTML = `
      <svg class="w-6 h-6 text-green-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M5 13l4 4L19 7" />
      </svg>
      <span class="text-lg font-bold">${name} deleted</span>
    `

    // Add to DOM
    document.body.appendChild(toast)

    // Animate in
    requestAnimationFrame(() => {
      toast.style.transition = 'all 0.3s cubic-bezier(0.4, 0, 0.2, 1)'
      toast.style.opacity = '1'
      toast.style.transform = 'translateX(0)'
    })

    // Auto-hide after 3 seconds
    setTimeout(() => {
      if (toast.parentElement) {
        toast.style.opacity = '0'
        toast.style.transform = 'translateX(20px)'
        setTimeout(() => toast.remove(), 300)
      }
    }, 3000)
  }

  hideElement() {
    const element = this.element
    const undoContainer = element.querySelector('[data-undo-container]')
    
    if (!undoContainer) return

    // Collapse the undo container smoothly
    const currentHeight = undoContainer.offsetHeight
    undoContainer.style.height = `${currentHeight}px`
    undoContainer.style.transition = "all 0.3s cubic-bezier(0.4, 0, 0.2, 1)"

    requestAnimationFrame(() => {
      undoContainer.style.height = "80px"
    })
  }

  removeElement() {
    // Actually remove from DOM (called after timeout if not undone)
    if (this.deletedData && this.deletedData.element) {
      this.deletedData.element.remove()
    }
  }
}