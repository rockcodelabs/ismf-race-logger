import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="phone-video-player"
// Simplified video player for phone displays with autoplay and speed control
export default class extends Controller {
  static targets = ["video", "playPauseBtn", "speedSelect"]
  static values = {
    videoBlobId: String,
    videoUrl: String
  }

  connect() {
    this.startMarker = null
    this.endMarker = null
    this.isAutoPlaying = false
    
    this.loadMarkers()
    this.setupAutoPlay()
  }

  // Load saved markers from API
  async loadMarkers() {
    if (!this.videoBlobIdValue) return

    try {
      const response = await fetch(`/api/videos/${this.videoBlobIdValue}/markers`)
      if (!response.ok) return

      const data = await response.json()
      this.startMarker = data.start_time || 0
      this.endMarker = data.end_time || this.videoTarget.duration
      
      console.log(`Loaded markers: ${this.startMarker}s - ${this.endMarker}s`)
    } catch (error) {
      console.error("Failed to load markers:", error)
    }
  }

  // Setup autoplay when metadata is loaded
  setupAutoPlay() {
    if (this.videoTarget.readyState >= 1) {
      // Metadata already loaded
      this.startAutoPlay()
    } else {
      // Wait for metadata to load
      this.videoTarget.addEventListener("loadedmetadata", () => this.startAutoPlay(), { once: true })
    }
  }

  // Start autoplay from saved loop start point
  startAutoPlay() {
    if (this.isAutoPlaying) return

    this.isAutoPlaying = true

    // Jump to start marker if set
    if (this.startMarker !== null) {
      this.videoTarget.currentTime = this.startMarker
    }

    // Attempt to autoplay (may fail due to browser policies)
    const playPromise = this.videoTarget.play()
    if (playPromise !== undefined) {
      playPromise
        .then(() => {
          console.log("Autoplay started")
          this.updatePlayPauseButton()
        })
        .catch(() => {
          console.log("Autoplay blocked by browser policy")
          this.isAutoPlaying = false
          this.updatePlayPauseButton()
        })
    }
  }

  // Toggle play/pause
  togglePlay() {
    if (this.videoTarget.paused) {
      this.videoTarget.play()
    } else {
      this.videoTarget.pause()
    }
    this.updatePlayPauseButton()
  }

  // Update play/pause button icon
  updatePlayPauseButton() {
    if (!this.hasPlayPauseBtnTarget) return

    const icon = this.videoTarget.paused ? this.playIcon() : this.pauseIcon()
    this.playPauseBtnTarget.innerHTML = icon
  }

  // Handle video ended - loop back to start if markers are set
  handleEnded() {
    if (this.startMarker !== null && this.endMarker !== null) {
      // Loop: jump back to start and replay
      this.videoTarget.currentTime = this.startMarker
      this.videoTarget.play()
    }
  }

  // Handle time update - stop at end marker if set
  handleTimeUpdate() {
    if (this.endMarker !== null && this.videoTarget.currentTime >= this.endMarker) {
      this.videoTarget.currentTime = this.startMarker || 0
      this.videoTarget.play()
    }
  }

  // Change playback speed
  changeSpeed(event) {
    const speed = parseFloat(event.target.value)
    this.videoTarget.playbackRate = speed
  }

  // Icon generators
  playIcon() {
    return `
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
        <path d="M8 5v14l11-7z"/>
      </svg>
    `
  }

  pauseIcon() {
    return `
      <svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24">
        <path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/>
      </svg>
    `
  }
}