// frozen_string_literal: true

import { Controller } from "@hotwired/stimulus"
import VideoCacheService from "services/video_cache_service"

// VideoPrefetchController
//
// Handles background prefetching and caching of all videos for the current race.
// Starts automatically on page load and runs in the background.
//
// Features:
// - Automatic prefetch on page load
// - Parallel downloads (configurable)
// - Progress tracking
// - Cache status display
// - Manual cache clear
//
// Usage:
//   <div data-controller="video-prefetch"
//        data-video-prefetch-race-id-value="123"
//        data-video-prefetch-videos-value='[{"id": 1, "url": "/path"}]'
//        data-video-prefetch-auto-start-value="true">
//     <div data-video-prefetch-target="status"></div>
//     <button data-action="click->video-prefetch#start">Prefetch</button>
//     <button data-action="click->video-prefetch#clear">Clear Cache</button>
//   </div>
//
export default class extends Controller {
  static targets = ["status", "progress", "icon"]
  
  static values = {
    raceId: Number,
    videos: Array,
    autoStart: { type: Boolean, default: true },
    maxParallel: { type: Number, default: 2 } // Download 2 videos at a time
  }

  async connect() {
    console.log('🎬 VideoPrefetchController connected', {
      raceId: this.raceIdValue,
      videoCount: this.videosValue.length,
      autoStart: this.autoStartValue
    })
    
    // Initialize video cache service
    this.videoCache = new VideoCacheService()
    
    try {
      await this.videoCache.init(this.raceIdValue)
      console.log('✅ Video cache initialized')
      
      // Update initial status
      await this.updateStatus()
      
      // Auto-start prefetch if enabled
      if (this.autoStartValue && this.videosValue.length > 0) {
        // Delay slightly to not interfere with page load
        setTimeout(() => this.start(), 1000)
      }
    } catch (error) {
      console.error('❌ Failed to initialize video cache:', error)
      this.showError('Video cache not available')
    }
  }

  disconnect() {
    this.cancelPrefetch = true
  }

  // Start prefetching videos
  async start() {
    if (this.prefetching) {
      console.log('⚠️ Prefetch already in progress')
      return
    }
    
    if (this.videosValue.length === 0) {
      console.log('ℹ️ No videos to prefetch')
      return
    }

    this.prefetching = true
    this.cancelPrefetch = false
    
    console.log(`📦 Starting prefetch of ${this.videosValue.length} videos...`)
    this.showPrefetching()

    try {
      const result = await this.videoCache.prefetchRaceVideos(
        this.videosValue,
        (progress) => this.updateProgress(progress)
      )
      
      console.log('✅ Prefetch complete:', result)
      
      if (result.cached > 0) {
        this.showSuccess(`${result.cached} video${result.cached === 1 ? '' : 's'} cached`)
      }
      
      if (result.failed > 0) {
        this.showWarning(`${result.failed} video${result.failed === 1 ? '' : 's'} failed`)
      }
      
      await this.updateStatus()
      
    } catch (error) {
      console.error('❌ Prefetch failed:', error)
      this.showError('Failed to cache videos')
    } finally {
      this.prefetching = false
    }
  }

  // Cancel ongoing prefetch
  cancel() {
    if (this.prefetching) {
      console.log('🛑 Cancelling prefetch...')
      this.cancelPrefetch = true
      this.prefetching = false
      this.showStatus('Prefetch cancelled')
    }
  }

  // Clear cache for current race
  async clear() {
    if (!confirm('Clear all cached videos for this race?')) {
      return
    }

    try {
      const count = await this.videoCache.clearRace()
      console.log(`🗑️ Cleared ${count} videos from cache`)
      this.showSuccess(`${count} video${count === 1 ? '' : 's'} removed from cache`)
      await this.updateStatus()
    } catch (error) {
      console.error('❌ Failed to clear cache:', error)
      this.showError('Failed to clear cache')
    }
  }

  // Update cache status display
  async updateStatus() {
    try {
      const stats = await this.videoCache.getStats()
      
      if (this.hasStatusTarget) {
        const cachedCount = stats.video_count
        const totalCount = this.videosValue.length
        const cacheSize = stats.total_size_mb
        
        if (cachedCount === 0) {
          this.statusTarget.innerHTML = `
            <div class="flex items-center gap-2 text-gray-500">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 16a4 4 0 01-.88-7.903A5 5 0 1115.9 6L16 6a5 5 0 011 9.9M9 19l3 3m0 0l3-3m-3 3V10" />
              </svg>
              <span class="text-xs">No videos cached</span>
            </div>
          `
        } else if (cachedCount === totalCount) {
          this.statusTarget.innerHTML = `
            <div class="flex items-center gap-2 text-green-600">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
              </svg>
              <span class="text-xs font-medium">${cachedCount}/${totalCount} cached (${cacheSize} MB)</span>
            </div>
          `
        } else {
          this.statusTarget.innerHTML = `
            <div class="flex items-center gap-2 text-blue-600">
              <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 16v1a3 3 0 003 3h10a3 3 0 003-3v-1m-4-4l-4 4m0 0l-4-4m4 4V4" />
              </svg>
              <span class="text-xs font-medium">${cachedCount}/${totalCount} cached (${cacheSize} MB)</span>
            </div>
          `
        }
      }
    } catch (error) {
      console.error('Failed to update status:', error)
    }
  }

  // Update progress during prefetch
  updateProgress(progress) {
    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `Caching videos: ${progress.current}/${progress.total} (${progress.progress}%)`
    }
    
    console.log('📊 Prefetch progress:', progress)
  }

  // Show prefetching state
  showPrefetching() {
    if (this.hasStatusTarget) {
      this.statusTarget.innerHTML = `
        <div class="flex items-center gap-2 text-blue-600 animate-pulse">
          <svg class="w-4 h-4 animate-spin" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 4v5h.582m15.356 2A8.001 8.001 0 004.582 9m0 0H9m11 11v-5h-.581m0 0a8.003 8.003 0 01-15.357-2m15.357 2H15" />
          </svg>
          <span class="text-xs font-medium">Caching videos...</span>
        </div>
      `
    }
  }

  // Show success message
  showSuccess(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.innerHTML = `
        <div class="flex items-center gap-2 text-green-600">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span class="text-xs font-medium">${message}</span>
        </div>
      `
    }
  }

  // Show warning message
  showWarning(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.innerHTML = `
        <div class="flex items-center gap-2 text-yellow-600">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
          <span class="text-xs font-medium">${message}</span>
        </div>
      `
    }
  }

  // Show error message
  showError(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.innerHTML = `
        <div class="flex items-center gap-2 text-red-600">
          <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span class="text-xs">${message}</span>
        </div>
      `
    }
  }

  // Show generic status
  showStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message
    }
  }
}