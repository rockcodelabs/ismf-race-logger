# Performance Patterns (37signals Style)

Reference guide for database, CSS, and rendering optimizations extracted from 37signals' Fizzy codebase.

---

## CSS Performance

### Avoid Complex `:has()` Selectors

Safari freezes on complex nested `:has()` selectors. Prefer simpler selectors over clever CSS.

```css
/* Bad: Complex nested :has() */
.card:has(.avatar:has(.badge:has(.count))) {
  /* Safari will freeze */
}

/* Good: Simpler approach */
.card--with-badge-count {
  /* Use a class instead */
}
```

### View Transitions

Remove unnecessary `view-transition-name` causing navigation jank.

```css
/* Only add view-transition-name when needed */
.card {
  /* Avoid: view-transition-name: card; on every card */
}

/* Better: Add only to specific elements that need transitions */
.card--transitioning {
  view-transition-name: card;
}
```

---

## Database Performance

### N+1 → JOINs

Replace `find_each` loops with JOINs for bulk operations.

```ruby
# Bad: N+1 queries
user.mentions.find_each do |mention|
  mention.destroy if mention.card.collection_id == collection.id
end

# Good: Single query with JOINs
user.mentions
  .joins("LEFT JOIN cards ON ...")
  .joins("LEFT JOIN comments ON ...")
  .where("cards.collection_id = ?", id)
  .destroy_all
```

> Accept "unmaintainable" SQL when performance requires it:
> "Way way way faster but feels unmaintainable"

### Counter Caches

Fast reads, but callbacks are bypassed. Consider manual approach if you need side effects.

```ruby
# In model
belongs_to :board, counter_cache: true

# Note: This bypasses callbacks - if you need side effects,
# increment/decrement manually in the appropriate callback
```

### Preloaded Scopes

Create `preloaded` scopes to prevent N+1 queries:

```ruby
class Card < ApplicationRecord
  scope :preloaded, -> {
    includes(:column, :tags, board: [:entropy, :columns])
  }
end

# Usage
Card.preloaded.where(board: @board)
```

### In-Memory Checks Over Extra Queries

```ruby
# Bad - extra query
assignments.exists? assignee: user

# Good - in-memory check
assignments.any? { |a| a.assignee_id == user.id }
```

---

## Pagination

### Start with Reasonable Page Sizes

- Start with 25-50 items per page
- Reduce if initial render is slow (e.g., 50 → 25)
- Use "Load more" buttons or intersection observer
- Separate pagination per column/section

```ruby
# Controller
def index
  @cards = Card.preloaded
               .where(board: @board)
               .page(params[:page])
               .per(25)  # Start conservative
end
```

### Lazy Loading with Intersection Observer

```javascript
// Load more when user scrolls near bottom
export default class extends Controller {
  static values = { url: String }

  connect() {
    this.observer = new IntersectionObserver((entries) => {
      if (entries.some(entry => entry.isIntersecting)) {
        this.#loadMore()
      }
    })
    this.observer.observe(this.element)
  }

  disconnect() {
    this.observer?.disconnect()
  }

  async #loadMore() {
    const response = await fetch(this.urlValue)
    // Handle response
  }
}
```

---

## Active Storage

### Read Replicas

Use `preprocessed: true` - lazy generation fails on read-only replicas.

```ruby
class User < ApplicationRecord
  has_one_attached :avatar do |attachable|
    attachable.variant :thumb, resize_to_limit: [100, 100], preprocessed: true
  end
end
```

### Slow Uploads

Extend signed URL expiry from default 5 min to 48 hours. Cloudflare buffering can exceed default timeout.

```ruby
# config/initializers/active_storage.rb
Rails.application.config.active_storage.service_urls_expire_in = 48.hours
```

### Large Files

Skip previews above size threshold (e.g., 16MB) to avoid timeouts.

```ruby
class Document < ApplicationRecord
  has_one_attached :file

  def previewable?
    file.attached? && file.blob.byte_size < 16.megabytes
  end
end
```

### Avatar Optimization

- Redirect to blob URL instead of streaming through Rails
- Define thumbnail variants for consistent sizing
- Faster than proxying through the app

```ruby
# Controller
def avatar
  redirect_to @user.avatar.variant(:thumb), allow_other_host: true
end
```

---

## Rendering Performance

### Lazy Loading with Turbo Frames

Convert expensive menus to turbo frames. Load on interaction, not page load.

```erb
<%# Instead of rendering expensive content on page load %>
<%= turbo_frame_tag "notifications",
      src: notifications_path,
      loading: :lazy do %>
  <span class="loading-placeholder">Loading...</span>
<% end %>
```

### Debouncing

100ms debounce on filter search feels responsive.

```javascript
// In Stimulus controller
static values = { delay: { type: Number, default: 100 } }

filter() {
  clearTimeout(this.timeout)
  this.timeout = setTimeout(() => {
    this.#performFilter()
  }, this.delayValue)
}
```

### Fragment Caching

```erb
<%# Cache expensive partials %>
<% cache card do %>
  <%= render "cards/preview", card: card %>
<% end %>

<%# Collection caching %>
<%= render partial: "cards/preview",
           collection: @cards,
           cached: true %>
```

---

## Puma/Ruby Tuning

```ruby
# config/puma.rb
workers Concurrent.physical_processor_count
threads 1, 1

before_fork do
  Process.warmup  # GC, compact, malloc_trim for CoW
end
```

Use `autotuner` gem to collect data and suggest tuning.

---

## N+1 Prevention

### Use Prosopite Gem for Detection

```ruby
# Gemfile
gem "prosopite", group: [:development, :test]

# config/environments/development.rb
config.after_initialize do
  Prosopite.rails_logger = true
  Prosopite.raise = true  # Fail tests on N+1
end
```

### Common N+1 Fixes

```ruby
# Bad: N+1 in view
@cards.each do |card|
  card.assignees.each { |a| a.name }  # N+1!
end

# Good: Eager load
@cards = Card.includes(:assignees).all
```

---

## Optimistic UI for Drag & Drop

Insert immediately, request async:

```javascript
async drop(event) {
  const item = this.draggedItem
  const container = event.target.closest("[data-drop-target]")

  // 1. Insert immediately (optimistic)
  this.#insertDraggedItem(container, item)

  // 2. Request in background
  await this.#submitDropRequest(item, container)
}

#insertDraggedItem(container, item) {
  // Insert at correct position respecting priority
  const topItems = container.querySelectorAll("[data-priority='high']")
  const insertPoint = topItems[topItems.length - 1]?.nextSibling || container.firstChild
  container.insertBefore(item, insertPoint)
}
```

---

## Video Performance (Project-Specific)

### Lazy Video Loading

```erb
<%# Use preload="metadata" to avoid loading full video %>
<video preload="metadata" playsinline>
  <source src="<%= video_url %>" type="video/mp4">
</video>
```

### Debounced Clip Time Saves

Only save clip times when user finishes dragging (on `committed` event, not every `change`).

```javascript
// Save only on drag end, not during drag
rangeCommitted(event) {
  const { start, end } = event.detail
  this.#saveClipTimes(start, end)  // Debounced save
}

rangeChanged(event) {
  // Just update UI, don't save
  this.videoTarget.currentTime = event.detail.start
}
```

### Skip Large Video Previews

```ruby
class Report < ApplicationRecord
  MAX_PREVIEW_SIZE = 50.megabytes

  def video_previewable?(video)
    video.blob.byte_size < MAX_PREVIEW_SIZE
  end
end
```

---

## Performance Targets

### FOP Devices (Touch/Mobile)

| Metric | Target |
|--------|--------|
| Bib modal open | < 50ms |
| Bib selection | < 100ms perceived |
| Offline queue sync | < 30s after reconnection |

### Desktop Devices

| Metric | Target |
|--------|--------|
| Report list load | < 300ms (100 reports) |
| Real-time notification | < 1s delay |
| Dashboard render | < 200ms |

### Video Player

| Metric | Target |
|--------|--------|
| Slider responsiveness | < 16ms (60fps) |
| Video seek latency | < 100ms |
| Frame step accuracy | ±1 frame |

---

## Quick Wins Checklist

- [ ] Add `preloaded` scopes to frequently queried models
- [ ] Use `includes()` for associations accessed in views
- [ ] Add counter caches for counts displayed in lists
- [ ] Use `preload="metadata"` for video elements
- [ ] Debounce search/filter inputs (100ms minimum)
- [ ] Lazy load below-the-fold content with Turbo Frames
- [ ] Cache expensive partials with fragment caching
- [ ] Use `preprocessed: true` for Active Storage variants
- [ ] Add database indexes for frequently filtered columns
- [ ] Use Prosopite/Bullet in development to catch N+1 queries

---

## Tools

### Development

- **Bullet gem** - Detect N+1 queries and unused eager loading
- **Prosopite gem** - Alternative N+1 detector
- **rack-mini-profiler** - Page load performance
- **memory_profiler** - Memory usage analysis

### Production

- **Scout APM / New Relic** - Application performance monitoring
- **Skylight** - Rails-focused performance monitoring
- **autotuner gem** - Puma/GC tuning suggestions

---

## Resources

- [Rails Performance Best Practices](https://guides.rubyonrails.org/v7.1/active_record_querying.html#eager-loading-associations)
- [Bullet Gem](https://github.com/flyerhzm/bullet)
- [Prosopite Gem](https://github.com/charkost/prosopite)