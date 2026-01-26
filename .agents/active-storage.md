# Active Storage Patterns (37signals Style)

Reference guide for file uploads, storage configuration, and video handling. Optimized for local NAS storage with cloud backup options.

---

## Storage Configuration

### Local NAS Storage (Primary)

Configure Active Storage to use your local NAS for fast reads and writes:

```yaml
# config/storage.yml

# Development - local disk
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>

# Production - NAS mount
nas:
  service: Disk
  root: /mnt/nas/ismf-race-logger/storage
  public: false

# Optional: Mirror to cloud for backup
mirror:
  service: Mirror
  primary: nas
  mirrors: [s3_backup]

# S3-compatible backup (MinIO, Backblaze, etc.)
s3_backup:
  service: S3
  bucket: ismf-race-logger-backups
  access_key_id: <%= Rails.application.credentials.dig(:s3, :access_key_id) %>
  secret_access_key: <%= Rails.application.credentials.dig(:s3, :secret_access_key) %>
  region: us-east-1
  endpoint: https://s3.example.com
  force_path_style: true                        # Required for MinIO, Pure Storage, etc.
  request_checksum_calculation: when_required   # For non-AWS S3-compatible services
```

```ruby
# config/environments/production.rb
config.active_storage.service = :nas
# Or use mirror for redundancy:
# config.active_storage.service = :mirror
```

### NAS Mount Setup

Ensure the NAS is mounted before Rails starts:

```bash
# /etc/fstab entry (example for NFS)
nas.local:/volume1/rails-storage /mnt/nas/ismf-race-logger/storage nfs defaults,_netdev 0 0

# Or for SMB/CIFS
//nas.local/rails-storage /mnt/nas/ismf-race-logger/storage cifs credentials=/etc/nas-credentials,uid=1000,gid=1000 0 0
```

```ruby
# config/initializers/active_storage.rb
# Verify NAS mount on boot (optional safety check)
if Rails.env.production?
  nas_path = Pathname.new("/mnt/nas/ismf-race-logger/storage")
  unless nas_path.exist? && nas_path.writable?
    Rails.logger.error "NAS storage not mounted or not writable!"
    # Optionally: fail fast
    # raise "NAS storage unavailable"
  end
end
```

---

## Video Attachments

### Model Configuration

```ruby
# app/models/report.rb
class Report < ApplicationRecord
  # Multiple videos per report
  has_many_attached :videos do |attachable|
    # Preprocessed variants for consistent sizing
    attachable.variant :thumbnail,
      resize_to_limit: [320, 180],
      format: :webp,
      preprocessed: true

    attachable.variant :preview,
      resize_to_limit: [640, 360],
      format: :webp,
      preprocessed: true
  end

  # Video validation
  validate :validate_videos

  # Maximum file size (100MB per video)
  MAX_VIDEO_SIZE = 100.megabytes

  # Maximum video duration (5 minutes)
  MAX_VIDEO_DURATION = 5.minutes

  # Allowed content types
  ALLOWED_VIDEO_TYPES = %w[
    video/mp4
    video/webm
    video/quicktime
    video/x-m4v
  ].freeze

  private

  def validate_videos
    videos.each do |video|
      validate_video_size(video)
      validate_video_type(video)
      validate_video_duration(video)
    end
  end

  def validate_video_size(video)
    return unless video.blob.byte_size > MAX_VIDEO_SIZE

    errors.add(:videos, "must be less than #{MAX_VIDEO_SIZE / 1.megabyte}MB each")
    video.purge_later
  end

  def validate_video_type(video)
    return if ALLOWED_VIDEO_TYPES.include?(video.blob.content_type)

    errors.add(:videos, "must be MP4, WebM, or MOV format")
    video.purge_later
  end

  def validate_video_duration(video)
    duration = video_duration(video)
    return if duration.nil? || duration <= MAX_VIDEO_DURATION

    errors.add(:videos, "must be #{MAX_VIDEO_DURATION.to_i / 60} minutes or less")
    video.purge_later
  end

  def video_duration(video)
    return nil unless video.blob.metadata[:duration]
    video.blob.metadata[:duration].seconds
  end
end
```

### Video Metadata Analysis

Active Storage uses FFprobe to analyze video metadata. Ensure it's available:

```dockerfile
# Dockerfile
RUN apt-get update && apt-get install -y ffmpeg
```

```ruby
# config/initializers/active_storage.rb
# Configure video analyzer
Rails.application.config.active_storage.analyzers = [
  ActiveStorage::Analyzer::VideoAnalyzer,
  ActiveStorage::Analyzer::ImageAnalyzer,
  ActiveStorage::Analyzer::AudioAnalyzer
]

# Ensure metadata is extracted on upload
Rails.application.config.active_storage.track_variants = true
```

### Custom Video Analyzer (Enhanced Duration Check)

```ruby
# app/analyzers/video_duration_analyzer.rb
class VideoDurationAnalyzer < ActiveStorage::Analyzer::VideoAnalyzer
  def metadata
    super.merge(analyzed_at: Time.current)
  end

  # Override to add custom duration validation
  def duration
    # FFprobe returns duration in seconds
    probe[:duration]&.to_f
  end

  private

  def probe
    @probe ||= begin
      download_blob_to_tempfile do |file|
        probe_from(file)
      end
    end
  end

  def probe_from(file)
    IO.popen([ffprobe_path, "-show_format", "-v", "quiet", "-print_format", "json", file.path]) do |io|
      JSON.parse(io.read).dig("format") || {}
    end
  rescue
    {}
  end

  def ffprobe_path
    ActiveStorage.paths[:ffprobe] || "ffprobe"
  end
end
```

---

## Video Size & Duration Validation Concern

Extract validation logic into a reusable concern:

```ruby
# app/models/concerns/video_validatable.rb
module VideoValidatable
  extend ActiveSupport::Concern

  included do
    class_attribute :video_max_size, default: 100.megabytes
    class_attribute :video_max_duration, default: 5.minutes
    class_attribute :video_allowed_types, default: %w[video/mp4 video/webm video/quicktime]
  end

  class_methods do
    def validates_videos(attribute, max_size: nil, max_duration: nil, types: nil)
      validate do
        send(attribute).each do |video|
          next unless video.attached?

          validate_video_attachment(
            video,
            max_size: max_size || video_max_size,
            max_duration: max_duration || video_max_duration,
            types: types || video_allowed_types
          )
        end
      end
    end
  end

  private

  def validate_video_attachment(video, max_size:, max_duration:, types:)
    blob = video.blob

    # Size validation
    if blob.byte_size > max_size
      errors.add(:base, "Video '#{blob.filename}' exceeds maximum size of #{max_size / 1.megabyte}MB")
    end

    # Type validation
    unless types.include?(blob.content_type)
      errors.add(:base, "Video '#{blob.filename}' must be #{types.map { |t| t.split('/').last.upcase }.join(', ')} format")
    end

    # Duration validation (requires metadata)
    if blob.metadata[:duration] && blob.metadata[:duration] > max_duration
      errors.add(:base, "Video '#{blob.filename}' exceeds maximum duration of #{max_duration.to_i / 60} minutes")
    end
  end
end
```

Usage:

```ruby
class Report < ApplicationRecord
  include VideoValidatable

  has_many_attached :videos

  # Use defaults (100MB, 5 min)
  validates_videos :videos

  # Or customize
  validates_videos :videos,
    max_size: 200.megabytes,
    max_duration: 10.minutes,
    types: %w[video/mp4]
end
```

---

## Direct Upload Configuration

### Extended URL Expiry

For slow connections or CDN buffering (like Cloudflare):

```ruby
# config/initializers/active_storage.rb
module ActiveStorage
  # Extend direct upload URL expiry from 5 min to 48 hours
  mattr_accessor :service_urls_for_direct_uploads_expire_in, default: 48.hours
end

# Monkey-patch Blob to use extended expiry
ActiveSupport.on_load(:active_storage_blob) do
  ActiveStorage::Blob.class_eval do
    def service_url_for_direct_upload(expires_in: ActiveStorage.service_urls_for_direct_uploads_expire_in)
      service.url_for_direct_upload(
        key,
        expires_in: expires_in,
        content_type: content_type,
        content_length: byte_size,
        checksum: checksum,
        custom_metadata: custom_metadata
      )
    end
  end
end
```

### JavaScript Upload with Progress

```javascript
// app/javascript/controllers/upload_controller.js
import { Controller } from "@hotwired/stimulus"
import { DirectUpload } from "@rails/activestorage"

export default class extends Controller {
  static targets = ["input", "progress", "progressBar"]
  static values = { url: String }

  upload(event) {
    const files = event.target.files
    Array.from(files).forEach(file => this.#uploadFile(file))
  }

  #uploadFile(file) {
    const upload = new DirectUpload(file, this.urlValue, this)
    
    upload.create((error, blob) => {
      if (error) {
        this.#handleError(error)
      } else {
        this.#handleSuccess(blob)
      }
    })
  }

  // DirectUpload callbacks
  directUploadWillStoreFileWithXHR(request) {
    request.upload.addEventListener("progress", event => {
      const progress = (event.loaded / event.total) * 100
      this.#updateProgress(progress)
    })
  }

  #updateProgress(progress) {
    if (this.hasProgressBarTarget) {
      this.progressBarTarget.style.width = `${progress}%`
    }
    if (this.hasProgressTarget) {
      this.progressTarget.textContent = `${Math.round(progress)}%`
    }
  }

  #handleSuccess(blob) {
    this.dispatch("uploaded", { detail: { signedId: blob.signed_id, filename: blob.filename } })
  }

  #handleError(error) {
    console.error("Upload failed:", error)
    this.dispatch("error", { detail: { message: error.message } })
  }
}
```

---

## Large File Handling

### Skip Previews for Large Videos

```ruby
# config/initializers/active_storage.rb
module ActiveStorageBlobPreviewable
  MAX_PREVIEWABLE_SIZE = 50.megabytes

  def previewable?
    super && byte_size <= MAX_PREVIEWABLE_SIZE
  end
end

ActiveSupport.on_load(:active_storage_blob) do
  ActiveStorage::Blob.prepend(ActiveStorageBlobPreviewable)
end
```

### Streaming Large Videos

Redirect to blob URL instead of streaming through Rails:

```ruby
# app/controllers/videos_controller.rb
class VideosController < ApplicationController
  def show
    video = ActiveStorage::Blob.find_signed!(params[:signed_id])
    
    # Redirect to direct URL (faster, doesn't tie up Rails workers)
    redirect_to video.url(disposition: :inline), allow_other_host: true
  end
end
```

---

## Variant Configuration

### Preprocessed Variants (Required for Read Replicas)

```ruby
has_one_attached :video do |attachable|
  # Always preprocess - lazy generation fails on read-only replicas
  attachable.variant :poster,
    resize_to_limit: [1280, 720],
    format: :webp,
    preprocessed: true
end
```

### Centralized Variant Definitions

```ruby
# app/models/concerns/video_variants.rb
module VideoVariants
  extend ActiveSupport::Concern

  VARIANTS = {
    thumbnail: {
      resize_to_limit: [320, 180],
      format: :webp
    },
    preview: {
      resize_to_limit: [640, 360],
      format: :webp
    },
    poster: {
      resize_to_limit: [1280, 720],
      format: :webp
    }
  }.freeze

  included do
    has_many_attached :videos do |attachable|
      VARIANTS.each do |name, options|
        attachable.variant name, **options, preprocessed: true
      end
    end
  end
end
```

---

## Cleanup & Maintenance

### Purge Orphaned Blobs

```ruby
# lib/tasks/storage.rake
namespace :storage do
  desc "Purge orphaned blobs older than 7 days"
  task purge_orphans: :environment do
    ActiveStorage::Blob
      .unattached
      .where("created_at < ?", 7.days.ago)
      .find_each(&:purge_later)
  end

  desc "Check NAS storage health"
  task check_health: :environment do
    path = Pathname.new(Rails.configuration.active_storage.service_configurations.dig("nas", "root"))
    
    puts "NAS Path: #{path}"
    puts "Exists: #{path.exist?}"
    puts "Writable: #{path.writable?}"
    
    if path.exist?
      total = `df -h #{path} | tail -1 | awk '{print $2}'`.strip
      used = `df -h #{path} | tail -1 | awk '{print $3}'`.strip
      avail = `df -h #{path} | tail -1 | awk '{print $4}'`.strip
      puts "Total: #{total}, Used: #{used}, Available: #{avail}"
    end
  end
end
```

### Background Jobs for Processing

```ruby
# app/jobs/analyze_video_job.rb
class AnalyzeVideoJob < ApplicationJob
  queue_as :default

  def perform(blob_id)
    blob = ActiveStorage::Blob.find(blob_id)
    blob.analyze unless blob.analyzed?
  end
end
```

---

## Security

### Signed URLs

Always use signed URLs for private files:

```ruby
# Good - signed URL expires
video.url(expires_in: 1.hour, disposition: :inline)

# Bad - permanent URL
video.url
```

### Content-Type Validation

```ruby
# config/initializers/active_storage.rb
Rails.application.config.active_storage.content_types_to_serve_as_binary = [
  "text/html",
  "text/javascript",
  "text/css"
]

Rails.application.config.active_storage.content_types_allowed_inline = [
  "video/mp4",
  "video/webm",
  "video/quicktime",
  "image/png",
  "image/jpeg",
  "image/webp",
  "image/gif"
]
```

---

## Quick Reference

### Common Commands

```ruby
# Attach video
report.videos.attach(io: file, filename: "race.mp4", content_type: "video/mp4")

# Check if analyzed
report.videos.first.blob.analyzed?

# Get duration (after analysis)
report.videos.first.blob.metadata[:duration]

# Get file size
report.videos.first.blob.byte_size

# Purge specific video
report.videos.find(id).purge

# Purge all videos
report.videos.purge
```

### Validation Cheat Sheet

| Validation | Method | Value |
|------------|--------|-------|
| Max file size | `blob.byte_size` | 100.megabytes |
| Max duration | `blob.metadata[:duration]` | 300 (seconds) |
| Content type | `blob.content_type` | video/mp4 |
| Filename | `blob.filename` | *.mp4, *.webm |

---

## Resources

- [Active Storage Guide](https://guides.rubyonrails.org/active_storage_overview.html)
- [Direct Uploads](https://guides.rubyonrails.org/active_storage_overview.html#direct-uploads)
- [FFmpeg Documentation](https://ffmpeg.org/documentation.html)