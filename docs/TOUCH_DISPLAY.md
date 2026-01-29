# Touch Display Implementation Guide

**Complete guide for the touch screen UI on Raspberry Pi 7" Touch Display 2**

**Version:** 3.0  
**Last Updated:** 2025-01-29  
**Display Resolution:** 1280×720 (landscape mode)

---

## Table of Contents

1. [Overview](#overview)
2. [Display Specifications](#display-specifications)
3. [Architecture](#architecture)
4. [Implementation Details](#implementation-details)
5. [Virtual Keyboard](#virtual-keyboard)
6. [Touch Detection](#touch-detection)
7. [Layout Guidelines](#layout-guidelines)
8. [Development Workflow](#development-workflow)
9. [Testing](#testing)
10. [Troubleshooting](#troubleshooting)

---

## Overview

The ISMF Race Logger includes a touch-optimized interface designed specifically for the Raspberry Pi 7" Touch Display 2, enabling referees to manage race incidents using only touch input.

### Key Features

- ✅ **Auto-detection** - Automatically activates on 1280×720 displays
- ✅ **Virtual keyboard** - Full on-screen keyboard with preview display
- ✅ **Touch-optimized UI** - Large buttons, clear spacing, no scrolling
- ✅ **Cookie persistence** - Touch mode survives reboots
- ✅ **No native keyboard** - Chromium's native keyboard is disabled
- ✅ **Landscape mode** - Optimized for 1280×720 (rotated 90° from native)

### Design Principles

1. **No Scrolling** - All content fits within 1280×720 viewport
2. **Large Touch Targets** - Minimum 64px for critical buttons
3. **Visual Feedback** - Clear pressed states and animations
4. **Input Preview** - Always visible even when keyboard covers input
5. **Minimal Navigation** - Floating hamburger menu, context-aware
6. **Responsive** - Adapts to both desktop and touch seamlessly

---

## Display Specifications

### Hardware

**Raspberry Pi Touch Display 2 (Official 7" Display)**

| Specification | Value |
|--------------|-------|
| **Native Resolution** | 720×1280 (portrait) |
| **Configured Resolution** | 1280×720 (landscape, rotated 90°) |
| **Display Size** | 7 inches diagonal |
| **Touch Technology** | 10-point capacitive multi-touch |
| **Interface** | DSI (Display Serial Interface) |
| **Power** | 5V via GPIO or separate USB |

### Configuration

Display is rotated via `/boot/firmware/config.txt`:

```bash
display_rotate=1  # 90° clockwise for landscape
```

### Viewport Dimensions

```
┌────────────────────────────────┐
│                                │
│        1280px width            │
│                                │  720px
│                                │  height
│                                │
└────────────────────────────────┘
```

**Available space after keyboard:**
- With keyboard visible: ~420px height
- Without keyboard: 720px height

---

## Architecture

### Rails 8 + Hotwire Stack

```
┌─────────────────────────────────────────┐
│  Touch Display (1280×720)               │
│                                         │
│  ┌───────────────────────────────────┐ │
│  │  Chromium Browser (Kiosk Mode)    │ │
│  │                                   │ │
│  │  ┌─────────────────────────────┐ │ │
│  │  │  Rails Application          │ │ │
│  │  │  ├── Turbo (navigation)     │ │ │
│  │  │  ├── Stimulus Controllers   │ │ │
│  │  │  │   ├── touch_detection    │ │ │
│  │  │  │   ├── keyboard           │ │ │
│  │  │  │   └── touch_nav          │ │ │
│  │  │  └── simple-keyboard (lib)  │ │ │
│  │  └─────────────────────────────┘ │ │
│  └───────────────────────────────────┘ │
└─────────────────────────────────────────┘
```

### Components

| Component | Purpose | Location |
|-----------|---------|----------|
| **Touch Views** | Touch-optimized ERB templates | `app/views/**/*.html+touch.erb` |
| **Touch CSS** | Display-specific styles | `app/assets/stylesheets/touch.css` |
| **Stimulus Controllers** | Touch behavior & keyboard | `app/javascript/controllers/` |
| **simple-keyboard** | Virtual keyboard library | `vendor/javascript/` (importmap) |
| **ApplicationController** | Variant detection | `app/controllers/application_controller.rb` |

---

## Implementation Details

### 1. Touch View Convention

Rails automatically selects `.touch.html.erb` variant when `request.variant = :touch`:

```ruby
# app/controllers/application_controller.rb
before_action :set_variant

def set_variant
  if touch_device?
    request.variant = :touch
  end
end

def touch_device?
  cookies[:touch_display] == "1" || params[:touch] == "1"
end
```

**File naming:**
```
app/views/
  home/
    index.html.erb         # Desktop version
    index.html+touch.erb   # Touch version
  sessions/
    new.html.erb
    new.html+touch.erb
  admin/
    dashboard/
      index.html.erb
      index.html+touch.erb
```

### 2. Touch CSS Loading

Touch-specific CSS loads only in touch mode:

```erb
<!-- app/views/layouts/application.html.erb -->
<% if request.variant.include?(:touch) %>
  <%= stylesheet_link_tag "touch", "data-turbo-track": "reload" %>
<% end %>
```

**CSS structure:**

```css
/* app/assets/stylesheets/touch.css */

/* Base touch styles - apply to all pages */
body.touch-mode {
  font-size: 18px;
  overflow: hidden;
  height: 100vh;
}

/* Touch buttons */
.touch-btn {
  min-height: 64px;
  font-size: 1.125rem;
  padding: 1rem 1.5rem;
  touch-action: manipulation;
}

/* Touch inputs */
.touch-input {
  min-height: 60px;
  font-size: 1.125rem;
  padding: 1rem;
}

/* Media queries for 1280×720 */
@media (max-width: 1280px) and (max-height: 720px) {
  /* Display-specific adjustments */
}
```

### 3. Page Structure

**Standard touch page layout:**

```erb
<!-- app/views/home/index.html+touch.erb -->
<div class="h-screen flex flex-col items-center justify-between py-6 px-6 overflow-hidden">
  
  <!-- Top Spacer -->
  <div class="flex-shrink-0 h-6"></div>
  
  <!-- Main Content - Centered, Flexible Height -->
  <div class="flex-1 flex flex-col items-center justify-center w-full max-w-md">
    <!-- Logo, Title, Buttons -->
  </div>
  
  <!-- Footer - Fixed at Bottom -->
  <div class="flex-shrink-0 w-full text-center pb-2">
    <p class="text-white/40 text-sm font-medium">
      ISMF © <%= Date.current.year %>
    </p>
  </div>
  
</div>
```

**Key classes:**
- `h-screen` - Full viewport height (NOT `min-h-screen`)
- `overflow-hidden` - No scrolling by default
- `flex-1` - Content takes available space
- `flex-shrink-0` - Header/footer stay fixed size

---

## Virtual Keyboard

### Implementation: simple-keyboard

**Why simple-keyboard?**
- ✅ No native OS keyboard needed
- ✅ Pure JavaScript (no dependencies)
- ✅ Customizable layouts
- ✅ Input preview support
- ✅ Audio feedback
- ✅ Works in Chromium kiosk mode

### Setup

**Importmap configuration:**

```ruby
# config/importmap.rb
pin "simple-keyboard", to: "https://cdn.jsdelivr.net/npm/simple-keyboard@3.8.93/build/index.min.js"
```

**CSS import:**

```css
/* app/assets/stylesheets/application.css */
@import "https://cdn.jsdelivr.net/npm/simple-keyboard@3.8.93/build/css/index.min.css";
```

### Stimulus Controller

**Core keyboard functionality:**

```javascript
// app/javascript/controllers/keyboard_controller.js
import { Controller } from "@hotwired/stimulus"
import SimpleKeyboard from "simple-keyboard"

export default class extends Controller {
  static targets = ["input"]
  
  connect() {
    console.log("🎹 Keyboard controller connected")
    this.initKeyboard()
  }
  
  initKeyboard() {
    this.keyboard = new SimpleKeyboard({
      onChange: input => this.handleChange(input),
      onKeyPress: button => this.handleKeyPress(button),
      layout: {
        default: [
          "1 2 3 4 5 6 7 8 9 0",
          "q w e r t y u i o p",
          "a s d f g h j k l",
          "z x c v b n m",
          "{space} @ . {bksp}"
        ]
      },
      theme: "hg-theme-default hg-theme-touch",
      display: {
        "{bksp}": "⌫",
        "{space}": "___"
      }
    })
  }
  
  handleChange(input) {
    this.inputTarget.value = input
  }
  
  handleKeyPress(button) {
    // Audio feedback
    this.playBeep()
    
    // Handle special keys
    if (button === "{bksp}") {
      this.keyboard.setInput(
        this.keyboard.getInput().slice(0, -1)
      )
    }
  }
  
  playBeep() {
    // Simple audio feedback
    const audio = new Audio('data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIGGS57OihUhIMTqXh8bllHAU2jdXwyXksBSV9yO/ekkILFGO56+mjVRUKRp3e8sFuIAUsgs/y2Ik3CBhju+zpoVQSC1Ci4PG+ayMGO5TS8Md0KwYnh8n')
    audio.play().catch(() => {})
  }
}
```

### Input Preview Display

**Custom preview implementation:**

```javascript
// app/javascript/controllers/keyboard_controller.js (continued)

connect() {
  this.createPreviewDisplay()
  this.initKeyboard()
}

createPreviewDisplay() {
  // Create preview element
  this.preview = document.createElement('div')
  this.preview.className = 'keyboard-preview'
  this.preview.textContent = 'Type here...'
  
  // Insert before keyboard
  const keyboardContainer = this.element.querySelector('.simple-keyboard')
  keyboardContainer.insertBefore(this.preview, keyboardContainer.firstChild)
}

updatePreview(input) {
  // Show bullets for password fields
  if (this.inputTarget.type === 'password') {
    this.preview.textContent = '•'.repeat(input.length) || 'Type password...'
  } else {
    this.preview.textContent = input || 'Type here...'
  }
}
```

**Preview CSS:**

```css
/* app/assets/stylesheets/touch.css */

.keyboard-preview {
  position: absolute;
  top: 10px;
  left: 50%;
  transform: translateX(-50%);
  background: #10b981;
  color: white;
  padding: 0.5rem 1rem;
  border-radius: 0.5rem;
  font-size: 1rem;
  font-family: monospace;
  min-width: 200px;
  text-align: center;
  z-index: 1000;
  box-shadow: 0 2px 8px rgba(0,0,0,0.2);
}

.keyboard-preview:empty::before {
  content: 'Type here...';
  opacity: 0.7;
}
```

### Keyboard Positioning

**Fixed at bottom, above viewport:**

```css
.simple-keyboard {
  position: fixed;
  bottom: 0;
  left: 0;
  right: 0;
  z-index: 999;
  background: #f3f4f6;
  box-shadow: 0 -4px 12px rgba(0,0,0,0.15);
  max-height: 300px;
}
```

### Disabling Native Keyboard

**Critical Chromium flags:**

```bash
# /usr/local/bin/start-kiosk.sh
chromium-browser \
  --kiosk \
  --disable-touch-keyboard \
  --disable-features=TranslateUI,VirtualKeyboard \
  http://pi5main.local:3005
```

**Why both flags?**
- `--disable-touch-keyboard` - Disables on-screen keyboard
- `--disable-features=VirtualKeyboard` - Disables virtual keyboard API

---

## Touch Detection

### Automatic Detection

**Priority order:**

1. **URL parameter** (`?touch=1` or `?touch=0`) - Manual override
2. **Cookie** (`touch_display=1`) - Persisted preference
3. **Screen size** (1280×720) - Auto-detected
4. **Default** - Desktop mode

### Stimulus Controller

```javascript
// app/javascript/controllers/touch_detection_controller.js
import { Controller } from "@hotwired/stimulus"

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
    
    console.log(`📏 Screen size: ${width}×${height}`)
    
    // Detect 1280×720 (Pi Touch Display 2 landscape)
    if (width === 1280 && height === 720) {
      console.log("✅ Pi touch display detected! Setting cookie...")
      this.setCookie("touch_display", "1", 365)
      window.location.reload()
    }
  }

  setCookie(name, value, days) {
    const expires = new Date(Date.now() + days * 864e5).toUTCString()
    document.cookie = `${name}=${value}; expires=${expires}; path=/; SameSite=Lax`
  }

  hasCookie(name) {
    return document.cookie.split("; ").some(row => row.startsWith(`${name}=`))
  }
}
```

**Usage in layout:**

```erb
<!-- app/views/layouts/application.html.erb -->
<body data-controller="touch-detection" class="<%= 'touch-mode' if request.variant.include?(:touch) %>">
  <!-- Content -->
</body>
```

### Manual Toggle (Development)

```ruby
# app/controllers/application_controller.rb

def enable_touch_mode
  cookies[:touch_display] = { value: "1", expires: 1.year }
  redirect_back(fallback_location: root_path)
end

def disable_touch_mode
  cookies.delete(:touch_display)
  redirect_back(fallback_location: root_path)
end
```

```ruby
# config/routes.rb
get '/touch/enable', to: 'application#enable_touch_mode'
get '/touch/disable', to: 'application#disable_touch_mode'
```

---

## Layout Guidelines

### No-Scroll Policy

**Rule:** All touch pages MUST fit within 1280×720 viewport without scrolling.

**Enforcement:**

```css
body.touch-mode {
  height: 100vh;
  overflow: hidden;
}

/* Main container */
.touch-container {
  height: 100vh;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}
```

**Opt-in scrolling only when necessary:**

```css
/* For specific scrollable areas */
.touch-scrollable {
  overflow-y: auto;
  max-height: 400px;
}

.touch-scrollable-sm { max-height: 200px; }
.touch-scrollable-md { max-height: 300px; }
.touch-scrollable-lg { max-height: 400px; }
```

### Spacing Adjustments

**Reduce spacing for 720px height:**

| Element | Desktop | Touch (1280×720) |
|---------|---------|------------------|
| Page title | `text-4xl mb-8` | `text-3xl mb-4` |
| Section spacing | `mb-8` | `mb-4` |
| Card padding | `p-6` | `p-4` |
| Logo size | `120px × 120px` | `96px × 96px` |
| Button height | `80px` | `64px` |
| Input height | `70px` | `60px` |
| Form spacing | `space-y-8` | `space-y-4` |

### Touch Target Sizes

**Minimum sizes for interactive elements:**

```css
/* Critical buttons (submit, confirm) */
.touch-btn-primary {
  min-height: 80px;
  min-width: 200px;
  font-size: 1.25rem;
}

/* Standard buttons */
.touch-btn {
  min-height: 64px;
  min-width: 150px;
  font-size: 1.125rem;
}

/* Small buttons (cancel, back) */
.touch-btn-sm {
  min-height: 48px;
  min-width: 100px;
  font-size: 1rem;
}

/* Form inputs */
.touch-input {
  min-height: 60px;
  font-size: 1.125rem;
  padding: 1rem;
}
```

### Visual Feedback

**Touch interactions must have clear feedback:**

```css
.touch-btn {
  transition: all 0.15s ease;
}

.touch-btn:active {
  transform: scale(0.95);
  opacity: 0.8;
  background-color: #dc2626;
}

/* Ripple effect */
.touch-btn {
  position: relative;
  overflow: hidden;
}

.touch-btn::after {
  content: '';
  position: absolute;
  top: 50%;
  left: 50%;
  width: 0;
  height: 0;
  border-radius: 50%;
  background: rgba(255, 255, 255, 0.5);
  transform: translate(-50%, -50%);
  transition: width 0.6s, height 0.6s;
}

.touch-btn:active::after {
  width: 300px;
  height: 300px;
}
```

### Navigation

**Floating hamburger menu (top-left) with horizontal navigation bar:**

```erb
<!-- app/views/shared/_touch_nav.html.erb -->
<% unless current_page?(root_path) %>
  <div data-controller="touch-nav">
    <!-- Hamburger button (top-left) -->
    <button data-action="touch-nav#toggle" 
            class="touch-hamburger-btn">
      <svg><!-- Icon --></svg>
    </button>
    
    <!-- Horizontal navigation bar (slides down from top) -->
    <div data-touch-nav-target="menu" 
         class="touch-menu-panel">
      <div class="touch-menu-content">
        <nav class="touch-menu-items">
          <%= link_to root_path, class: "touch-menu-item" do %>
            <svg class="touch-menu-icon"><!-- Home icon --></svg>
            <span>Home</span>
          <% end %>
          <button data-action="click->touch-nav#goBack" class="touch-menu-item">
            <svg class="touch-menu-icon"><!-- Back icon --></svg>
            <span>Back</span>
          </button>
          <%= button_to session_path, method: :delete, class: "touch-menu-item" do %>
            <svg class="touch-menu-icon"><!-- Sign Out icon --></svg>
            <span>Sign Out</span>
          <% end %>
        </nav>
      </div>
    </div>
  </div>
<% end %>
```

**Hamburger button and horizontal navigation CSS:**

```css
/* Hamburger button (top-left corner) */
.touch-hamburger-btn {
  position: fixed;
  top: 1rem;
  left: 1rem;
  z-index: 10001;
  width: 80px;
  height: 80px;
  border-radius: 1rem;
  background: rgba(26, 26, 46, 0.85);
  backdrop-filter: blur(10px);
  display: flex;
  align-items: center;
  justify-content: center;
  color: white;
  transition: all 0.2s ease;
  border: 3px solid rgba(233, 69, 96, 0.6);
  box-shadow: 0 4px 16px rgba(0, 0, 0, 0.3);
  cursor: pointer;
}

/* Horizontal menu panel - slides down from top */
.touch-menu-panel {
  position: fixed;
  top: 0;
  left: 0;
  right: 0;
  z-index: 10000;
  pointer-events: none;
  transition: none;
}

.touch-menu-panel.touch-menu-open {
  pointer-events: auto;
}

/* Horizontal menu content container */
.touch-menu-content {
  position: absolute;
  top: 0;
  left: 0;
  right: 0;
  background: linear-gradient(135deg, #1a1a2e 0%, #0f3460 100%);
  border-bottom: 4px solid rgba(233, 69, 96, 0.8);
  box-shadow: 0 4px 24px rgba(0, 0, 0, 0.5);
  transform: translateY(-100%);
  transition: transform 0.3s ease;
  padding: 1.5rem;
  padding-left: 7rem; /* Space for hamburger button */
}

.touch-menu-panel.touch-menu-open .touch-menu-content {
  transform: translateY(0);
}

/* Horizontal menu items container */
.touch-menu-items {
  display: flex;
  flex-direction: row;
  gap: 1rem;
  align-items: center;
  justify-content: flex-start;
  flex-wrap: wrap;
}

/* Individual menu item - horizontal button */
.touch-menu-item {
  display: flex;
  align-items: center;
  gap: 0.75rem;
  padding: 1rem 1.5rem;
  background: rgba(255, 255, 255, 0.1);
  backdrop-filter: blur(10px);
  border: 2px solid rgba(233, 69, 96, 0.3);
  border-radius: 0.75rem;
  color: white;
  font-size: 1.25rem;
  font-weight: 700;
  text-decoration: none;
  transition: all 0.15s ease;
  cursor: pointer;
  box-shadow: 0 2px 8px rgba(0, 0, 0, 0.2);
  white-space: nowrap;
}

.touch-menu-icon {
  width: 1.75rem;
  height: 1.75rem;
  flex-shrink: 0;
}
```

---

## Development Workflow

### Creating Touch Views

**1. Start with desktop view:**

```erb
<!-- app/views/incidents/new.html.erb -->
<div class="container mx-auto p-8">
  <h1 class="text-4xl mb-8">New Incident</h1>
  <!-- Form -->
</div>
```

**2. Create touch variant:**

```erb
<!-- app/views/incidents/new.html+touch.erb -->
<div class="h-screen flex flex-col overflow-hidden p-4">
  <h1 class="text-3xl mb-4">New Incident</h1>
  <!-- Compact form -->
</div>
```

**3. Test both:**

```bash
# Desktop
open http://localhost:3005/incidents/new

# Touch
open http://localhost:3005/incidents/new?touch=1
```

### Local Testing (Mac)

**Method 1: URL parameter**

```bash
# Start Docker
docker compose up -d

# Open with touch mode
open http://localhost:3005?touch=1
```

**Method 2: Browser DevTools**

```
1. Open Chrome DevTools (Cmd+Option+I)
2. Click Device Toolbar (Cmd+Shift+M)
3. Select "Edit..." from device dropdown
4. Add custom device:
   - Name: "Pi Touch Display 2"
   - Width: 1280
   - Height: 720
   - Device pixel ratio: 1
5. Select device and reload
```

**Method 3: Cookie override**

```javascript
// In browser console
document.cookie = "touch_display=1; path=/; max-age=31536000"
location.reload()
```

### Testing on Pi

**Method 1: Direct testing**

```bash
# SSH to Pi
ssh rege@pi5main.local

# Stop kiosk
sudo systemctl stop kiosk.service

# Start Chromium manually
chromium-browser --kiosk http://pi5main.local:3005

# Exit: Alt+F4
```

**Method 2: Remote debugging**

```bash
# On Pi
sudo systemctl stop kiosk.service
chromium-browser --remote-debugging-port=9222 --kiosk http://pi5main.local:3005 &

# On Mac
# Open Chrome, go to: chrome://inspect
# Configure: Add pi5main.local:9222
# Click "Inspect" on target
```

### Debugging Touch Issues

**Check variant:**

```erb
<!-- Add to layout temporarily -->
<div style="position: fixed; top: 0; right: 0; background: yellow; padding: 1rem; z-index: 9999;">
  Variant: <%= request.variant.inspect %>
  Cookie: <%= cookies[:touch_display] %>
  Width: <span id="width"></span>
  Height: <span id="height"></span>
  <script>
    document.getElementById('width').textContent = window.innerWidth
    document.getElementById('height').textContent = window.innerHeight
  </script>
</div>
```

**Check CSS loading:**

```javascript
// Browser console
document.querySelector('link[href*="touch.css"]')
// Should return <link> element if loaded
```

**Check keyboard:**

```javascript
// Browser console
document.querySelector('.simple-keyboard')
// Should return keyboard element
```

---

## Testing

### Manual Testing Checklist

**Touch Detection**
- [ ] Auto-detects 1280×720 screen
- [ ] Sets cookie `touch_display=1`
- [ ] Cookie persists after reload
- [ ] Cookie persists after reboot
- [ ] Manual override with `?touch=1` works
- [ ] Manual override with `?touch=0` works

**Layout**
- [ ] All pages fit in 720px height (no scroll)
- [ ] Buttons are large enough (64px minimum)
- [ ] Text is readable (18px minimum)
- [ ] No horizontal scrolling
- [ ] Footer stays at bottom
- [ ] Navigation accessible

**Virtual Keyboard**
- [ ] Keyboard appears on input focus
- [ ] Only custom keyboard appears (no native)
- [ ] Preview display shows typed text
- [ ] Preview shows bullets for passwords
- [ ] Keyboard doesn't hide when switching inputs
- [ ] Backspace works
- [ ] Space works
- [ ] @ symbol works
- [ ] Enter submits form
- [ ] Audio feedback on keypress

**Form Interaction**
- [ ] Can type in all input fields
- [ ] Can submit forms
- [ ] Validation errors display properly
- [ ] Success messages display properly
- [ ] Can navigate with touch only
- [ ] No mouse required

**Navigation**
- [ ] Hamburger menu works
- [ ] Menu slides down from top
- [ ] Menu closes when tapping hamburger button again
- [ ] Back button works
- [ ] Sign Out works
- [ ] Home button works

**Performance**
- [ ] Page loads in <2 seconds
- [ ] Touch response is immediate
- [ ] No lag when typing
- [ ] No memory leaks over 1 hour
- [ ] No JavaScript errors in console

### Automated Tests

**System specs for touch views:**

```ruby
# spec/system/touch_display_spec.rb
require 'rails_helper'

RSpec.describe 'Touch Display', type: :system do
  before do
    driven_by(:selenium_chrome_headless)
  end

  context 'with touch mode enabled' do
    before do
      # Set cookie to enable touch mode
      page.driver.browser.manage.add_cookie(
        name: 'touch_display',
        value: '1',
        path: '/'
      )
    end

    it 'displays touch-optimized home page' do
      visit root_path
      
      expect(page).to have_css('body.touch-mode')
      expect(page).to have_css('.touch-btn')
      expect(page).to have_css('.touch-logo')
    end

    it 'shows virtual keyboard on input focus', js: true do
      visit new_session_path
      
      find('input[type="email"]').click
      
      expect(page).to have_css('.simple-keyboard')
      expect(page).to have_css('.keyboard-preview')
    end

    it 'allows form submission with virtual keyboard', js: true do
      user = create(:user, email: 'test@example.com', password: 'password')
      
      visit new_session_path
      
      # Type with virtual keyboard would require Capybara integration
      # For now, test without keyboard
      fill_in 'Email', with: 'test@example.com'
      fill_in 'Password', with: 'password'
      click_button 'Sign In'
      
      expect(page).to have_current_path(admin_root_path)
    end
  end
end
```

### Visual Regression Testing

**Capture screenshots for comparison:**

```ruby
# spec/system/touch_visual_spec.rb
RSpec.describe 'Touch Visual Regression', type: :system do
  it 'matches home page screenshot' do
    visit root_path(touch: 1)
    
    page.save_screenshot('tmp/screenshots/touch_home.png', full: true)
    
    # Use Percy or similar for visual diffs
  end
end
```

---

## Troubleshooting

### Native Keyboard Still Appears

**Problem:** Both native and custom keyboard show, keyboards overlap.

**Solution:**

```bash
# Check Chromium flags
ps aux | grep chromium | grep -o '\-\-[^ ]*keyboard[^ ]*'

# Should see:
#   --disable-touch-keyboard
#   --disable-features=VirtualKeyboard (as part of longer flag)

# If wrong, update kiosk script
sudo nano /usr/local/bin/start-kiosk.sh

# Ensure both flags present:
#   --disable-touch-keyboard
#   --disable-features=TranslateUI,VirtualKeyboard

sudo systemctl restart kiosk.service
```

### Touch Mode Not Activating

**Problem:** Desktop layout shows instead of touch.

**Check resolution:**

```javascript
// Browser console
console.log(`${window.innerWidth}×${window.innerHeight}`)
// Should be: 1280×720
```

**Check cookie:**

```javascript
// Browser console
document.cookie.split('; ').find(row => row.startsWith('touch_display='))
// Should be: touch_display=1
```

**Force touch mode:**

```
Visit: http://pi5main.local:3005?touch=1
```

### Keyboard Not Appearing

**Problem:** Touch input, no keyboard shows.

**Check importmap:**

```bash
# Check if simple-keyboard is loaded
curl http://pi5main.local:3005 | grep simple-keyboard

# Should see importmap entry
```

**Check browser console:**

```
F12 → Console → Look for errors
Common: "Failed to load module"
```

**Solution:**

```bash
# Clear cache
rm -rf ~/.config/chromium/Default/Cache/*
sudo systemctl restart kiosk.service
```

### Input Field Hidden by Keyboard

**Problem:** Can't see what you're typing.

**Solution:** This is why we have the preview display!

**Verify preview works:**

```javascript
// Browser console
document.querySelector('.keyboard-preview')
// Should return preview element
```

**If missing, check keyboard controller:**

```bash
# View logs
sudo journalctl -u kiosk.service | grep -i keyboard
```

### Performance Issues

**Problem:** Slow touch response, laggy keyboard.

**Check resources:**

```bash
# Memory
free -h
# Should have >100MB free

# CPU
top
# Chromium should be <50% when idle

# Temperature
vcgencmd measure_temp
# Should be <70°C
```

**Solutions:**

```bash
# Add cooling fan

# Reduce Chromium features
# Edit /usr/local/bin/start-kiosk.sh
# Add:
#   --disable-gpu
#   --disable-software-rasterizer

# Clear cache
rm -rf ~/.config/chromium/Default/Cache/*
```

### Cookie Not Persisting

**Problem:** Touch mode resets after reboot.

**Check cookie settings:**

```javascript
// Browser console
document.cookie.split('; ').find(row => row.startsWith('touch_display='))
```

**Check incognito mode:**

```bash
# Verify kiosk script doesn't use --incognito
cat /usr/local/bin/start-kiosk.sh | grep incognito

# If present, remove it:
sudo nano /usr/local/bin/start-kiosk.sh
# Remove --incognito flag

sudo systemctl restart kiosk.service
```

---

## Reference

### Key Files

```
app/
├── controllers/
│   └── application_controller.rb      # Variant detection
├── views/
│   ├── **/*.html+touch.erb            # Touch view variants
│   ├── layouts/
│   │   └── application.html.erb       # Touch CSS loading
│   └── shared/
│       └── _touch_nav.html.erb        # Navigation partial
├── javascript/
│   └── controllers/
│       ├── keyboard_controller.js     # Virtual keyboard
│       ├── touch_detection_controller.js
│       └── touch_nav_controller.js
├── assets/
│   └── stylesheets/
│       └── touch.css                   # Touch display styles
└── config/
    └── importmap.rb                    # simple-keyboard import
```

### Related Documentation

- **Kiosk Setup:** [KIOSK_DEPLOYMENT.md](KIOSK_DEPLOYMENT.md)
- **Testing:** Run `bundle exec rspec spec/system/touch_display_spec.rb`
- **Architecture:** See `.rules` file section 15

### External Resources

- **simple-keyboard:** https://simple-keyboard.com/
- **Raspberry Pi Touch Display:** https://www.raspberrypi.com/products/raspberry-pi-touch-display/
- **Rails Variants:** https://guides.rubyonrails.org/layouts_and_rendering.html#the-request-format-and-variants

---

## Support

For issues or questions:

- **GitHub Issues:** https://github.com/your-org/ismf-race-logger/issues
- **Email:** tech-support@ismf.org
- **Kiosk Deployment:** See [KIOSK_DEPLOYMENT.md](KIOSK_DEPLOYMENT.md)

---

**Document Version:** 3.0  
**Last Updated:** 2025-01-29  
**Next Review:** 2025-03-01