import { Controller } from "@hotwired/stimulus"

// Touch Detection controller for automatic device detection
//
// Automatically detects 800×480 screen (Raspberry Pi Touch Display 2)
// and sets a persistent cookie to enable touch mode.
//
// Usage:
//   <body data-controller="touch-detection">
//
// Detection priority:
//   1. URL parameter (?touch=1)
//   2. Cookie (touch_display=1)
//   3. Screen size detection (800×480)
//   4. Default (desktop)
//
export default class extends Controller {
  connect() {
    console.log("📱 Touch detection controller connected")
    
    // Only detect if no cookie is set
    if (!this.hasCookie("touch_display")) {
      this.detectScreenSize()
    } else {
      console.log("🍪 Touch mode cookie already set:", this.getCookie("touch_display"))
    }
  }

  detectScreenSize() {
    const width = window.innerWidth
    const height = window.innerHeight
    
    console.log(`📏 Screen size: ${width}×${height}`)
    
    // Detect 800×480 (Pi Touch Display 2)
    // Also detect 480×800 (portrait mode)
    const isTouch = (width === 800 && height === 480) || (width === 480 && height === 800)
    
    if (isTouch) {
      console.log("✅ Pi touch display detected! Setting cookie...")
      this.setCookie("touch_display", "1", 365)
      
      // Reload to apply touch mode
      console.log("🔄 Reloading page to apply touch mode...")
      window.location.reload()
    } else {
      console.log("🖥️ Desktop display detected (no touch mode)")
    }
  }

  hasCookie(name) {
    return document.cookie.split("; ").some(row => row.startsWith(`${name}=`))
  }

  getCookie(name) {
    const row = document.cookie.split("; ").find(row => row.startsWith(`${name}=`))
    return row ? row.split("=")[1] : null
  }

  setCookie(name, value, days) {
    const expires = new Date(Date.now() + days * 864e5).toUTCString()
    document.cookie = `${name}=${value}; expires=${expires}; path=/; SameSite=Lax`
    console.log(`🍪 Cookie set: ${name}=${value} (expires in ${days} days)`)
  }

  // Action to manually enable touch mode
  // Usage: data-action="click->touch-detection#enableTouch"
  enableTouch(event) {
    event.preventDefault()
    console.log("👆 Manually enabling touch mode...")
    this.setCookie("touch_display", "1", 365)
    window.location.reload()
  }

  // Action to manually disable touch mode
  // Usage: data-action="click->touch-detection#disableTouch"
  disableTouch(event) {
    event.preventDefault()
    console.log("🖱️ Manually disabling touch mode...")
    this.setCookie("touch_display", "0", 365)
    window.location.reload()
  }
}