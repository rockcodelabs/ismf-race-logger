import { Controller } from "@hotwired/stimulus"

// Touch Report Controller
// Handles the split-screen report creation interface for touch displays
//
// Features:
// - Location selection (left sidebar)
// - Bib/participant selection (center grid)
// - Automatic form submission when both are selected
// - Client UUID generation for idempotency
//
export default class extends Controller {
  static targets = [
    "locationBanner",
    "bibButton",
    "form",
    "locationInput",
    "participationInput",
    "bibInput",
    "clientUuidInput",
    "pendingQueue"
  ]

  connect() {
    this.selectedLocationId = null
    this.selectedLocationName = null
    this.isSubmitting = false
  }

  disconnect() {
    // Clean up
  }

  // Called when a location button is tapped
  selectLocation(event) {
    const locationId = event.params.locationId
    const locationName = event.params.locationName

    // Update selection state
    this.selectedLocationId = locationId
    this.selectedLocationName = locationName

    // Update UI - highlight selected location
    this.updateLocationButtons(locationId)

    // Update banner
    this.updateLocationBanner(locationName)

    // Enable bib buttons
    this.enableBibButtons()

    // Haptic feedback if available
    this.vibrate(10)
  }

  // Called when a bib button is tapped
  selectBib(event) {
    if (!this.selectedLocationId) {
      this.showToast("Please select a location first")
      return
    }

    if (this.isSubmitting) {
      return
    }

    const participationId = event.params.participationId
    const bibNumber = event.params.bib
    const athleteName = event.params.athlete

    // Highlight the tapped bib briefly
    const button = event.currentTarget
    button.classList.add("ring-4", "ring-green-400", "bg-green-50")

    // Generate client UUID for idempotency
    const clientUuid = this.generateUUID()

    // Fill the hidden form
    if (this.hasLocationInputTarget) {
      this.locationInputTarget.value = this.selectedLocationId
    }
    
    if (this.hasParticipationInputTarget) {
      this.participationInputTarget.value = participationId
    }
    
    if (this.hasBibInputTarget) {
      this.bibInputTarget.value = bibNumber
    }
    
    if (this.hasClientUuidInputTarget) {
      this.clientUuidInputTarget.value = clientUuid
    }

    // Haptic feedback
    this.vibrate(50)

    // Submit the form
    this.isSubmitting = true

    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    }

    // Reset after a delay (form will navigate away on success)
    setTimeout(() => {
      this.isSubmitting = false
      button.classList.remove("ring-4", "ring-green-400", "bg-green-50")
    }, 2000)
  }

  // Update location button styling
  updateLocationButtons(selectedId) {
    const buttons = this.element.querySelectorAll(".touch-location-btn")
    
    buttons.forEach(button => {
      const locationId = button.dataset.locationId
      
      if (locationId == selectedId) {
        // Selected state
        button.classList.add("ring-4", "ring-offset-2", "ring-blue-500", "scale-105")
        button.classList.remove("opacity-60")
      } else {
        // Unselected state
        button.classList.remove("ring-4", "ring-offset-2", "ring-blue-500", "scale-105")
        button.classList.add("opacity-60")
      }
    })
  }

  // Update the location banner text
  updateLocationBanner(locationName) {
    if (this.hasLocationBannerTarget) {
      this.locationBannerTarget.innerHTML = `
        <p class="text-sm font-medium text-gray-800">
          <span class="text-blue-600 font-bold">📍 ${locationName}</span>
          <span class="text-gray-400 ml-2">— Tap a bib to create report</span>
        </p>
      `
      this.locationBannerTarget.classList.remove("bg-gray-200")
      this.locationBannerTarget.classList.add("bg-blue-50", "border-blue-200")
    }
  }

  // Enable all bib buttons
  enableBibButtons() {
    this.bibButtonTargets.forEach(button => {
      button.disabled = false
      button.classList.remove("opacity-50")
      button.classList.add("hover:border-blue-400", "active:bg-blue-50")
    })
  }

  // Generate a UUID v4
  generateUUID() {
    return "xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx".replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0
      const v = c === "x" ? r : (r & 0x3 | 0x8)
      return v.toString(16)
    })
  }

  // Haptic feedback (if supported)
  vibrate(duration) {
    if (navigator.vibrate) {
      navigator.vibrate(duration)
    }
  }

  // Show a toast message
  showToast(message) {
    // Create toast element
    const toast = document.createElement("div")
    toast.className = "fixed bottom-24 left-1/2 -translate-x-1/2 px-6 py-3 bg-gray-900 text-white rounded-xl shadow-lg z-50 text-sm font-medium animate-slide-up"
    toast.textContent = message

    document.body.appendChild(toast)

    // Remove after delay
    setTimeout(() => {
      toast.remove()
    }, 2000)
  }
}