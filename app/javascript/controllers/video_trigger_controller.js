import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="video-trigger"
// This controller bridges thumbnail clicks to the video player modal
export default class extends Controller {
  static values = {
    videoUrl: String
  }

  open(event) {
    event.preventDefault()
    
    const videoUrl = event.currentTarget.dataset.videoUrl
    const videoBlobId = event.currentTarget.dataset.videoBlobId
    
    if (!videoUrl) {
      console.error("No video URL provided")
      return
    }

    // Find the video player modal controller
    const modalElement = document.getElementById("video-player-modal")
    if (!modalElement) {
      console.error("Video player modal not found")
      return
    }

    // Get the Stimulus controller instance
    const videoPlayerController = this.application.getControllerForElementAndIdentifier(
      modalElement,
      "video-player"
    )

    if (!videoPlayerController) {
      console.error("Video player controller not found")
      return
    }

    // Call the open method directly by passing the video URL and blob ID
    videoPlayerController.openWithUrl(videoUrl, videoBlobId)
  }
}