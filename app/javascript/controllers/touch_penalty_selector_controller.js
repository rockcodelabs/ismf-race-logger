import { Controller } from "@hotwired/stimulus"

// Touch Penalty Selector Controller
// Handles the penalty selection modal for the incident decision interface
//
// Features:
// - Modal open/close
// - Search/filter penalties
// - Add/remove penalties from the form
// - Visual feedback
//
export default class extends Controller {
  static targets = [
    "modal",
    "searchInput",
    "penaltyList",
    "selectedPenalties",
    "emptyState"
  ]

  connect() {
    console.log("⚠️ Touch penalty selector controller connected")
    this.selectedPenaltyIds = new Set()
    
    // Initialize from existing hidden inputs
    this.initializeSelectedPenalties()
  }

  disconnect() {
    console.log("⚠️ Touch penalty selector controller disconnected")
  }

  // Initialize selected penalties from existing form data
  initializeSelectedPenalties() {
    if (this.hasSelectedPenaltiesTarget) {
      const existingInputs = this.selectedPenaltiesTarget.querySelectorAll('input[name="penalty_ids[]"]')
      existingInputs.forEach(input => {
        this.selectedPenaltyIds.add(input.value)
      })
    }
  }

  // Open the penalty selection modal
  openModal(event) {
    event.preventDefault()
    
    if (this.hasModalTarget) {
      this.modalTarget.classList.remove('hidden')
      document.body.style.overflow = 'hidden'
      
      // Focus search input
      if (this.hasSearchInputTarget) {
        setTimeout(() => this.searchInputTarget.focus(), 100)
      }
    }
    
    this.vibrate(10)
  }

  // Close the penalty selection modal
  closeModal(event) {
    if (event) event.preventDefault()
    
    if (this.hasModalTarget) {
      this.modalTarget.classList.add('hidden')
      document.body.style.overflow = ''
      
      // Clear search
      if (this.hasSearchInputTarget) {
        this.searchInputTarget.value = ''
        this.filterPenalties()
      }
    }
  }

  // Filter penalties based on search input
  filterPenalties() {
    if (!this.hasSearchInputTarget) return
    
    const query = this.searchInputTarget.value.toLowerCase().trim()
    const penaltyItems = this.element.querySelectorAll('.penalty-item')
    const categories = this.element.querySelectorAll('.penalty-category')
    
    penaltyItems.forEach(item => {
      const searchText = item.getAttribute('data-penalty-search') || ''
      const matches = query === '' || searchText.includes(query)
      item.style.display = matches ? '' : 'none'
    })
    
    // Show/hide category headers based on visible items
    categories.forEach(category => {
      const visibleItems = category.querySelectorAll('.penalty-item:not([style*="display: none"])')
      category.style.display = visibleItems.length > 0 ? '' : 'none'
    })
  }

  // Select a penalty from the modal list
  selectPenalty(event) {
    const button = event.currentTarget
    const penaltyId = button.getAttribute('data-penalty-id')
    const penaltyNumber = button.getAttribute('data-penalty-number')
    const penaltyName = button.getAttribute('data-penalty-name')
    const penaltyCategory = button.getAttribute('data-penalty-category')
    
    // Check if already selected
    if (this.selectedPenaltyIds.has(penaltyId)) {
      this.showToast('Penalty already added')
      return
    }
    
    // Add to selected set
    this.selectedPenaltyIds.add(penaltyId)
    
    // Add to the UI
    this.addPenaltyToUI(penaltyId, penaltyNumber, penaltyName, penaltyCategory)
    
    // Hide empty state
    this.hideEmptyState()
    
    // Haptic feedback
    this.vibrate(20)
    
    // Close modal
    this.closeModal()
    
    // Show confirmation
    this.showToast(`Added: ${penaltyNumber}`)
  }

  // Add a penalty to the selected penalties UI
  addPenaltyToUI(penaltyId, penaltyNumber, penaltyName, penaltyCategory) {
    if (!this.hasSelectedPenaltiesTarget) return
    
    const penaltyHTML = `
      <div class="flex items-center gap-3 p-3 rounded-xl bg-orange-50 border border-orange-200"
           data-penalty-id="${penaltyId}">
        <input type="hidden" name="penalty_ids[]" value="${penaltyId}">
        <span class="w-10 h-10 flex items-center justify-center rounded-lg bg-orange-500 text-white font-bold text-sm shrink-0">
          ${penaltyNumber}
        </span>
        <div class="flex-1 min-w-0">
          <p class="text-sm font-semibold text-ismf-navy truncate">${penaltyName}</p>
          <p class="text-xs text-gray-500">${penaltyCategory}</p>
        </div>
        <button type="button"
                class="w-8 h-8 flex items-center justify-center rounded-full bg-red-100 text-red-600 active:bg-red-200 transition"
                data-action="click->touch-penalty-selector#removePenalty"
                data-penalty-id="${penaltyId}">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    `
    
    this.selectedPenaltiesTarget.insertAdjacentHTML('beforeend', penaltyHTML)
  }

  // Remove a penalty from the selection
  removePenalty(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget
    const penaltyId = button.getAttribute('data-penalty-id')
    const penaltyElement = this.selectedPenaltiesTarget.querySelector(`[data-penalty-id="${penaltyId}"]`)
    
    if (penaltyElement) {
      penaltyElement.remove()
    }
    
    this.selectedPenaltyIds.delete(penaltyId)
    
    // Show empty state if no penalties left
    if (this.selectedPenaltyIds.size === 0) {
      this.showEmptyState()
    }
    
    this.vibrate(10)
  }

  // Hide the empty state message
  hideEmptyState() {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.add('hidden')
    }
  }

  // Show the empty state message
  showEmptyState() {
    if (this.hasEmptyStateTarget) {
      this.emptyStateTarget.classList.remove('hidden')
    }
  }

  // Haptic feedback (if supported)
  vibrate(duration) {
    if (navigator.vibrate) {
      navigator.vibrate(duration)
    }
  }

  // Show a toast message
  showToast(message) {
    const toast = document.createElement('div')
    toast.className = 'fixed bottom-24 left-1/2 -translate-x-1/2 px-6 py-3 bg-gray-900 text-white rounded-xl shadow-lg z-[100] text-sm font-medium animate-slide-up'
    toast.textContent = message

    document.body.appendChild(toast)

    setTimeout(() => {
      toast.remove()
    }, 2000)
  }
}