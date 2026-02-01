// Clickable Row Controller
//
// Makes table rows clickable while excluding specific elements (checkboxes, buttons, links)
// Click anywhere on the row to navigate to the URL specified in data-clickable-row-url-value
//
// Usage:
//   <tr data-controller="clickable-row" 
//       data-clickable-row-url-value="/path/to/resource"
//       data-action="click->clickable-row#navigate">
//     ...
//   </tr>

import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    url: String
  }

  navigate(event) {
    // Don't navigate if clicking on interactive elements
    const clickedElement = event.target.closest('a, button, input, select, textarea')
    
    if (clickedElement) {
      // User clicked on a link, button, or form element - let default behavior happen
      return
    }

    // Don't navigate if clicking on elements with data-no-row-click attribute
    if (event.target.closest('[data-no-row-click]')) {
      return
    }

    // Navigate to the URL
    if (this.urlValue) {
      // Use Turbo Drive for smooth navigation
      if (window.Turbo) {
        window.Turbo.visit(this.urlValue)
      } else {
        // Fallback for non-Turbo environments
        window.location.href = this.urlValue
      }
    }
  }
}