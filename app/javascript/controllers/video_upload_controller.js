// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"
import ChunkedUploadService from "services/chunked_upload_service"
import VideoCacheService from "services/video_cache_service"

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
// - Per-row progress with speed and ETA
//
// Usage:
//   <tr data-controller="video-upload"
//       data-video-upload-report-id-value="123"
//       data-video-upload-race-id-value="1"
//       data-video-upload-direct-upload-url-value="/rails/active_storage/direct_uploads"
//       data-video-upload-attach-url-value="/admin/races/1/reports/123/videos">
//
export default class extends Controller {
  static targets = ["progressContainer", "progressBar", "progressText", "speedText"]
  
  static values = {
    reportId: Number,
    raceId: Number,
    directUploadUrl: String,
    attachUrl: String,
    maxSize: { type: Number, default: 500 * 1024 * 1024 }, // 500MB
    allowedTypes: { type: Array, default: ["video/mp4", "video/quicktime", "video/webm", "video/ogg", "video/x-msvideo", "video/avi"] },
    useChunkedUpload: { type: Boolean, default: true },
    chunkSize: { type: Number, default: 10 * 1024 * 1024 }, // 10MB chunks
    maxParallelChunks: { type: Number, default: 3 }
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
    this.uploadStartTime = null
    this.lastProgressTime = null
    this.lastLoadedBytes = 0
    
    // Initialize video cache service
    this.initVideoCache()
    
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
  
  async initVideoCache() {
    try {
      this.videoCache = new VideoCacheService()
      await this.videoCache.init(this.raceIdValue)
      console.log('✅ Video cache initialized for race', this.raceIdValue)
    } catch (error) {
      console.warn('⚠️ Video cache not available:', error)
      this.videoCache = null
    }
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
      files: event.dataTransfer ? event.dataTransfer.files : null
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

  // Upload files via Direct Upload or Chunked Upload
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
      console.log('📤 Starting upload for', files.length, 'file(s)...')
      // Upload all files
      for (const file of files) {
        console.log(`  ⬆️ Uploading: ${file.name}`)
        try {
          // Use chunked upload for files > 20MB, otherwise use direct upload
          const useChunked = this.useChunkedUploadValue && file.size > 20 * 1024 * 1024
          
          if (useChunked) {
            console.log(`  📦 Using chunked upload for ${file.name} (${(file.size / 1024 / 1024).toFixed(1)}MB)`)
            const signedId = await this.uploadFileChunked(file)
            console.log(`  ✅ Chunked upload complete: ${file.name} → ${signedId}`)
            signedIds.push(signedId)
          } else {
            console.log(`  📤 Using direct upload for ${file.name} (${(file.size / 1024 / 1024).toFixed(1)}MB)`)
            const signedId = await this.uploadFile(file)
            console.log(`  ✅ Direct upload complete: ${file.name} → ${signedId}`)
            signedIds.push(signedId)
          }
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
        const attachedVideos = await this.attachVideos(signedIds)
        console.log('✅ Videos attached successfully')
        
        // Cache uploaded videos for instant playback
        if (this.videoCache && attachedVideos) {
          console.log('💾 Caching uploaded videos...')
          this.cacheUploadedVideos(attachedVideos)
        }
        
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
    
    // Reset tracking variables
    this.uploadStartTime = Date.now()
    this.lastProgressTime = Date.now()
    this.lastLoadedBytes = 0
    
    return new Promise((resolve, reject) => {
      const upload = new DirectUpload(file, this.directUploadUrlValue, {
        directUploadWillStoreFileWithXHR: (xhr) => {
          xhr.upload.addEventListener('progress', (event) => {
            if (event.lengthComputable) {
              const progress = Math.round((event.loaded / event.total) * 100)
              console.log(`    📊 Upload progress for ${file.name}: ${progress}%`)
              
              // Calculate speed and ETA
              const now = Date.now()
              const timeDiff = (now - this.lastProgressTime) / 1000 // seconds
              const bytesDiff = event.loaded - this.lastLoadedBytes
              
              if (timeDiff > 0.5) { // Update every 500ms
                const speedBps = bytesDiff / timeDiff // bytes per second
                const speedMbps = (speedBps / (1024 * 1024)).toFixed(2) // MB/s
                
                const remainingBytes = event.total - event.loaded
                const eta = speedBps > 0 ? Math.ceil(remainingBytes / speedBps) : 0
                
                this.updateProgress(progress, file.name, speedMbps, eta, event.loaded, event.total)
                
                this.lastProgressTime = now
                this.lastLoadedBytes = event.loaded
              } else {
                // Just update progress without recalculating speed
                this.updateProgress(progress, file.name)
              }
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
  
  // Upload a file using chunked upload service
  uploadFileChunked(file) {
    console.log(`    📦 Creating ChunkedUploadService for ${file.name}`)
    
    return new Promise((resolve, reject) => {
      const service = new ChunkedUploadService({
        file: file,
        chunkSize: this.chunkSizeValue,
        maxParallelChunks: this.maxParallelChunksValue,
        
        onProgress: (progressData) => {
          console.log(`    📊 Chunked upload progress:`, progressData)
          
          const speedMbps = (progressData.speed / (1024 * 1024)).toFixed(2)
          this.updateProgress(
            progressData.progress,
            file.name,
            speedMbps,
            progressData.eta,
            progressData.bytesUploaded,
            progressData.totalBytes
          )
        },
        
        onChunkComplete: (chunkIndex, data) => {
          console.log(`    ✓ Chunk ${chunkIndex} uploaded (${data.received}/${data.total})`)
        },
        
        onComplete: (blobId, result) => {
          console.log(`    ✅ ChunkedUpload success for ${file.name}:`, result)
          resolve(blobId)
        },
        
        onError: (error) => {
          console.error(`    ❌ ChunkedUpload error for ${file.name}:`, error)
          reject(error)
        }
      })
      
      console.log('    📡 Starting chunked upload...')
      service.start()
    })
  }

  // Update progress display
  updateProgress(percentage, filename, speedMbps = null, eta = null, loaded = null, total = null) {
    // Update element with upload progress feedback
    let progressMessage = `Uploading ${filename}... ${percentage}%`
    
    if (speedMbps !== null && eta !== null) {
      progressMessage += ` • ${speedMbps} MB/s • ${this.formatETA(eta)}`
    }
    
    console.log(`📈 ${progressMessage}`)
    
    // Show progress in the upload zone
    this.showUploadProgress(percentage, filename, speedMbps, eta, loaded, total)
  }

  // Show upload progress in the UI
  showUploadProgress(percentage, filename, speedMbps = null, eta = null, loaded = null, total = null) {
    // Find or create progress container in the row
    let progressContainer = this.element.querySelector('.upload-progress-container')
    
    if (!progressContainer) {
      // Find the videos cell (7th td)
      const videosCell = this.element.querySelector('td:nth-child(7)')
      if (!videosCell) return
      
      // Create progress container
      progressContainer = document.createElement('div')
      progressContainer.className = 'upload-progress-container'
      progressContainer.innerHTML = `
        <div class="flex items-center gap-3">
          <div class="flex-1 min-w-0">
            <div class="flex items-center justify-between mb-1">
              <span class="text-xs font-medium text-blue-700 truncate" data-upload-filename></span>
              <span class="text-xs font-semibold text-blue-900" data-upload-percentage></span>
            </div>
            <div class="w-full bg-blue-100 rounded-full h-2 overflow-hidden">
              <div class="bg-blue-600 h-2 rounded-full transition-all duration-300" data-upload-progress-bar style="width: 0%"></div>
            </div>
            <div class="flex items-center justify-between mt-1">
              <span class="text-xs text-gray-600" data-upload-speed></span>
              <span class="text-xs text-gray-600" data-upload-size></span>
            </div>
          </div>
        </div>
      `
      
      // Replace cell content with progress
      videosCell.innerHTML = ''
      videosCell.appendChild(progressContainer)
    }
    
    // Update progress UI
    const filenameEl = progressContainer.querySelector('[data-upload-filename]')
    const percentageEl = progressContainer.querySelector('[data-upload-percentage]')
    const progressBar = progressContainer.querySelector('[data-upload-progress-bar]')
    const speedEl = progressContainer.querySelector('[data-upload-speed]')
    const sizeEl = progressContainer.querySelector('[data-upload-size]')
    
    if (filenameEl) filenameEl.textContent = filename
    if (percentageEl) percentageEl.textContent = `${percentage}%`
    if (progressBar) progressBar.style.width = `${percentage}%`
    
    if (speedEl && speedMbps !== null && eta !== null) {
      speedEl.textContent = `${speedMbps} MB/s • ${this.formatETA(eta)}`
    }
    
    if (sizeEl && loaded !== null && total !== null) {
      const loadedMB = (loaded / (1024 * 1024)).toFixed(1)
      const totalMB = (total / (1024 * 1024)).toFixed(1)
      sizeEl.textContent = `${loadedMB} / ${totalMB} MB`
    }
  }

  // Clear upload progress
  clearUploadProgress() {
    const progressContainer = this.element.querySelector('.upload-progress-container')
    if (progressContainer) {
      progressContainer.remove()
    }
  }
  
  // Format ETA in seconds to human-readable string
  formatETA(seconds) {
    if (seconds < 60) {
      return `${seconds}s left`
    } else if (seconds < 3600) {
      const mins = Math.floor(seconds / 60)
      const secs = seconds % 60
      return `${mins}m ${secs}s left`
    } else {
      const hours = Math.floor(seconds / 3600)
      const mins = Math.floor((seconds % 3600) / 60)
      return `${hours}h ${mins}m left`
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
        'X-CSRF-Token': token,
        'Accept': 'application/json'
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
      throw new Error(error.error || (error.errors && error.errors[0]) || 'Failed to attach videos')
    }

    // Try to parse response to get video IDs and URLs for caching
    try {
      const contentType = response.headers.get('content-type')
      if (contentType && contentType.includes('application/json')) {
        const result = await response.json()
        console.log('    ✅ Attach successful with data:', result)
        return result.videos || null
      }
    } catch (e) {
      console.log('    ✅ Attach successful (no JSON response)')
    }
    
    return null
  }
  
  // Cache uploaded videos for instant playback
  async cacheUploadedVideos(videos) {
    if (!videos || videos.length === 0) return
    
    try {
      for (const video of videos) {
        if (video.id && video.url) {
          console.log(`💾 Caching video ${video.id}...`)
          await this.videoCache.put(video.id, video.url, {
            filename: video.filename,
            report_id: this.reportIdValue,
            uploaded_at: new Date().toISOString()
          })
          console.log(`✅ Video ${video.id} cached`)
        }
      }
    } catch (error) {
      console.warn('⚠️ Failed to cache videos:', error)
      // Don't fail the upload if caching fails
    }
  }

  // Show uploading state
  showUploadingState(fileCount) {
    console.log('💫 Showing uploading state:', fileCount, 'file(s)')
    this.element.classList.add('bg-blue-50', 'ring-2', 'ring-blue-400')
  }

  // Clear uploading state
  clearUploadingState() {
    console.log('🧹 Clearing uploading state')
    this.element.classList.remove('bg-blue-50', 'ring-2', 'ring-blue-400')
    this.clearUploadProgress()
    
    // Show success state briefly
    this.showSuccessState()
  }
  
  // Show success state briefly after upload completes
  showSuccessState() {
    const videosCell = this.element.querySelector('td:nth-child(7)')
    if (!videosCell) return
    
    videosCell.innerHTML = `
      <div class="flex items-center gap-2 text-green-600 animate-pulse">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span class="text-sm font-medium">Upload complete!</span>
      </div>
    `
    
    // The Turbo Stream broadcast will automatically update the row with video thumbnails
    // No need to reload - just clear the success message after a brief moment
    setTimeout(() => {
      videosCell.querySelector('.animate-pulse')?.classList.remove('animate-pulse')
    }, 1500)
  }

  // Show success message
  showSuccess(message) {
    console.log('✅ SUCCESS:', message)
    
    // Use generic flash API
    if (window.flash) {
      window.flash.success(message)
    } else {
      // Fallback: dispatch custom event
      document.dispatchEvent(new CustomEvent('flash:show', {
        detail: { message, type: 'notice' }
      }))
    }
  }

  // Show error message
  showError(message) {
    console.error('❌ ERROR:', message)
    
    // Use generic flash API
    if (window.flash) {
      window.flash.error(message)
    } else {
      // Fallback: dispatch custom event
      document.dispatchEvent(new CustomEvent('flash:show', {
        detail: { message, type: 'alert' }
      }))
    }
    
    // Dispatch error event for other listeners
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

  // Legacy method - kept for backwards compatibility but now uses generic flash API
  showFlashMessage(message, type) {
    if (window.flash) {
      if (type === 'notice') {
        window.flash.success(message)
      } else {
        window.flash.error(message)
      }
    } else {
      // Fallback: dispatch custom event
      document.dispatchEvent(new CustomEvent('flash:show', {
        detail: { message, type }
      }))
    }
  }
}