// frozen_string_literal: true

// VideoCacheService
//
// Service for caching video blobs in IndexedDB for offline playback and instant loading.
// Uses race-scoped storage - only caches videos for the current race.
//
// Features:
// - IndexedDB-based blob storage
// - Race-scoped caching (one race at a time)
// - Automatic cache invalidation when switching races
// - Cache size tracking and management
// - Background prefetching support
//
// Usage:
//   const cache = new VideoCacheService()
//   await cache.init(raceId)
//
//   // Cache a video
//   await cache.put(videoId, videoUrl, metadata)
//
//   // Get cached video
//   const blobUrl = await cache.get(videoId)
//
//   // Prefetch all videos for race
//   await cache.prefetchRaceVideos(raceId, videoUrls, onProgress)
//
export default class VideoCacheService {
  constructor() {
    this.dbName = 'ismf_video_cache'
    this.dbVersion = 1
    this.storeName = 'videos'
    this.db = null
    this.currentRaceId = null
  }

  // Initialize database and set current race
  async init(raceId) {
    this.currentRaceId = raceId
    
    return new Promise((resolve, reject) => {
      const request = indexedDB.open(this.dbName, this.dbVersion)
      
      request.onerror = () => {
        console.error('Failed to open IndexedDB:', request.error)
        reject(request.error)
      }
      
      request.onsuccess = () => {
        this.db = request.result
        console.log('✅ VideoCacheService initialized for race', raceId)
        resolve(this.db)
      }
      
      request.onupgradeneeded = (event) => {
        const db = event.target.result
        
        // Create object store if it doesn't exist
        if (!db.objectStoreNames.contains(this.storeName)) {
          const objectStore = db.createObjectStore(this.storeName, { keyPath: 'id' })
          
          // Indexes for efficient querying
          objectStore.createIndex('race_id', 'race_id', { unique: false })
          objectStore.createIndex('video_id', 'video_id', { unique: false })
          objectStore.createIndex('cached_at', 'cached_at', { unique: false })
          
          console.log('✅ Created video cache object store')
        }
      }
    })
  }

  // Put video blob in cache
  async put(videoId, videoUrl, metadata = {}) {
    if (!this.db) {
      throw new Error('VideoCacheService not initialized')
    }

    try {
      // Fetch video blob
      console.log(`📥 Downloading video ${videoId} for caching...`)
      const response = await fetch(videoUrl)
      
      if (!response.ok) {
        throw new Error(`Failed to fetch video: ${response.statusText}`)
      }
      
      const blob = await response.blob()
      const size = blob.size
      
      console.log(`💾 Caching video ${videoId} (${(size / 1024 / 1024).toFixed(2)} MB)`)
      
      // Store in IndexedDB
      const record = {
        id: `${this.currentRaceId}_${videoId}`,
        race_id: this.currentRaceId,
        video_id: videoId,
        blob: blob,
        url: videoUrl,
        size: size,
        content_type: blob.type,
        cached_at: new Date().toISOString(),
        metadata: metadata
      }
      
      await this.putRecord(record)
      
      console.log(`✅ Video ${videoId} cached successfully`)
      return record
      
    } catch (error) {
      console.error(`❌ Failed to cache video ${videoId}:`, error)
      throw error
    }
  }

  // Get video from cache
  async get(videoId) {
    if (!this.db) {
      throw new Error('VideoCacheService not initialized')
    }

    try {
      const recordId = `${this.currentRaceId}_${videoId}`
      const record = await this.getRecord(recordId)
      
      if (!record) {
        console.log(`❌ Video ${videoId} not in cache`)
        return null
      }
      
      // Create blob URL
      const blobUrl = URL.createObjectURL(record.blob)
      console.log(`✅ Video ${videoId} loaded from cache`)
      
      return {
        blobUrl: blobUrl,
        size: record.size,
        cachedAt: record.cached_at,
        metadata: record.metadata
      }
      
    } catch (error) {
      console.error(`❌ Failed to get video ${videoId} from cache:`, error)
      return null
    }
  }

  // Check if video is cached
  async has(videoId) {
    if (!this.db) {
      throw new Error('VideoCacheService not initialized')
    }

    try {
      const recordId = `${this.currentRaceId}_${videoId}`
      const record = await this.getRecord(recordId)
      return record !== null
    } catch (error) {
      console.error(`Failed to check cache for video ${videoId}:`, error)
      return false
    }
  }

  // Delete video from cache
  async delete(videoId) {
    if (!this.db) {
      throw new Error('VideoCacheService not initialized')
    }

    try {
      const recordId = `${this.currentRaceId}_${videoId}`
      await this.deleteRecord(recordId)
      console.log(`🗑️ Deleted video ${videoId} from cache`)
    } catch (error) {
      console.error(`Failed to delete video ${videoId} from cache:`, error)
      throw error
    }
  }

  // Get all cached videos for current race
  async getAllForRace() {
    if (!this.db) {
      throw new Error('VideoCacheService not initialized')
    }

    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([this.storeName], 'readonly')
      const objectStore = transaction.objectStore(this.storeName)
      const index = objectStore.index('race_id')
      const request = index.getAll(this.currentRaceId)
      
      request.onsuccess = () => {
        resolve(request.result)
      }
      
      request.onerror = () => {
        reject(request.error)
      }
    })
  }

  // Get cache statistics for current race
  async getStats() {
    try {
      const records = await this.getAllForRace()
      const totalSize = records.reduce((sum, r) => sum + r.size, 0)
      
      return {
        race_id: this.currentRaceId,
        video_count: records.length,
        total_size: totalSize,
        total_size_mb: (totalSize / 1024 / 1024).toFixed(2),
        videos: records.map(r => ({
          video_id: r.video_id,
          size: r.size,
          size_mb: (r.size / 1024 / 1024).toFixed(2),
          cached_at: r.cached_at
        }))
      }
    } catch (error) {
      console.error('Failed to get cache stats:', error)
      return {
        race_id: this.currentRaceId,
        video_count: 0,
        total_size: 0,
        total_size_mb: '0.00',
        videos: []
      }
    }
  }

  // Clear cache for current race
  async clearRace() {
    if (!this.db) {
      throw new Error('VideoCacheService not initialized')
    }

    try {
      const records = await this.getAllForRace()
      
      for (const record of records) {
        await this.deleteRecord(record.id)
      }
      
      console.log(`🗑️ Cleared cache for race ${this.currentRaceId} (${records.length} videos)`)
      return records.length
      
    } catch (error) {
      console.error('Failed to clear race cache:', error)
      throw error
    }
  }

  // Clear all caches (all races)
  async clearAll() {
    if (!this.db) {
      throw new Error('VideoCacheService not initialized')
    }

    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([this.storeName], 'readwrite')
      const objectStore = transaction.objectStore(this.storeName)
      const request = objectStore.clear()
      
      request.onsuccess = () => {
        console.log('🗑️ Cleared all video caches')
        resolve()
      }
      
      request.onerror = () => {
        reject(request.error)
      }
    })
  }

  // Prefetch multiple videos for current race in background
  async prefetchRaceVideos(videoList, onProgress = null) {
    if (!this.db) {
      throw new Error('VideoCacheService not initialized')
    }

    console.log(`📦 Prefetching ${videoList.length} videos for race ${this.currentRaceId}`)
    
    const results = {
      total: videoList.length,
      cached: 0,
      skipped: 0,
      failed: 0,
      errors: []
    }

    for (let i = 0; i < videoList.length; i++) {
      const video = videoList[i]
      
      try {
        // Check if already cached
        const isCached = await this.has(video.id)
        
        if (isCached) {
          console.log(`⏭️ Video ${video.id} already cached, skipping`)
          results.skipped++
        } else {
          // Download and cache
          await this.put(video.id, video.url, video.metadata || {})
          results.cached++
        }
        
        // Report progress
        if (onProgress) {
          onProgress({
            current: i + 1,
            total: videoList.length,
            progress: Math.round(((i + 1) / videoList.length) * 100),
            cached: results.cached,
            skipped: results.skipped,
            failed: results.failed
          })
        }
        
      } catch (error) {
        console.error(`Failed to prefetch video ${video.id}:`, error)
        results.failed++
        results.errors.push({
          video_id: video.id,
          error: error.message
        })
      }
    }

    console.log(`✅ Prefetch complete:`, results)
    return results
  }

  // Low-level: Put record in IndexedDB
  putRecord(record) {
    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([this.storeName], 'readwrite')
      const objectStore = transaction.objectStore(this.storeName)
      const request = objectStore.put(record)
      
      request.onsuccess = () => {
        resolve(request.result)
      }
      
      request.onerror = () => {
        reject(request.error)
      }
    })
  }

  // Low-level: Get record from IndexedDB
  getRecord(id) {
    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([this.storeName], 'readonly')
      const objectStore = transaction.objectStore(this.storeName)
      const request = objectStore.get(id)
      
      request.onsuccess = () => {
        resolve(request.result || null)
      }
      
      request.onerror = () => {
        reject(request.error)
      }
    })
  }

  // Low-level: Delete record from IndexedDB
  deleteRecord(id) {
    return new Promise((resolve, reject) => {
      const transaction = this.db.transaction([this.storeName], 'readwrite')
      const objectStore = transaction.objectStore(this.storeName)
      const request = objectStore.delete(id)
      
      request.onsuccess = () => {
        resolve()
      }
      
      request.onerror = () => {
        reject(request.error)
      }
    })
  }

  // Clean up blob URLs to prevent memory leaks
  static revokeObjectURL(blobUrl) {
    if (blobUrl && blobUrl.startsWith('blob:')) {
      URL.revokeObjectURL(blobUrl)
    }
  }

  // Check if IndexedDB is supported
  static isSupported() {
    return 'indexedDB' in window
  }

  // Get estimated storage quota and usage
  static async getStorageEstimate() {
    if ('storage' in navigator && 'estimate' in navigator.storage) {
      const estimate = await navigator.storage.estimate()
      return {
        quota: estimate.quota,
        usage: estimate.usage,
        quota_mb: (estimate.quota / 1024 / 1024).toFixed(2),
        usage_mb: (estimate.usage / 1024 / 1024).toFixed(2),
        available_mb: ((estimate.quota - estimate.usage) / 1024 / 1024).toFixed(2),
        percent_used: ((estimate.usage / estimate.quota) * 100).toFixed(2)
      }
    }
    return null
  }
}