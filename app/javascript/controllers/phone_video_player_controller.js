import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="phone-video-player"
// Phone video player — simplified: plays saved marker loop from desktop player.
export default class extends Controller {
  static targets = ["video", "playPauseBtn", "speedSelect", "loopModeBtn", "progressBar"]
  static values = {
    loopMode: { type: Boolean, default: true }
  }

  connect() {
    this.startMarker = null
    this.endMarker = null
    this.isAutoPlaying = false
    window.phoneVideoPlayerController = this
    this.updateLoopModeButton()

    // Debug: watch for video errors
    this.videoTarget.addEventListener("error", (e) => {
      const err = this.videoTarget.error
      console.error("[PhonePlayer] ❌ Video error:", err?.code, err?.message, e)
    })
    this.videoTarget.addEventListener("stalled", () => console.warn("[PhonePlayer] ⚠️ Video stalled"))
    this.videoTarget.addEventListener("suspend", () => console.log("[PhonePlayer] Video suspended (network idle)"))
    this.videoTarget.addEventListener("waiting", () => console.log("[PhonePlayer] Video waiting for data..."))
    this.videoTarget.addEventListener("canplay", () => console.log("[PhonePlayer] canplay — readyState:", this.videoTarget.readyState))
    this.videoTarget.addEventListener("canplaythrough", () => console.log("[PhonePlayer] canplaythrough"))
  }

  // Called by openPhoneVideoPlayer() — load markers then autoplay
  async open(videoUrl, videoBlobId) {
    this.startMarker = null
    this.endMarker = null
    this.isAutoPlaying = false
    this.loopModeValue = true

    // Muted is required for reliable autoplay across browsers / iOS
    this.videoTarget.muted = true
    this.videoTarget.src = videoUrl
    this.updateLoopModeButton()

    console.log("[PhonePlayer] open() — url:", videoUrl, "blobId:", videoBlobId)
    this._debugDom()

    await this.loadMarkers(videoBlobId)
    console.log("[PhonePlayer] Markers ready — start:", this.startMarker, "end:", this.endMarker)
    this.autoPlayFromMarker()
  }

  close() {
    this.videoTarget.pause()
    this.videoTarget.src = ""
    this.element.style.display = "none"
    this.isAutoPlaying = false
    this.updatePlayPauseButton()
  }

  async loadMarkers(videoBlobId) {
    if (!videoBlobId) return
    try {
      const response = await fetch(`/admin/videos/markers/${videoBlobId}`)
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
      console.log("[PhonePlayer] Calling play()...")
      this._debugVideoState("before play()")
      this.videoTarget.play()
        .then(() => {
          console.log("[PhonePlayer] ✓ Playing")
          this.updatePlayPauseButton()
          // Give the browser one frame to paint, then check if video is actually visible
          requestAnimationFrame(() => {
            requestAnimationFrame(() => this._debugVideoState("after first paint"))
          })
        })
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
        console.log("[PhonePlayer] Seeking to", start)
        this.videoTarget.currentTime = start
        // Wait for seek to settle before play() — prevents AbortError on mobile
        this.videoTarget.addEventListener("seeked", () => doPlay(), { once: true })
      } else {
        doPlay()
      }
    }

    if (this.videoTarget.readyState >= 2) {
      console.log("[PhonePlayer] Metadata already loaded, seeking + playing")
      seekAndPlay()
    } else {
      console.log("[PhonePlayer] Waiting for metadata...")
      this.videoTarget.addEventListener("loadedmetadata", () => {
        console.log("[PhonePlayer] Metadata loaded")
        seekAndPlay()
      }, { once: true })
    }
  }

  // ── Debug helpers ──────────────────────────────────────────────────────────

  _debugDom() {
    const modal = this.element
    const video = this.videoTarget

    const modalRect   = modal.getBoundingClientRect()
    const videoRect   = video.getBoundingClientRect()
    const modalStyle  = getComputedStyle(modal)
    const videoStyle  = getComputedStyle(video)

    console.group("[PhonePlayer] DOM snapshot")

    console.log("Modal display:", modalStyle.display,
      "| visibility:", modalStyle.visibility,
      "| opacity:", modalStyle.opacity,
      "| z-index:", modalStyle.zIndex,
      "| position:", modalStyle.position)
    console.log("Modal rect:", JSON.stringify(modalRect.toJSON()))

    console.log("Video display:", videoStyle.display,
      "| visibility:", videoStyle.visibility,
      "| opacity:", videoStyle.opacity,
      "| z-index:", videoStyle.zIndex,
      "| position:", videoStyle.position)
    console.log("Video rect:", JSON.stringify(videoRect.toJSON()))

    // Check for ancestor transforms that break position:fixed
    let el = video.parentElement
    while (el && el !== document.body) {
      const s = getComputedStyle(el)
      if (s.transform !== "none" || s.filter !== "none" || s.willChange !== "auto") {
        console.warn("[PhonePlayer] ⚠️ Ancestor breaks position:fixed — transform/filter/will-change found on:", el,
          "| transform:", s.transform, "| filter:", s.filter, "| willChange:", s.willChange)
      }
      el = el.parentElement
    }

    console.groupEnd()
  }

  _debugVideoState(label = "") {
    const v = this.videoTarget
    console.group(`[PhonePlayer] Video state ${label ? "(" + label + ")" : ""}`)
    console.log("src:", v.src)
    console.log("readyState:", v.readyState, "| networkState:", v.networkState)
    console.log("paused:", v.paused, "| ended:", v.ended, "| muted:", v.muted)
    console.log("currentTime:", v.currentTime, "| duration:", v.duration)
    console.log("videoWidth:", v.videoWidth, "| videoHeight:", v.videoHeight,
      "← (0×0 means no decoded frames yet)")
    const rect = v.getBoundingClientRect()
    console.log("rendered size:", rect.width, "×", rect.height,
      "| top:", rect.top, "left:", rect.left)
    const s = getComputedStyle(v)
    console.log("z-index:", s.zIndex, "| position:", s.position,
      "| opacity:", s.opacity, "| visibility:", s.visibility)
    console.groupEnd()
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

  playIcon() {
    return `<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M8 5v14l11-7z"/></svg>`
  }

  pauseIcon() {
    return `<svg class="w-6 h-6" fill="currentColor" viewBox="0 0 24 24"><path d="M6 4h4v16H6V4zm8 0h4v16h-4V4z"/></svg>`
  }
}