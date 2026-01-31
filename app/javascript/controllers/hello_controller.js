import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.textContent = "Hello World!"
  }
}
// Force recompile - Sat Jan 31 12:12:42 CET 2026
