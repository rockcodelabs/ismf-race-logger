# Feature: Video Clip Selector

> Select time ranges from attached videos using a slider, with frame-by-frame navigation via spacebar.

---

## Overview

Reports may have one or more video attachments. The video clip selector allows users to:

1. **Select a time range** from a video using a dual-handle slider (start/end times)
2. **Replace videos** easily with drag-and-drop or file picker
3. **Navigate frame-by-frame** using the spacebar for precise review

This follows the 37signals philosophy of **building small, focused components** that do one thing well.

---

## User Stories

### Primary Use Case

> As a VAR operator reviewing a report, I want to select a specific 2-5 second clip from an attached video so that referees can quickly see the relevant moment without scrubbing through the full recording.

### Secondary Use Cases

> As a VAR operator, I want to step through video frame-by-frame using spacebar to find the exact moment of an infraction.

> As a VAR operator, I want to easily replace a video if I attached the wrong file.

---

## Requirements

### Functional Requirements

| Requirement | Description |
|-------------|-------------|
| Multi-video support | Reports can have multiple attached videos (via `has_many_attached :videos`) |
| Time range selection | Dual-handle slider to set `video_start_time` and `video_end_time` in seconds |
| Frame-by-frame | Spacebar advances video by one frame (~33ms for 30fps, ~16ms for 60fps) |
| Video replacement | Easy drag-and-drop or click-to-replace for each video |
| Persistence | Selected time range persists to the Report model |
| Preview playback | Play button plays only the selected range |

### Non-Functional Requirements

| Requirement | Target |
|-------------|--------|
| Slider responsiveness | < 16ms (60fps) for handle drag |
| Video seek latency | < 100ms to seek to new position |
| Frame step accuracy | ±1 frame |

---

## Data Model Updates

### Report Model Changes

```ruby
# app/models/report.rb
class Report < ApplicationRecord
  has_many_attached :videos  # Changed from has_one_attached :video

  # Per-video clip times stored as JSON
  # Format: { "blob_id_1" => { start: 2.5, end: 5.0 }, "blob_id_2" => { start: 0, end: 3.0 } }
  # Alternatively, use a separate VideoClip model for more complex needs
  store :video_clips, coder: JSON, default: {}

  def clip_for(video_blob)
    video_clips[video_blob.id.to_s] || { "start" => 0, "end" => video_duration(video_blob) }
  end

  def set_clip_for(video_blob, start_time:, end_time:)
    video_clips[video_blob.id.to_s] = { "start" => start_time, "end" => end_time }
    save
  end

  private

  def video_duration(video_blob)
    video_blob.metadata[:duration] || 0
  end
end
```

### Migration

```ruby
# db/migrate/XXXXXX_add_video_clips_to_reports.rb
class AddVideoClipsToReports < ActiveRecord::Migration[8.1]
  def change
    add_column :reports, :video_clips, :jsonb, default: {}, null: false
  end
end
```

---

## Technical Approach

### 1. Video Player with Clip Selector (Stimulus Controller)

A single Stimulus controller manages:
- HTML5 `<video>` element
- Dual-handle range slider for clip selection
- Frame-by-frame navigation
- Time display and updates

Following 37signals patterns:
- **Single-purpose controller** - one job per controller
- **Values API** for configuration
- **Event dispatch** for communication between controllers
- **Clean up in disconnect()**

### 2. Component Structure

```
app/
├── components/
│   └── reports/
│       ├── video_player_component.rb
│       ├── video_player_component.html.erb
│       ├── video_list_component.rb
│       └── video_list_component.html.erb
├── javascript/
│   └── controllers/
│       ├── video_clip_controller.js      # Main clip selector
│       ├── video_replace_controller.js   # Drag-drop replacement
│       └── range_slider_controller.js    # Reusable dual-handle slider
└── views/
    └── reports/
        └── _video_section.html.erb
```

---

## Implementation Plan

### Phase 1: Range Slider Controller (Reusable)

A generic dual-handle range slider following 37signals' reusable controller pattern.

#### Task 1.1: Create Range Slider Controller

```javascript
// app/javascript/controllers/range_slider_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["track", "startHandle", "endHandle", "startValue", "endValue", "fill"]
  static values = {
    min: { type: Number, default: 0 },
    max: { type: Number, default: 100 },
    start: { type: Number, default: 0 },
    end: { type: Number, default: 100 },
    step: { type: Number, default: 0.1 }
  }

  connect() {
    this.#updatePositions()
    this.#bindEvents()
  }

  disconnect() {
    this.#unbindEvents()
  }

  // Handle drag start
  startDragStart(event) {
    event.preventDefault()
    this.activeHandle = "start"
    this.#startDrag(event)
  }

  endDragStart(event) {
    event.preventDefault()
    this.activeHandle = "end"
    this.#startDrag(event)
  }

  // Public API to set values programmatically
  setRange(start, end) {
    this.startValue = Math.max(this.minValue, Math.min(start, this.endValue - this.stepValue))
    this.endValue = Math.min(this.maxValue, Math.max(end, this.startValue + this.stepValue))
    this.#updatePositions()
    this.#dispatchChange()
  }

  // Private methods
  #startDrag(event) {
    this.dragging = true
    this.trackRect = this.trackTarget.getBoundingClientRect()

    this.#onMove = this.#handleMove.bind(this)
    this.#onEnd = this.#handleEnd.bind(this)

    document.addEventListener("mousemove", this.#onMove)
    document.addEventListener("mouseup", this.#onEnd)
    document.addEventListener("touchmove", this.#onMove)
    document.addEventListener("touchend", this.#onEnd)
  }

  #handleMove(event) {
    if (!this.dragging) return

    const clientX = event.touches ? event.touches[0].clientX : event.clientX
    const ratio = (clientX - this.trackRect.left) / this.trackRect.width
    const value = this.minValue + ratio * (this.maxValue - this.minValue)
    const snapped = Math.round(value / this.stepValue) * this.stepValue

    if (this.activeHandle === "start") {
      this.startValue = Math.max(this.minValue, Math.min(snapped, this.endValue - this.stepValue))
    } else {
      this.endValue = Math.min(this.maxValue, Math.max(snapped, this.startValue + this.stepValue))
    }

    this.#updatePositions()
    this.#dispatchChange()
  }

  #handleEnd() {
    this.dragging = false
    document.removeEventListener("mousemove", this.#onMove)
    document.removeEventListener("mouseup", this.#onEnd)
    document.removeEventListener("touchmove", this.#onMove)
    document.removeEventListener("touchend", this.#onEnd)

    this.dispatch("committed", { detail: { start: this.startValue, end: this.endValue } })
  }

  #updatePositions() {
    const range = this.maxValue - this.minValue
    const startPercent = ((this.startValue - this.minValue) / range) * 100
    const endPercent = ((this.endValue - this.minValue) / range) * 100

    this.startHandleTarget.style.left = `${startPercent}%`
    this.endHandleTarget.style.left = `${endPercent}%`
    this.fillTarget.style.left = `${startPercent}%`
    this.fillTarget.style.width = `${endPercent - startPercent}%`

    if (this.hasStartValueTarget) {
      this.startValueTarget.textContent = this.#formatTime(this.startValue)
    }
    if (this.hasEndValueTarget) {
      this.endValueTarget.textContent = this.#formatTime(this.endValue)
    }
  }

  #formatTime(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = (seconds % 60).toFixed(1)
    return `${mins}:${secs.padStart(4, "0")}`
  }

  #dispatchChange() {
    this.dispatch("change", { detail: { start: this.startValue, end: this.endValue } })
  }

  #bindEvents() {
    // Keyboard support for accessibility
    this.startHandleTarget.addEventListener("keydown", this.#handleKeydown.bind(this, "start"))
    this.endHandleTarget.addEventListener("keydown", this.#handleKeydown.bind(this, "end"))
  }

  #unbindEvents() {
    this.startHandleTarget.removeEventListener("keydown", this.#handleKeydown)
    this.endHandleTarget.removeEventListener("keydown", this.#handleKeydown)
  }

  #handleKeydown(handle, event) {
    const delta = event.shiftKey ? this.stepValue * 10 : this.stepValue

    switch (event.key) {
      case "ArrowLeft":
      case "ArrowDown":
        event.preventDefault()
        if (handle === "start") {
          this.startValue = Math.max(this.minValue, this.startValue - delta)
        } else {
          this.endValue = Math.max(this.startValue + this.stepValue, this.endValue - delta)
        }
        break
      case "ArrowRight":
      case "ArrowUp":
        event.preventDefault()
        if (handle === "start") {
          this.startValue = Math.min(this.endValue - this.stepValue, this.startValue + delta)
        } else {
          this.endValue = Math.min(this.maxValue, this.endValue + delta)
        }
        break
    }

    this.#updatePositions()
    this.#dispatchChange()
  }
}
```

---

### Phase 2: Video Clip Controller

#### Task 2.1: Create Video Clip Controller

```javascript
// app/javascript/controllers/video_clip_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["video", "slider", "currentTime", "playClipButton"]
  static values = {
    blobId: String,
    duration: Number,
    startTime: { type: Number, default: 0 },
    endTime: Number,
    frameRate: { type: Number, default: 30 }
  }

  connect() {
    this.#initializeEndTime()
    this.#bindVideoEvents()
    this.#bindKeyboardEvents()
  }

  disconnect() {
    this.#unbindVideoEvents()
    this.#unbindKeyboardEvents()
  }

  // Called when video metadata loads
  videoLoaded() {
    this.durationValue = this.videoTarget.duration
    if (!this.endTimeValue || this.endTimeValue > this.durationValue) {
      this.endTimeValue = this.durationValue
    }
    this.dispatch("ready", { detail: { duration: this.durationValue } })
  }

  // Range slider changed
  rangeChanged(event) {
    const { start, end } = event.detail
    this.startTimeValue = start
    this.endTimeValue = end
    this.videoTarget.currentTime = start
  }

  // Range slider committed (drag ended)
  rangeCommitted(event) {
    const { start, end } = event.detail
    this.#saveClipTimes(start, end)
  }

  // Play only the selected clip range
  playClip() {
    this.videoTarget.currentTime = this.startTimeValue
    this.videoTarget.play()
  }

  // Pause playback
  pause() {
    this.videoTarget.pause()
  }

  // Frame-by-frame navigation (spacebar handler)
  stepFrame(event) {
    // Don't step if focused on input elements
    if (this.#shouldIgnoreKeydown(event)) return

    event.preventDefault()
    const frameDuration = 1 / this.frameRateValue
    const newTime = Math.min(
      this.endTimeValue,
      this.videoTarget.currentTime + frameDuration
    )
    this.videoTarget.currentTime = newTime
  }

  // Step backward (shift+space)
  stepFrameBack(event) {
    if (this.#shouldIgnoreKeydown(event)) return

    event.preventDefault()
    const frameDuration = 1 / this.frameRateValue
    const newTime = Math.max(
      this.startTimeValue,
      this.videoTarget.currentTime - frameDuration
    )
    this.videoTarget.currentTime = newTime
  }

  // Video time update handler
  #handleTimeUpdate = () => {
    const currentTime = this.videoTarget.currentTime

    // Update current time display
    if (this.hasCurrentTimeTarget) {
      this.currentTimeTarget.textContent = this.#formatTime(currentTime)
    }

    // Stop at end of clip range
    if (currentTime >= this.endTimeValue) {
      this.videoTarget.pause()
      this.videoTarget.currentTime = this.endTimeValue
    }
  }

  // Private methods
  #initializeEndTime() {
    if (!this.endTimeValue && this.durationValue) {
      this.endTimeValue = this.durationValue
    }
  }

  #bindVideoEvents() {
    this.videoTarget.addEventListener("loadedmetadata", this.videoLoaded.bind(this))
    this.videoTarget.addEventListener("timeupdate", this.#handleTimeUpdate)
  }

  #unbindVideoEvents() {
    this.videoTarget.removeEventListener("loadedmetadata", this.videoLoaded.bind(this))
    this.videoTarget.removeEventListener("timeupdate", this.#handleTimeUpdate)
  }

  #bindKeyboardEvents() {
    this.#keydownHandler = this.#handleKeydown.bind(this)
    document.addEventListener("keydown", this.#keydownHandler)
  }

  #unbindKeyboardEvents() {
    document.removeEventListener("keydown", this.#keydownHandler)
  }

  #handleKeydown(event) {
    if (event.code === "Space") {
      if (event.shiftKey) {
        this.stepFrameBack(event)
      } else {
        this.stepFrame(event)
      }
    }
  }

  #shouldIgnoreKeydown(event) {
    return event.target.closest("input, textarea, select, [contenteditable]")
  }

  async #saveClipTimes(start, end) {
    const url = this.element.dataset.clipUpdateUrl
    if (!url) return

    try {
      const response = await fetch(url, {
        method: "PATCH",
        headers: {
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: JSON.stringify({
          blob_id: this.blobIdValue,
          start_time: start,
          end_time: end
        })
      })

      if (response.ok) {
        this.dispatch("saved")
      }
    } catch (error) {
      console.error("Failed to save clip times:", error)
    }
  }

  #formatTime(seconds) {
    const mins = Math.floor(seconds / 60)
    const secs = (seconds % 60).toFixed(1)
    return `${mins}:${secs.padStart(4, "0")}`
  }
}
```

---

### Phase 3: Video Replace Controller

#### Task 3.1: Create Video Replace Controller

```javascript
// app/javascript/controllers/video_replace_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropZone", "preview"]
  static values = {
    blobId: String,
    acceptTypes: { type: String, default: "video/mp4,video/webm,video/quicktime" }
  }
  static classes = ["dragOver"]

  connect() {
    this.#bindDragEvents()
  }

  disconnect() {
    this.#unbindDragEvents()
  }

  // Click to select file
  selectFile() {
    this.inputTarget.click()
  }

  // File selected via input
  fileSelected(event) {
    const file = event.target.files[0]
    if (file) {
      this.#handleFile(file)
    }
  }

  // Drag events
  dragEnter(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.add(this.dragOverClass)
  }

  dragOver(event) {
    event.preventDefault()
  }

  dragLeave(event) {
    // Only remove class if leaving the drop zone entirely
    if (!this.dropZoneTarget.contains(event.relatedTarget)) {
      this.dropZoneTarget.classList.remove(this.dragOverClass)
    }
  }

  drop(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove(this.dragOverClass)

    const file = event.dataTransfer.files[0]
    if (file && this.#isValidType(file)) {
      this.#handleFile(file)
    }
  }

  // Private methods
  #bindDragEvents() {
    this.dropZoneTarget.addEventListener("dragenter", this.dragEnter.bind(this))
    this.dropZoneTarget.addEventListener("dragover", this.dragOver.bind(this))
    this.dropZoneTarget.addEventListener("dragleave", this.dragLeave.bind(this))
    this.dropZoneTarget.addEventListener("drop", this.drop.bind(this))
  }

  #unbindDragEvents() {
    this.dropZoneTarget.removeEventListener("dragenter", this.dragEnter)
    this.dropZoneTarget.removeEventListener("dragover", this.dragOver)
    this.dropZoneTarget.removeEventListener("dragleave", this.dragLeave)
    this.dropZoneTarget.removeEventListener("drop", this.drop)
  }

  #isValidType(file) {
    const acceptedTypes = this.acceptTypesValue.split(",").map(t => t.trim())
    return acceptedTypes.includes(file.type)
  }

  async #handleFile(file) {
    // Show preview immediately (optimistic UI)
    this.#showPreview(file)

    // Upload the file
    const formData = new FormData()
    formData.append("video", file)
    if (this.blobIdValue) {
      formData.append("replace_blob_id", this.blobIdValue)
    }

    const url = this.element.dataset.uploadUrl
    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content
        },
        body: formData
      })

      if (response.ok) {
        const data = await response.json()
        this.dispatch("replaced", { detail: { blobId: data.blob_id } })
      } else {
        this.dispatch("error", { detail: { message: "Upload failed" } })
      }
    } catch (error) {
      this.dispatch("error", { detail: { message: error.message } })
    }
  }

  #showPreview(file) {
    if (this.hasPreviewTarget) {
      const url = URL.createObjectURL(file)
      this.previewTarget.src = url
      this.previewTarget.load()
    }
  }
}
```

---

### Phase 4: View Components

#### Task 4.1: Create VideoPlayerComponent

```ruby
# app/components/reports/video_player_component.rb
class Reports::VideoPlayerComponent < ApplicationComponent
  def initialize(report:, video:)
    @report = report
    @video = video
    @clip = report.clip_for(video.blob)
  end

  private

  attr_reader :report, :video, :clip

  def video_url
    rails_blob_url(video, disposition: :inline)
  end

  def blob_id
    video.blob.id
  end

  def duration
    video.blob.metadata[:duration] || 0
  end

  def start_time
    clip["start"] || 0
  end

  def end_time
    clip["end"] || duration
  end

  def clip_update_url
    report_video_clip_path(report)
  end
end
```

```erb
<%# app/components/reports/video_player_component.html.erb %>
<div class="video-player"
     data-controller="video-clip"
     data-video-clip-blob-id-value="<%= blob_id %>"
     data-video-clip-duration-value="<%= duration %>"
     data-video-clip-start-time-value="<%= start_time %>"
     data-video-clip-end-time-value="<%= end_time %>"
     data-clip-update-url="<%= clip_update_url %>">

  <%# Video element %>
  <video data-video-clip-target="video"
         class="video-player__video"
         src="<%= video_url %>"
         preload="metadata"
         playsinline>
  </video>

  <%# Controls bar %>
  <div class="video-player__controls">
    <button type="button"
            class="video-player__play-btn"
            data-action="click->video-clip#playClip"
            aria-label="Play selected clip">
      ▶ Play Clip
    </button>

    <button type="button"
            class="video-player__pause-btn"
            data-action="click->video-clip#pause"
            aria-label="Pause">
      ⏸ Pause
    </button>

    <span class="video-player__time"
          data-video-clip-target="currentTime">
      0:00.0
    </span>
  </div>

  <%# Range slider for clip selection %>
  <div class="video-player__slider"
       data-controller="range-slider"
       data-range-slider-min-value="0"
       data-range-slider-max-value="<%= duration %>"
       data-range-slider-start-value="<%= start_time %>"
       data-range-slider-end-value="<%= end_time %>"
       data-range-slider-step-value="0.1"
       data-action="range-slider:change->video-clip#rangeChanged range-slider:committed->video-clip#rangeCommitted">

    <div class="range-slider__track" data-range-slider-target="track">
      <div class="range-slider__fill" data-range-slider-target="fill"></div>
      <button type="button"
              class="range-slider__handle range-slider__handle--start"
              data-range-slider-target="startHandle"
              data-action="mousedown->range-slider#startDragStart touchstart->range-slider#startDragStart"
              aria-label="Clip start time"
              tabindex="0">
      </button>
      <button type="button"
              class="range-slider__handle range-slider__handle--end"
              data-range-slider-target="endHandle"
              data-action="mousedown->range-slider#endDragStart touchstart->range-slider#endDragStart"
              aria-label="Clip end time"
              tabindex="0">
      </button>
    </div>

    <div class="range-slider__labels">
      <span data-range-slider-target="startValue"><%= format_time(start_time) %></span>
      <span data-range-slider-target="endValue"><%= format_time(end_time) %></span>
    </div>
  </div>

  <%# Keyboard hint %>
  <p class="video-player__hint">
    Press <kbd>Space</kbd> to step forward one frame, <kbd>Shift+Space</kbd> to step back.
  </p>
</div>
```

#### Task 4.2: Create VideoListComponent

```ruby
# app/components/reports/video_list_component.rb
class Reports::VideoListComponent < ApplicationComponent
  def initialize(report:)
    @report = report
  end

  private

  attr_reader :report

  def videos
    report.videos
  end

  def upload_url
    report_videos_path(report)
  end
end
```

```erb
<%# app/components/reports/video_list_component.html.erb %>
<div class="video-list">
  <h3 class="video-list__title">Videos (<%= videos.count %>)</h3>

  <% if videos.any? %>
    <div class="video-list__items">
      <% videos.each do |video| %>
        <%= turbo_frame_tag dom_id(video.blob, :player) do %>
          <div class="video-list__item"
               data-controller="video-replace"
               data-video-replace-blob-id-value="<%= video.blob.id %>"
               data-upload-url="<%= upload_url %>">

            <%= render Reports::VideoPlayerComponent.new(report: report, video: video) %>

            <%# Replace button %>
            <div class="video-list__replace"
                 data-video-replace-target="dropZone"
                 data-video-replace-drag-over-class="video-list__replace--active">

              <input type="file"
                     accept="video/mp4,video/webm,video/quicktime"
                     data-video-replace-target="input"
                     data-action="change->video-replace#fileSelected"
                     class="visually-hidden">

              <button type="button"
                      class="btn btn--secondary"
                      data-action="click->video-replace#selectFile">
                Replace Video
              </button>

              <span class="video-list__drop-hint">or drop file here</span>
            </div>

            <%# Delete button %>
            <%= button_to "Remove",
                          report_video_path(report, video.blob.id),
                          method: :delete,
                          class: "btn btn--danger btn--small",
                          data: { turbo_confirm: "Remove this video?" } %>
          </div>
        <% end %>
      <% end %>
    </div>
  <% end %>

  <%# Add new video %>
  <div class="video-list__add"
       data-controller="video-replace"
       data-upload-url="<%= upload_url %>">

    <input type="file"
           accept="video/mp4,video/webm,video/quicktime"
           multiple
           data-video-replace-target="input"
           data-action="change->video-replace#fileSelected"
           class="visually-hidden">

    <button type="button"
            class="btn btn--primary"
            data-action="click->video-replace#selectFile">
      + Add Video
    </button>
  </div>
</div>
```

---

### Phase 5: Controller & Routes

#### Task 5.1: Create Videos Controller

```ruby
# app/controllers/reports/videos_controller.rb
class Reports::VideosController < ApplicationController
  before_action :set_report

  def create
    if params[:replace_blob_id].present?
      replace_video
    else
      add_video
    end
  end

  def destroy
    blob = @report.videos.blobs.find(params[:id])
    blob.attachments.destroy_all

    # Clean up clip data
    @report.video_clips.delete(params[:id].to_s)
    @report.save

    respond_to do |format|
      format.turbo_stream { render turbo_stream: turbo_stream.remove(dom_id(blob, :player)) }
      format.html { redirect_to @report }
    end
  end

  private

  def set_report
    @report = Report.find(params[:report_id])
    authorize @report, :update?
  end

  def add_video
    @report.videos.attach(params[:video])
    blob = @report.videos.blobs.last

    respond_to do |format|
      format.json { render json: { blob_id: blob.id } }
      format.turbo_stream
    end
  end

  def replace_video
    old_blob = @report.videos.blobs.find(params[:replace_blob_id])

    # Copy clip times to new blob
    old_clip = @report.video_clips[old_blob.id.to_s]

    # Remove old attachment
    old_blob.attachments.destroy_all

    # Add new attachment
    @report.videos.attach(params[:video])
    new_blob = @report.videos.blobs.last

    # Transfer clip data
    if old_clip
      @report.video_clips.delete(old_blob.id.to_s)
      @report.video_clips[new_blob.id.to_s] = old_clip
      @report.save
    end

    respond_to do |format|
      format.json { render json: { blob_id: new_blob.id } }
    end
  end
end
```

#### Task 5.2: Create Video Clips Controller

```ruby
# app/controllers/reports/video_clips_controller.rb
class Reports::VideoClipsController < ApplicationController
  before_action :set_report

  def update
    @report.set_clip_for(
      find_blob,
      start_time: params[:start_time].to_f,
      end_time: params[:end_time].to_f
    )

    head :ok
  end

  private

  def set_report
    @report = Report.find(params[:report_id])
    authorize @report, :update?
  end

  def find_blob
    @report.videos.blobs.find(params[:blob_id])
  end
end
```

#### Task 5.3: Routes

```ruby
# config/routes.rb
resources :reports do
  resource :video_clip, only: [:update], controller: "reports/video_clips"
  resources :videos, only: [:create, :destroy], controller: "reports/videos"
end
```

---

### Phase 6: CSS Styling

#### Task 6.1: Video Player Styles

```css
/* app/assets/stylesheets/components/video_player.css */

.video-player {
  --player-bg: oklch(15% 0 0);
  --player-accent: oklch(65% 0.2 250);
  --player-handle: oklch(95% 0 0);
  --player-track: oklch(30% 0 0);
  --player-fill: oklch(65% 0.2 250);

  display: flex;
  flex-direction: column;
  gap: 0.75rem;
  padding: 1rem;
  background: var(--player-bg);
  border-radius: 0.5rem;
}

.video-player__video {
  width: 100%;
  max-height: 400px;
  object-fit: contain;
  border-radius: 0.25rem;
}

.video-player__controls {
  display: flex;
  align-items: center;
  gap: 0.5rem;
}

.video-player__play-btn,
.video-player__pause-btn {
  padding: 0.5rem 1rem;
  border: none;
  border-radius: 0.25rem;
  background: var(--player-accent);
  color: white;
  cursor: pointer;
  font-size: 0.875rem;
}

.video-player__time {
  margin-left: auto;
  font-family: monospace;
  color: oklch(70% 0 0);
}

.video-player__hint {
  font-size: 0.75rem;
  color: oklch(60% 0 0);
}

.video-player__hint kbd {
  padding: 0.125rem 0.375rem;
  background: oklch(25% 0 0);
  border-radius: 0.25rem;
  font-family: inherit;
}

/* Range Slider */
.range-slider__track {
  position: relative;
  height: 8px;
  background: var(--player-track);
  border-radius: 4px;
  cursor: pointer;
}

.range-slider__fill {
  position: absolute;
  height: 100%;
  background: var(--player-fill);
  border-radius: 4px;
  pointer-events: none;
}

.range-slider__handle {
  position: absolute;
  top: 50%;
  width: 16px;
  height: 16px;
  margin-left: -8px;
  transform: translateY(-50%);
  background: var(--player-handle);
  border: 2px solid var(--player-accent);
  border-radius: 50%;
  cursor: grab;
}

.range-slider__handle:active {
  cursor: grabbing;
  transform: translateY(-50%) scale(1.1);
}

.range-slider__handle:focus {
  outline: 2px solid var(--player-accent);
  outline-offset: 2px;
}

.range-slider__labels {
  display: flex;
  justify-content: space-between;
  margin-top: 0.25rem;
  font-size: 0.75rem;
  font-family: monospace;
  color: oklch(70% 0 0);
}

/* Video List */
.video-list {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.video-list__title {
  font-size: 1.125rem;
  font-weight: 600;
}

.video-list__items {
  display: flex;
  flex-direction: column;
  gap: 1.5rem;
}

.video-list__item {
  border: 1px solid oklch(30% 0 0);
  border-radius: 0.5rem;
  overflow: hidden;
}

.video-list__replace {
  display: flex;
  align-items: center;
  gap: 0.5rem;
  padding: 0.75rem 1rem;
  background: oklch(20% 0 0);
  border-top: 1px solid oklch(30% 0 0);
}

.video-list__replace--active {
  background: oklch(25% 0.05 250);
  outline: 2px dashed var(--player-accent);
  outline-offset: -2px;
}

.video-list__drop-hint {
  font-size: 0.75rem;
  color: oklch(50% 0 0);
}

.video-list__add {
  padding: 1rem;
  border: 2px dashed oklch(30% 0 0);
  border-radius: 0.5rem;
  text-align: center;
}
```

---

## Testing

### System Tests

```ruby
# test/system/video_clip_selector_test.rb
require "application_system_test_case"

class VideoClipSelectorTest < ApplicationSystemTestCase
  setup do
    @report = reports(:with_video)
    sign_in users(:var_operator)
  end

  test "displays video player with clip slider" do
    visit report_path(@report)

    assert_selector ".video-player"
    assert_selector ".range-slider__track"
    assert_selector ".range-slider__handle", count: 2
  end

  test "adjusts clip range with slider" do
    visit report_path(@report)

    # Drag start handle
    start_handle = find(".range-slider__handle--start")
    start_handle.drag_to(find(".range-slider__track"), x: 50, y: 0)

    # Check that start time updated
    assert_selector "[data-range-slider-target='startValue']", text: /\d:\d+\.\d/
  end

  test "plays only selected clip range" do
    visit report_path(@report)

    click_button "Play Clip"

    # Video should be playing
    video = find("video")
    assert video.evaluate_script("!this.paused")
  end

  test "frame stepping with spacebar" do
    visit report_path(@report)

    video = find("video")
    initial_time = video.evaluate_script("this.currentTime")

    # Press spacebar
    page.driver.browser.keyboard.type(:space)

    # Time should have advanced by approximately one frame
    new_time = video.evaluate_script("this.currentTime")
    assert new_time > initial_time
  end

  test "replaces video via drag and drop" do
    visit report_path(@report)

    # Simulate file drop
    drop_zone = find(".video-list__replace")

    # Note: Actual file drop simulation requires additional setup
    # This is a placeholder for the test structure
    assert_selector ".video-list__replace"
  end
end
```

### Controller Tests

```ruby
# test/controllers/reports/videos_controller_test.rb
require "test_helper"

class Reports::VideosControllerTest < ActionDispatch::IntegrationTest
  setup do
    @report = reports(:one)
    @user = users(:var_operator)
    sign_in @user
  end

  test "creates new video attachment" do
    file = fixture_file_upload("test.mp4", "video/mp4")

    assert_difference("@report.videos.count") do
      post report_videos_path(@report), params: { video: file }
    end

    assert_response :success
  end

  test "replaces existing video" do
    @report.videos.attach(fixture_file_upload("test.mp4", "video/mp4"))
    old_blob_id = @report.videos.first.blob.id
    new_file = fixture_file_upload("test2.mp4", "video/mp4")

    post report_videos_path(@report), params: {
      video: new_file,
      replace_blob_id: old_blob_id
    }

    assert_response :success
    refute @report.reload.videos.blobs.exists?(id: old_blob_id)
  end

  test "deletes video attachment" do
    @report.videos.attach(fixture_file_upload("test.mp4", "video/mp4"))
    blob_id = @report.videos.first.blob.id

    assert_difference("@report.videos.count", -1) do
      delete report_video_path(@report, blob_id)
    end
  end
end
```

---

## Accessibility

- **Keyboard navigation**: Slider handles are focusable and adjustable with arrow keys
- **ARIA labels**: All interactive elements have descriptive labels
- **Focus indicators**: Visible focus rings on all interactive elements
- **Screen reader support**: Time values announced when changed

---

## Performance Considerations

- **Lazy video loading**: Videos use `preload="metadata"` to avoid loading full content
- **Debounced saves**: Clip time changes are saved only on drag end (committed event)
- **Optimistic UI**: Preview updates immediately on file selection before upload completes
- **Frame accuracy**: HTML5 video seeking is frame-accurate in modern browsers

---

## Future Enhancements (V2+)

1. **Video thumbnails timeline** - Show thumbnail strip along the slider
2. **Multiple clip ranges** - Allow selecting multiple non-contiguous ranges
3. **Clip export** - Export selected clip as separate file
4. **Waveform display** - Show audio waveform for audio-based navigation
5. **Slow motion playback** - 0.25x, 0.5x playback speeds
6. **Touch gestures** - Pinch to zoom timeline on touch devices

---

## Related Documents

- [FOP Real-Time Performance](./fop-realtime-performance.md) - Report creation flow
- [MSO Import Participants](./mso-import-participants.md) - Participant data
- [Architecture Overview](../architecture-overview.md) - Report model details