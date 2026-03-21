import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="phone-video-player"
// Phone video player — simplified: plays saved marker loop from desktop player.
export default class extends Controller {
  static targets = ["video", "playPauseBtn", "muteBtn", "speedSelect", "loopModeBtn", "progressBar"]
  static values = {
    loopMode: { type: Boolean, default: true }
  }

  connect() {
    this.startMarker = null
    this.endMarker = null
    this.isAutoPlaying = false
    window.phoneVideoPlayerController = this
    this.updateLoopModeButton()

    this.updateMuteButton()
    this.videoTarget.addEventListener("error", () => {
      const err = this.videoTarget.error
      console.error("[PhonePlayer] Video error:", err?.code, err?.message)
    })
  }

  // Called by openPhoneVideoPlayer() — load markers then autoplay
  async open(videoUrl) {
    this.startMarker = null
    this.endMarker = null
    this.isAutoPlaying = false
    this.loopModeValue = true

    // Muted is required for reliable autoplay across browsers / iOS
    this.videoTarget.muted = true
    this.updateMuteButton()
    this.videoTarget.src = videoUrl
    this.updateLoopModeButton()

    await this.loadMarkers(videoUrl)
    this.autoPlayFromMarker()
  }

  close() {
    this.videoTarget.pause()
    this.videoTarget.src = ""
    this.element.style.display = "none"
    this.isAutoPlaying = false
    this.updatePlayPauseButton()
  }

  // Extract the ActiveStorage signed_id from a rails_blob_path URL.
  // URL shape: /rails/active_storage/blobs/redirect/:signed_id/filename
  //            /rails/active_storage/blobs/:signed_id/filename  (older)
  extractSignedId(videoUrl) {
    if (!videoUrl) return null
    const match = videoUrl.match(/\/blobs\/(?:redirect\/)?([^/]+)\//)
    return match ? match[1] : null
  }

  async loadMarkers(videoUrl) {
    const signedId = this.extractSignedId(videoUrl)
    if (!signedId) return
    try {
      const response = await fetch(`/admin/videos/markers/${signedId}`)
      if (!response.ok) return
      const data = await response.json()
      // API returns 0 when no marker is saved — treat 0 as "not set"
      this.startMarker = data.start_time > 0 ? data.start_time : null
      this.endMarker   = data.end_time   > 0 ? data.end_time   : null
    } catch (err) {
      console.error("[PhonePlayer] Failed to load markers:", err)
    }
  }

  // Seek to start marker, wait for seek to complete, then play (avoids AbortError on iOS)
  autoPlayFromMarker() {
    if (this.isAutoPlaying) return
    this.isAutoPlaying = true

    const doPlay = () => {
      this.videoTarget.play()
        .then(() => this.updatePlayPauseButton())
        .catch((err) => {
          if (err.name !== "AbortError") {
            console.warn("[PhonePlayer] play() blocked:", err.name, err.message)
          }
          this.isAutoPlaying = false
          this.updatePlayPauseButton()
        })
    }

    const seekAndPlay = () => {
      const start = this.startMarker ?? 0
      if (start > 0) {
        this.videoTarget.currentTime = start
        // Wait for seek to settle before play() — prevents AbortError on mobile
        this.videoTarget.addEventListener("seeked", () => doPlay(), { once: true })
      } else {
        doPlay()
      }
    }

    if (this.videoTarget.readyState >= 2) {
      seekAndPlay()
    } else {
      this.videoTarget.addEventListener("loadedmetadata", () => seekAndPlay(), { once: true })
    }
  }

  // ── Playback controls ──────────────────────────────────────────────────────

  togglePlay() {
    if (this.videoTarget.paused) {
      this.videoTarget.play()
        .then(() => this.updatePlayPauseButton())
        .catch((err) => {
          if (err.name !== "AbortError") console.warn("[PhonePlayer] togglePlay blocked:", err)
          this.updatePlayPauseButton()
        })
    } else {
      this.videoTarget.pause()
      this.updatePlayPauseButton()
    }
  }

  updatePlayPauseButton() {
    if (!this.hasPlayPauseBtnTarget) return
    this.playPauseBtnTarget.innerHTML = this.videoTarget.paused ? this.playIcon() : this.pauseIcon()
  }

  toggleMute() {
    this.videoTarget.muted = !this.videoTarget.muted
    this.updateMuteButton()
  }

  updateMuteButton() {
    if (!this.hasMuteBtnTarget) return
    this.muteBtnTarget.innerHTML = this.videoTarget.muted ? this.mutedIcon() : this.soundIcon()
  }

  changeSpeed(event) {
    this.videoTarget.playbackRate = parseFloat(event.target.value)
  }

  seek(event) {
    if (!this.videoTarget.duration) return
    const rect = event.currentTarget.getBoundingClientRect()
    const percent = Math.max(0, Math.min(1, (event.clientX - rect.left) / rect.width))
    this.videoTarget.currentTime = percent * this.videoTarget.duration
  }

  // ── Loop mode ──────────────────────────────────────────────────────────────

  toggleLoopMode() {
    this.loopModeValue = !this.loopModeValue
    const wasPaused = this.videoTarget.paused

    // When turning loop ON, jump to start marker; when OFF, jump to beginning
    const seekTarget = this.loopModeValue ? (this.startMarker ?? 0) : 0
    this.videoTarget.currentTime = seekTarget

    if (!wasPaused) {
      this.videoTarget.addEventListener("seeked", () => {
        this.videoTarget.play()
          .then(() => this.updatePlayPauseButton())
          .catch((err) => { if (err.name !== "AbortError") console.warn(err) })
      }, { once: true })
    }

    this.updateLoopModeButton()
  }

  updateLoopModeButton() {
    if (!this.hasLoopModeBtnTarget) return
    const on = this.loopModeValue
    this.loopModeBtnTarget.textContent = on ? "Loop: ON" : "Full Video"
    this.loopModeBtnTarget.className =
      `px-4 py-3 ${on ? "bg-green-600 hover:bg-green-700" : "bg-gray-700 hover:bg-gray-800"} ` +
      `active:scale-95 rounded-lg text-white font-bold touch-manipulation transition-all text-sm shrink-0 whitespace-nowrap`
  }

  // ── Video event handlers ───────────────────────────────────────────────────

  // Always update progress bar; enforce loop boundaries only when loop is ON
  handleTimeUpdate() {
    if (this.hasProgressBarTarget && this.videoTarget.duration) {
      const percent = (this.videoTarget.currentTime / this.videoTarget.duration) * 100
      this.progressBarTarget.style.width = `${percent}%`
    }

    if (!this.loopModeValue) return

    const t = this.videoTarget.currentTime
    const start = this.startMarker ?? 0

    // Enforce start boundary: prevent scrubbing before the start marker
    if (start > 0 && t < start) {
      this.videoTarget.currentTime = start
      return
    }

    // Enforce end marker: loop back to start when end is reached
    if (this.endMarker !== null && t >= this.endMarker) {
      this.videoTarget.currentTime = start
      this.videoTarget.play().catch(() => {})
    }
  }

  // Loop the whole video when loop is ON — even if no end marker was saved
  handleEnded() {
    if (this.loopModeValue) {
      this.videoTarget.currentTime = this.startMarker ?? 0
      this.videoTarget.play().catch(() => {})
    }
    this.updatePlayPauseButton()
  }

  // ── Icons ──────────────────────────────────────────────────────────────────

  soundIcon() {
    return `<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
        d="M15.536 8.464a5 5 0 010 7.072M12 6v12m0 0l-4-4H4V10h4l4-4z"/>
    </svg>`
  }

  mutedIcon() {
    return `<svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2"
        d="M5.586 15H4a1 1 0 01-1-1v-4a1 1 0 011-1h1.586l4.707-4.707C10.923 3.663 12 4.109 12 5v14c0 .891-1.077 1.337-1.707.707L5.586 15z"/>
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2"/>
    </svg>`
  }

  playIcon() {
    return `<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>`
  }

  pauseIcon() {
    return `<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/></svg>`
  }
}