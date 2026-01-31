// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"

// Generic Turbo error handling for Rails 8
// Handles 422/400 validation errors and displays them to users
document.addEventListener("turbo:frame-missing", (event) => {
  // When Turbo can't find a frame, prevent the error and show a message
  event.preventDefault()
  console.error("Turbo frame missing:", event.detail)
  showErrorAlert("An error occurred. Please try again.")
})

document.addEventListener("turbo:submit-end", (event) => {
  const { fetchResponse } = event.detail
  
  if (!fetchResponse) return
  
  const { response } = fetchResponse
  
  // Handle validation errors (422) and bad requests (400)
  if (response && (response.status === 422 || response.status === 400)) {
    event.preventDefault()
    
    // Try to extract error message from response
    response.text().then(html => {
      // Try to find flash messages in the response
      const parser = new DOMParser()
      const doc = parser.parseFromString(html, "text/html")
      
      // Look for alert/error messages in the response
      const alertElement = doc.querySelector(".flash-alert, [data-flash-type='alert']")
      const errorMessage = alertElement?.textContent?.trim()
      
      if (errorMessage) {
        showErrorAlert(errorMessage)
      } else {
        // Generic error message
        showErrorAlert("Validation failed. Please check your input and try again.")
      }
    }).catch(err => {
      console.error("Error parsing response:", err)
      showErrorAlert("An error occurred. Please try again.")
    })
  }
})

document.addEventListener("turbo:fetch-request-error", (event) => {
  console.error("Fetch request error:", event.detail)
})

// Helper function to show error alerts
function showErrorAlert(message) {
  // Remove any existing alerts
  const existingAlerts = document.querySelectorAll(".turbo-error-alert")
  existingAlerts.forEach(alert => alert.remove())
  
  // Create alert element
  const alert = document.createElement("div")
  alert.className = "turbo-error-alert fixed top-24 left-4 right-4 z-50 bg-red-100 border-2 border-red-500 text-red-900 px-6 py-4 rounded-xl flex items-center gap-4 shadow-lg"
  alert.innerHTML = `
    <svg class="w-8 h-8 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
    </svg>
    <span class="text-xl font-semibold">${escapeHtml(message)}</span>
    <button class="ml-auto text-red-700 hover:text-red-900" onclick="this.parentElement.remove()">
      <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
      </svg>
    </button>
  `
  
  document.body.appendChild(alert)
  
  // Auto-dismiss after 5 seconds
  setTimeout(() => {
    alert.remove()
  }, 5000)
  
  // Vibrate if available (touch devices)
  if (navigator.vibrate) {
    navigator.vibrate([50, 100, 50])
  }
}

// Helper function to escape HTML
function escapeHtml(text) {
  const div = document.createElement("div")
  div.textContent = text
  return div.innerHTML
}