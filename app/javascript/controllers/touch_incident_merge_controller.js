import { Controller } from "@hotwired/stimulus"

// Touch Incident Merge Controller
// Handles the report selection UI for creating incidents from merged reports
//
// Features:
// - Visual checkbox selection with touch-friendly targets
// - Selected count display
// - Enable/disable submit button based on selection
//
export default class extends Controller {
  static targets = [
    "checkbox",
    "checkmark",
    "selectedCount",
    "submitButton"
  ]

  connect() {
    console.log("🔗 Touch incident merge controller connected")
    this.updateUI()
  }

  disconnect() {
    console.log("🔗 Touch incident merge controller disconnected")
  }

  // Called when a report row is tapped
  toggleReport(event) {
    // Find the checkbox within this label
    const label = event.currentTarget
    const checkbox = label.querySelector('input[type="checkbox"]')
    const checkmark = label.querySelector('[data-touch-incident-merge-target="checkmark"]')
    
    if (!checkbox) return
    
    // Toggle the checkbox
    checkbox.checked = !checkbox.checked
    
    // Update visual state
    this.updateCheckmark(checkmark, checkbox.checked)
    
    // Haptic feedback
    this.vibrate(10)
    
    // Update overall UI
    this.updateUI()
  }

  // Update the visual checkmark state
  updateCheckmark(checkmark, isChecked) {
    if (!checkmark) return
    
    const svg = checkmark.querySelector('svg')
    
    if (isChecked) {
      checkmark.classList.remove('border-gray-300', 'bg-white')
      checkmark.classList.add('border-blue-500', 'bg-blue-500')
      if (svg) svg.classList.remove('hidden')
    } else {
      checkmark.classList.add('border-gray-300', 'bg-white')
      checkmark.classList.remove('border-blue-500', 'bg-blue-500')
      if (svg) svg.classList.add('hidden')
    }
  }

  // Update the UI based on current selection state
  updateUI() {
    const checkedCount = this.getCheckedCount()
    
    // Update count display
    if (this.hasSelectedCountTarget) {
      this.selectedCountTarget.textContent = `${checkedCount} selected`
      
      if (checkedCount > 0) {
        this.selectedCountTarget.classList.remove('bg-blue-100', 'text-blue-800')
        this.selectedCountTarget.classList.add('bg-green-100', 'text-green-800')
      } else {
        this.selectedCountTarget.classList.add('bg-blue-100', 'text-blue-800')
        this.selectedCountTarget.classList.remove('bg-green-100', 'text-green-800')
      }
    }
    
    // Update submit button state
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = checkedCount === 0
    }
    
    // Sync visual state of all checkmarks with their checkboxes
    this.checkboxTargets.forEach((checkbox, index) => {
      const checkmark = this.checkmarkTargets[index]
      if (checkmark) {
        this.updateCheckmark(checkmark, checkbox.checked)
      }
    })
  }

  // Get the number of checked checkboxes
  getCheckedCount() {
    return this.checkboxTargets.filter(cb => cb.checked).length
  }

  // Haptic feedback (if supported)
  vibrate(duration) {
    if (navigator.vibrate) {
      navigator.vibrate(duration)
    }
  }
}