// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

console.log('📦 video_upload_controller.js module loading...')

// VideoUploadController
//
// Handles drag-and-drop video upload for individual report rows.
// Each row is its own drop zone - drag MP4 files directly onto a row to upload.
//
// Features:
// - Per-row drop zones (no selection needed)
// - Drag-and-drop from folder
// - File validation (MP4, 10-50MB)
// - Visual feedback during drag
// - Immediate upload on drop
//
// Usage:
//   <tr data-controller="video-upload"
//       data-video-upload-report-id-value="123"
//       data-video-upload-race-id-value="1"
//       data-video-upload-direct-upload-url-value="/rails/active_storage/direct_uploads"
//       data-video-upload-attach-url-value="/admin/races/1/reports/123/videos">
//
export default class extends Controller {
  static values = {
    reportId: Number,
    raceId: Number,
    directUploadUrl: String,
    attachUrl: String,
    maxSize: { type: Number, default: 500 * 1024 * 1024 }, // 500MB
    allowedTypes: { type: Array, default: ["video/mp4", "video/quicktime", "video/webm", "video/ogg", "video/x-msvideo", "video/avi"] }
  }

  connect() {
    console.log('🎬 VideoUploadController connected to element:', this.element, {
      reportId: this.reportIdValue,
      raceId: this.raceIdValue,
      directUploadUrl: this.directUploadUrlValue,
      attachUrl: this.attachUrlValue,
      maxSize: this.maxSizeValue,
      allowedTypes: this.allowedTypesValue,
      actions: this.element.dataset.action
    })
    this.dragCounter = 0
    this.uploading = false
    
    // Prevent default drag behavior on window to catch ALL drag events
    console.log('🛡️ Adding window-level drag prevention...')
    this.windowDragOverHandler = (e) => {
      console.log('🌍 Window dragover:', e.target.tagName)
      e.preventDefault()
      e.dataTransfer.dropEffect = 'none'
    }
    this.windowDropHandler = (e) => {
      console.log('🌍 Window drop (prevented):', e.target.tagName)
      e.preventDefault()
      return false
    }
    
    window.addEventListener('dragover', this.windowDragOverHandler, false)
    window.addEventListener('drop', this.windowDropHandler, false)
    
    console.log('✅ Window-level drag prevention installed')
  }
  
  disconnect() {
    console.log('👋 VideoUploadController disconnecting...')
    window.removeEventListener('dragover', this.windowDragOverHandler, false)
    window.removeEventListener('drop', this.windowDropHandler, false)
    console.log('✅ Window-level drag prevention removed')
  }

  // Handle drag enter (highlight row)
  dragEnter(event) {
    console.log('🎯 Drag enter', { dragCounter: this.dragCounter + 1 })
    event.preventDefault()
    event.stopPropagation()
    
    this.dragCounter++

    if (this.dragCounter === 1 && !this.uploading) {
      console.log('✨ Highlighting row')
      this.element.classList.add('ring-4', 'ring-blue-500', 'bg-blue-100', 'shadow-lg', 'scale-[1.01]')
      this.element.style.position = 'relative'
      this.element.style.zIndex = '10'
    }
  }

  // Handle drag over (required to allow drop)
  dragOver(event) {
    event.preventDefault()
    event.stopPropagation()
    event.dataTransfer.dropEffect = 'copy'
  }

  // Handle drag leave (remove highlight)
  dragLeave(event) {
    console.log('👋 Drag leave', { dragCounter: this.dragCounter - 1 })
    event.preventDefault()
    event.stopPropagation()
    
    this.dragCounter--

    if (this.dragCounter === 0) {
      console.log('🧹 Removing highlight')
      this.element.classList.remove('ring-4', 'ring-blue-500', 'bg-blue-100', 'shadow-lg', 'scale-[1.01]')
      this.element.style.position = ''
      this.element.style.zIndex = ''
    }
  }

  // Handle drop (process files)
  drop(event) {
    console.log('📥 Drop event received on row!', {
      event,
      target: event.target,
      currentTarget: event.currentTarget,
      dataTransfer: event.dataTransfer,
      files: event.dataTransfer?.files
    })
    event.preventDefault()
    event.stopPropagation()
    
    this.dragCounter = 0
    this.element.classList.remove('ring-4', 'ring-blue-500', 'bg-blue-100', 'shadow-lg', 'scale-[1.01]')
    this.element.style.position = ''
    this.element.style.zIndex = ''

    // Get dropped files
    const files = Array.from(event.dataTransfer.files)
    console.log('📁 Files dropped:', files.length, files.map(f => ({
      name: f.name,
      type: f.type,
      size: f.size,
      sizeMB: (f.size / 1024 / 1024).toFixed(2) + 'MB'
    })))

    if (files.length === 0) {
      console.warn('⚠️ No files in drop event')
      this.showError('No files were dropped')
      return
    }

    // Validate and upload files
    this.processFiles(files)
  }

  // Process dropped files
  processFiles(files) {
    console.log('🔍 Processing files...', files.length)
    // Filter and validate files
    const validFiles = []
    const errors = []

    files.forEach(file => {
      console.log(`🔎 Validating file: ${file.name}`)
      const validation = this.validateFile(file)
      console.log(`  → Result:`, validation)
      if (validation.valid) {
        validFiles.push(file)
      } else {
        errors.push(`${file.name}: ${validation.error}`)
      }
    })

    console.log('📊 Validation complete:', {
      total: files.length,
      valid: validFiles.length,
      invalid: errors.length
    })

    // Show validation errors if any
    if (errors.length > 0) {
      console.error('❌ File validation errors:', errors)
      this.showError(`${errors.length} file(s) invalid. Check console for details.`)
    }

    // Upload valid files
    if (validFiles.length > 0) {
      console.log('✅ Starting upload for valid files:', validFiles.map(f => f.name))
      this.uploadFiles(validFiles)
    } else {
      console.warn('⚠️ No valid files to upload')
    }
  }

  // Validate single file
  validateFile(file) {
    const sizeMB = (file.size / 1024 / 1024).toFixed(2)
    const maxMB = Math.round(this.maxSizeValue / 1024 / 1024)

    // Check file type
    if (!this.allowedTypesValue.includes(file.type)) {
      console.warn(`  ❌ Invalid type: ${file.type} (allowed: ${this.allowedTypesValue.join(', ')})`)
      return {
        valid: false,
        error: `Invalid type (${file.type}). Supported: MP4, MOV, WebM, OGG, AVI`
      }
    }

    // Check file size (no minimum, only maximum)
    if (file.size > this.maxSizeValue) {
      console.warn(`  ❌ File too large: ${sizeMB}MB (maximum: ${maxMB}MB)`)
      return {
        valid: false,
        error: `File too large (maximum: ${maxMB}MB)`
      }
    }

    console.log(`  ✅ Valid: ${sizeMB}MB MP4`)
    return { valid: true }
  }

  // Upload files via Direct Upload
  async uploadFiles(files) {
    console.log('🚀 uploadFiles called with', files.length, 'files')
    
    if (this.uploading) {
      console.warn('⚠️ Upload already in progress, ignoring')
      this.showError('Upload already in progress for this report')
      return
    }

    this.uploading = true
    this.showUploadingState(files.length)

    const signedIds = []
    const failedUploads = []

    try {
      console.log('📤 Starting Direct Upload for', files.length, 'file(s)...')
      // Upload all files
      for (const file of files) {
        console.log(`  ⬆️ Uploading: ${file.name}`)
        try {
          const signedId = await this.uploadFile(file)
          console.log(`  ✅ Upload complete: ${file.name} → ${signedId}`)
          signedIds.push(signedId)
        } catch (error) {
          console.error(`  ❌ Failed to upload ${file.name}:`, error)
          failedUploads.push(file.name)
        }
      }

      console.log('📦 Upload phase complete:', {
        successful: signedIds.length,
        failed: failedUploads.length,
        signedIds
      })

      // Attach uploaded files to report
      if (signedIds.length > 0) {
        console.log('🔗 Attaching videos to report...', this.attachUrlValue)
        await this.attachVideos(signedIds)
        console.log('✅ Videos attached successfully')
        this.showSuccess(`${signedIds.length} video${signedIds.length === 1 ? '' : 's'} uploaded successfully`)
      }

      if (failedUploads.length > 0) {
        console.error('❌ Failed uploads:', failedUploads)
        this.showError(`${failedUploads.length} file(s) failed to upload`)
      }

    } catch (error) {
      console.error('💥 Upload error:', error)
      this.showError(error.message || 'Upload failed')
    } finally {
      console.log('🏁 Upload complete, resetting state')
      this.uploading = false
      this.clearUploadingState()
    }
  }

  // Upload a single file via Direct Upload
  uploadFile(file) {
    console.log(`    🎬 Creating DirectUpload for ${file.name} to ${this.directUploadUrlValue}`)
    return new Promise((resolve, reject) => {
      const upload = new DirectUpload(file, this.directUploadUrlValue, {
        directUploadWillStoreFileWithXHR: (xhr) => {
          xhr.upload.addEventListener('progress', (event) => {
            if (event.lengthComputable) {
              const progress = Math.round((event.loaded / event.total) * 100)
              console.log(`    📊 Upload progress for ${file.name}: ${progress}%`)
              this.updateProgress(progress, file.name)
            }
          })
        }
      })
      
      console.log('    📡 Calling upload.create()...')
      upload.create((error, blob) => {
        if (error) {
          console.error(`    ❌ DirectUpload error for ${file.name}:`, error)
          reject(error)
        } else {
          console.log(`    ✅ DirectUpload success for ${file.name}:`, blob)
          resolve(blob.signed_id)
        }
      })
    })
  }

  // Update progress display
  updateProgress(percentage, filename) {
    // Update element with upload progress feedback
    const progressMessage = `Uploading ${filename}... ${percentage}%`
    console.log(`📈 ${progressMessage}`)
    
    // Show progress in the upload zone
    this.showUploadProgress(percentage, filename)
  }

  // Show upload progress in the UI
  showUploadProgress(percentage, filename) {
    // Add a subtle progress indicator to the drop zone
    const progressText = this.element.querySelector('.upload-progress-text')
    if (progressText) {
      progressText.textContent = `Uploading ${filename}... ${percentage}%`
    } else {
      // Create progress text if it doesn't exist
      const dropZone = this.element.querySelector('.border-dashed')
      if (dropZone) {
        const text = document.createElement('p')
        text.className = 'upload-progress-text text-sm text-blue-600 font-medium mt-2'
        text.textContent = `Uploading ${filename}... ${percentage}%`
        dropZone.appendChild(text)
      }
    }
  }

  // Clear upload progress
  clearUploadProgress() {
    const progressText = this.element.querySelector('.upload-progress-text')
    if (progressText) {
      progressText.remove()
    }
  }

  // Attach uploaded videos to report
  async attachVideos(signedIds) {
    console.log('    🔐 Getting CSRF token...')
    const token = document.querySelector('meta[name="csrf-token"]').content
    console.log('    🔐 CSRF token:', token ? 'Found' : 'MISSING!')

    const payload = { blob_ids: signedIds }
    console.log('    📮 Attaching videos POST:', {
      url: this.attachUrlValue,
      payload
    })

    const response = await fetch(this.attachUrlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token
      },
      body: JSON.stringify(payload)
    })

    console.log('    📬 Attach response:', {
      status: response.status,
      ok: response.ok,
      statusText: response.statusText
    })

    if (!response.ok) {
      const error = await response.json()
      console.error('    ❌ Attach failed:', error)
      throw new Error(error.error || error.errors?.[0] || 'Failed to attach videos')
    }

    console.log('    ✅ Attach successful')
  }

  // Show uploading state
  showUploadingState(fileCount) {
    console.log('💫 Showing uploading state:', fileCount, 'file(s)')
    this.element.classList.add('bg-blue-50', 'animate-pulse', 'ring-2', 'ring-blue-400')
  }

  // Clear uploading state
  clearUploadingState() {
    console.log('🧹 Clearing uploading state')
    this.element.classList.remove('bg-blue-50', 'animate-pulse', 'ring-2', 'ring-blue-400')
    this.clearUploadProgress()
  }

  // Show success message
  showSuccess(message) {
    // Show flash message in DOM
    this.showFlashMessage(message, 'notice')
    console.log('✅ SUCCESS:', message)
  }

  // Show error message
  showError(message) {
    console.error('❌ ERROR:', message)
    
    // Show flash message in DOM
    this.showFlashMessage(message, 'alert')
    
    // Dispatch error event for flash notifications
    console.log('📣 Dispatching error event...')
    this.dispatch('error', {
      detail: { message },
      bubbles: true
    })

    // Highlight element briefly in red
    console.log('🔴 Highlighting in red')
    this.element.classList.add('bg-red-50', 'ring-2', 'ring-red-400')
    setTimeout(() => {
      this.element.classList.remove('bg-red-50', 'ring-2', 'ring-red-400')
    }, 3000)
  }

  // Show flash message in DOM
  showFlashMessage(message, type) {
    const flashContainer = document.getElementById('flash-messages')
    if (!flashContainer) {
      console.warn('⚠️ Flash container not found')
      return
    }

    const flashId = `flash-${crypto.randomUUID()}`
    const bgClass = type === 'notice' ? 'bg-green-100' : 'bg-red-100'
    const borderClass = type === 'notice' ? 'border-green-500' : 'border-red-500'
    const textClass = type === 'notice' ? 'text-green-900' : 'text-red-900'
    const buttonClass = type === 'notice' ? 'text-green-700 hover:text-green-900' : 'text-red-700 hover:text-red-900'
    const iconPath = type === 'notice' 
      ? 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z'
      : 'M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z'
    const dismissTime = type === 'notice' ? 3000 : 5000

    const flashHTML = `
      <div id="${flashId}" class="fixed bottom-8 left-1/2 -translate-x-1/2 z-[9999] ${bgClass} border-2 ${borderClass} ${textClass} px-6 py-4 rounded-xl flex items-center gap-4 shadow-lg animate-slide-down max-w-md" style="display: flex !important; position: fixed !important; visibility: visible !important; pointer-events: auto;">
        <svg class="w-8 h-8 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${iconPath}" />
        </svg>
        <span class="text-xl font-semibold flex-1">${message}</span>
        <button type="button" class="${buttonClass}" onclick="this.parentElement.remove()">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    `

    flashContainer.insertAdjacentHTML('beforeend', flashHTML)

    // Auto-dismiss
    setTimeout(() => {
      const flashElement = document.getElementById(flashId)
      if (flashElement) {
        flashElement.remove()
      }
    }, dismissTime)
  }
}