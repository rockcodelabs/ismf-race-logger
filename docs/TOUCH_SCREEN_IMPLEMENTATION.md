# Touch Screen Implementation Guide

**Version:** 2.0  
**Date:** 2025-01-XX  
**Status:** Complete Refactor & Research

---

## Table of Contents

1. [Overview](#overview)
2. [Current Implementation Review](#current-implementation-review)
3. [Research Findings](#research-findings)
4. [Proposed Architecture](#proposed-architecture)
5. [Implementation Plan](#implementation-plan)
6. [Code Structure](#code-structure)
7. [Testing Strategy](#testing-strategy)
8. [Deployment & Configuration](#deployment--configuration)

---

## Overview

This document outlines the complete touch screen implementation for the ISMF Race Logger application. The system must support:

- **7" Raspberry Pi Touch Display** (800×480 resolution) in kiosk mode
- **Virtual on-screen keyboard** for text input when physical keyboard is unavailable
- **Touch-optimized UI** with large buttons and clear navigation
- **Rails 8 conventions** using Hotwire (Turbo, Stimulus)
- **Automatic device detection** with manual override capability
- **Remote debugging** from Mac to Pi via Docker logs

---

## Current Implementation Review

### What Exists

#### 1. Files & Structure

```
app/
├── views/
│   ├── layouts/
│   │   ├── touch.html.erb           # Touch-specific layout (413 lines)
│   │   └── touch.html.erb.backup    # Backup file
│   ├── shared/
│   │   └── _virtual_keyboard.html.erb  # Virtual keyboard partial (387 lines)
│   ├── home/
│   │   └── index.html+touch.erb     # Touch home page
│   └── sessions/
│       └── new.html+touch.erb       # Touch login page
└── web/controllers/
    └── application_controller.rb     # Touch detection logic

docs/
├── VIRTUAL_KEYBOARD.md
├── TOUCH_DISPLAY_GUIDELINES.md
├── TOUCH_DISPLAY_SUMMARY.md
├── TOUCH_DISPLAY_UX.md
└── TOUCH_QUICK_REFERENCE.md
```

#### 2. Detection Mechanism

Located in `app/web/controllers/application_controller.rb`:

```ruby
def touch_display?
  # 1. Check URL parameter (?touch=1)
  # 2. Check cookie preference
  # 3. Check User-Agent (Raspberry Pi, mobile)
  # 4. Default to false
end

def set_variant
  request.variant = :touch if touch_display?
end

def set_touch_layout
  self.class.layout "touch" if touch_display?
end
```

#### 3. Virtual Keyboard Implementation

**Current approach:**
- Inline HTML in `_virtual_keyboard.html.erb` (387 lines)
- Inline JavaScript in `<script>` tags (280+ lines)
- Manual DOM manipulation
- Custom event handling
- Inline CSS in layout (300+ lines)

**Features:**
- QWERTY layout with numbers row
- Preview display showing typed text
- Shift key for uppercase
- Backspace, Enter, Hide buttons
- Audio feedback (beep on keypress)
- Attempts to prevent native mobile keyboard

#### 4. Touch Layout

**Current features:**
- Large button styles (`.touch-btn`, 80px min-height)
- Touch-optimized inputs (70px min-height)
- Collapsible navigation bar
- Flash message styling
- All CSS inline in layout file

### Problems Identified

1. **❌ Buttons not clickable** - Main issue preventing usage
2. **❌ Messy code** - 387 lines of inline HTML/JS in partial
3. **❌ No Rails 8 conventions** - No Stimulus controllers
4. **❌ Hard to debug** - Inline scripts, no structured logging
5. **❌ Multiple documentation files** - Scattered information
6. **❌ CSS in layout** - Should be in assets pipeline
7. **❌ No tests** - No way to verify functionality
8. **❌ Backup files in views** - `touch.html.erb.backup` should be removed

---

## Research Findings

### Virtual Keyboard Libraries

#### Option 1: simple-keyboard (RECOMMENDED)

**Pros:**
- ✅ Modern, actively maintained (2.4k stars)
- ✅ Framework agnostic (works with Stimulus)
- ✅ Lightweight (518 kB unpacked)
- ✅ Customizable layouts
- ✅ Touch-optimized
- ✅ Multiple input type support
- ✅ MIT license
- ✅ Can be imported via importmap (Rails 8)

**Cons:**
- ⚠️ External dependency
- ⚠️ Requires NPM or CDN

**Installation:**
```ruby
# config/importmap.rb
pin "simple-keyboard", to: "https://cdn.jsdelivr.net/npm/simple-keyboard@3.8.93/build/index.min.js"
pin "simple-keyboard/css", to: "https://cdn.jsdelivr.net/npm/simple-keyboard@3.8.93/build/css/index.min.css"
```

**Usage with Stimulus:**
```javascript
// app/javascript/controllers/keyboard_controller.js
import { Controller } from "@hotwired/stimulus"
import Keyboard from "simple-keyboard"

export default class extends Controller {
  connect() {
    this.keyboard = new Keyboard({
      onChange: input => this.onChange(input),
      onKeyPress: button => this.onKeyPress(button)
    })
  }
}
```

#### Option 2: Custom Build with Stimulus

**Pros:**
- ✅ Full control over implementation
- ✅ No external dependencies
- ✅ Tailored to exact needs
- ✅ Smaller bundle size

**Cons:**
- ❌ More development time
- ❌ More maintenance burden
- ❌ Need to handle edge cases ourselves

### Recommendation

**Use `simple-keyboard` for the following reasons:**

1. **Battle-tested** - Used in production by thousands of projects
2. **Touch-optimized** - Designed for kiosks and touchscreens
3. **Rails 8 compatible** - Works with importmap, no build step needed
4. **Time savings** - Focus on business logic, not keyboard edge cases
5. **Future-proof** - Active development, regular updates
6. **Customizable** - Can be styled to match ISMF branding

---

## Proposed Architecture

### Rails 8 Conventions

Following Hotwire principles:

```
Request → Controller → Set Variant → Render Touch View
                ↓
        Stimulus Controller (Keyboard)
                ↓
        Update Input → Turbo Frame (optional)
```

### Component Structure

```
app/
├── javascript/
│   └── controllers/
│       ├── keyboard_controller.js      # Virtual keyboard logic
│       ├── touch_detection_controller.js  # Device detection
│       └── touch_nav_controller.js     # Navigation behavior
│
├── views/
│   ├── layouts/
│   │   └── touch.html.erb              # Touch layout (CLEANED)
│   ├── shared/
│   │   └── _keyboard.html.erb          # Keyboard container only
│   ├── home/
│   │   └── index.html+touch.erb
│   └── sessions/
│       └── new.html+touch.erb
│
├── assets/
│   └── stylesheets/
│       └── touch.css                   # Touch-specific styles
│
└── web/controllers/
    └── application_controller.rb       # Touch detection
```

### Detection Strategy (Cookie-Based)

**Priority Order:**

1. **URL Parameter** (`?touch=1` or `?touch=0`)
   - Sets cookie for 1 year
   - Allows manual override
   - Best for testing

2. **Cookie** (`touch_display=1`)
   - Persists user preference
   - Pi remembers touch mode forever
   - Fast, no JavaScript needed

3. **Screen Size Detection** (JS, 800×480)
   - Fallback for first visit
   - Sets cookie automatically
   - Stimulus controller handles this

4. **Default** (desktop)
   - Phones get responsive design
   - Desktops get full interface

**Implementation:**

```ruby
# app/web/controllers/application_controller.rb
def touch_display?
  return params[:touch] == "1" if params[:touch].present?
  cookies[:touch_display] == "1"
end
```

```javascript
// app/javascript/controllers/touch_detection_controller.js
export default class extends Controller {
  connect() {
    // Only run if no cookie set
    if (!this.hasCookie()) {
      this.detectScreenSize()
    }
  }

  detectScreenSize() {
    const is800x480 = window.innerWidth === 800 && window.innerHeight === 480
    if (is800x480) {
      this.setCookie("touch_display", "1")
      window.location.reload()
    }
  }
}
```

---

## Implementation Plan

### Phase 1: Clean Up (Remove Old Code)

**Tasks:**
1. ✅ Remove `_virtual_keyboard.html.erb` partial
2. ✅ Remove inline CSS from `touch.html.erb` layout
3. ✅ Remove inline JavaScript from views
4. ✅ Delete `touch.html.erb.backup`
5. ✅ Delete redundant documentation files:
   - `VIRTUAL_KEYBOARD.md`
   - `TOUCH_DISPLAY_GUIDELINES.md`
   - `TOUCH_DISPLAY_SUMMARY.md`
   - `TOUCH_DISPLAY_UX.md`
   - `TOUCH_QUICK_REFERENCE.md`
6. ✅ Keep only this file: `TOUCH_SCREEN_IMPLEMENTATION.md`

### Phase 2: Install Dependencies

**Tasks:**
1. ✅ Add `simple-keyboard` to importmap
2. ✅ Create Stimulus keyboard controller
3. ✅ Create touch CSS file
4. ✅ Test importmap loading

**Commands:**
```bash
# Add to config/importmap.rb
bin/importmap pin simple-keyboard
```

### Phase 3: Build Components

**Tasks:**
1. ✅ Create `keyboard_controller.js` (Stimulus)
2. ✅ Create `touch_detection_controller.js` (Stimulus)
3. ✅ Create `touch_nav_controller.js` (Stimulus)
4. ✅ Create `app/assets/stylesheets/touch.css`
5. ✅ Simplify `touch.html.erb` layout
6. ✅ Create minimal `_keyboard.html.erb` partial

### Phase 4: Update Views

**Tasks:**
1. ✅ Update `home/index.html+touch.erb`
2. ✅ Update `sessions/new.html+touch.erb`
3. ✅ Add keyboard to forms
4. ✅ Test navigation behavior
5. ✅ Verify flash messages work

### Phase 5: Testing

**Tasks:**
1. ✅ Write system tests for touch views
2. ✅ Write Stimulus controller tests
3. ✅ Test on Mac with `?touch=1`
4. ✅ Test on Pi touch display
5. ✅ Verify cookie persistence
6. ✅ Test keyboard input (text, email, password, numbers)

### Phase 6: Documentation & Deployment

**Tasks:**
1. ✅ Update `.rules` file
2. ✅ Update `AGENTS.md` if needed
3. ✅ Document debugging strategies
4. ✅ Deploy to production
5. ✅ Test in kiosk mode

---

## Code Structure

### 1. Stimulus Keyboard Controller

**File:** `app/javascript/controllers/keyboard_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"
import Keyboard from "simple-keyboard"

// Connects to data-controller="keyboard"
export default class extends Controller {
  static targets = ["input"]
  static values = {
    layout: { type: String, default: "default" }
  }

  connect() {
    console.log("🎹 Keyboard controller connected")
    this.initKeyboard()
    this.setupInputListeners()
  }

  disconnect() {
    if (this.keyboard) {
      this.keyboard.destroy()
    }
  }

  initKeyboard() {
    this.keyboard = new Keyboard({
      onChange: input => this.handleChange(input),
      onKeyPress: button => this.handleKeyPress(button),
      layout: this.getLayout(),
      theme: "hg-theme-default touch-keyboard-theme",
      display: {
        "{bksp}": "⌫ DELETE",
        "{enter}": "↵ ENTER",
        "{shift}": "⇧ SHIFT",
        "{space}": "SPACE",
        "{tab}": "TAB",
        "{lock}": "CAPS",
        "{preview}": ""  // Empty, we'll style this as preview display
      },
      buttonTheme: [
        {
          class: "keyboard-preview-button",
          buttons: "{preview}"
        }
      ]
    })
    
    // Hide keyboard initially
    this.element.style.display = "none"
    
    // Setup preview display
    this.setupPreviewDisplay()
  }

  setupPreviewDisplay() {
    // Find the preview button and convert it to display
    setTimeout(() => {
      const previewBtn = this.element.querySelector('.keyboard-preview-button')
      if (previewBtn) {
        previewBtn.style.pointerEvents = 'none'
        previewBtn.style.cursor = 'default'
        previewBtn.style.background = 'rgba(16, 185, 129, 0.2)'
        previewBtn.style.border = '2px solid rgba(16, 185, 129, 0.5)'
        previewBtn.style.color = '#10b981'
        previewBtn.style.fontSize = '1rem'
        previewBtn.style.fontFamily = 'monospace'
        previewBtn.style.overflow = 'hidden'
        previewBtn.style.textOverflow = 'ellipsis'
        previewBtn.style.whiteSpace = 'nowrap'
        previewBtn.textContent = 'Preview...'
      }
    }, 100)
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

  setupInputListeners() {
    // Prevent native mobile/kiosk keyboard from showing
    document.addEventListener("focus", (e) => {
      if (this.isTextInput(e.target)) {
        // Temporarily set readonly to prevent native keyboard
        e.target.setAttribute("readonly", "readonly")
        setTimeout(() => {
          e.target.removeAttribute("readonly")
        }, 100)
      }
    }, true)

    // Show keyboard on focus
    document.addEventListener("focusin", (e) => {
      if (this.isTextInput(e.target)) {
        this.showKeyboard(e.target)
      }
    })

    // Hide keyboard on blur (delayed)
    document.addEventListener("focusout", (e) => {
      setTimeout(() => {
        if (!this.element.contains(document.activeElement)) {
          this.hideKeyboard()
        }
      }, 100)
    })
  }

  isTextInput(element) {
    return element.matches('input[type="text"], input[type="email"], input[type="password"], textarea')
  }

  showKeyboard(input) {
    this.currentInput = input
    this.element.style.display = "block"
    
    // Set keyboard value to current input value
    this.keyboard.setInput(input.value)
    
    // Update preview with current value
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
          previewBtn.textContent = '•'.repeat(value.length)
        } else {
          previewBtn.textContent = value
        }
        previewBtn.style.fontWeight = 'bold'
        previewBtn.style.opacity = '1'
      } else {
        previewBtn.textContent = 'Type here...'
        previewBtn.style.fontWeight = 'normal'
        previewBtn.style.opacity = '0.6'
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
      // Add newline
      this.keyboard.setInput(this.keyboard.getInput() + "\n")
    } else {
      // Submit form
      const form = this.currentInput.closest("form")
      if (form) {
        form.requestSubmit()
      }
    }
  }

  handleShift() {
    const currentLayout = this.keyboard.options.layoutName
    const newLayout = currentLayout === "default" ? "shift" : "default"
    this.keyboard.setOptions({ layoutName: newLayout })
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
      gainNode.gain.setValueAtTime(0.1, audioContext.currentTime)
      gainNode.gain.exponentialRampToValueAtTime(0.01, audioContext.currentTime + 0.05)
      
      oscillator.start()
      oscillator.stop(audioContext.currentTime + 0.05)
    } catch (e) {
      // Silently fail
    }
  }
}
```

### 2. Touch Detection Controller

**File:** `app/javascript/controllers/touch_detection_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="touch-detection"
// Automatically detects 800x480 screen and sets cookie
export default class extends Controller {
  connect() {
    console.log("📱 Touch detection controller connected")
    
    // Only detect if no cookie is set
    if (!this.hasCookie("touch_display")) {
      this.detectScreenSize()
    }
  }

  detectScreenSize() {
    const width = window.innerWidth
    const height = window.innerHeight
    
    console.log(`📏 Screen size: ${width}x${height}`)
    
    // Detect 800x480 (Pi Touch Display 2)
    if (width === 800 && height === 480) {
      console.log("✅ Pi touch display detected!")
      this.setCookie("touch_display", "1", 365)
      window.location.reload()
    }
  }

  hasCookie(name) {
    return document.cookie.split("; ").some(row => row.startsWith(`${name}=`))
  }

  setCookie(name, value, days) {
    const expires = new Date(Date.now() + days * 864e5).toUTCString()
    document.cookie = `${name}=${value}; expires=${expires}; path=/; SameSite=Lax`
    console.log(`🍪 Cookie set: ${name}=${value}`)
  }
}
```

### 3. Touch Navigation Controller

**File:** `app/javascript/controllers/touch_nav_controller.js`

```javascript
import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="touch-nav"
// Handles collapsible navigation with auto-hide on scroll
export default class extends Controller {
  static targets = ["navbar", "hamburger", "navContent"]

  connect() {
    console.log("🧭 Touch navigation controller connected")
    this.isExpanded = true
    this.lastScrollY = window.scrollY
    this.setupScrollListener()
  }

  disconnect() {
    window.removeEventListener("scroll", this.handleScroll)
  }

  setupScrollListener() {
    this.handleScroll = this.handleScroll.bind(this)
    window.addEventListener("scroll", this.handleScroll, { passive: true })
  }

  handleScroll() {
    const currentScrollY = window.scrollY
    
    // Hide nav when scrolling down (after 100px)
    if (currentScrollY > 100 && currentScrollY > this.lastScrollY) {
      this.hideNav()
    }
    // Show nav when scrolling up
    else if (currentScrollY < this.lastScrollY) {
      this.showNav()
    }
    
    this.lastScrollY = currentScrollY
  }

  toggleNav() {
    this.isExpanded = !this.isExpanded
    
    if (this.isExpanded) {
      this.showNav()
    } else {
      this.hideNav()
    }
  }

  showNav() {
    this.navbarTarget.classList.remove("nav-hidden")
  }

  hideNav() {
    this.navbarTarget.classList.add("nav-hidden")
  }
}
```

### 4. Touch CSS

**File:** `app/assets/stylesheets/touch.css`

```css
/* Touch Display Styles */
/* Optimized for 800×480 Raspberry Pi Touch Display 2 */

/* Base touch styles */
body.touch-mode {
  font-family: 'Poppins', system-ui, sans-serif;
  font-size: 18px;
  overflow-x: hidden;
  -webkit-user-select: none;
  user-select: none;
  -webkit-tap-highlight-color: rgba(233, 69, 96, 0.3);
}

/* Prevent native keyboard on touch inputs */
body.touch-mode input[type="text"],
body.touch-mode input[type="email"],
body.touch-mode input[type="password"],
body.touch-mode textarea {
  -webkit-user-modify: read-write-plaintext-only;
}

body.touch-mode input,
body.touch-mode textarea {
  -webkit-user-select: text;
  user-select: text;
}

/* Touch Buttons */
.touch-btn {
  min-height: 80px;
  font-size: 1.5rem;
  font-weight: 700;
  padding: 1.5rem 2rem;
  border-radius: 1rem;
  display: flex;
  align-items: center;
  justify-content: center;
  gap: 1rem;
  transition: all 0.15s ease;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  position: relative;
  overflow: hidden;
}

.touch-btn:active {
  transform: scale(0.96);
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
}

.touch-btn-primary {
  background: linear-gradient(135deg, #e94560 0%, #c73850 100%);
  color: white;
}

.touch-btn-secondary {
  background: linear-gradient(135deg, #0f3460 0%, #082441 100%);
  color: white;
}

/* Touch Inputs */
.touch-input {
  min-height: 70px;
  font-size: 1.25rem;
  padding: 1.25rem 1.5rem;
  border: 3px solid #d1d5db;
  border-radius: 1rem;
  width: 100%;
}

.touch-input:focus {
  outline: none;
  border-color: #e94560;
  box-shadow: 0 0 0 4px rgba(233, 69, 96, 0.2);
}

.touch-label {
  font-size: 1.25rem;
  font-weight: 700;
  color: #1a1a2e;
  margin-bottom: 0.75rem;
  display: block;
}

/* Navigation */
.touch-nav-btn {
  width: 64px;
  height: 64px;
  border-radius: 0.875rem;
  background: rgba(233, 69, 96, 0.15);
  backdrop-filter: blur(10px);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  transition: all 0.15s ease;
  border: 2px solid rgba(233, 69, 96, 0.3);
  flex-shrink: 0;
}

.touch-nav-btn:active {
  transform: scale(0.95);
  background: rgba(233, 69, 96, 0.3);
  border-color: rgba(233, 69, 96, 0.5);
}

.nav-hidden {
  transform: translateY(-100%);
}

/* Virtual Keyboard (simple-keyboard) */
.simple-keyboard {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 10000;
  background: #2c3e50;
  padding: 1rem;
  border-top: 4px solid #e94560;
  box-shadow: 0 -6px 24px rgba(0, 0, 0, 0.6);
}

.simple-keyboard .hg-button {
  height: 56px;
  font-size: 1.25rem;
  font-weight: 700;
  background: #34495e;
  color: white;
  border: 2px solid #4a5f7f;
  border-radius: 0.5rem;
  transition: all 0.1s ease;
}

.simple-keyboard .hg-button:active {
  transform: scale(0.95);
  background: #4a5f7f;
  box-shadow: 0 3px 8px rgba(0, 0, 0, 0.3) inset;
}

.simple-keyboard .hg-button-bksp {
  background: #e67e22 !important;
}

.simple-keyboard .hg-button-enter {
  background: #16a34a !important;
}

/* Keyboard preview button (left of spacebar) */
.keyboard-preview-button {
  background: rgba(16, 185, 129, 0.2) !important;
  border: 2px solid rgba(16, 185, 129, 0.5) !important;
  color: #10b981 !important;
  font-family: monospace !important;
  font-size: 1rem !important;
  overflow: hidden !important;
  text-overflow: ellipsis !important;
  white-space: nowrap !important;
  pointer-events: none !important;
  cursor: default !important;
  min-width: 120px !important;
}

/* Touch spacing utilities */
.touch-spacing {
  padding: 2rem;
}

.touch-spacing-lg {
  padding: 3rem;
}

/* Scrollbar */
::-webkit-scrollbar {
  width: 8px;
  height: 8px;
}

::-webkit-scrollbar-track {
  background: transparent;
}

::-webkit-scrollbar-thumb {
  background: rgba(26, 26, 46, 0.3);
  border-radius: 4px;
}
```

### 5. Simplified Touch Layout

**File:** `app/views/layouts/touch.html.erb`

```erb
<!DOCTYPE html>
<html lang="en">
  <head>
    <title><%= content_for(:title) || "ISMF Race Logger" %></title>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
    <meta name="apple-mobile-web-app-capable" content="yes">
    
    <%= csrf_meta_tags %>
    <%= csp_meta_tag %>
    <%= stylesheet_link_tag "tailwind", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
    <%= stylesheet_link_tag "touch", "data-turbo-track": "reload" %>
    <%= javascript_importmap_tags %>
  </head>

  <body class="min-h-screen bg-gradient-to-br from-ismf-navy via-ismf-blue to-ismf-navy text-white antialiased touch-mode" data-controller="touch-detection">
    
    <!-- Navigation (hidden on home page) -->
    <% unless request.path == root_path %>
      <%= render "shared/touch_nav" %>
    <% end %>
    
    <!-- Flash Messages -->
    <%= render "shared/flash_messages" %>

    <!-- Page Content -->
    <%= yield %>
    
    <!-- Virtual Keyboard -->
    <%= render "shared/keyboard" %>
  </body>
</html>
```

### 6. Keyboard Partial

**File:** `app/views/shared/_keyboard.html.erb`

```erb
<div data-controller="keyboard" class="simple-keyboard-container"></div>
```

### 7. Touch Navigation Partial

**File:** `app/views/shared/_touch_nav.html.erb`

```erb
<nav data-controller="touch-nav" data-touch-nav-target="navbar" class="fixed top-0 left-0 right-0 z-40 bg-ismf-navy/95 backdrop-blur-sm border-b-2 border-ismf-red shadow-lg transition-transform duration-300">
  <div class="flex items-center justify-between px-6 py-4 gap-4">
    <!-- Hamburger Menu -->
    <button data-action="click->touch-nav#toggleNav" class="touch-nav-btn">
      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="width: 2rem; height: 2rem;">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M4 6h16M4 12h16M4 18h16" />
      </svg>
    </button>
    
    <!-- Home -->
    <%= link_to root_path, class: "touch-nav-btn" do %>
      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="width: 2rem; height: 2rem;">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
      </svg>
    <% end %>
    
    <!-- Back -->
    <button onclick="window.history.back()" class="touch-nav-btn">
      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="width: 2rem; height: 2rem;">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M10 19l-7-7m0 0l7-7m-7 7h18" />
      </svg>
    </button>
    
    <!-- Page Title -->
    <div class="flex-1 text-center">
      <h1 class="text-xl font-bold text-white truncate px-2">
        <%= content_for?(:page_title) ? yield(:page_title) : "ISMF" %>
      </h1>
    </div>
    
    <!-- Sign Out -->
    <% if Current.user %>
      <%= button_to session_path, method: :delete, class: "touch-nav-btn" do %>
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="width: 2rem; height: 2rem;">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M17 16l4-4m0 0l-4-4m4 4H7m6 4v1a3 3 0 01-3 3H6a3 3 0 01-3-3V7a3 3 0 013-3h4a3 3 0 013 3v1" />
        </svg>
      <% end %>
    <% end %>
  </div>
</nav>
```

---

## Testing Strategy

### 1. System Tests

**File:** `test/system/touch_display_test.rb`

```ruby
require "application_system_test_case"

class TouchDisplayTest < ApplicationSystemTestCase
  test "accessing with ?touch=1 shows touch layout" do
    visit root_path(touch: "1")
    
    assert_selector "body.touch-mode"
    assert_selector ".simple-keyboard-container"
  end
  
  test "cookie persists touch mode" do
    visit root_path(touch: "1")
    visit new_session_path
    
    assert_selector "body.touch-mode"
    assert_selector ".touch-btn"
  end
  
  test "virtual keyboard shows on input focus" do
    visit new_session_path(touch: "1")
    
    find("#email_address").click
    
    assert_selector ".simple-keyboard", visible: true
  end
  
  test "can type with virtual keyboard" do
    visit new_session_path(touch: "1")
    
    find("#email_address").click
    
    # Simulate keyboard input
    page.execute_script("document.querySelector('#email_address').value = 'test@example.com'")
    
    assert_field "email_address", with: "test@example.com"
  end
end
```

### 2. Stimulus Controller Tests

**File:** `test/javascript/controllers/keyboard_controller_test.js`

```javascript
import { Application } from "@hotwired/stimulus"
import KeyboardController from "../../../app/javascript/controllers/keyboard_controller"

describe("KeyboardController", () => {
  let application
  let element
  
  beforeEach(() => {
    application = Application.start()
    application.register("keyboard", KeyboardController)
    
    element = document.createElement("div")
    element.dataset.controller = "keyboard"
    document.body.appendChild(element)
  })
  
  afterEach(() => {
    document.body.removeChild(element)
    application.stop()
  })
  
  it("connects successfully", () => {
    expect(element.dataset.controller).toBe("keyboard")
  })
  
  it("shows keyboard on input focus", () => {
    const input = document.createElement("input")
    input.type = "text"
    document.body.appendChild(input)
    
    input.focus()
    
    // Wait for keyboard to show
    setTimeout(() => {
      expect(element.style.display).toBe("block")
      document.body.removeChild(input)
    }, 200)
  })
})
```

### 3. Manual Testing Checklist

**On Mac (Docker):**

- [ ] Visit `http://localhost:3000?touch=1`
- [ ] Verify touch layout loads
- [ ] Verify cookie is set
- [ ] Click email input - keyboard appears
- [ ] Type on physical keyboard - input works
- [ ] Click keyboard buttons - visual feedback
- [ ] Submit form with Enter key
- [ ] Navigate between pages - layout persists
- [ ] Visit `?touch=0` - desktop layout returns

**On Raspberry Pi Touch Display:**

- [ ] Open in kiosk mode
- [ ] Verify touch layout auto-detected
- [ ] Touch email input - keyboard appears
- [ ] **Only custom keyboard appears (no native keyboard)**
- [ ] Touch keyboard buttons - characters appear
- [ ] **Preview display shows typed text** (left of spacebar)
- [ ] **Preview shows bullets for password fields**
- [ ] Visual feedback on button press
- [ ] Audio feedback (beep)
- [ ] Enter key submits form
- [ ] Backspace key deletes
- [ ] Shift key toggles uppercase
- [ ] Navigation buttons work (Home, Back, Sign Out)
- [ ] Scroll behavior - nav auto-hides
- [ ] Keyboard doesn't overlap input fields
- [ ] Reboot Pi - touch mode persists

### 4. Debugging Tools

**Console Logging:**

All Stimulus controllers include `console.log` statements:

```javascript
console.log("🎹 Keyboard controller connected")
console.log("⌨️ Keyboard shown for:", input.id)
console.log("🔑 Key pressed:", button)
```

**View logs on Mac (Docker):**

```bash
docker compose logs -f app
```

**View logs on Pi (via SSH from Mac):**

```bash
ssh pi@pi5main.local
journalctl -u chromium-kiosk -f
```

**Rails Logger:**

```ruby
Rails.logger.info "=== TOUCH DEBUG ==="
Rails.logger.info "Cookie: #{cookies[:touch_display]}"
Rails.logger.info "Variant: #{request.variant.inspect}"
```

**Browser DevTools on Pi:**

Enable remote debugging:

```bash
# On Pi - start Chromium with debugging
chromium-browser --remote-debugging-port=9222 --user-data-dir=/tmp/chrome-debug

# On Mac - connect to Pi
chrome://inspect
# Add pi5main.local:9222
```

---

## Deployment & Configuration

### 1. Importmap Configuration

**File:** `config/importmap.rb`

```ruby
# Virtual keyboard
pin "simple-keyboard", to: "https://cdn.jsdelivr.net/npm/simple-keyboard@3.8.93/build/index.min.js"

# Stimulus controllers
pin_all_from "app/javascript/controllers", under: "controllers"
```

### 2. Asset Pipeline

Ensure `touch.css` is compiled:

**File:** `app/assets/config/manifest.js`

```javascript
//= link application.css
//= link touch.css
```

### 3. Ansible Kiosk Configuration

**IMPORTANT:** Disable native Chromium virtual keyboard to prevent conflicts with our custom keyboard.

**File:** `ansible/inventory.yml` (UPDATED)

```yaml
chromium_flags:
  - --kiosk
  - --touch-events=enabled
  - --disable-features=VirtualKeyboard  # Disable native keyboard
  - --disable-touch-keyboard            # Disable touch keyboard
```

**Rationale:**
- Chromium's built-in virtual keyboard conflicts with our `simple-keyboard` implementation
- Native keyboard may overlap or interfere with touch events
- We have full control over our custom keyboard appearance and behavior
- Prevents double-keyboard issues (both keyboards showing at once)

### 4. Environment Variables

No special environment variables needed. Touch detection works via cookies.

### 5. Deployment Commands

```bash
# 1. Commit changes
git add .
git commit -m "Refactor: Clean touch screen implementation with simple-keyboard"

# 2. Push to GitHub (triggers deployment)
git push origin main

# 3. Wait for GitHub Actions (3-5 minutes)
# Monitor at: https://github.com/rege/ismf-race-logger/actions

# 4. Verify on Pi
# SSH to Pi and check logs
ssh pi@pi5main.local
journalctl -u chromium-kiosk -f
```

---

## Future Enhancements

### Short-term (Next Sprint)

1. **Numeric keypad layout** - For bib number entry
2. **Keyboard themes** - Match ISMF branding
3. **Haptic feedback** - Vibration on supported devices
4. **Auto-hide keyboard timer** - Hide after N seconds of inactivity
5. **Preview display scrolling** - Auto-scroll preview for long text

### Medium-term

1. **Touch-specific admin dashboard**
2. **Touch-optimized incident forms**
3. **Gesture support** - Swipe to navigate
4. **Offline keyboard** - Works without network

### Long-term

1. **Multi-language support** - Other keyboard layouts
2. **Voice input** - Speech-to-text alternative
3. **Custom phone UI** - Dedicated mobile touch interface
4. **Progressive Web App** - Installable on mobile devices

---

## Troubleshooting

### Issue: Buttons not clickable

**Symptoms:**
- Buttons visible but no response to touch
- Console shows no click events

**Solutions:**
1. Check `z-index` - keyboard might be overlapping
2. Verify CSS `pointer-events` not set to `none`
3. Check for JavaScript errors in console
4. Ensure Stimulus controller is connected

**Debug:**
```javascript
document.addEventListener('click', (e) => {
  console.log('Click detected:', e.target)
}, true)
```

### Issue: Keyboard doesn't appear

**Symptoms:**
- Focus input, keyboard doesn't show
- No console logs from keyboard controller

**Solutions:**
1. Verify importmap loaded: Check Network tab for `simple-keyboard`
2. Check Stimulus registration: `application.controllers` in console
3. Verify data-controller attribute exists
4. Check for JavaScript errors

**Debug:**
```bash
# Check importmap
curl http://localhost:3000/assets/application-[hash].js | grep simple-keyboard
```

### Issue: Native keyboard shows alongside custom keyboard

**Symptoms:**
- Both native Chromium keyboard and simple-keyboard appear
- Keyboards overlap or conflict
- Input behaves strangely

**Solutions:**
1. **Disable Chromium's native keyboard** (recommended):
   ```yaml
   # ansible/inventory.yml
   chromium_flags:
     - --disable-features=VirtualKeyboard
     - --disable-touch-keyboard
   ```

2. **Prevent native keyboard via JavaScript**:
   - Already implemented in `keyboard_controller.js`
   - Sets `readonly` attribute temporarily on focus
   - Removes after 100ms to allow our keyboard

3. **Check Chromium flags**:
   ```bash
   # SSH to Pi
   ssh pi@pi5main.local
   
   # Check running Chromium process
   ps aux | grep chromium
   ```

**Verify fix:**
- Only one keyboard should appear at a time
- Touch input should trigger only `simple-keyboard`
- No native keyboard UI visible

### Issue: Cookie not persisting

**Symptoms:**
- Need to add `?touch=1` on every visit
- Touch mode doesn't auto-activate on Pi

**Solutions:**
1. Check cookie expiration: Dev tools → Application → Cookies
2. Verify SameSite policy (should be `Lax` or `None`)
3. Check HTTPS vs HTTP (cookies may be rejected)
4. Clear cookies and try again

**Debug:**
```javascript
// Check cookies
console.log(document.cookie)

// Set manually
document.cookie = "touch_display=1; path=/; max-age=31536000"
```

### Issue: Input field hidden by keyboard

**Symptoms:**
- Type in input, can't see what you're typing
- Keyboard covers input field

**Solutions:**
1. Add `scrollIntoView` on focus
2. Add bottom padding to page
3. Increase keyboard z-index
4. Adjust viewport on focus

**Fix:**
```javascript
input.scrollIntoView({ behavior: "smooth", block: "center" })
```

### Issue: No audio feedback

**Symptoms:**
- Keyboard works but no beep sound

**Solutions:**
1. Check browser audio permissions
2. Verify AudioContext is supported
3. Check if sound is muted
4. Try different frequency/volume

**Debug:**
```javascript
// Test audio
const ctx = new AudioContext()
const osc = ctx.createOscillator()
osc.connect(ctx.destination)
osc.start()
osc.stop(ctx.currentTime + 0.1)
```

---

## Migration Checklist

### Before Migration

- [ ] Backup current working code
- [ ] Review all touch-related files
- [ ] Document custom behavior to preserve
- [ ] Test current functionality on Pi
- [ ] Create feature branch

### During Migration

- [ ] Remove old keyboard partial
- [ ] Remove inline CSS/JS
- [ ] Install simple-keyboard
- [ ] Create Stimulus controllers
- [ ] Create touch.css
- [ ] Update layouts
- [ ] Update views
- [ ] **Update Ansible config to disable native keyboard**
- [ ] Write tests

### After Migration

- [ ] Run tests locally
- [ ] Test on Mac with `?touch=1`
- [ ] Deploy to staging (if available)
- [ ] Test on Pi touch display
- [ ] Verify cookie persistence
- [ ] Check performance
- [ ] Update documentation
- [ ] Clean up old files
- [ ] Merge to main

---

## Conclusion

This implementation provides a clean, maintainable, Rails 8-compliant touch screen interface using:

- **simple-keyboard** - Battle-tested virtual keyboard library
- **Stimulus controllers** - Clean JavaScript organization
- **Cookie-based detection** - Persistent, reliable mode switching
- **Rails variants** - Automatic template selection
- **Proper separation of concerns** - CSS in assets, JS in controllers
- **Comprehensive testing** - System tests and manual checklists
- **Remote debugging** - Console logs visible on Mac from Pi

The new architecture is easier to understand, debug, and extend than the previous inline implementation.

---

**Document Version:** 2.0  
**Last Updated:** 2025-01-XX  
**Status:** Ready for Implementation