// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="confirm-delete"
//
// Provides a two-step confirmation pattern for delete actions
// that works well on both desktop and touch devices.
// Uses absolute positioning to prevent layout shift.
//
// Usage:
//   <%= button_to path, method: :delete,
//       data: {
//         controller: "confirm-delete",
//         confirm_delete_name_value: "John Doe",
//         action: "confirm-delete#confirm"
//       },
//       class: "..." do %>
//     <svg>...</svg>
//   <% end %>
//
export default class extends Controller {
  static values = {
    name: String
  }

  connect() {
    this.confirmed = false
    this.resetTimeout = null
    this.confirmOverlay = null
    this.boundHandleClickOutside = this.handleClickOutside.bind(this)
  }

  disconnect() {
    this.clearResetTimeout()
    this.removeClickOutsideListener()
    this.removeOverlay()
  }

  confirm(event) {
    // If already confirmed, let the form submit
    if (this.confirmed) {
      return true
    }

    // Prevent the first click from submitting
    event.preventDefault()
    event.stopPropagation()

    // Enter confirmation state
    this.showConfirmation()

    // Auto-reset after 3 seconds of inactivity
    this.scheduleReset()
    
    // Listen for clicks outside to cancel
    this.addClickOutsideListener()
  }

  showConfirmation() {
    this.confirmed = true
    
    // Haptic feedback for touch devices
    if (navigator.vibrate) {
      navigator.vibrate(50) // Short vibration
    }
    
    // Get button dimensions and position
    const button = this.element
    const rect = button.getBoundingClientRect()
    
    // Create overlay with confirmation UI
    this.confirmOverlay = document.createElement('div')
    this.confirmOverlay.style.position = 'absolute'
    this.confirmOverlay.style.top = `${rect.top + window.scrollY}px`
    this.confirmOverlay.style.right = `${document.documentElement.clientWidth - rect.right}px`
    this.confirmOverlay.style.width = 'auto'
    this.confirmOverlay.style.height = `${rect.height}px`
    this.confirmOverlay.style.zIndex = '50'
    this.confirmOverlay.style.pointerEvents = 'all'
    this.confirmOverlay.style.display = 'flex'
    this.confirmOverlay.style.justifyContent = 'flex-end'
    
    // Create the confirmation button
    const confirmButton = document.createElement('button')
    confirmButton.type = 'button'
    confirmButton.className = 'inline-flex items-center justify-center bg-red-600 text-white hover:bg-red-700 active:bg-red-800 px-3 py-1.5 rounded-lg transition-all shadow-md font-medium text-sm whitespace-nowrap h-full'
    
    // Add icon
    const svg = document.createElementNS('http://www.w3.org/2000/svg', 'svg')
    svg.setAttribute('class', 'w-5 h-5 shrink-0 mr-2')
    svg.setAttribute('fill', 'none')
    svg.setAttribute('stroke', 'currentColor')
    svg.setAttribute('viewBox', '0 0 24 24')
    const path = document.createElementNS('http://www.w3.org/2000/svg', 'path')
    path.setAttribute('stroke-linecap', 'round')
    path.setAttribute('stroke-linejoin', 'round')
    path.setAttribute('stroke-width', '2')
    path.setAttribute('d', 'M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16')
    svg.appendChild(path)
    
    // Add text
    const text = document.createTextNode(`Remove ${this.nameValue}?`)
    
    confirmButton.appendChild(svg)
    confirmButton.appendChild(text)
    
    // Click on confirm button actually submits the form
    confirmButton.addEventListener('click', (e) => {
      e.preventDefault()
      e.stopPropagation()
      this.removeOverlay()
      this.removeClickOutsideListener()
      button.click() // Trigger the original button
    })
    
    this.confirmOverlay.appendChild(confirmButton)
    document.body.appendChild(this.confirmOverlay)
    
    // Hide the original button visually but keep it in the layout
    button.style.visibility = 'hidden'
  }

  removeOverlay() {
    // Show the original button first
    if (this.element) {
      this.element.style.visibility = 'visible'
    }
    
    // Then remove overlay
    if (this.confirmOverlay) {
      this.confirmOverlay.remove()
      this.confirmOverlay = null
    }
  }

  scheduleReset() {
    this.clearResetTimeout()
    this.resetTimeout = setTimeout(() => {
      this.reset()
    }, 3000)
  }

  clearResetTimeout() {
    if (this.resetTimeout) {
      clearTimeout(this.resetTimeout)
      this.resetTimeout = null
    }
  }

  reset() {
    this.confirmed = false
    this.clearResetTimeout()
    this.removeClickOutsideListener()
    this.removeOverlay()
  }

  // Allow manual reset via action
  cancel(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    this.reset()
  }

  // Click outside handler
  handleClickOutside(event) {
    // If click is outside the overlay, reset
    if (this.confirmOverlay && !this.confirmOverlay.contains(event.target)) {
      this.cancel()
    }
  }

  addClickOutsideListener() {
    // Delay to avoid immediate trigger from the same click
    setTimeout(() => {
      document.addEventListener('click', this.boundHandleClickOutside, true)
    }, 100)
  }

  removeClickOutsideListener() {
    document.removeEventListener('click', this.boundHandleClickOutside, true)
  }
}