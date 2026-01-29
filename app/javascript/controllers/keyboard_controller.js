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
    
    // Dynamically import simple-keyboard
    this.loadKeyboard()
  }

  disconnect() {
    if (this.keyboard) {
      this.keyboard.destroy()
    }
    
    // Remove event listeners
    document.removeEventListener("focusin", this.handleFocusIn)
    document.removeEventListener("focusout", this.handleFocusOut)
    document.removeEventListener("focus", this.preventNativeKeyboard, true)
  }

  async loadKeyboard() {
    try {
      // Import simple-keyboard
      const Keyboard = (await import("simple-keyboard")).default
      
      this.initKeyboard(Keyboard)
      this.setupInputListeners()
      this.createKeyboardHTML()
      
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
      theme: "simple-keyboard touch-keyboard-theme",
      display: {
        "{bksp}": "⌫ DEL",
        "{enter}": "↵ ENTER",
        "{shift}": "⇧",
        "{space}": "SPACE",
        "{preview}": "Type here..."
      },
      buttonTheme: [
        {
          class: "keyboard-preview-button",
          buttons: "{preview}"
        }
      ],
      mergeDisplay: true
    })
    
    // Hide keyboard initially
    this.element.style.display = "none"
    
    // Setup preview display styling
    this.setupPreviewDisplay()
  }

  getLayout() {
    return {
      default: [
        "1 2 3 4 5 6 7 8 9 0 {bksp}",
        "q w e r t y u i o p",
        "a s d f g h j k l",
        "{shift} z x c v b n m {shift}",
        "{preview} @ . {space} _ {enter}"
      ],
      shift: [
        "! @ # $ % ^ & * ( ) {bksp}",
        "Q W E R T Y U I O P",
        "A S D F G H J K L",
        "{shift} Z X C V B N M {shift}",
        "{preview} @ . {space} _ {enter}"
      ]
    }
  }

  setupPreviewDisplay() {
    setTimeout(() => {
      const previewBtn = this.element.querySelector('.keyboard-preview-button')
      if (previewBtn) {
        previewBtn.style.pointerEvents = 'none'
        previewBtn.style.cursor = 'default'
        previewBtn.style.fontFamily = 'monospace'
        previewBtn.style.overflow = 'hidden'
        previewBtn.style.textOverflow = 'ellipsis'
        previewBtn.style.whiteSpace = 'nowrap'
      }
    }, 100)
  }

  createKeyboardHTML() {
    // Add simple-keyboard CSS dynamically
    if (!document.getElementById('simple-keyboard-css')) {
      const link = document.createElement('link')
      link.id = 'simple-keyboard-css'
      link.rel = 'stylesheet'
      link.href = 'https://cdn.jsdelivr.net/npm/simple-keyboard@3.8.93/build/css/index.min.css'
      document.head.appendChild(link)
    }
  }

  setupInputListeners() {
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
      
      // Temporarily set readonly to block native keyboard
      event.target.setAttribute("readonly", "readonly")
      setTimeout(() => {
        event.target.removeAttribute("readonly")
      }, 100)
    }
  }

  handleFocusIn(event) {
    if (this.isTextInput(event.target)) {
      this.showKeyboard(event.target)
    }
  }

  handleFocusOut(event) {
    // Delay to check if focus moved to keyboard
    setTimeout(() => {
      if (!this.element.contains(document.activeElement)) {
        this.hideKeyboard()
      }
    }, 100)
  }

  isTextInput(element) {
    return element.matches('input[type="text"], input[type="email"], input[type="password"], textarea')
  }

  showKeyboard(input) {
    this.currentInput = input
    this.element.style.display = "block"
    
    // Set keyboard value to current input value
    this.keyboard.setInput(input.value)
    
    // Update preview
    this.updatePreview(input.value)
    
    // Scroll input into view
    setTimeout(() => {
      input.scrollIntoView({ behavior: "smooth", block: "center" })
    }, 100)
    
    console.log("⌨️ Keyboard shown for:", input.id || input.name)
  }

  hideKeyboard() {
    this.element.style.display = "none"
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
    const previewBtn = this.element.querySelector('.keyboard-preview-button')
    if (previewBtn) {
      if (value && value.length > 0) {
        // Show actual text or bullets for password
        if (this.currentInput && this.currentInput.type === 'password') {
          previewBtn.textContent = '•'.repeat(Math.min(value.length, 20))
        } else {
          // Truncate long text
          previewBtn.textContent = value.length > 20 ? value.slice(-20) : value
        }
      } else {
        previewBtn.textContent = 'Type here...'
      }
    }
  }

  handleKeyPress(button) {
    console.log("🔑 Key pressed:", button)
    
    // Play audio feedback
    this.playBeep()
    
    // Handle special keys
    if (button === "{enter}") {
      this.handleEnter()
    } else if (button === "{shift}") {
      this.handleShift()
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

  handleShift() {
    const currentLayout = this.keyboard.options.layoutName
    const newLayout = currentLayout === "default" ? "shift" : "default"
    this.keyboard.setOptions({ layoutName: newLayout })
    console.log("⇧ Shift toggled to:", newLayout)
  }

  playBeep() {
    try {
      const audioContext = new (window.AudioContext || window.webkitAudioContext)()
      const oscillator = audioContext.createOscillator()
      const gainNode = audioContext.createGain()
      
      oscillator.connect(gainNode)
      gainNode.connect(audioContext.destination)
      
      oscillator.frequency.value = 800
      oscillator.type = "sine"
      gainNode.gain.setValueAtTime(0.08, audioContext.currentTime)
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.05)
      
      oscillator.start()
      oscillator.stop(audioContext.currentTime + 0.05)
    } catch (e) {
      // Silently fail if audio not available
    }
  }
}