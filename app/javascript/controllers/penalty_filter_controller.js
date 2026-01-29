// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"

// Penalty filter controller for touch display
// Filters penalties by category (A-F) and race type (Individual/Team, Vertical, Sprint/Relay)
export default class extends Controller {
  static targets = [
    "categoryBtn",
    "raceTypeBtn",
    "categorySection",
    "penaltyCard",
    "noResults"
  ]

  connect() {
    this.activeCategory = "all"
    this.activeRaceType = "all"
  }

  filterCategory(event) {
    const category = event.currentTarget.dataset.category

    // Update active state
    this.activeCategory = category
    this.categoryBtnTargets.forEach(btn => {
      const isActive = btn.dataset.category === category
      
      // Update button styling
      if (isActive) {
        btn.classList.remove("bg-gray-100", "text-gray-700", "hover:bg-gray-200", "border-gray-200")
        btn.classList.add("bg-ismf-red", "text-white", "hover:bg-ismf-red/90", "border-white/20")
      } else {
        btn.classList.remove("bg-ismf-red", "text-white", "hover:bg-ismf-red/90", "border-white/20")
        btn.classList.add("bg-gray-100", "text-gray-700", "hover:bg-gray-200", "border-gray-200")
      }
    })

    this.applyFilters()
  }

  filterRaceType(event) {
    const raceType = event.currentTarget.dataset.raceType

    // Update active state
    this.activeRaceType = raceType
    this.raceTypeBtnTargets.forEach(btn => {
      const isActive = btn.dataset.raceType === raceType
      
      // Update button styling
      if (isActive) {
        btn.classList.remove("bg-gray-100", "text-gray-700", "hover:bg-gray-200", "border-gray-200")
        btn.classList.add("bg-ismf-red", "text-white", "hover:bg-ismf-red/90", "border-white/20")
      } else {
        btn.classList.remove("bg-ismf-red", "text-white", "hover:bg-ismf-red/90", "border-white/20")
        btn.classList.add("bg-gray-100", "text-gray-700", "hover:bg-gray-200", "border-gray-200")
      }
    })

    this.applyFilters()
  }

  applyFilters() {
    let visibleCount = 0
    const visibleCategories = new Set()

    // Filter penalty cards
    this.penaltyCardTargets.forEach(card => {
      const cardCategory = card.dataset.category
      const matchesCategory = this.activeCategory === "all" || cardCategory === this.activeCategory
      
      let matchesRaceType = true
      if (this.activeRaceType !== "all") {
        const hasApplicablePenalty = card.dataset[this.camelCase(this.activeRaceType)] === "yes"
        matchesRaceType = hasApplicablePenalty
      }

      const shouldShow = matchesCategory && matchesRaceType

      if (shouldShow) {
        card.classList.remove("hidden")
        visibleCategories.add(cardCategory)
        visibleCount++
      } else {
        card.classList.add("hidden")
      }
    })

    // Show/hide category headers based on visible cards
    this.categorySectionTargets.forEach(section => {
      const category = section.dataset.category
      if (visibleCategories.has(category)) {
        section.classList.remove("hidden")
      } else {
        section.classList.add("hidden")
      }
    })

    // Show/hide "no results" message
    if (visibleCount === 0) {
      this.noResultsTarget.classList.remove("hidden")
    } else {
      this.noResultsTarget.classList.add("hidden")
    }
  }

  // Convert snake_case to camelCase for dataset attribute access
  camelCase(str) {
    return str.replace(/_([a-z])/g, (match, letter) => letter.toUpperCase())
  }
}