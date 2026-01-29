import { Controller } from "@hotwired/stimulus"

// Touch-friendly confirmation modal controller
//
// Usage:
//   <div data-controller="touch-confirm">
//     <button data-action="touch-confirm#show"
//             data-touch-confirm-message-param="Delete this user?"
//             data-touch-confirm-url-param="/admin/users/123"
//             data-touch-confirm-method-param="delete">
//       Delete
//     </button>
//   </div>
//
export default class extends Controller {
  connect() {
    console.log("🔔 Touch confirm controller connected")
    this.modalElement = null
  }

  disconnect() {
    console.log("🔔 Touch confirm controller disconnecting")
    this.removeModal()
  }

  // Show confirmation modal
  show(event) {
    event.preventDefault()
    event.stopPropagation()

    const button = event.currentTarget
    const message = button.dataset.touchConfirmMessageParam || "Are you sure?"
    const url = button.dataset.touchConfirmUrlParam
    const method = button.dataset.touchConfirmMethodParam || "delete"

    console.log("🔔 Show modal:", { message, url, method })

    if (!url) {
      console.error("touch-confirm: No URL provided")
      return
    }

    this.showModal(message, url, method)
  }

  // Show the modal with dynamic content
  showModal(message, url, method) {
    // Remove any existing modal
    this.removeModal()

    // Create new modal
    this.createModal(message, url, method)

    // Show modal
    this.modalElement.classList.remove("hidden")
    document.body.style.overflow = "hidden"
  }

  // Hide modal
  hide(event) {
    if (event) {
      event.preventDefault()
      event.stopPropagation()
    }
    
    console.log("🔔 Hiding modal")
    
    if (this.modalElement) {
      this.modalElement.classList.add("hidden")
    }
    document.body.style.overflow = ""
  }

  // Confirm and submit form
  confirm(event) {
    console.log("🔔 Confirming action")
    // Let the form submit naturally
    document.body.style.overflow = ""
  }

  // Create modal HTML and append to body
  createModal(message, url, method) {
    const modal = document.createElement("div")
    modal.className = "fixed inset-0 z-50 overflow-y-auto"
    modal.innerHTML = `
      <!-- Backdrop -->
      <div class="fixed inset-0 bg-black bg-opacity-75 transition-opacity" data-action="click->touch-confirm#hide"></div>
      
      <!-- Modal Container -->
      <div class="flex min-h-full items-center justify-center p-4">
        <div class="relative bg-white rounded-3xl shadow-2xl w-full max-w-md transform transition-all">
          
          <!-- Warning Icon -->
          <div class="flex justify-center pt-8 pb-4">
            <div class="w-20 h-20 bg-red-100 rounded-full flex items-center justify-center">
              <svg class="w-12 h-12 text-red-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" 
                      d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
              </svg>
            </div>
          </div>

          <!-- Message -->
          <div class="px-6 pb-6 text-center">
            <h3 class="text-2xl font-bold text-ismf-navy mb-2">Confirm Action</h3>
            <p class="text-lg text-ismf-gray">${this.escapeHtml(message)}</p>
          </div>

          <!-- Form for deletion -->
          <form action="${this.escapeHtml(url)}"
                data-turbo="true"
                method="post"
                data-action="submit->touch-confirm#confirm">
            <input type="hidden" name="_method" value="${this.escapeHtml(method)}">
            <input type="hidden" name="authenticity_token" value="${this.getCsrfToken()}">
            
            <!-- Action Buttons -->
            <div class="flex gap-3 px-6 pb-6">
              <button type="button"
                      data-action="click->touch-confirm#hide"
                      class="touch-btn touch-btn-secondary flex-1 min-h-[88px]">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="width: 2rem; height: 2rem;">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" d="M6 18L18 6M6 6l12 12" />
                </svg>
                <span>Cancel</span>
              </button>
              
              <button type="submit"
                      class="touch-btn bg-linear-to-r! from-red-500! to-red-600! text-white! flex-1 min-h-[88px]">
                <svg fill="none" stroke="currentColor" viewBox="0 0 24 24" style="width: 2rem; height: 2rem;">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2.5" 
                        d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
                </svg>
                <span>Delete</span>
              </button>
            </div>
          </form>
        </div>
      </div>
    `
    
    document.body.appendChild(modal)
    this.modalElement = modal
    
    console.log("🔔 Modal created and appended to body")
  }

  // Remove modal from DOM
  removeModal() {
    if (this.modalElement) {
      this.modalElement.remove()
      this.modalElement = null
      document.body.style.overflow = ""
      console.log("🔔 Modal removed")
    }
  }

  // Get CSRF token from meta tag
  getCsrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ""
  }

  // Escape HTML to prevent XSS
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
}