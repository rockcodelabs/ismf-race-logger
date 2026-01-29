import { Controller } from "@hotwired/stimulus"

// Keyboard controller for virtual on-screen keyboard
//
// Uses simple-keyboard library for touch-optimized input
//
// Usage:
//   <div data-controller="keyboard"></div>
//
// Features:
//   - Auto-show on input focus
//   - Auto-hide on blur
//   - Input preview (left of spacebar)
//   - Password masking (bullets)
//   - Audio feedback
//   - Shift key toggle
//   - Enter key submits forms
//
export default class extends Controller {
  connect() {
    console.log("🎹 Keyboard controller connected")
    
    // Initialize audio context (will be resumed on first user interaction)
    this.audioContext = null
    this.audioResumed = false
    
    // Ensure keyboard starts hidden
    this.element.style.display = "none"
    this.element.style.visibility = "hidden"
    
    // Dynamically import simple-keyboard
    this.loadKeyboard()
    
    // Setup Turbo cleanup
    this.handleTurboBeforeVisit = this.handleTurboBeforeVisit.bind(this)
    document.addEventListener("turbo:before-visit", this.handleTurboBeforeVisit)
  }

  disconnect() {
    console.log("🎹 Keyboard controller disconnecting")
    
    // Force hide keyboard immediately
    this.forceHideKeyboard()
    
    if (this.keyboard) {
      this.keyboard.destroy()
    }
    
    // Close audio context
    if (this.audioContext) {
      this.audioContext.close()
    }
    
    // Remove event listeners
    document.removeEventListener("focusin", this.handleFocusIn)
    document.removeEventListener("focusout", this.handleFocusOut)
    document.removeEventListener("focus", this.preventNativeKeyboard, true)
    document.removeEventListener("turbo:before-visit", this.handleTurboBeforeVisit)
  }

  handleTurboBeforeVisit() {
    console.log("🚫 Turbo navigation - hiding keyboard")
    this.forceHideKeyboard()
  }

  forceHideKeyboard() {
    this.element.style.display = "none"
    this.element.style.visibility = "hidden"
    this.currentInput = null
  }

  async loadKeyboard() {
    try {
      // Import simple-keyboard - use named export SimpleKeyboard
      const { SimpleKeyboard } = await import("simple-keyboard")
      
      this.initKeyboard(SimpleKeyboard)
      this.setupInputListeners()
      
      console.log("✅ Keyboard loaded successfully")
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
    // Find the preview button after keyboard renders
    setTimeout(() => {
      const previewBtn = this.element.querySelector('[data-skbtn="{preview}"]')
      if (previewBtn) {
        previewBtn.classList.add('keyboard-preview-button')
        previewBtn.style.pointerEvents = 'none'
        previewBtn.style.userSelect = 'none'
      }
    }, 100)
  }

  createKeyboardHTML() {
    // CSS is loaded from assets/stylesheets/simple-keyboard.css
    // No need to dynamically load it
  }

  setupInputListeners() {
    // Prevent keyboard element from being focusable
    this.element.setAttribute("tabindex", "-1")
    
    // Prevent native mobile/kiosk keyboard
    this.preventNativeKeyboard = this.preventNativeKeyboard.bind(this)
    document.addEventListener("focus", this.preventNativeKeyboard, true)

    // Show keyboard on focus
    this.handleFocusIn = this.handleFocusIn.bind(this)
    document.addEventListener("focusin", this.handleFocusIn)

    // Hide keyboard on blur
    this.handleFocusOut = this.handleFocusOut.bind(this)
    document.addEventListener("focusout", this.handleFocusOut)
  }

  preventNativeKeyboard(event) {
    if (this.isTextInput(event.target)) {
      // Skip if inside keyboard
      if (event.target.closest('[data-controller="keyboard"]')) {
        return
      }
      
      console.log("🛡️ Preventing native keyboard for:", event.target.id || event.target.name)
      
      // Set input to readonly briefly to prevent native keyboard
      event.target.setAttribute("readonly", "readonly")
      setTimeout(() => {
        event.target.removeAttribute("readonly")
        event.target.focus()
      }, 10)
    }
  }

  handleFocusIn(event) {
    if (this.isTextInput(event.target)) {
      this.showKeyboard(event.target)
    }
  }

  handleFocusOut(event) {
    // Only hide if clicking outside both input and keyboard
    setTimeout(() => {
      const activeElement = document.activeElement
      
      // Keep keyboard open if:
      // - Still focused on a text input
      // - Clicking on keyboard element
      if (this.isTextInput(activeElement)) {
        return
      }
      
      // Check if click is on keyboard
      const clickedElement = document.elementFromPoint(
        event.clientX || window.innerWidth / 2,
        event.clientY || window.innerHeight - 100
      )
      
      if (clickedElement && this.element.contains(clickedElement)) {
        return
      }
      
      this.hideKeyboard()
    }, 200)
  }

  isTextInput(element) {
    return element.matches('input[type="text"], input[type="email"], input[type="password"], textarea')
  }

  showKeyboard(input) {
    this.currentInput = input
    this.element.style.display = "block"
    this.element.style.visibility = "visible"
    
    // Set keyboard value to current input value
    this.keyboard.setInput(input.value)
    
    // Update preview
    this.updatePreview(input.value)
    
    console.log("⌨️ Keyboard shown for:", input.id || input.name)
  }

  hideKeyboard() {
    this.element.style.display = "none"
    this.element.style.visibility = "hidden"
    this.currentInput = null
    
    // Reset to default layout
    this.keyboard.setOptions({ layoutName: "default" })
    
    console.log("🚫 Keyboard hidden")
  }

  handleChange(input) {
    if (this.currentInput) {
      this.currentInput.value = input
      this.currentInput.dispatchEvent(new Event("input", { bubbles: true }))
      this.updatePreview(input)
    }
  }

  updatePreview(value) {
    const previewBtn = this.element.querySelector('[data-skbtn="{preview}"]')
    if (previewBtn) {
      // Show masked or actual value
      let displayValue = value
      if (this.currentInput && this.currentInput.type === 'password') {
        displayValue = '•'.repeat(value.length)
      }
      
      // Truncate if too long
      if (displayValue.length > 30) {
        displayValue = '...' + displayValue.slice(-27)
      }
      
      previewBtn.textContent = displayValue || ' '
    }
  }

  handleKeyPress(button) {
    console.log("🔑 Key pressed:", button)
    
    // Play audio feedback
    this.playBeep()
    
    // Handle special keys (swapped positions)
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
    console.log("🚫 Hide button pressed")
    
    // Blur current input
    if (this.currentInput) {
      this.currentInput.blur()
    }
    
    // Hide keyboard
    this.hideKeyboard()
  }

  async playBeep() {
    try {
      // Create audio context once
      if (!this.audioContext) {
        this.audioContext = new (window.AudioContext || window.webkitAudioContext)()
      }
      
      // Resume audio context on first user interaction
      if (!this.audioResumed && this.audioContext.state === 'suspended') {
        await this.audioContext.resume()
        this.audioResumed = true
      }
      
      // Only play if context is running
      if (this.audioContext.state === 'running') {
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
      }
    } catch (e) {
      // Silently fail if audio not available
    }
  }
}