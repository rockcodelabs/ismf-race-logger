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
    // Create flash message element
    const flashContainer = document.getElementById("flash-messages")
    if (!flashContainer) return

    const flashClass = type === "notice" ? "flash-notice" : "flash-alert"
    const iconPath = type === "notice" 
      ? "M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z"
      : "M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z"

    const flashElement = document.createElement("div")
    flashElement.className = flashClass
    flashElement.innerHTML = `
      <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${iconPath}" />
      </svg>
      ${message}
    `

    flashContainer.appendChild(flashElement)

    // Auto-remove after 3 seconds
    setTimeout(() => {
      flashElement.remove()
    }, 3000)
  }
}