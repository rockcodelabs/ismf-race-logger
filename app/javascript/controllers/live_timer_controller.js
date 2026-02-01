// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="live-timer"
export default class extends Controller {
  static targets = ["display", "date"]

  connect() {
    this.updateTime()
    this.intervalId = setInterval(() => {
      this.updateTime()
    }, 1000)
  }

  disconnect() {
    if (this.intervalId) {
      clearInterval(this.intervalId)
    }
  }

  updateTime() {
    const now = new Date()
    
    // Format time as HH:MM:SS
    const hours = String(now.getHours()).padStart(2, '0')
    const minutes = String(now.getMinutes()).padStart(2, '0')
    const seconds = String(now.getSeconds()).padStart(2, '0')
    
    this.displayTarget.textContent = `${hours}:${minutes}:${seconds}`
    
    // Format date as "Day, Mon DD, YYYY"
    const options = { 
      weekday: 'short', 
      year: 'numeric', 
      month: 'short', 
      day: 'numeric' 
    }
    this.dateTarget.textContent = now.toLocaleDateString('en-US', options)
  }
}