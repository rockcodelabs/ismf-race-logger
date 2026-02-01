// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="incident-selection"
export default class extends Controller {
  static targets = [
    "checkbox",
    "selectAll",
    "actionBar",
    "selectedCount",
    "deleteForm",
    "deleteHiddenInputs",
    "row"
  ]

  static values = {
    raceId: Number
  }

  connect() {
    this.selectedIncidentIds = new Set()
    this.updateActionBar()
  }

  // Toggle all checkboxes
  toggleAll(event) {
    const checked = event.target.checked
    
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
      const incidentId = parseInt(checkbox.dataset.incidentId)
      
      if (checked) {
        this.selectedIncidentIds.add(incidentId)
      } else {
        this.selectedIncidentIds.delete(incidentId)
      }
    })
    
    this.updateActionBar()
  }

  // Update selection when individual checkbox changes
  updateSelection(event) {
    const checkbox = event.target
    const incidentId = parseInt(checkbox.dataset.incidentId)
    
    if (checkbox.checked) {
      this.selectedIncidentIds.add(incidentId)
    } else {
      this.selectedIncidentIds.delete(incidentId)
    }
    
    // Update "select all" checkbox state
    this.updateSelectAllState()
    this.updateActionBar()
  }

  // Update the "select all" checkbox state based on individual checkboxes
  updateSelectAllState() {
    if (!this.hasSelectAllTarget) return
    
    const totalCheckboxes = this.checkboxTargets.length
    const checkedCheckboxes = this.checkboxTargets.filter(cb => cb.checked).length
    
    if (checkedCheckboxes === 0) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    } else if (checkedCheckboxes === totalCheckboxes) {
      this.selectAllTarget.checked = true
      this.selectAllTarget.indeterminate = false
    } else {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = true
    }
  }

  // Show/hide action bar and update count
  updateActionBar() {
    const count = this.selectedIncidentIds.size
    
    if (count > 0) {
      this.actionBarTarget.classList.remove("hidden")
      this.selectedCountTarget.textContent = `${count} incident${count === 1 ? '' : 's'} selected`
    } else {
      this.actionBarTarget.classList.add("hidden")
    }
  }

  // Clear all selections
  clearSelection() {
    this.selectedIncidentIds.clear()
    
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    }
    
    this.updateActionBar()
  }

  // Delete selected incidents permanently
  deleteSelected() {
    const count = this.selectedIncidentIds.size
    
    if (count === 0) {
      alert("Please select at least one incident to delete.")
      return
    }
    
    // Analyze selected incidents
    const selectedCheckboxes = Array.from(this.checkboxTargets).filter(cb => cb.checked)
    const incidentsWithReports = selectedCheckboxes.filter(cb => {
      const reportsCount = parseInt(cb.dataset.reportsCount) || 0
      return reportsCount > 0
    })
    const decidedIncidents = selectedCheckboxes.filter(cb => {
      const status = cb.dataset.incidentStatus
      return status === "approved" || status === "rejected"
    })
    
    // Build confirmation message
    let confirmMessage = `⚠️ WARNING: This will permanently delete ${count} incident${count === 1 ? '' : 's'}.\n\n`
    
    if (decidedIncidents.length > 0) {
      confirmMessage += `${decidedIncidents.length} of these incidents have jury decisions.\n`
      confirmMessage += "Deleting them will remove decision records and may affect race results.\n\n"
    }
    
    if (incidentsWithReports.length > 0) {
      const totalReports = incidentsWithReports.reduce((sum, cb) => {
        return sum + (parseInt(cb.dataset.reportsCount) || 0)
      }, 0)
      confirmMessage += `${incidentsWithReports.length} incidents have ${totalReports} linked report${totalReports === 1 ? '' : 's'}.\n`
      confirmMessage += "All linked reports will also be PERMANENTLY DELETED.\n\n"
    }
    
    confirmMessage += "This action CANNOT be undone!\n\n"
    confirmMessage += "Are you absolutely sure you want to delete these incidents and all their reports?"
    
    if (!confirm(confirmMessage)) {
      return
    }
    
    // Build hidden inputs for incident_ids
    this.deleteHiddenInputsTarget.innerHTML = ""
    
    this.selectedIncidentIds.forEach(incidentId => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "incident_ids[]"
      input.value = incidentId
      this.deleteHiddenInputsTarget.appendChild(input)
    })
    
    // Submit the form
    this.deleteFormTarget.requestSubmit()
  }
}