import { Controller } from "@hotwired/stimulus"
import VideoCacheService from "services/video_cache_service"

// Connects to data-controller="video-player"
export default class extends Controller {
  static targets = [
    "modal",
    "video",
    "playPauseBtn",
    "playPauseIcon",
    "currentTime",
    "duration",
    "progress",
    "progressBar",
    "volumeSlider",
    "muteBtn",
    "muteIcon",
    "frameCount",
    "startMarker",
    "endMarker",
    "markerHighlight",
    "startTimeInput",
    "endTimeInput",
    "speedSelect"
  ]

  static values = {
    videoUrl: String,
    videoBlobId: String,
    fps: { type: Number, default: 30 }
  }

  connect() {
    this.playing = false
    this.startTime = 0
    this.endTime = 0
    this.frameStep = 1 / this.fpsValue
    this.isDraggingProgress = false
    this.isDraggingStart = false
    this.isDraggingEnd = false
    this.loopEnabled = false
    this.isMuted = true // Default to muted
    this.currentBlobUrl = null // Track blob URLs for cleanup
    
    // Initialize video cache service
    this.initVideoCache()
  }
  
  async initVideoCache() {
    try {
      this.videoCache = new VideoCacheService()
      // Get race ID from data attribute on page
      const raceElement = document.querySelector('[data-race-id]')
      if (raceElement) {
        const raceId = parseInt(raceElement.dataset.raceId, 10)
        await this.videoCache.init(raceId)
        console.log('✅ Video cache initialized for player')
      }
    } catch (error) {
      console.warn('⚠️ Video cache not available for player:', error)
      this.videoCache = null
    }
  }

  open(event) {
    event.preventDefault()
    const videoUrl = event.currentTarget.dataset.videoUrl
    const videoBlobId = event.currentTarget.dataset.videoBlobId
    
    if (!videoUrl) {
      console.error("No video URL provided")
      return
    }

    this.openWithUrl(videoUrl, videoBlobId)
  }

  async openWithUrl(videoUrl, videoBlobId = null) {
    if (!videoUrl) {
      console.error("No video URL provided")
      return
    }

    this.videoUrlValue = videoUrl
    this.videoBlobIdValue = videoBlobId
    
    // Try to load from cache first
    const cachedVideoUrl = await this.loadFromCache(videoBlobId)
    const finalUrl = cachedVideoUrl || videoUrl
    
    this.videoTarget.src = finalUrl
    this.videoTarget.muted = this.isMuted // Set default mute state
    this.modalTarget.classList.remove("hidden")
    this.modalTarget.classList.add("flex")
    
    // Prevent body scroll
    document.body.style.overflow = "hidden"
    
    // Add keyboard listener
    this.boundKeyHandler = this.handleKeyboard.bind(this)
    document.addEventListener("keydown", this.boundKeyHandler)
    
    // Load existing markers if available
    this.loadMarkers()
  }
  
  // Load video from cache if available
  async loadFromCache(videoBlobId) {
    if (!this.videoCache || !videoBlobId) {
      console.log('📡 Loading video from server (no cache)')
      return null
    }
    
    try {
      // Extract video ID from blob ID or URL
      const videoId = this.extractVideoId(videoBlobId)
      if (!videoId) {
        console.log('📡 Loading video from server (no video ID)')
        return null
      }
      
      console.log(`🔍 Checking cache for video ${videoId}...`)
      const cached = await this.videoCache.get(videoId)
      
      if (cached && cached.blobUrl) {
        console.log(`✅ Video ${videoId} loaded from cache (instant playback)`)
        
        // Clean up previous blob URL if exists
        if (this.currentBlobUrl) {
          VideoCacheService.revokeObjectURL(this.currentBlobUrl)
        }
        
        this.currentBlobUrl = cached.blobUrl
        this.showCacheIndicator(true)
        return cached.blobUrl
      } else {
        console.log(`📡 Loading video ${videoId} from server (not cached)`)
        this.showCacheIndicator(false)
        
        // Optionally: Cache it in background after loading
        this.cacheVideoInBackground(videoId, this.videoUrlValue)
        
        return null
      }
    } catch (error) {
      console.error('Failed to load from cache:', error)
      this.showCacheIndicator(false)
      return null
    }
  }
  
  // Extract video ID from blob ID or attachment ID
  extractVideoId(identifier) {
    if (!identifier) return null
    
    // If it's a number, use it directly
    if (typeof identifier === 'number') return identifier
    
    // If it's a string that looks like a number, parse it
    const parsed = parseInt(identifier, 10)
    if (!isNaN(parsed)) return parsed
    
    // Otherwise try to extract from URL patterns
    const match = identifier.match(/\/(\d+)\//)
    return match ? parseInt(match[1], 10) : null
  }
  
  // Cache video in background for next time
  async cacheVideoInBackground(videoId, videoUrl) {
    if (!this.videoCache || !videoId || !videoUrl) return
    
    try {
      console.log(`💾 Caching video ${videoId} in background...`)
      await this.videoCache.put(videoId, videoUrl)
      console.log(`✅ Video ${videoId} cached for next time`)
      this.showCacheIndicator(true)
    } catch (error) {
      console.warn(`⚠️ Failed to cache video ${videoId}:`, error)
    }
  }
  
  // Show cache status indicator
  showCacheIndicator(fromCache) {
    // Add a small indicator to show if video is from cache
    const indicator = this.modalTarget.querySelector('.cache-indicator')
    if (indicator) {
      indicator.remove()
    }
    
    const indicatorEl = document.createElement('div')
    indicatorEl.className = 'cache-indicator absolute top-20 right-4 px-3 py-1 rounded-full text-xs font-medium z-50'
    
    if (fromCache) {
      indicatorEl.classList.add('bg-green-500', 'text-white')
      indicatorEl.innerHTML = `
        <div class="flex items-center gap-1">
          <svg class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
          <span>Cached</span>
        </div>
      `
    } else {
      indicatorEl.classList.add('bg-blue-500', 'text-white')
      indicatorEl.innerHTML = `
        <div class="flex items-center gap-1">
          <svg class="w-3 h-3 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          <span>Streaming</span>
        </div>
      `
    }
    
    this.modalTarget.appendChild(indicatorEl)
    
    // Auto-hide after 3 seconds
    setTimeout(() => {
      indicatorEl.style.opacity = '0'
      indicatorEl.style.transition = 'opacity 0.5s'
      setTimeout(() => indicatorEl.remove(), 500)
    }, 3000)
  }

  close() {
    this.videoTarget.pause()
    this.videoTarget.currentTime = 0
    this.videoTarget.src = '' // Clear src to release resources
    this.modalTarget.classList.add("hidden")
    this.modalTarget.classList.remove("flex")
    
    // Cleanup blob URL if we created one
    if (this.currentBlobUrl) {
      VideoCacheService.revokeObjectURL(this.currentBlobUrl)
      this.currentBlobUrl = null
    }
    
    // Restore body scroll
    document.body.style.overflow = ""
    
    // Remove keyboard listener
    if (this.boundKeyHandler) {
      document.removeEventListener("keydown", this.boundKeyHandler)
    }
  }

  closeOnBackdrop(event) {
    if (event.target === event.currentTarget) {
      this.close()
    }
  }

  // Playback controls
  togglePlay() {
    if (this.playing) {
      this.pause()
    } else {
      this.play()
    }
  }

  play() {
    // Check if we're at or past the end marker
    if (this.endTime > 0 && this.videoTarget.currentTime >= this.endTime) {
      this.videoTarget.currentTime = this.startTime > 0 ? this.startTime : 0
    }
    
    const playPromise = this.videoTarget.play()
    
    if (playPromise !== undefined) {
      playPromise
        .then(() => {
          this.playing = true
          this.updatePlayPauseButton()
          console.log('✅ Video playing successfully')
        })
        .catch(error => {
          console.error('❌ Auto-play prevented:', error)
          this.playing = false
          this.updatePlayPauseButton()
          // Optionally show user feedback that they need to manually start playback
        })
    } else {
      this.playing = true
      this.updatePlayPauseButton()
    }
  }

  pause() {
    this.videoTarget.pause()
    this.playing = false
    this.updatePlayPauseButton()
  }

  updatePlayPauseButton() {
    const isPlaying = !this.videoTarget.paused
    this.playPauseIconTarget.innerHTML = isPlaying ? this.pauseIcon() : this.playIcon()
  }

  // Frame-by-frame navigation
  nextFrame() {
    this.pause()
    this.videoTarget.currentTime = Math.min(
      this.videoTarget.currentTime + this.frameStep,
      this.videoTarget.duration
    )
  }

  previousFrame() {
    this.pause()
    this.videoTarget.currentTime = Math.max(
      this.videoTarget.currentTime - this.frameStep,
      0
    )
  }

  // Jump controls
  skipForward() {
    this.videoTarget.currentTime = Math.min(
      this.videoTarget.currentTime + 5,
      this.videoTarget.duration
    )
  }

  skipBackward() {
    this.videoTarget.currentTime = Math.max(
      this.videoTarget.currentTime - 5,
      0
    )
  }

  // Time marker controls
  setStartMarker() {
    this.startTime = this.videoTarget.currentTime
    this.updateMarkers()
    this.updateMarkerInputs()
  }

  setEndMarker() {
    this.endTime = this.videoTarget.currentTime
    this.updateMarkers()
    this.updateMarkerInputs()
  }

  clearMarkers() {
    this.startTime = 0
    this.endTime = 0
    this.updateMarkers()
    this.updateMarkerInputs()
  }

  jumpToStart() {
    if (this.startTime > 0) {
      this.videoTarget.currentTime = this.startTime
    }
  }

  jumpToEnd() {
    if (this.endTime > 0) {
      this.videoTarget.currentTime = this.endTime
    }
  }

  toggleLoop() {
    this.loopEnabled = !this.loopEnabled
    this.updateLoopButton()
  }

  updateLoopButton() {
    const loopBtn = document.querySelector('[data-video-player-target="loopBtn"]')
    if (loopBtn) {
      if (this.loopEnabled) {
        loopBtn.classList.add('bg-blue-600', 'text-white')
        loopBtn.classList.remove('bg-gray-700', 'hover:bg-gray-600')
      } else {
        loopBtn.classList.remove('bg-blue-600', 'text-white')
        loopBtn.classList.add('bg-gray-700', 'hover:bg-gray-600')
      }
    }
  }

  async saveMarkers() {
    if (!this.videoBlobIdValue) {
      console.error("No video blob ID available")
      alert("Cannot save markers - video ID not found")
      return
    }

    const data = {
      blob_id: this.videoBlobIdValue,
      start_time: this.startTime,
      end_time: this.endTime,
      loop_enabled: this.loopEnabled,
      muted: this.videoTarget.muted
    }

    console.log('Saving markers:', data)

    try {
      const response = await fetch('/admin/videos/markers', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify(data)
      })

      const result = await response.json()
      console.log('Save response:', result)

      if (response.ok) {
        console.log('Markers saved successfully:', result)
        this.showSaveSuccess()
      } else {
        console.error('Save failed:', result)
        throw new Error('Failed to save markers')
      }
    } catch (error) {
      console.error('Error saving markers:', error)
      alert('Failed to save markers. Please try again.')
    }
  }

  async loadMarkers() {
    if (!this.videoBlobIdValue) {
      console.log('No blob ID, skipping marker load')
      return
    }

    console.log('Loading markers for blob:', this.videoBlobIdValue)

    try {
      const response = await fetch(`/admin/videos/markers/${this.videoBlobIdValue}`)
      
      if (response.ok) {
        const data = await response.json()
        console.log('Loaded markers:', data)
        
        if (data.start_time !== undefined && data.end_time !== undefined) {
          this.startTime = data.start_time
          this.endTime = data.end_time
          this.loopEnabled = data.loop_enabled || false
          this.isMuted = data.muted !== undefined ? data.muted : true
          this.videoTarget.muted = this.isMuted
          console.log('Set markers - start:', this.startTime, 'end:', this.endTime, 'loop:', this.loopEnabled, 'muted:', this.isMuted)
          this.updateMarkers()
          this.updateMarkerInputs()
          this.updateLoopButton()
          this.updateMuteButton()
          
          // Auto-play if markers are set
          if (this.startTime > 0 || this.endTime > 0) {
            console.log('🎬 Auto-playing video from start marker')
            this.autoPlayFromMarker()
          }
        }
      }
    } catch (error) {
      console.error('Error loading markers:', error)
    }
  }

  autoPlayFromMarker() {
    // Ensure video is muted for autoplay to work
    this.videoTarget.muted = this.isMuted
    
    const attemptPlay = () => {
      console.log('⏩ Seeking to start marker:', this.startTime)
      this.videoTarget.currentTime = this.startTime
      
      // Wait a bit for seek to complete, then play
      setTimeout(() => {
        console.log('▶️ Attempting to play video...')
        this.play()
      }, 200)
    }
    
    // Wait for video to be ready
    if (this.videoTarget.readyState >= 2) {
      // Video metadata is already loaded
      attemptPlay()
    } else {
      // Wait for metadata to load
      this.videoTarget.addEventListener('loadedmetadata', attemptPlay, { once: true })
    }
  }

  showSaveSuccess() {
    // Create temporary success message
    const saveBtn = document.querySelector('[data-action*="saveMarkers"]')
    if (saveBtn) {
      const originalText = saveBtn.innerHTML
      saveBtn.innerHTML = '✓ Saved!'
      saveBtn.classList.add('bg-green-600')
      saveBtn.classList.remove('bg-blue-600')
      
      setTimeout(() => {
        saveBtn.innerHTML = originalText
        saveBtn.classList.remove('bg-green-600')
        saveBtn.classList.add('bg-blue-600')
      }, 2000)
    }
  }

  updateMarkers() {
    if (!this.videoTarget.duration) return
    
    const duration = this.videoTarget.duration
    
    // Update start marker position
    if (this.startTime > 0) {
      const startPercent = (this.startTime / duration) * 100
      this.startMarkerTarget.style.left = `${startPercent}%`
      this.startMarkerTarget.classList.remove("hidden")
    } else {
      this.startMarkerTarget.classList.add("hidden")
    }
    
    // Update end marker position
    if (this.endTime > 0) {
      const endPercent = (this.endTime / duration) * 100
      this.endMarkerTarget.style.left = `${endPercent}%`
      this.endMarkerTarget.classList.remove("hidden")
    } else {
      this.endMarkerTarget.classList.add("hidden")
    }
    
    // Update highlight between markers
    if (this.startTime > 0 && this.endTime > 0) {
      const startPercent = (this.startTime / duration) * 100
      const endPercent = (this.endTime / duration) * 100
      this.markerHighlightTarget.style.left = `${startPercent}%`
      this.markerHighlightTarget.style.width = `${endPercent - startPercent}%`
      this.markerHighlightTarget.classList.remove("hidden")
    } else {
      this.markerHighlightTarget.classList.add("hidden")
    }
  }

  updateMarkerInputs() {
    if (this.hasStartTimeInputTarget) {
      this.startTimeInputTarget.value = this.formatTime(this.startTime)
    }
    if (this.hasEndTimeInputTarget) {
      this.endTimeInputTarget.value = this.formatTime(this.endTime)
    }
  }

  // Progress bar controls
  startDrag(event) {
    this.isDraggingProgress = true
    this.updateProgress(event)
  }

  drag(event) {
    if (this.isDraggingProgress) {
      this.updateProgress(event)
    }
  }

  stopDrag() {
    this.isDraggingProgress = false
  }

  updateProgress(event) {
    const rect = this.progressTarget.getBoundingClientRect()
    const x = event.clientX - rect.left
    const percent = Math.max(0, Math.min(1, x / rect.width))
    this.videoTarget.currentTime = percent * this.videoTarget.duration
  }

  // Volume controls
  toggleMute() {
    this.videoTarget.muted = !this.videoTarget.muted
    this.isMuted = this.videoTarget.muted
    this.updateMuteButton()
  }

  updateVolume(event) {
    this.videoTarget.volume = event.target.value / 100
    this.videoTarget.muted = false
    this.isMuted = false
    this.updateMuteButton()
  }

  updateMuteButton() {
    const isMuted = this.videoTarget.muted || this.videoTarget.volume === 0
    this.muteIconTarget.innerHTML = isMuted ? this.mutedIcon() : this.volumeIcon()
  }

  // Speed control
  changeSpeed(event) {
    this.videoTarget.playbackRate = parseFloat(event.target.value)
  }

  // Video event handlers
  handleLoadedMetadata() {
    this.durationTarget.textContent = this.formatTime(this.videoTarget.duration)
    
    // Only set endTime to duration if not already loaded from metadata
    if (this.endTime === 0) {
      this.endTime = this.videoTarget.duration
    }
    
    this.updateMarkers()
    this.updateMarkerInputs()
  }

  handleTimeUpdate() {
    // Update current time display
    this.currentTimeTarget.textContent = this.formatTime(this.videoTarget.currentTime)
    
    // Update frame count
    const currentFrame = Math.floor(this.videoTarget.currentTime * this.fpsValue)
    const totalFrames = Math.floor(this.videoTarget.duration * this.fpsValue)
    this.frameCountTarget.textContent = `Frame ${currentFrame} / ${totalFrames}`
    
    // Update progress bar
    const percent = (this.videoTarget.currentTime / this.videoTarget.duration) * 100
    this.progressBarTarget.style.width = `${percent}%`
    
    // Check if we've reached the end marker
    if (this.endTime > 0 && this.videoTarget.currentTime >= this.endTime) {
      if (this.loopEnabled && this.startTime >= 0) {
        // Loop back to start marker
        console.log('🔁 Looping back to start marker:', this.startTime)
        this.videoTarget.currentTime = this.startTime > 0 ? this.startTime : 0
        // Ensure video continues playing after seeking
        if (this.videoTarget.paused) {
          this.play()
        }
      } else {
        // Stop at end marker
        this.pause()
        this.videoTarget.currentTime = this.endTime
      }
    }
  }

  handleEnded() {
    this.playing = false
    this.updatePlayPauseButton()
  }

  // Keyboard shortcuts
  handleKeyboard(event) {
    // Don't handle if user is typing in an input
    if (event.target.tagName === "INPUT" || event.target.tagName === "TEXTAREA") {
      return
    }

    switch(event.key) {
      case " ":
      case "k":
      case "K":
        event.preventDefault()
        this.togglePlay()
        break
      case "ArrowLeft":
        event.preventDefault()
        if (event.shiftKey) {
          this.skipBackward()
        } else {
          this.previousFrame()
        }
        break
      case "ArrowRight":
        event.preventDefault()
        if (event.shiftKey) {
          this.skipForward()
        } else {
          this.nextFrame()
        }
        break
      case "m":
      case "M":
        event.preventDefault()
        this.toggleMute()
        break
      case "i":
      case "I":
        event.preventDefault()
        this.setStartMarker()
        break
      case "o":
      case "O":
        event.preventDefault()
        this.setEndMarker()
        break
      case "l":
      case "L":
        event.preventDefault()
        this.toggleLoop()
        break
      case "Escape":
        event.preventDefault()
        this.close()
        break
      case "0":
      case "1":
      case "2":
      case "3":
      case "4":
      case "5":
      case "6":
      case "7":
      case "8":
      case "9":
        event.preventDefault()
        const percent = parseInt(event.key) / 10
        this.videoTarget.currentTime = this.videoTarget.duration * percent
        break
    }
  }

  // Helper methods
  formatTime(seconds) {
    if (isNaN(seconds)) return "0:00"
    
    const mins = Math.floor(seconds / 60)
    const secs = Math.floor(seconds % 60)
    const ms = Math.floor((seconds % 1) * 100)
    return `${mins}:${secs.toString().padStart(2, "0")}.${ms.toString().padStart(2, "0")}`
  }

  playIcon() {
    return `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.752 11.168l-3.197-2.132A1 1 0 0010 9.87v4.263a1 1 0 001.555.832l3.197-2.132a1 1 0 000-1.664z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />`
  }

  pauseIcon() {
    return `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 9v6m4-6v6m7-3a9 9 0 11-18 0 9 9 0 0118 0z" />`
  }

  volumeIcon() {
    return `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.536 8.464a5 5 0 010 7.072m2.828-9.9a9 9 0 010 12.728M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />`
  }

  mutedIcon() {
    return `<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z" />
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2" />`
  }
}

