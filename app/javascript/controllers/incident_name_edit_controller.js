// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="incident-name-edit"
export default class extends Controller {
  static targets = ["display", "input", "form"]
  static values = {
    incidentId: Number,
    raceId: Number,
    currentName: String
  }

  connect() {
    // Store original name for cancel
    this.originalName = this.currentNameValue
  }

  edit(event) {
    event.preventDefault()
    
    // Show input, hide display
    this.displayTarget.classList.add("hidden")
    this.formTarget.classList.remove("hidden")
    
    // Focus input and select text
    this.inputTarget.focus()
    this.inputTarget.select()
  }

  cancel(event) {
    event.preventDefault()
    
    // Restore original value
    this.inputTarget.value = this.originalName
    
    // Hide input, show display
    this.formTarget.classList.add("hidden")
    this.displayTarget.classList.remove("hidden")
  }

  async save(event) {
    event.preventDefault()
    
    const newName = this.inputTarget.value.trim()
    const url = `/admin/races/${this.raceIdValue}/incidents/${this.incidentIdValue}`
    
    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
          "Accept": "application/json"
        },
        body: JSON.stringify({
          incident: {
            custom_name: newName
          }
        })
      })

      if (response.ok) {
        const data = await response.json()
        
        // Update display with new name
        const displayName = newName || `Incident #${this.incidentIdValue}`
        this.displayTarget.textContent = displayName
        this.currentNameValue = newName
        this.originalName = newName
        
        // Hide input, show display
        this.formTarget.classList.add("hidden")
        this.displayTarget.classList.remove("hidden")
        
        // Show success message (optional)
        this.showFlash("Incident name updated successfully", "notice")
      } else {
        this.showFlash("Failed to update incident name", "alert")
      }
    } catch (error) {
      console.error("Error updating incident name:", error)
      this.showFlash("An error occurred while updating", "alert")
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.cancel(event)
    } else if (event.key === "Enter") {
      event.preventDefault()
      this.save(event)
    }
  }

  showFlash(message, type) {
    // Use generic flash API if available
    if (window.flash) {
      if (type === "notice") {
        window.flash.success(message)
      } else {
        window.flash.error(message)
      }
    } else {
      // Fallback: dispatch custom event
      document.dispatchEvent(new CustomEvent('flash:show', {
        detail: { message, type }
      }))
    }
  }
}