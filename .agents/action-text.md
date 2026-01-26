# Action Text Patterns (37signals Style)

Reference guide for rich text editing, sanitizer configuration, and content handling.

---

## Setup

### Installation

```bash
bin/rails action_text:install
```

### Basic Usage

```ruby
# app/models/report.rb
class Report < ApplicationRecord
  has_rich_text :description
  has_rich_text :notes
end
```

```erb
<%# app/views/reports/_form.html.erb %>
<%= form_with model: report do |form| %>
  <%= form.rich_text_area :description %>
<% end %>
```

---

## Sanitizer Configuration

### Sync Rails and Action Text Sanitizers

**Critical for production** - Action Text's sanitizer doesn't automatically inherit from Rails config:

```ruby
# config/initializers/sanitization.rb
Rails.application.config.after_initialize do
  # Add custom tags and attributes to Rails sanitizer
  Rails::HTML5::SafeListSanitizer.allowed_tags.merge(%w[
    s
    table tr td th thead tbody
    details summary
    video source
    figure figcaption
  ])

  Rails::HTML5::SafeListSanitizer.allowed_attributes.merge(%w[
    data-turbo-frame
    data-action
    data-controller
    controls
    type
    width
    height
    src
    poster
  ])

  # CRITICAL: Explicitly sync with Action Text in production
  ActionText::ContentHelper.allowed_tags = Rails::HTML5::SafeListSanitizer.allowed_tags
  ActionText::ContentHelper.allowed_attributes = Rails::HTML5::SafeListSanitizer.allowed_attributes
end
```

### Testing Sanitizer Configuration

```ruby
# test/helpers/action_text_rendering_test.rb
class ActionTextRenderingTest < ActionView::TestCase
  test "custom data attributes in content are preserved" do
    html = '<p><a href="#" data-turbo-frame="modal">Open modal</a></p>'
    content = ActionText::Content.new(html)
    rendered = content.to_s

    assert_match(/data-turbo-frame="modal"/, rendered)
  end

  test "video elements are preserved" do
    html = '<video controls><source src="video.mp4" type="video/mp4"></video>'
    content = ActionText::Content.new(html)
    rendered = content.to_s

    assert_match(/<video/, rendered)
    assert_match(/<source/, rendered)
  end
end
```

---

## Custom HTML Processing

### Auto-linking at Render Time

Process HTML when rendering, not when saving (keeps original content pristine):

```ruby
# app/helpers/html_helper.rb
module HtmlHelper
  include ERB::Util

  EXCLUDE_PUNCTUATION = %(.?,:!;"'<>)
  EXCLUDE_PUNCTUATION_REGEX = /[#{Regexp.escape(EXCLUDE_PUNCTUATION)}]+\z/

  def format_html(html)
    fragment = Nokogiri::HTML5.fragment(html)
    auto_link(fragment)
    fragment.to_html.html_safe
  end

  private

  EXCLUDED_ELEMENTS = %w[a figcaption pre code]
  EMAIL_REGEXP = /\b[a-zA-Z0-9.!#$%&'*+\/=?^_`{|}~-]+@[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(?:\.[a-zA-Z0-9](?:[a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*\b/
  URL_REGEXP = URI::DEFAULT_PARSER.make_regexp(%w[http https])

  def auto_link(fragment)
    fragment.traverse do |node|
      next unless auto_linkable_node?(node)

      content = h(node.text)
      linked_content = content.dup

      auto_link_urls(linked_content)
      auto_link_emails(linked_content)

      if linked_content != content
        node.replace(Nokogiri::HTML5.fragment(linked_content))
      end
    end
  end

  def auto_linkable_node?(node)
    node.text? && node.ancestors.none? { |ancestor| EXCLUDED_ELEMENTS.include?(ancestor.name) }
  end

  def auto_link_urls(text)
    text.gsub!(URL_REGEXP) do |match|
      url, trailing_punct = extract_url_and_punctuation(match)
      %(<a href="#{url}" rel="noreferrer">#{url}</a>#{trailing_punct})
    end
  end

  def extract_url_and_punctuation(url_match)
    url_match = CGI.unescapeHTML(url_match)
    if match = url_match.match(EXCLUDE_PUNCTUATION_REGEX)
      len = match[0].length
      [url_match[..-(len + 1)], url_match[-len..]]
    else
      [url_match, ""]
    end
  end

  def auto_link_emails(text)
    text.gsub!(EMAIL_REGEXP) do |match|
      %(<a href="mailto:#{match}">#{match}</a>)
    end
  end
end
```

### Override Action Text Content Layout

```erb
<%# app/views/layouts/action_text/contents/_content.html.erb %>
<div class="action-text-content">
  <%= format_html yield -%>
</div>
```

---

## Link Retargeting

### Stimulus Controller for Links

Retarget links based on domain (internal vs external):

```javascript
// app/javascript/controllers/retarget_links_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.querySelectorAll("a").forEach(this.#retargetLink.bind(this))
  }

  #retargetLink(link) {
    link.target = this.#targetsSameDomain(link) ? "_top" : "_blank"
    
    // Add noopener for external links
    if (link.target === "_blank") {
      link.rel = "noopener noreferrer"
    }
  }

  #targetsSameDomain(link) {
    return link.href.startsWith(window.location.origin)
  }
}
```

Usage:

```erb
<div class="rich-text-content" data-controller="retarget-links">
  <%= report.description %>
</div>
```

---

## Custom Attachable Partials

### Remote Video Attachment

```erb
<%# app/views/action_text/attachables/_remote_video.html.erb %>
<figure class="attachment attachment--preview attachment--video">
  <%= tag.video controls: true, width: remote_video.width, height: remote_video.height, preload: "metadata" do %>
    <%= tag.source src: remote_video.url, type: remote_video.content_type %>
  <% end %>
  <% if caption = remote_video.try(:caption) %>
    <figcaption class="attachment__caption">
      <%= caption %>
    </figcaption>
  <% end %>
</figure>
```

### Remote Image (with skip_pipeline)

Handle malformed URLs gracefully:

```erb
<%# app/views/action_text/attachables/_remote_image.html.erb %>
<figure class="attachment attachment--preview">
  <%= image_tag remote_image.url,
        skip_pipeline: true,
        width: remote_image.width,
        height: remote_image.height,
        loading: :lazy %>
  <% if caption = remote_image.try(:caption) %>
    <figcaption class="attachment__caption">
      <%= caption %>
    </figcaption>
  <% end %>
</figure>
```

---

## Rich Text CSS Styling

```css
/* app/assets/stylesheets/components/action_text.css */

.action-text-content {
  --block-margin: 0.5lh;
}

/* Typography */
.action-text-content :is(h1, h2, h3, h4, h5, h6) {
  font-weight: 800;
  letter-spacing: -0.02ch;
  line-height: 1.1;
  margin-block: 0 var(--block-margin);
  overflow-wrap: break-word;
  text-wrap: balance;
}

.action-text-content h1 { font-size: 2rem; }
.action-text-content h2 { font-size: 1.5rem; }
.action-text-content h3 { font-size: 1.25rem; }

/* Hide empty paragraphs */
.action-text-content p:empty {
  display: none;
}

/* Lists */
.action-text-content :is(ul, ol) {
  padding-inline-start: 2ch;
  margin-block: var(--block-margin);
}

.action-text-content li {
  margin-block: 0.25lh;
}

/* Code blocks */
.action-text-content code {
  background: oklch(20% 0 0);
  padding: 0.125em 0.375em;
  border-radius: 0.25em;
  font-size: 0.875em;
}

.action-text-content pre {
  display: block;
  overflow-x: auto;
  padding: 0.5lh 2ch;
  tab-size: 2;
  white-space: pre;
  background: oklch(15% 0 0);
  border-radius: 0.5rem;
}

.action-text-content pre code {
  background: transparent;
  padding: 0;
}

/* Links */
.action-text-content a {
  color: oklch(65% 0.2 250);
  text-decoration: underline;
  text-underline-offset: 0.15em;
}

.action-text-content a:hover {
  text-decoration-thickness: 2px;
}

/* Links hugging media */
.action-text-content a:has(img),
.action-text-content a:has(video) {
  inline-size: fit-content;
  margin-inline: auto;
}

/* Media constraints */
.action-text-content img,
.action-text-content video {
  inline-size: auto;
  margin-inline: auto;
  max-block-size: 32rem;
  max-inline-size: 100%;
  object-fit: contain;
  border-radius: 0.25rem;
}

/* Blockquotes */
.action-text-content blockquote {
  border-inline-start: 4px solid oklch(40% 0 0);
  margin-inline-start: 0;
  padding-inline-start: 1ch;
  color: oklch(70% 0 0);
}

/* Tables */
.action-text-content table {
  border-collapse: collapse;
  inline-size: 100%;
  margin-block: var(--block-margin);
}

.action-text-content th,
.action-text-content td {
  border: 1px solid oklch(30% 0 0);
  padding: 0.5em 1ch;
  text-align: start;
}

.action-text-content th {
  background: oklch(20% 0 0);
  font-weight: 600;
}

/* Attachments */
.action-text-content .attachment {
  display: block;
  margin-block: var(--block-margin);
}

.action-text-content .attachment--preview {
  text-align: center;
}

.action-text-content .attachment__caption {
  font-size: 0.875rem;
  color: oklch(60% 0 0);
  margin-block-start: 0.25lh;
}

/* Video attachments */
.action-text-content .attachment--video video {
  max-inline-size: 100%;
  border-radius: 0.5rem;
}
```

---

## Testing Helpers

### HTML Comparison Helper

```ruby
# test/test_helpers/action_text_test_helper.rb
module ActionTextTestHelper
  def assert_action_text(expected_html, content)
    assert_equal_html <<~HTML, content.to_s
      <div class="action-text-content">#{expected_html}</div>
    HTML
  end

  def assert_equal_html(expected, actual)
    assert_equal normalize_html(expected), normalize_html(actual)
  end

  def normalize_html(html)
    Nokogiri::HTML.fragment(html).tap do |fragment|
      fragment.traverse do |node|
        node.content = node.text.squish if node.text?
      end
    end.to_html.strip
  end
end
```

### Include in Tests

```ruby
# test/test_helper.rb
class ActiveSupport::TestCase
  include ActionTextTestHelper
end
```

---

## Form Integration

### Apply Rich Text Styling to Forms

```erb
<%= form_with model: report, class: "rich-text-content", data: { controller: "auto-save" } do |form| %>
  <%= form.label :description %>
  <%= form.rich_text_area :description, class: "rich-text-editor" %>
<% end %>
```

### Custom Toolbar

```erb
<%= form.rich_text_area :description,
      data: {
        direct_upload_url: rails_direct_uploads_url,
        blob_url_template: rails_service_blob_url(":signed_id", ":filename")
      } %>
```

---

## Performance

### Lazy Load Attachments

```erb
<div class="rich-text-content" data-controller="lazy-images">
  <%= report.description %>
</div>
```

```javascript
// app/javascript/controllers/lazy_images_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.element.querySelectorAll("img").forEach(img => {
      img.loading = "lazy"
    })
  }
}
```

### Fragment Caching

```erb
<% cache report do %>
  <div class="rich-text-content" data-controller="retarget-links">
    <%= report.description %>
  </div>
<% end %>
```

---

## Security

### Content Security Policy

```ruby
# config/initializers/content_security_policy.rb
Rails.application.configure do
  config.content_security_policy do |policy|
    # Allow inline styles for Trix editor
    policy.style_src :self, :unsafe_inline

    # Allow blob URLs for attachments
    policy.img_src :self, :blob, :data
    policy.media_src :self, :blob
  end
end
```

### XSS Prevention

Action Text automatically sanitizes HTML. For extra safety:

```ruby
# Never bypass sanitization
report.description.to_s  # Safe - sanitized

# Don't do this!
report.description.body.to_s.html_safe  # Dangerous!
```

---

## Quick Reference

### Common Operations

```ruby
# Check if has content
report.description.present?
report.description.blank?

# Get plain text
report.description.to_plain_text

# Get HTML (sanitized)
report.description.to_s

# Check for attachments
report.description.attachments.any?

# Get embeds/attachments
report.description.embeds
report.description.attachments

# Create content programmatically
report.description = ActionText::Content.new("<p>Hello</p>")
```

### Attachment Types

| Type | Partial Location |
|------|------------------|
| ActiveStorage::Blob | `_blob.html.erb` |
| RemoteImage | `_remote_image.html.erb` |
| RemoteVideo | `_remote_video.html.erb` |
| Custom Model | `_model_name.html.erb` |

---

## Resources

- [Action Text Guide](https://guides.rubyonrails.org/action_text_overview.html)
- [Trix Editor](https://trix-editor.org/)
- [Rails HTML Sanitizer](https://github.com/rails/rails-html-sanitizer)