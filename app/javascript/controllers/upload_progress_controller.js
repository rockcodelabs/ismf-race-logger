// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"

// UploadProgressController
//
// Displays upload progress for video uploads.
// Shows aggregate progress across all batches, with minimize/expand functionality.
//
// Features:
// - Overall progress bar
// - File count and batch count
// - Minimize to badge
// - Auto-dismiss on completion
//
// Usage:
//   <div data-controller="upload-progress"
//        data-upload-progress-target="container"
//        data-action="upload-queue:update->upload-progress#update
//                     upload-queue:notification->upload-progress#showNotification">
//     <!-- Progress UI here -->
//   </div>
//
export default class extends Controller {
  static targets = [
    "container",
    "progressBar",
    "progressText",
    "batchCount",
    "fileCount",
    "minimized",
    "expanded"
  ]

  connect() {
    this.isMinimized = false
    this.hide()
  }

  // Update progress from upload queue
  update(event) {
    const { batches, files, progress } = event.detail

    if (batches === 0) {
      this.hideWithDelay()
      return
    }

    this.show()
    this.updateProgress(progress)
    this.updateCounts(batches, files)
  }

  // Show progress container
  show() {
    if (this.hasContainerTarget) {
      this.containerTarget.classList.remove('hidden')
    }
  }

  // Hide progress container
  hide() {
    if (this.hasContainerTarget) {
      this.containerTarget.classList.add('hidden')
    }
  }

  // Hide with delay (for completion animation)
  hideWithDelay() {
    setTimeout(() => {
      this.hide()
      this.reset()
    }, 3000)
  }

  // Update progress bar and text
  updateProgress(progress) {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${progress}%`
      this.progressBarTarget.setAttribute('aria-valuenow', progress)
    }

    if (this.hasProgressTextTarget) {
      this.progressTextTarget.textContent = `${progress}%`
    }
  }

  // Update batch and file counts
  updateCounts(batches, files) {
    if (this.hasBatchCountTarget) {
      const batchText = batches === 1 ? 'report' : 'reports'
      this.batchCountTarget.textContent = `${batches} ${batchText}`
    }

    if (this.hasFileCountTarget) {
      const fileText = files === 1 ? 'file' : 'files'
      this.fileCountTarget.textContent = `${files} ${fileText}`
    }
  }

  // Toggle minimize/expand
  toggleMinimize(event) {
    event.preventDefault()
    this.isMinimized = !this.isMinimized

    if (this.isMinimized) {
      this.minimize()
    } else {
      this.expand()
    }
  }

  // Minimize to small badge
  minimize() {
    if (this.hasExpandedTarget && this.hasMinimizedTarget) {
      this.expandedTarget.classList.add('hidden')
      this.minimizedTarget.classList.remove('hidden')
    }
  }

  // Expand to full view
  expand() {
    if (this.hasExpandedTarget && this.hasMinimizedTarget) {
      this.expandedTarget.classList.remove('hidden')
      this.minimizedTarget.classList.add('hidden')
    }
  }

  // Close/cancel uploads
  close(event) {
    event.preventDefault()
    
    // Confirm if uploads are in progress
    if (confirm('Cancel all uploads in progress?')) {
      this.dispatch('cancel')
      this.hide()
      this.reset()
    }
  }

  // Reset progress state
  reset() {
    this.isMinimized = false
    this.updateProgress(0)
    this.updateCounts(0, 0)
    
    if (this.hasExpandedTarget && this.hasMinimizedTarget) {
      this.expandedTarget.classList.remove('hidden')
      this.minimizedTarget.classList.add('hidden')
    }
  }

  // Show notification (success or error)
  // Uses generic flash API provided by flash-stack controller
  showNotification(event) {
    const { message, type } = event.detail
    
    // Use global flash API if available
    if (window.flash) {
      if (type === 'success') {
        window.flash.success(message)
      } else if (type === 'error') {
        window.flash.error(message)
      } else {
        window.flash.notice(message)
      }
    } else {
      // Fallback: dispatch custom event
      document.dispatchEvent(new CustomEvent('flash:show', {
        detail: { message, type: type === 'success' ? 'notice' : 'alert' }
      }))
    }
  }
}