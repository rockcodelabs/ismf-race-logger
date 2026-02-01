// frozen_string_literal: true

// ChunkedUploadService
//
// Service for uploading large video files in chunks with parallel upload support.
// Provides better reliability on mobile/unstable connections with automatic retry.
//
// Features:
// - Splits large files into configurable chunks (default 10MB)
// - Parallel chunk uploads (configurable concurrency)
// - Automatic retry on chunk failure
// - Progress tracking per chunk and overall
// - Resumable uploads (future enhancement)
//
// Usage:
//   const service = new ChunkedUploadService({
//     file: videoFile,
//     chunkSize: 10 * 1024 * 1024, // 10MB
//     maxParallelChunks: 3,
//     onProgress: (progress) => console.log(progress),
//     onChunkComplete: (chunkIndex) => console.log(`Chunk ${chunkIndex} done`),
//     onComplete: (blobId) => console.log(`Upload complete: ${blobId}`),
//     onError: (error) => console.error(error)
//   })
//
//   await service.start()
//
export default class ChunkedUploadService {
  constructor(options) {
    this.file = options.file
    this.chunkSize = options.chunkSize || 10 * 1024 * 1024 // 10MB default
    this.maxParallelChunks = options.maxParallelChunks || 3
    this.maxRetries = options.maxRetries || 3
    
    // Callbacks
    this.onProgress = options.onProgress || (() => {})
    this.onChunkComplete = options.onChunkComplete || (() => {})
    this.onComplete = options.onComplete || (() => {})
    this.onError = options.onError || (() => {})
    
    // API endpoints
    this.initiateUrl = '/admin/chunked_uploads/initiate'
    this.chunkUrl = '/admin/chunked_uploads/chunk'
    this.finalizeUrl = '/admin/chunked_uploads/finalize'
    
    // State
    this.uploadId = null
    this.chunks = []
    this.completedChunks = new Set()
    this.failedChunks = new Map() // chunkIndex -> retryCount
    this.cancelled = false
    this.uploadStartTime = null
    this.totalBytesUploaded = 0
  }
  
  // Start the chunked upload process
  async start() {
    try {
      this.uploadStartTime = Date.now()
      
      // Step 1: Initiate upload session
      await this.initiate()
      
      // Step 2: Split file into chunks
      this.createChunks()
      
      // Step 3: Upload chunks in parallel
      await this.uploadChunks()
      
      // Step 4: Finalize and assemble chunks
      const result = await this.finalize()
      
      this.onComplete(result.blob_id, result)
      return result
      
    } catch (error) {
      this.onError(error)
      throw error
    }
  }
  
  // Cancel the upload
  cancel() {
    this.cancelled = true
  }
  
  // Step 1: Initiate upload session on server
  async initiate() {
    const totalChunks = Math.ceil(this.file.size / this.chunkSize)
    
    const response = await fetch(this.initiateUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken()
      },
      body: JSON.stringify({
        filename: this.file.name,
        content_type: this.file.type,
        total_size: this.file.size,
        total_chunks: totalChunks
      })
    })
    
    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || 'Failed to initiate upload')
    }
    
    const data = await response.json()
    this.uploadId = data.upload_id
    
    return data
  }
  
  // Step 2: Create chunk metadata
  createChunks() {
    const totalChunks = Math.ceil(this.file.size / this.chunkSize)
    
    for (let i = 0; i < totalChunks; i++) {
      const start = i * this.chunkSize
      const end = Math.min(start + this.chunkSize, this.file.size)
      
      this.chunks.push({
        index: i,
        start: start,
        end: end,
        size: end - start,
        blob: this.file.slice(start, end)
      })
    }
  }
  
  // Step 3: Upload chunks with parallel support
  async uploadChunks() {
    const chunkQueue = [...this.chunks]
    const activeUploads = []
    
    while (chunkQueue.length > 0 || activeUploads.length > 0) {
      if (this.cancelled) {
        throw new Error('Upload cancelled')
      }
      
      // Start new uploads up to max parallel limit
      while (activeUploads.length < this.maxParallelChunks && chunkQueue.length > 0) {
        const chunk = chunkQueue.shift()
        const uploadPromise = this.uploadChunk(chunk)
          .then(() => {
            // Remove from active uploads when done
            const index = activeUploads.indexOf(uploadPromise)
            if (index > -1) activeUploads.splice(index, 1)
          })
          .catch(error => {
            // Handle retry logic
            const retryCount = this.failedChunks.get(chunk.index) || 0
            
            if (retryCount < this.maxRetries) {
              console.warn(`Chunk ${chunk.index} failed, retrying (${retryCount + 1}/${this.maxRetries})`)
              this.failedChunks.set(chunk.index, retryCount + 1)
              chunkQueue.push(chunk) // Re-queue for retry
            } else {
              console.error(`Chunk ${chunk.index} failed after ${this.maxRetries} retries`)
              throw error
            }
            
            // Remove from active uploads
            const index = activeUploads.indexOf(uploadPromise)
            if (index > -1) activeUploads.splice(index, 1)
          })
        
        activeUploads.push(uploadPromise)
      }
      
      // Wait for at least one upload to complete
      if (activeUploads.length > 0) {
        await Promise.race(activeUploads)
      }
    }
  }
  
  // Upload a single chunk
  async uploadChunk(chunk) {
    const formData = new FormData()
    formData.append('upload_id', this.uploadId)
    formData.append('chunk_index', chunk.index)
    formData.append('chunk', chunk.blob, `chunk_${chunk.index}`)
    
    const response = await fetch(this.chunkUrl, {
      method: 'POST',
      headers: {
        'X-CSRF-Token': this.csrfToken()
      },
      body: formData
    })
    
    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || `Failed to upload chunk ${chunk.index}`)
    }
    
    const data = await response.json()
    
    // Mark chunk as complete
    this.completedChunks.add(chunk.index)
    this.totalBytesUploaded += chunk.size
    
    // Calculate overall progress
    const progress = Math.round((this.totalBytesUploaded / this.file.size) * 100)
    const elapsed = Date.now() - this.uploadStartTime
    const speed = this.totalBytesUploaded / (elapsed / 1000) // bytes per second
    const remaining = this.file.size - this.totalBytesUploaded
    const eta = speed > 0 ? Math.ceil(remaining / speed) : 0
    
    this.onProgress({
      progress: progress,
      completed: this.completedChunks.size,
      total: this.chunks.length,
      speed: speed,
      eta: eta,
      bytesUploaded: this.totalBytesUploaded,
      totalBytes: this.file.size
    })
    
    this.onChunkComplete(chunk.index, data)
    
    return data
  }
  
  // Step 4: Finalize upload (assemble chunks on server)
  async finalize() {
    const response = await fetch(this.finalizeUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': this.csrfToken()
      },
      body: JSON.stringify({
        upload_id: this.uploadId
      })
    })
    
    if (!response.ok) {
      const error = await response.json()
      throw new Error(error.error || 'Failed to finalize upload')
    }
    
    return await response.json()
  }
  
  // Get CSRF token from meta tag
  csrfToken() {
    const token = document.querySelector('meta[name="csrf-token"]')
    return token ? token.content : ''
  }
  
  // Helper: Format bytes to human-readable size
  static formatBytes(bytes) {
    if (bytes === 0) return '0 B'
    const k = 1024
    const sizes = ['B', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return parseFloat((bytes / Math.pow(k, i)).toFixed(2)) + ' ' + sizes[i]
  }
  
  // Helper: Format speed (bytes/sec to MB/s)
  static formatSpeed(bytesPerSecond) {
    const mbps = bytesPerSecond / (1024 * 1024)
    return mbps.toFixed(2) + ' MB/s'
  }
}