import { Controller } from "@hotwired/stimulus"

// Flash Stack Controller - Generic flash message manager
//
// Manages flash messages from multiple sources:
// 1. Turbo Stream broadcasts (via #flash-messages container)
// 2. Programmatic JavaScript calls (via custom events)
// 3. Page load flashes (rendered by Rails)
//
// Usage (Turbo Streams - already works):
//   Turbo::StreamsChannel.broadcast_append_to(stream, target: "flash-messages", ...)
//
// Usage (JavaScript - simple API):
//   window.flash.success("Operation completed!")
//   window.flash.error("Something went wrong")
//   window.flash.notice("Info message")
//
// Or via custom event:
//   document.dispatchEvent(new CustomEvent('flash:show', {
//     detail: { message: "Hello", type: "notice" }
//   }))
//
export default class extends Controller {
  connect() {
    // Register global API for easy access
    window.flash = {
      success: (msg) => this.show(msg, 'notice'),
      error: (msg) => this.show(msg, 'alert'),
      notice: (msg) => this.show(msg, 'notice'),
      alert: (msg) => this.show(msg, 'alert')
    }

    // Listen for custom flash events
    this.boundShowHandler = this.handleShowEvent.bind(this)
    document.addEventListener('flash:show', this.boundShowHandler)

    // Start observing for DOM changes (Turbo Stream broadcasts)
    this.startObserving()
    
    // Position existing messages on initial load
    this.repositionMessages()
  }

  disconnect() {
    // Cleanup
    if (this.observer) {
      this.observer.disconnect()
    }
    document.removeEventListener('flash:show', this.boundShowHandler)
    delete window.flash
  }

  // Handle custom flash:show events
  handleShowEvent(event) {
    const { message, type } = event.detail
    this.show(message, type || 'notice')
  }

  // Programmatically show a flash message
  show(message, type = 'notice') {
    const flashElement = this.createFlashElement(message, type)
    this.element.appendChild(flashElement)
  }

  // Create a flash message element with proper structure
  createFlashElement(message, type) {
    // Determine styling and behavior based on type
    const config = this.getFlashConfig(type)
    
    // Create container div
    const flashElement = document.createElement('div')
    flashElement.id = `flash-${this.generateUUID()}`
    flashElement.className = `fixed left-1/2 -translate-x-1/2 z-9999 ${config.bgClass} border-2 ${config.borderClass} ${config.textClass} px-4 py-3 rounded-xl flex items-center gap-3 shadow-lg max-w-sm transition-all duration-300`
    
    // Set Stimulus controller and values
    flashElement.setAttribute('data-controller', 'flash')
    flashElement.setAttribute('data-flash-dismiss-after-value', config.dismissTime)
    flashElement.setAttribute('data-action', 'flash:removed->flash-stack#reposition')
    
    // Inline styles for visibility
    flashElement.style.display = 'flex'
    flashElement.style.visibility = 'visible'
    flashElement.style.pointerEvents = 'auto'
    
    // Build HTML content
    flashElement.innerHTML = `
      <svg class="w-6 h-6 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="${config.iconPath}" />
      </svg>
      <span class="text-base font-semibold flex-1">${this.escapeHtml(message)}</span>
      <button type="button" class="${config.buttonClass}" data-action="click->flash#dismiss">
        <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      </button>
    `
    
    return flashElement
  }

  // Get configuration for flash type
  getFlashConfig(type) {
    if (type === 'notice' || type === 'success') {
      return {
        bgClass: 'bg-green-100',
        borderClass: 'border-green-500',
        textClass: 'text-green-900',
        buttonClass: 'text-green-700 hover:text-green-900',
        iconPath: 'M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z',
        dismissTime: '3000'
      }
    } else { // alert, error
      return {
        bgClass: 'bg-red-100',
        borderClass: 'border-red-500',
        textClass: 'text-red-900',
        buttonClass: 'text-red-700 hover:text-red-900',
        iconPath: 'M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z',
        dismissTime: '5000'
      }
    }
  }

  // Escape HTML to prevent XSS
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }

  // Generate UUID for flash message ID
  generateUUID() {
    return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
      const r = Math.random() * 16 | 0
      const v = c == 'x' ? r : (r & 0x3 | 0x8)
      return v.toString(16)
    })
  }

  startObserving() {
    // Create a MutationObserver to watch for added/removed flash messages
    this.observer = new MutationObserver((mutations) => {
      // Check if any flash messages were added or removed
      const flashChanged = mutations.some(mutation => {
        const addedFlashes = Array.from(mutation.addedNodes).some(node => 
          node.nodeType === 1 && node.id && node.id.startsWith('flash-')
        )
        const removedFlashes = Array.from(mutation.removedNodes).some(node =>
          node.nodeType === 1 && node.id && node.id.startsWith('flash-')
        )
        return addedFlashes || removedFlashes
      })

      if (flashChanged) {
        this.repositionMessages()
      }
    })

    // Start observing the container
    this.observer.observe(this.element, {
      childList: true,
      subtree: false
    })
  }

  repositionMessages() {
    // Get all flash messages
    const messages = Array.from(this.element.querySelectorAll('[id^="flash-"]'))
    
    if (messages.length === 0) return

    // Base offset from bottom (matching the original bottom-6 = 1.5rem = 24px)
    const baseOffset = 24
    
    // Gap between messages
    const gap = 12

    // Position each message from bottom up
    let currentOffset = baseOffset
    
    messages.forEach((message, index) => {
      // Set the bottom position
      message.style.bottom = `${currentOffset}px`
      
      // Ensure fixed positioning is maintained
      message.style.position = 'fixed'
      message.style.left = '50%'
      message.style.transform = 'translateX(-50%)'
      message.style.zIndex = `${9999 + index}` // Stack with increasing z-index
      
      // Calculate offset for next message (current message height + gap)
      const messageHeight = message.offsetHeight
      currentOffset += messageHeight + gap
    })
  }

  // Manual trigger for repositioning (can be called from other controllers)
  reposition() {
    this.repositionMessages()
  }
}