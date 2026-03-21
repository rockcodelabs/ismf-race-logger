// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="participant-selection"
//
// Manages bulk selection of participants in the race table.
// Tracks selected participant IDs and updates the bulk action bar.
//
// Usage:
//   <div data-controller="participant-selection">
//     <table>
//       <thead>
//         <tr>
//           <th>
//             <input type="checkbox" data-action="participant-selection#toggleAll">
//           </th>
//         </tr>
//       </thead>
//       <tbody>
//         <tr data-participation-id="123">
//           <td>
//             <input type="checkbox" data-action="participant-selection#toggle">
//           </td>
//         </tr>
//       </tbody>
//     </table>
//     <div id="bulk-action-bar"><!-- bulk actions --></div>
//   </div>
//
export default class extends Controller {
  static targets = ["selectAllCheckbox", "participantCheckbox", "bulkActionBar"]
  static values = {
    racePath: String
  }

  connect() {
    this.updateBulkActionBar()
  }

  toggle(event) {
    this.updateBulkActionBar()
  }

  toggleAll(event) {
    const selectAllCheckbox = event.target
    const checked = selectAllCheckbox.checked

    // Update all participant checkboxes
    this.participantCheckboxTargets.forEach(checkbox => {
      checkbox.checked = checked
    })

    this.updateBulkActionBar()
  }

  updateBulkActionBar() {
    const selectedIds = this.getSelectedParticipationIds()
    const totalCount = this.participantCheckboxTargets.length
    const selectedCount = selectedIds.length

    // Update select all checkbox state
    if (this.hasSelectAllCheckboxTarget) {
      this.selectAllCheckboxTarget.checked = selectedCount === totalCount && totalCount > 0
      this.selectAllCheckboxTarget.indeterminate = selectedCount > 0 && selectedCount < totalCount
    }

    // Show/hide bulk action bar and update UI
    if (selectedCount > 0) {
      this.showBulkActionBar(selectedIds, selectedCount, totalCount)
    } else {
      this.hideBulkActionBar()
    }
  }

  showBulkActionBar(selectedIds, selectedCount, totalCount) {
    if (!this.hasBulkActionBarTarget) {
      return
    }

    const bulkBar = this.bulkActionBarTarget
    const unselectedCount = totalCount - selectedCount

    // Store selected IDs for form submission
    bulkBar.dataset.selectedIds = JSON.stringify(selectedIds)

    // Update count display
    const countBadge = bulkBar.querySelector('[data-selected-count]')
    if (countBadge) {
      countBadge.textContent = selectedCount
    }

    // Update "Remove Rest" button state
    const removeRestBtn = bulkBar.querySelector('[data-remove-rest-btn]')
    if (removeRestBtn) {
      removeRestBtn.disabled = unselectedCount === 0
      if (unselectedCount === 0) {
        removeRestBtn.classList.add('opacity-50', 'cursor-not-allowed')
        removeRestBtn.setAttribute('aria-disabled', 'true')
      } else {
        removeRestBtn.classList.remove('opacity-50', 'cursor-not-allowed')
        removeRestBtn.setAttribute('aria-disabled', 'false')
      }
    }

    // Update unselected count for "Remove Rest" button text
    const removeRestBtnText = bulkBar.querySelector('[data-remove-rest-count]')
    if (removeRestBtnText) {
      removeRestBtnText.textContent = unselectedCount
    }

    // Show the action bar
    bulkBar.classList.remove('hidden')
  }

  hideBulkActionBar() {
    if (this.hasBulkActionBarTarget) {
      this.bulkActionBarTarget.classList.add('hidden')
    }
  }

  getSelectedParticipationIds() {
    return this.participantCheckboxTargets
      .filter(checkbox => checkbox.checked)
      .map(checkbox => {
        const row = checkbox.closest('tr')
        return row.dataset.participationId
      })
      .filter(Boolean)
  }

  removeSelected(event) {
    event.preventDefault()
    const selectedIds = this.getSelectedParticipationIds()

    if (selectedIds.length === 0) {
      alert('No participants selected')
      return
    }

    const count = selectedIds.length
    if (confirm(`Remove ${count} selected participant${count !== 1 ? 's' : ''}?`)) {
      this.submitBulkDelete(selectedIds, 'remove_selected')
    }
  }

  removeRest(event) {
    event.preventDefault()
    const selectedIds = this.getSelectedParticipationIds()
    const totalCount = this.participantCheckboxTargets.length
    const removeCount = totalCount - selectedIds.length

    if (removeCount === 0) {
      alert('No other participants to remove')
      return
    }

    if (confirm(`Remove ${removeCount} other participant${removeCount !== 1 ? 's' : ''}? This will keep only the ${selectedIds.length} selected.`)) {
      this.submitBulkDelete(selectedIds, 'remove_rest')
    }
  }

  submitBulkDelete(selectedIds, mode) {
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = this.racePathValue.replace(/\/$/, '') + '/participations/bulk_destroy'
    form.style.display = 'none'

    // Add CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.content
    if (csrfToken) {
      const tokenInput = document.createElement('input')
      tokenInput.type = 'hidden'
      tokenInput.name = 'authenticity_token'
      tokenInput.value = csrfToken
      form.appendChild(tokenInput)
    }

    // Add parameters based on mode
    if (mode === 'remove_selected') {
      selectedIds.forEach(id => {
        const input = document.createElement('input')
        input.type = 'hidden'
        input.name = 'participation_ids[]'
        input.value = id
        form.appendChild(input)
      })
    } else if (mode === 'remove_rest') {
      // For remove_rest, send IDs to keep
      selectedIds.forEach(id => {
        const input = document.createElement('input')
        input.type = 'hidden'
        input.name = 'participation_ids_to_keep[]'
        input.value = id
        form.appendChild(input)
      })
    }

    document.body.appendChild(form)
    form.submit()
  }
}