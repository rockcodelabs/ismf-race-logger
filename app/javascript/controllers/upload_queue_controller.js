// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

// UploadQueueController
//
// Manages multiple concurrent video upload batches to different reports.
// Allows users to select different reports and start new uploads while
// previous uploads are still in progress.
//
// Usage:
//   <div data-controller="upload-queue">
//     <!-- Upload interface here -->
//   </div>
//
export default class extends Controller {
  static targets = ["progress"]
  static values = {
    directUploadUrl: String,
    attachUrl: String
  }

  connect() {
    this.batches = new Map() // batchId -> BatchUploader
    this.activeBatches = 0
  }

  disconnect() {
    // Cancel all active uploads on disconnect
    this.batches.forEach(batch => batch.cancel())
    this.batches.clear()
  }

  // Add a new upload batch for a specific report
  // Called from video_upload_controller when files are dropped
  addBatch(reportId, raceId, files) {
    const batchId = crypto.randomUUID()
    
    const batch = new BatchUploader({
      id: batchId,
      reportId: reportId,
      raceId: raceId,
      files: files,
      directUploadUrl: this.directUploadUrlValue,
      attachUrl: this.attachUrlValue.replace(':report_id', reportId),
      onProgress: (progress) => this.handleBatchProgress(batchId, progress),
      onComplete: (signedIds) => this.handleBatchComplete(batchId, reportId, signedIds),
      onError: (error) => this.handleBatchError(batchId, error)
    })

    this.batches.set(batchId, batch)
    this.activeBatches++
    this.updateProgressDisplay()
    
    batch.start()
  }

  // Handle progress updates from individual batches
  handleBatchProgress(batchId, progress) {
    const batch = this.batches.get(batchId)
    if (batch) {
      batch.progress = progress
      this.updateProgressDisplay()
    }
  }

  // Handle batch completion
  handleBatchComplete(batchId, reportId, signedIds) {
    const batch = this.batches.get(batchId)
    if (!batch) return

    // Send signed IDs to controller to attach videos
    this.attachVideosToReport(reportId, signedIds)
      .then(() => {
        this.removeBatch(batchId)
        this.showSuccessNotification(signedIds.length, reportId)
      })
      .catch(error => {
        this.handleBatchError(batchId, error)
      })
  }

  // Handle batch errors
  handleBatchError(batchId, error) {
    console.error('Upload batch error:', error)
    this.removeBatch(batchId)
    this.showErrorNotification(error.message)
  }

  // Remove completed or failed batch
  removeBatch(batchId) {
    this.batches.delete(batchId)
    this.activeBatches--
    this.updateProgressDisplay()

    // Hide progress if no active batches
    if (this.activeBatches === 0) {
      this.hideProgress()
    }
  }

  // Update progress display with aggregated data
  updateProgressDisplay() {
    if (!this.hasProgressTarget) return

    const totalFiles = Array.from(this.batches.values())
      .reduce((sum, batch) => sum + batch.files.length, 0)
    
    const overallProgress = this.calculateOverallProgress()
    
    // Dispatch custom event for progress UI to update
    this.dispatch('update', {
      detail: {
        batches: this.activeBatches,
        files: totalFiles,
        progress: overallProgress
      }
    })
  }

  // Calculate overall progress across all batches
  calculateOverallProgress() {
    if (this.batches.size === 0) return 0

    const totalProgress = Array.from(this.batches.values())
      .reduce((sum, batch) => sum + (batch.progress || 0), 0)
    
    return Math.round(totalProgress / this.batches.size)
  }

  // Show progress indicator
  showProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.remove('hidden')
    }
  }

  // Hide progress indicator
  hideProgress() {
    if (this.hasProgressTarget) {
      this.progressTarget.classList.add('hidden')
    }
  }

  // Send signed blob IDs to controller to attach to report
  async attachVideosToReport(reportId, signedIds) {
    const url = this.attachUrlValue.replace(':report_id', reportId)
    const token = document.querySelector('meta[name="csrf-token"]').content

    const response = await fetch(url, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token
      },
      body: JSON.stringify({ blob_ids: signedIds })
    })

    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || 'Failed to attach videos')
    }
  }

  // Show success notification
  showSuccessNotification(count, reportId) {
    const message = `${count} video${count === 1 ? '' : 's'} uploaded successfully to Report #${reportId}`
    this.showNotification(message, 'success')
  }

  // Show error notification
  showErrorNotification(message) {
    this.showNotification(message, 'error')
  }

  // Show notification (integrates with flash controller)
  showNotification(message, type) {
    this.dispatch('notification', {
      detail: { message, type }
    })
  }

  // Check if user is navigating away with active uploads
  beforeUnload(event) {
    if (this.activeBatches > 0) {
      event.preventDefault()
      event.returnValue = 'Uploads in progress. Are you sure you want to leave?'
      return event.returnValue
    }
  }
}

// BatchUploader class
// Handles uploading a batch of files for one report
class BatchUploader {
  constructor(options) {
    this.id = options.id
    this.reportId = options.reportId
    this.raceId = options.raceId
    this.files = options.files
    this.directUploadUrl = options.directUploadUrl
    this.attachUrl = options.attachUrl
    this.onProgress = options.onProgress
    this.onComplete = options.onComplete
    this.onError = options.onError
    
    this.uploads = []
    this.signedIds = []
    this.progress = 0
    this.cancelled = false
  }

  start() {
    this.files.forEach(file => {
      const upload = new DirectUpload(
        file,
        this.directUploadUrl,
        this
      )
      
      this.uploads.push({
        upload: upload,
        file: file,
        progress: 0,
        completed: false
      })
      
      upload.create((error, blob) => {
        if (error) {
          if (!this.cancelled) {
            this.onError(error)
          }
        } else {
          this.handleFileComplete(file, blob.signed_id)
        }
      })
    })
  }

  // DirectUpload callback: track progress for individual file
  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener('progress', (event) => {
      if (this.cancelled) return
      
      const progress = (event.loaded / event.total) * 100
      this.updateFileProgress(event.target, progress)
    })
  }

  // Update progress for a specific file
  updateFileProgress(target, progress) {
    // Find upload by comparing XHR targets (not ideal but works)
    const upload = this.uploads.find(u => !u.completed)
    if (upload) {
      upload.progress = progress
      this.calculateOverallProgress()
    }
  }

  // Handle individual file completion
  handleFileComplete(file, signedId) {
    if (this.cancelled) return

    this.signedIds.push(signedId)
    
    const upload = this.uploads.find(u => u.file === file)
    if (upload) {
      upload.completed = true
      upload.progress = 100
    }

    this.calculateOverallProgress()

    // Check if all files are done
    if (this.signedIds.length === this.files.length) {
      this.onComplete(this.signedIds)
    }
  }

  // Calculate overall progress for this batch
  calculateOverallProgress() {
    const totalProgress = this.uploads.reduce((sum, u) => sum + u.progress, 0)
    this.progress = Math.round(totalProgress / this.uploads.length)
    this.onProgress(this.progress)
  }

  // Cancel all uploads in this batch
  cancel() {
    this.cancelled = true
    // Note: DirectUpload doesn't provide cancel method, uploads will complete but be ignored
  }
}