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
  showNotification(event) {
    const { message, type } = event.detail
    
    // Create flash message element
    const flashContainer = document.getElementById('flash-messages')
    if (!flashContainer) return

    const flashElement = document.createElement('div')
    flashElement.className = this.getFlashClasses(type)
    flashElement.textContent = message
    flashElement.setAttribute('data-controller', 'flash')
    flashElement.setAttribute('data-flash-delay-value', '5000')

    flashContainer.appendChild(flashElement)
  }

  // Get CSS classes for flash message based on type
  getFlashClasses(type) {
    const baseClasses = 'px-4 py-3 rounded-lg shadow-lg mb-2'
    
    if (type === 'success') {
      return `${baseClasses} bg-green-100 text-green-800 border border-green-200`
    } else if (type === 'error') {
      return `${baseClasses} bg-red-100 text-red-800 border border-red-200`
    } else {
      return `${baseClasses} bg-blue-100 text-blue-800 border border-blue-200`
    }
  }
}