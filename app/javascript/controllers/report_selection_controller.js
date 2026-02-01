// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="report-selection"
export default class extends Controller {
  static targets = [
    "checkbox",
    "selectAll",
    "actionBar",
    "selectedCount",
    "form",
    "hiddenInputs",
    "deleteButton",
    "deleteForm",
    "deleteHiddenInputs",
    "row"
  ]

  static values = {
    raceId: Number
  }

  connect() {
    this.selectedReportIds = new Set()
    this.updateActionBar()
  }

  // Toggle all checkboxes
  toggleAll(event) {
    const checked = event.target.checked
    
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = checked
      const reportId = parseInt(checkbox.dataset.reportId)
      
      if (checked) {
        this.selectedReportIds.add(reportId)
      } else {
        this.selectedReportIds.delete(reportId)
      }
    })
    
    this.updateActionBar()
  }

  // Update selection when individual checkbox changes
  updateSelection(event) {
    const checkbox = event.target
    const reportId = parseInt(checkbox.dataset.reportId)
    
    if (checkbox.checked) {
      this.selectedReportIds.add(reportId)
    } else {
      this.selectedReportIds.delete(reportId)
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
    const count = this.selectedReportIds.size
    
    if (count > 0) {
      this.actionBarTarget.classList.remove("hidden")
      this.selectedCountTarget.textContent = `${count} report${count === 1 ? '' : 's'} selected`
    } else {
      this.actionBarTarget.classList.add("hidden")
    }
  }

  // Clear all selections
  clearSelection() {
    this.selectedReportIds.clear()
    
    this.checkboxTargets.forEach(checkbox => {
      checkbox.checked = false
    })
    
    if (this.hasSelectAllTarget) {
      this.selectAllTarget.checked = false
      this.selectAllTarget.indeterminate = false
    }
    
    this.updateActionBar()
  }

  // Create incident from selected reports
  createIncident() {
    const count = this.selectedReportIds.size
    
    if (count === 0) {
      alert("Please select at least one report.")
      return
    }

    // Check for linked reports and incidents with decisions
    const selectedCheckboxes = Array.from(this.checkboxTargets).filter(cb => cb.checked)
    const linkedReports = selectedCheckboxes.filter(cb => cb.dataset.incidentId)
    const reportsWithDecisions = selectedCheckboxes.filter(cb => cb.dataset.hasDecision === "true")
    
    // Build confirmation message
    let confirmMessage = ""
    
    if (count === 1) {
      confirmMessage = "You have selected only 1 report. Do you want to create an incident from this single report?"
    } else if (reportsWithDecisions.length > 0) {
      confirmMessage = `WARNING: ${reportsWithDecisions.length} of the selected reports are in incidents that already have jury decisions or penalties.\n\n`
      confirmMessage += "Moving these reports will affect existing decisions.\n\n"
      confirmMessage += "Are you sure you want to proceed?"
    } else if (linkedReports.length > 0 && reportsWithDecisions.length === 0) {
      confirmMessage = `${linkedReports.length} of the selected reports are already linked to incidents (with no decisions yet).\n\n`
      confirmMessage += "They will be moved to the new incident.\n\n"
      confirmMessage += "Continue?"
    }
    
    // Ask for confirmation if needed
    if (confirmMessage) {
      const confirmed = confirm(confirmMessage)
      if (!confirmed) return
    }
    
    // Build hidden inputs for report_ids
    this.hiddenInputsTarget.innerHTML = ""
    
    this.selectedReportIds.forEach(reportId => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "report_ids[]"
      input.value = reportId
      this.hiddenInputsTarget.appendChild(input)
    })
    
    // Submit the form
    this.formTarget.requestSubmit()
  }

  // Delete selected reports permanently
  deleteSelected() {
    const count = this.selectedReportIds.size
    
    if (count === 0) {
      alert("Please select at least one report to delete.")
      return
    }
    
    // Check if any are linked to incidents with decisions
    const selectedCheckboxes = Array.from(this.checkboxTargets).filter(cb => cb.checked)
    const linkedReports = selectedCheckboxes.filter(cb => cb.dataset.incidentId)
    const reportsWithDecisions = selectedCheckboxes.filter(cb => cb.dataset.hasDecision === "true")
    
    let confirmMessage = `⚠️ WARNING: This will permanently delete ${count} report${count === 1 ? '' : 's'}.\n\n`
    
    if (reportsWithDecisions.length > 0) {
      confirmMessage += `${reportsWithDecisions.length} of these reports are in incidents with jury decisions or penalties.\n`
      confirmMessage += "Deleting them may affect existing decisions and incident records.\n\n"
    } else if (linkedReports.length > 0) {
      confirmMessage += `${linkedReports.length} of these reports are linked to incidents.\n`
      confirmMessage += "Deleting them will also affect those incidents.\n\n"
    }
    
    confirmMessage += "This action CANNOT be undone!\n\n"
    confirmMessage += "Are you absolutely sure you want to delete these reports?"
    
    if (!confirm(confirmMessage)) {
      return
    }
    
    // Build hidden inputs for report_ids
    this.deleteHiddenInputsTarget.innerHTML = ""
    
    this.selectedReportIds.forEach(reportId => {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "report_ids[]"
      input.value = reportId
      this.deleteHiddenInputsTarget.appendChild(input)
    })
    
    // Submit the form
    this.deleteFormTarget.requestSubmit()
  }
}