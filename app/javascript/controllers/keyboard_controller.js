import { Controller } from "@hotwired/stimulus"

// Keyboard controller for virtual on-screen keyboard
// Uses simple-keyboard library for touch-optimized input
export default class extends Controller {
  connect() {
    console.log("🎹 Keyboard controller connected")
    
    // Initialize state
    this.currentInput = null
    this.audioContext = null
    this.audioResumed = false
    this.hideTimeout = null
    
    // Ensure keyboard starts hidden
    this.forceHideKeyboard()
    
    // Dynamically import and initialize keyboard
    this.loadKeyboard()
    
    // Setup Turbo cleanup
    this.handleTurboBeforeVisit = this.handleTurboBeforeVisit.bind(this)
    document.addEventListener("turbo:before-visit", this.handleTurboBeforeVisit)
  }

  disconnect() {
    console.log("🎹 Keyboard controller disconnecting")
    
    // Clear any pending timeouts
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
    }
    
    // Force hide keyboard immediately
    this.forceHideKeyboard()
    
    // Cleanup keyboard instance
    if (this.keyboard) {
      this.keyboard.destroy()
      this.keyboard = null
    }
    
    // Close audio context
    if (this.audioContext) {
      this.audioContext.close()
      this.audioContext = null
    }
    
    // Remove all event listeners
    this.removeEventListeners()
  }

  handleTurboBeforeVisit() {
    console.log("🚫 Turbo navigation - hiding keyboard")
    this.forceHideKeyboard()
  }

  forceHideKeyboard() {
    this.element.style.display = "none"
    this.element.style.visibility = "hidden"
    this.currentInput = null
    
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }
  }

  async loadKeyboard() {
    try {
      const { SimpleKeyboard } = await import("simple-keyboard")
      this.initKeyboard(SimpleKeyboard)
      this.setupInputListeners()
      console.log("✅ Keyboard loaded")
    } catch (error) {
      console.error("❌ Failed to load keyboard:", error)
    }
  }

  initKeyboard(Keyboard) {
    this.keyboard = new Keyboard(this.element, {
      onChange: input => this.handleChange(input),
      onKeyPress: button => this.handleKeyPress(button),
      layout: this.getLayout(),
      theme: "simple-keyboard",
      display: {
        "{bksp}": "⌫",
        "{hide}": "↵ Enter",
        "{enter}": "✕ Hide",
        "{space}": " ",
        "{preview}": ""
      },
      mergeDisplay: true,
      useTouchEvents: true,
      stopMouseDownPropagation: true,
      useButtonTag: true
    })
    
    // Hide keyboard initially
    this.element.style.display = "none"
    this.element.style.visibility = "hidden"
    
    // Setup preview display styling
    this.setupPreviewDisplay()
  }

  getLayout() {
    return {
      default: [
        "1 2 3 4 5 6 7 8 9 0 {bksp}",
        "q w e r t y u i o p @",
        "a s d f g h j k l .",
        "z x c v b n m - _",
        "{preview} {space} {hide} {enter}"
      ]
    }
  }

  setupPreviewDisplay() {
    // Use requestAnimationFrame for better performance than setTimeout
    requestAnimationFrame(() => {
      const previewBtn = this.element.querySelector('[data-skbtn="{preview}"]')
      if (previewBtn) {
        previewBtn.classList.add('keyboard-preview-button')
      }
    })
  }

  setupInputListeners() {
    this.element.setAttribute("tabindex", "-1")
    
    // Bind event handlers
    this.preventNativeKeyboard = this.preventNativeKeyboard.bind(this)
    this.handleFocusIn = this.handleFocusIn.bind(this)
    this.handleFocusOut = this.handleFocusOut.bind(this)
    
    // Add event listeners
    document.addEventListener("focus", this.preventNativeKeyboard, true)
    document.addEventListener("focusin", this.handleFocusIn, { passive: true })
    document.addEventListener("focusout", this.handleFocusOut, { passive: true })
  }

  removeEventListeners() {
    document.removeEventListener("focusin", this.handleFocusIn)
    document.removeEventListener("focusout", this.handleFocusOut)
    document.removeEventListener("focus", this.preventNativeKeyboard, true)
    document.removeEventListener("turbo:before-visit", this.handleTurboBeforeVisit)
  }

  preventNativeKeyboard(event) {
    const target = event.target
    if (this.isTextInput(target) && !target.closest('[data-controller="keyboard"]')) {
      // Briefly set readonly to prevent native keyboard
      target.setAttribute("readonly", "readonly")
      requestAnimationFrame(() => {
        target.removeAttribute("readonly")
      })
    }
  }

  handleFocusIn(event) {
    if (this.isTextInput(event.target)) {
      this.showKeyboard(event.target)
    }
  }

  handleFocusOut(event) {
    // Clear existing timeout
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
    }
    
    // Debounce hide to check if focus moved to keyboard or another input
    this.hideTimeout = setTimeout(() => {
      const activeElement = document.activeElement
      
      // Keep keyboard open if still focused on input or clicked on keyboard
      if (this.isTextInput(activeElement) || this.element.contains(activeElement)) {
        return
      }
      
      this.hideKeyboard()
    }, 150)
  }

  isTextInput(element) {
    return element.matches('input[type="text"], input[type="email"], input[type="password"], textarea')
  }

  showKeyboard(input) {
    if (this.hideTimeout) {
      clearTimeout(this.hideTimeout)
      this.hideTimeout = null
    }
    
    this.currentInput = input
    this.element.style.display = "block"
    this.element.style.visibility = "visible"
    
    // Set keyboard value to current input value
    this.keyboard.setInput(input.value)
    this.updatePreview(input.value)
  }

  hideKeyboard() {
    this.forceHideKeyboard()
    
    // Reset to default layout
    if (this.keyboard) {
      this.keyboard.setOptions({ layoutName: "default" })
    }
  }

  handleChange(input) {
    if (!this.currentInput) return
    
    this.currentInput.value = input
    this.currentInput.dispatchEvent(new Event("input", { bubbles: true }))
    this.updatePreview(input)
  }

  updatePreview(value) {
    const previewBtn = this.element.querySelector('[data-skbtn="{preview}"]')
    if (!previewBtn) return
    
    // Show masked or actual value
    let displayValue = value
    if (this.currentInput?.type === 'password') {
      displayValue = '•'.repeat(value.length)
    }
    
    // Truncate if too long
    if (displayValue.length > 30) {
      displayValue = '...' + displayValue.slice(-27)
    }
    
    previewBtn.textContent = displayValue || ' '
  }

  handleKeyPress(button) {
    // Play audio feedback
    this.playBeep()
    
    // Handle special keys (positions swapped in layout)
    if (button === "{hide}") {
      this.handleEnter()
    } else if (button === "{enter}") {
      this.handleHide()
    }
  }

  handleEnter() {
    if (!this.currentInput) return
    
    if (this.currentInput.tagName === "TEXTAREA") {
      // Add newline in textarea
      const currentValue = this.keyboard.getInput()
      this.keyboard.setInput(currentValue + "\n")
    } else {
      // Submit form
      const form = this.currentInput.closest("form")
      if (form) {
        console.log("📤 Submitting form")
        form.requestSubmit()
      }
    }
  }

  handleHide() {
    // Blur current input
    this.currentInput?.blur()
    
    // Hide keyboard
    this.hideKeyboard()
  }

  async playBeep() {
    try {
      // Initialize audio context lazily
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
      }
      
      // Resume audio context if suspended
      if (this.audioContext.state === 'suspended') {
        await this.audioContext.resume()
        this.audioResumed = true
      }
      
      // Only play if running
      if (this.audioContext.state !== 'running') return
      
      const oscillator = this.audioContext.createOscillator()
      const gainNode = this.audioContext.createGain()
      
      oscillator.connect(gainNode)
      gainNode.connect(this.audioContext.destination)
      
      oscillator.frequency.value = 800
      oscillator.type = "sine"
      gainNode.gain.setValueAtTime(0.08, this.audioContext.currentTime)
      gainNode.gain.exponentialRampToValueAtTime(0.01, this.audioContext.currentTime + 0.05)
      
      oscillator.start()
      oscillator.stop(this.audioContext.currentTime + 0.05)
    } catch (e) {
      // Silently fail
    }
  }
}