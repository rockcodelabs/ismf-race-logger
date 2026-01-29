import { Controller } from "@hotwired/stimulus"

// Emergency reload controller - allows reloading page if kiosk gets stuck
//
// Tap all 4 corners of the screen in sequence (top-left, top-right, bottom-right, bottom-left)
// within 3 seconds to trigger a page reload
//
// Usage:
//   <div data-controller="emergency-reload"></div>
//
export default class extends Controller {
  connect() {
    this.cornerSequence = []
    this.sequenceTimeout = null
    this.requiredCorners = ['top-left', 'top-right', 'bottom-right', 'bottom-left']
    this.cornerSize = 100 // pixels from edge to count as corner
    
    this.handleTouch = this.handleTouch.bind(this)
    document.addEventListener('touchstart', this.handleTouch, { passive: true })
    
    console.log("🚨 Emergency reload enabled: Tap all 4 corners in sequence to reload")
  }

  disconnect() {
    document.removeEventListener('touchstart', this.handleTouch)
    if (this.sequenceTimeout) {
      clearTimeout(this.sequenceTimeout)
    }
  }

  handleTouch(event) {
    const touch = event.touches[0]
    const corner = this.getCorner(touch.clientX, touch.clientY)
    
    if (!corner) return
    
    // Add to sequence
    this.cornerSequence.push(corner)
    
    // Visual feedback
    this.showFeedback(corner)
    
    // Check if sequence is complete
    if (this.cornerSequence.length === this.requiredCorners.length) {
      if (this.isValidSequence()) {
        this.triggerReload()
      } else {
        this.resetSequence()
      }
    }
    
    // Reset sequence after 3 seconds of inactivity
    if (this.sequenceTimeout) {
      clearTimeout(this.sequenceTimeout)
    }
    this.sequenceTimeout = setTimeout(() => {
      this.resetSequence()
    }, 3000)
  }

  getCorner(x, y) {
    const screenWidth = window.innerWidth
    const screenHeight = window.innerHeight
    const size = this.cornerSize
    
    // Top-left
    if (x < size && y < size) {
      return 'top-left'
    }
    
    // Top-right
    if (x > screenWidth - size && y < size) {
      return 'top-right'
    }
    
    // Bottom-right
    if (x > screenWidth - size && y > screenHeight - size) {
      return 'bottom-right'
    }
    
    // Bottom-left
    if (x < size && y > screenHeight - size) {
      return 'bottom-left'
    }
    
    return null
  }

  isValidSequence() {
    if (this.cornerSequence.length !== this.requiredCorners.length) {
      return false
    }
    
    for (let i = 0; i < this.requiredCorners.length; i++) {
      if (this.cornerSequence[i] !== this.requiredCorners[i]) {
        return false
      }
    }
    
    return true
  }

  resetSequence() {
    this.cornerSequence = []
    console.log("🔄 Emergency sequence reset")
  }

  showFeedback(corner) {
    console.log(`🎯 Corner tapped: ${corner} (${this.cornerSequence.length}/${this.requiredCorners.length})`)
    
    // Create visual feedback
    const feedback = document.createElement('div')
    feedback.className = 'emergency-feedback'
    feedback.style.cssText = `
      position: fixed;
      width: ${this.cornerSize}px;
      height: ${this.cornerSize}px;
      background: rgba(239, 68, 68, 0.5);
      pointer-events: none;
      z-index: 9999;
      animation: emergencyPulse 0.3s ease-out;
    `
    
    // Position based on corner
    switch(corner) {
      case 'top-left':
        feedback.style.top = '0'
        feedback.style.left = '0'
        break
      case 'top-right':
        feedback.style.top = '0'
        feedback.style.right = '0'
        break
      case 'bottom-right':
        feedback.style.bottom = '0'
        feedback.style.right = '0'
        break
      case 'bottom-left':
        feedback.style.bottom = '0'
        feedback.style.left = '0'
        break
    }
    
    document.body.appendChild(feedback)
    setTimeout(() => feedback.remove(), 300)
  }

  triggerReload() {
    console.log("🚨 EMERGENCY RELOAD TRIGGERED!")
    
    // Show fullscreen confirmation
    const overlay = document.createElement('div')
    overlay.style.cssText = `
      position: fixed;
      top: 0;
      left: 0;
      width: 100%;
      height: 100%;
      background: rgba(239, 68, 68, 0.95);
      display: flex;
      align-items: center;
      justify-content: center;
      z-index: 10000;
      color: white;
      font-size: 3rem;
      font-weight: bold;
      text-align: center;
      padding: 2rem;
    `
    overlay.textContent = 'RELOADING...'
    document.body.appendChild(overlay)
    
    // Reload after brief delay
    setTimeout(() => {
      window.location.reload()
    }, 500)
  }
}

// Add CSS animation
if (!document.getElementById('emergency-reload-styles')) {
  const style = document.createElement('style')
  style.id = 'emergency-reload-styles'
  style.textContent = `
    @keyframes emergencyPulse {
      0% { opacity: 1; transform: scale(1); }
      100% { opacity: 0; transform: scale(1.5); }
    }
  `
  document.head.appendChild(style)
}