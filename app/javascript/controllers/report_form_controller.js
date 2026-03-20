import { Controller } from "@hotwired/stimulus"

// Report Form Controller
// Handles the split-screen report creation interface for desktop
//
// Features:
// - Location selection (left sidebar)
// - Bib/participant selection (center grid)
// - Automatic form submission when both are selected
// - Client UUID generation for idempotency
//
export default class extends Controller {
  static targets = [
    "banner",
    "bannerText",
    "bibButton",
    "form",
    "locationInput",
    "participationInput",
    "bibInput",
    "clientUuidInput",
    "athletePositionInput",
    "athleteSelector",
    "athleteSelectorBib",
    "maleNameDisplay",
    "femaleNameDisplay",
    "gridContainer"
  ]

  connect() {
    this.selectedLocationId = null
    this.selectedLocationName = null
    this.isSubmitting = false
    this.pendingParticipationId = null
    this.pendingBibNumber = null
    this.pendingButton = null
  }

  disconnect() {
    // Clean up
  }

  // Called when a location button is clicked
  selectLocation(event) {
    const locationId = event.params.locationId
    const locationName = event.params.locationName

    // Update selection state
    this.selectedLocationId = locationId
    this.selectedLocationName = locationName

    // Update UI - highlight selected location
    this.updateLocationButtons(locationId)

    // Update banner
    this.updateBanner(locationName)

    // Enable bib buttons
    this.enableBibButtons()
  }

  // Called when a bib button is clicked
  selectBib(event) {
    if (!this.selectedLocationId) {
      this.showMessage("Please select a location first")
      return
    }

    if (this.isSubmitting) {
      return
    }

    const participationId = event.params.participationId
    const bibNumber = event.params.bib
    const isTeam = event.params.isTeam === true || event.params.isTeam === "true"
    const maleName = event.params.maleName
    const femaleName = event.params.femaleName

    const button = event.currentTarget

    // For relay teams: show M/F selector instead of submitting immediately
    if (isTeam && maleName && femaleName) {
      button.classList.add("selected")
      this.pendingParticipationId = participationId
      this.pendingBibNumber = bibNumber
      this.pendingButton = button
      this.showAthleteSelector(bibNumber, maleName, femaleName)
      return
    }

    // Individual athlete: submit immediately
    button.classList.add("selected")
    this.submitReport(participationId, bibNumber, null)

    setTimeout(() => {
      button.classList.remove("selected")
    }, 2000)
  }

  // Show the M/F athlete selector overlay
  showAthleteSelector(bib, maleName, femaleName) {
    if (this.hasAthleteSelectorTarget) {
      this.athleteSelectorTarget.classList.remove("hidden")
    }
    if (this.hasAthleteSelectorBibTarget) {
      this.athleteSelectorBibTarget.textContent = bib
    }
    if (this.hasMaleNameDisplayTarget) {
      this.maleNameDisplayTarget.textContent = maleName
    }
    if (this.hasFemaleNameDisplayTarget) {
      this.femaleNameDisplayTarget.textContent = femaleName
    }
  }

  // Hide the M/F athlete selector overlay
  hideAthleteSelector() {
    if (this.hasAthleteSelectorTarget) {
      this.athleteSelectorTarget.classList.add("hidden")
    }
  }

  // Called when Male button is clicked in overlay
  selectMale() {
    this.submitReport(this.pendingParticipationId, this.pendingBibNumber, 1)
    this.hideAthleteSelector()
    if (this.pendingButton) {
      setTimeout(() => {
        this.pendingButton.classList.remove("selected")
      }, 2000)
    }
  }

  // Called when Female button is clicked in overlay
  selectFemale() {
    this.submitReport(this.pendingParticipationId, this.pendingBibNumber, 2)
    this.hideAthleteSelector()
    if (this.pendingButton) {
      setTimeout(() => {
        this.pendingButton.classList.remove("selected")
      }, 2000)
    }
  }

  // Cancel the M/F selector overlay
  cancelAthleteSelector() {
    this.hideAthleteSelector()
    if (this.pendingButton) {
      this.pendingButton.classList.remove("selected")
    }
    this.pendingParticipationId = null
    this.pendingBibNumber = null
    this.pendingButton = null
  }

  // Fill form and submit with optional athlete_position
  submitReport(participationId, bibNumber, athletePosition) {
    if (this.hasLocationInputTarget) {
      this.locationInputTarget.value = this.selectedLocationId
    }
    if (this.hasParticipationInputTarget) {
      this.participationInputTarget.value = participationId || ""
    }
    if (this.hasBibInputTarget) {
      this.bibInputTarget.value = bibNumber || ""
    }
    if (this.hasClientUuidInputTarget) {
      this.clientUuidInputTarget.value = this.generateUUID()
    }
    if (this.hasAthletePositionInputTarget) {
      this.athletePositionInputTarget.value = athletePosition !== null ? athletePosition : ""
    }

    this.isSubmitting = true

    if (this.hasFormTarget) {
      this.formTarget.requestSubmit()
    } else {
      console.error("Form target not found!")
      this.showError("Form not found - please refresh the page")
    }

    setTimeout(() => {
      this.isSubmitting = false
    }, 2000)
  }

  // Called when "Number NN" (unknown bib) button is clicked
  selectUnknownBib(event) {
    if (!this.selectedLocationId) {
      this.showMessage("Please select a location first")
      return
    }

    if (this.isSubmitting) {
      return
    }

    const button = event.currentTarget
    button.classList.add("selected")

    this.submitReport(null, null, null)

    setTimeout(() => {
      button.classList.remove("selected")
    }, 2000)
  }

  // Update location button styling
  updateLocationButtons(selectedId) {
    const buttons = this.element.querySelectorAll(".location-btn")
    
    buttons.forEach(button => {
      const locationId = button.dataset.reportFormLocationIdParam
      
      if (locationId == selectedId) {
        // Selected state
        button.classList.add("active")
      } else {
        // Unselected state
        button.classList.remove("active")
      }
    })
  }

  // Update the banner text
  updateBanner(locationName) {
    if (this.hasBannerTarget && this.hasBannerTextTarget) {
      this.bannerTextTarget.innerHTML = `
        <span class="text-ismf-blue font-bold">📍 ${locationName}</span>
        <span class="text-gray-400 ml-2">— Select an athlete to create report</span>
      `
      this.bannerTarget.classList.remove("bg-gray-200")
      this.bannerTarget.classList.add("bg-blue-50", "border-blue-200")
    }
  }

  // Enable all bib buttons
  enableBibButtons() {
    this.bibButtonTargets.forEach(button => {
      button.disabled = false
      button.classList.remove("opacity-40")
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

  // Show a message
  showMessage(message) {
    if (this.hasBannerTextTarget) {
      this.bannerTextTarget.innerHTML = `<span class="text-blue-600">${message}</span>`
    }
  }

  // Show an error message
  showError(message) {
    if (this.hasBannerTextTarget && this.hasBannerTarget) {
      this.bannerTextTarget.innerHTML = `<span class="text-red-600 font-bold">❌ ${message}</span>`
      this.bannerTarget.classList.remove("bg-gray-200", "bg-blue-50")
      this.bannerTarget.classList.add("bg-red-50", "border-red-300")
    }
  }
}