# Web Layer Architecture

> Hanami-compatible web layer for ISMF Race Logger with Turbo, Hotwire, and Turbo Native support

This document describes the **Web Layer** of the Hanami Hybrid Architecture, focusing on controllers, templates, Parts, Broadcasters, and real-time features. It complements the main [Hanami Hybrid Architecture](./hanami-hybrid-architecture.md) document.

---

## Table of Contents

1. [Overview](#overview)
2. [Architecture Decisions](#architecture-decisions)
3. [Directory Structure](#directory-structure)
4. [Layer Components](#layer-components)
   - [Controllers](#controllers)
   - [Parts](#parts)
   - [Templates](#templates)
   - [Broadcasters](#broadcasters)
   - [Stimulus Controllers](#stimulus-controllers)
5. [Real-Time Architecture](#real-time-architecture)
6. [Turbo Native Support](#turbo-native-support)
7. [Dependency Injection](#dependency-injection)
8. [Data Flow](#data-flow)
9. [Implementation Plan](#implementation-plan)
10. [Quick Reference](#quick-reference)

---

## Overview

The web layer handles all HTTP concerns and real-time broadcasting. Key principles:

- **Thin controllers**: Delegate to Operations, set minimal instance variables
- **Parts for presentation**: View-specific logic lives in Parts, not Structs or templates
- **Dedicated Broadcasters**: Real-time Turbo Stream logic is separated from business logic
- **Turbo Native support**: Shared views with conditional rendering for native apps
- **No helpers**: Parts handle all presentation logic
- **No view classes**: Controllers stay simple for a small app

---

## Architecture Decisions

| Aspect | Decision | Rationale |
|--------|----------|-----------|
| **Real-time pattern** | Heavy real-time, multi-user collaboration | Race officials see incidents instantly |
| **Turbo Native** | Hybrid (shared views + conditional partials) | 80% code reuse, platform-specific chrome |
| **Broadcast architecture** | Dedicated Broadcasters (`app/broadcasters/`) | Separation of concerns, testable |
| **Broadcaster registration** | Yes, in DI container | Consistent with architecture, injectable |
| **Presentation logic** | Structs + Parts | Clean separation of domain and view |
| **Parts registration** | Part Factory in container | Auto-resolves struct → part |
| **Helpers** | None (Parts handle all) | Single responsibility |
| **Template location** | `app/views/` (Rails default) | Tooling compatibility, Parts handle logic |
| **Turbo Native variants** | Rails variants (`.turbo_native.html.erb`) | Built-in Rails support |
| **Stimulus controllers** | Rails default (`app/javascript/controllers/`) | Simple, flat structure |
| **View classes** | None | Small app, controllers stay simple |

---

## Directory Structure

```
app/
├── web/                              # Web layer (HTTP + presentation)
│   ├── controllers/                  # Thin HTTP adapters
│   │   ├── application_controller.rb
│   │   ├── concerns/
│   │   │   └── authentication.rb
│   │   ├── sessions_controller.rb
│   │   ├── home_controller.rb
│   │   └── admin/
│   │       ├── base_controller.rb
│   │       ├── dashboard_controller.rb
│   │       └── users_controller.rb
│   │
│   ├── parts/                        # Presentation decorators
│   │   ├── base.rb                   # Base part class
│   │   ├── factory.rb                # Auto-wraps structs → parts
│   │   ├── user.rb
│   │   └── incident.rb
│   │
│   └── package.yml                   # Packwerk boundaries
│
├── views/                            # ERB templates (Rails convention)
│   ├── layouts/
│   │   ├── application.html.erb
│   │   ├── application.turbo_native.html.erb  # Turbo Native variant
│   │   ├── admin.html.erb
│   │   └── admin.turbo_native.html.erb        # Turbo Native variant
│   ├── sessions/
│   │   └── new.html.erb
│   ├── home/
│   │   └── index.html.erb
│   ├── admin/
│   │   ├── dashboard/
│   │   │   └── index.html.erb
│   │   └── users/
│   │       ├── index.html.erb
│   │       ├── show.html.erb
│   │       └── _user.html.erb
│   └── shared/
│       └── _flash.html.erb
│
├── broadcasters/                     # Real-time Turbo Stream broadcasts
│   ├── base_broadcaster.rb
│   ├── incident_broadcaster.rb
│   └── user_broadcaster.rb
│
├── javascript/
│   └── controllers/                  # Stimulus controllers (Rails default)
│       ├── application.js
│       ├── index.js
│       ├── flash_controller.js
│       ├── dropdown_controller.js
│       └── presence_controller.js
│
└── helpers/                          # EMPTY (Parts handle presentation)
    └── application_helper.rb
```

> **Note:** Templates remain in `app/views/` (Rails convention) for tooling compatibility.
> The architectural benefit comes from Parts handling presentation logic, not template location.
```

---

## Layer Components

### Controllers

Thin HTTP adapters that:
- Call Operations for business logic
- Use Parts Factory to wrap structs for templates
- Handle HTTP responses (redirects, flash, status codes)
- Set Turbo Native variants

```ruby
# app/web/controllers/application_controller.rb
# frozen_string_literal: true

module Web
  module Controllers
    class ApplicationController < ActionController::Base
      include Concerns::Authentication
      include Pundit::Authorization

      layout "application"

      before_action :set_variant

      # Override controller_path for view lookup
      def self.controller_path
        @controller_path ||= name.sub(/^Web::Controllers::/, "").sub(/Controller$/, "").underscore
      end

      private

      def set_variant
        request.variant = :turbo_native if turbo_native_app?
      end

      def turbo_native_app?
        request.user_agent.to_s.include?("Turbo Native")
      end

      def parts_factory
        @parts_factory ||= AppContainer["parts.factory"]
      end
    end
  end
end
```

**Example controller with Operations + Parts:**

```ruby
# app/web/controllers/incidents_controller.rb
# frozen_string_literal: true

module Web
  module Controllers
    class IncidentsController < ApplicationController
      def index
        @race = race_repo.find!(params[:race_id])
        @incidents = parts_factory.wrap_many(
          incident_repo.for_race(params[:race_id])
        )
      end

      def create
        result = Operations::Incidents::Create.new.call(incident_params)

        result.either(
          ->(incident) {
            # Broadcast to all connected clients
            incident_broadcaster.created(incident)
            redirect_to race_path(incident.race_id), notice: "Incident reported"
          },
          ->(error) {
            @errors = error
            render :new, status: :unprocessable_entity
          }
        )
      end

      private

      def race_repo
        @race_repo ||= AppContainer["repos.race"]
      end

      def incident_repo
        @incident_repo ||= AppContainer["repos.incident"]
      end

      def incident_broadcaster
        @incident_broadcaster ||= AppContainer["broadcasters.incident"]
      end

      def incident_params
        params.require(:incident).permit(:bib_number, :description, :status)
      end
    end
  end
end
```

---

### Parts

Parts wrap Structs with view-specific presentation logic. They:
- Keep Structs pure (domain only)
- Keep templates simple (no inline logic)
- Are testable in isolation
- Delegate missing methods to the wrapped struct

#### Base Part

```ruby
# app/web/parts/base.rb
# frozen_string_literal: true

module Web
  module Parts
    # Base class for all view parts
    #
    # Parts wrap domain structs and add view-specific presentation logic.
    # This keeps structs pure and templates simple.
    #
    # Example:
    #   part = Web::Parts::User.new(user_struct)
    #   part.display_name      # Presentation logic
    #   part.email_address     # Delegated to struct
    #
    class Base
      attr_reader :value

      def initialize(value)
        @value = value
      end

      # Delegate missing methods to the wrapped value
      def method_missing(method, *args, &block)
        if value.respond_to?(method)
          value.public_send(method, *args, &block)
        else
          super
        end
      end

      def respond_to_missing?(method, include_private = false)
        value.respond_to?(method) || super
      end

      # For use in dom_id and other Rails helpers
      def to_model
        value
      end

      def to_s
        value.to_s
      end

      # Access Rails view helpers
      def helpers
        ApplicationController.helpers
      end
    end
  end
end
```

#### Part Factory

```ruby
# app/web/parts/factory.rb
# frozen_string_literal: true

module Web
  module Parts
    # Factory for wrapping structs in their corresponding parts
    #
    # Automatically resolves: Structs::Incident → Web::Parts::Incident
    #
    # Example:
    #   factory = Web::Parts::Factory.new
    #   part = factory.wrap(incident_struct)  # => Web::Parts::Incident
    #   parts = factory.wrap_many(incidents)  # => [Web::Parts::Incident, ...]
    #
    class Factory
      # Wrap a single struct in its corresponding part
      def wrap(struct)
        return nil if struct.nil?
        part_class_for(struct).new(struct)
      end

      # Wrap a collection of structs
      def wrap_many(structs)
        structs.map { |s| wrap(s) }
      end

      private

      def part_class_for(struct)
        # Structs::Incident → "Incident" → Web::Parts::Incident
        part_name = struct.class.name.sub("Structs::", "")
        "Web::Parts::#{part_name}".constantize
      rescue NameError
        # Fall back to base part if no specific part exists
        Web::Parts::Base
      end
    end
  end
end
```

#### Example Part

```ruby
# app/web/parts/user.rb
# frozen_string_literal: true

module Web
  module Parts
    # Presentation logic for User in views
    class User < Base
      def avatar_initials
        display_name.chars.first.upcase
      end

      def role_badge
        if value.admin?
          { class: "badge-danger", label: "Admin" }
        else
          { class: "badge-info", label: "User" }
        end
      end

      def created_at_formatted
        value.created_at.strftime("%b %d, %Y")
      end

      def dom_id
        "user_#{value.id}"
      end
    end
  end
end
```

```ruby
# app/web/parts/incident.rb
# frozen_string_literal: true

module Web
  module Parts
    # Presentation logic for Incident in views
    class Incident < Base
      def status_badge
        case value.status
        when "pending"
          { class: "badge-warning", label: "Pending" }
        when "reviewed"
          { class: "badge-info", label: "Reviewed" }
        when "official"
          { class: "badge-success", label: "Official" }
        else
          { class: "badge-secondary", label: value.status.titleize }
        end
      end

      def time_ago
        helpers.time_ago_in_words(value.reported_at)
      end

      def dom_id
        "incident_#{value.id}"
      end

      def bib_display
        "##{value.bib_number}"
      end
    end
  end
end
```

---

### Templates

Templates live in `app/views/` (Rails convention) and use Parts for all presentation logic.

> **Why `app/views/` instead of `app/web/templates/`?**
> - Rails tooling, generators, and gems expect `app/views/`
> - Mailer views naturally live in `app/views/`
> - The architectural benefit comes from Parts handling presentation logic, not template location
> - Parts + Structs already provide clean separation

#### Template Rules

1. **No business logic** — handled by Operations
2. **No complex presentation logic** — handled by Parts
3. **Use part methods** — `incident.status_badge`, not inline conditionals
4. **Turbo Frame IDs** — use `part.dom_id`

#### Example Template

```erb
<%# app/views/incidents/_incident.html.erb %>
<turbo-frame id="<%= incident.dom_id %>">
  <div class="incident-card" data-controller="incident">
    <div class="flex items-center justify-between">
      <span class="<%= incident.status_badge[:class] %>">
        <%= incident.status_badge[:label] %>
      </span>
      <span class="text-sm text-gray-500">
        <%= incident.time_ago %> ago
      </span>
    </div>
    
    <div class="mt-2">
      <span class="font-bold"><%= incident.bib_display %></span>
      <p class="text-gray-700"><%= incident.description %></p>
    </div>
    
    <div class="mt-3 flex gap-2">
      <%= link_to "View", incident_path(incident), class: "btn-secondary" %>
      <%= link_to "Edit", edit_incident_path(incident), class: "btn-outline" %>
    </div>
  </div>
</turbo-frame>
```

---

### Broadcasters

Broadcasters handle real-time Turbo Stream broadcasts. They:
- Wrap structs in Parts before rendering
- Know nothing about business logic (just delivery)
- Are registered in the DI container
- Can be mocked in tests

#### Base Broadcaster

```ruby
# app/broadcasters/base_broadcaster.rb
# frozen_string_literal: true

class BaseBroadcaster
  include Import["parts.factory"]

  private

  # Access the parts factory (injected)
  def parts_factory
    factory
  end

  # Wrap a struct in its part for rendering
  def wrap(struct)
    parts_factory.wrap(struct)
  end

  # Broadcast a Turbo Stream action
  def broadcast_to(stream, action:, target:, partial:, locals:)
    Turbo::StreamsChannel.broadcast_action_to(
      stream,
      action: action,
      target: target,
      partial: partial,
      locals: locals
    )
  end

  # Broadcast with automatic part wrapping
  def broadcast_append(stream, target:, partial:, struct:, as:)
    part = wrap(struct)
    broadcast_to(
      stream,
      action: :append,
      target: target,
      partial: partial,
      locals: { as => part }
    )
  end

  def broadcast_prepend(stream, target:, partial:, struct:, as:)
    part = wrap(struct)
    broadcast_to(
      stream,
      action: :prepend,
      target: target,
      partial: partial,
      locals: { as => part }
    )
  end

  def broadcast_replace(stream, target:, partial:, struct:, as:)
    part = wrap(struct)
    broadcast_to(
      stream,
      action: :replace,
      target: target,
      partial: partial,
      locals: { as => part }
    )
  end

  def broadcast_remove(stream, target:)
    Turbo::StreamsChannel.broadcast_action_to(
      stream,
      action: :remove,
      target: target
    )
  end
end
```

#### Example Broadcaster

```ruby
# app/broadcasters/incident_broadcaster.rb
# frozen_string_literal: true

class IncidentBroadcaster < BaseBroadcaster
  def created(incident)
    broadcast_prepend(
      stream_name(incident.race_id),
      target: "incidents",
      partial: "incidents/incident",
      struct: incident,
      as: :incident
    )
  end

  def updated(incident)
    broadcast_replace(
      stream_name(incident.race_id),
      target: "incident_#{incident.id}",
      partial: "incidents/incident",
      struct: incident,
      as: :incident
    )
  end

  def deleted(incident)
    broadcast_remove(
      stream_name(incident.race_id),
      target: "incident_#{incident.id}"
    )
  end

  private

  def stream_name(race_id)
    "race_#{race_id}_incidents"
  end
end
```

---

### Stimulus Controllers

Stimulus controllers live in `app/javascript/controllers/` (Rails default).

Keep it simple — flat structure for a small app.

```javascript
// app/javascript/controllers/flash_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { dismissAfter: { type: Number, default: 5000 } }

  connect() {
    if (this.dismissAfterValue > 0) {
      setTimeout(() => this.dismiss(), this.dismissAfterValue)
    }
  }

  dismiss() {
    this.element.classList.add("opacity-0", "transition-opacity")
    setTimeout(() => this.element.remove(), 300)
  }
}
```

```javascript
// app/javascript/controllers/presence_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { channel: String }

  connect() {
    // Subscribe to presence channel for real-time "who's online"
    this.subscription = this.createSubscription()
  }

  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
  }

  createSubscription() {
    // ActionCable subscription logic
  }
}
```

---

## Real-Time Architecture

### Data Flow for Real-Time Updates

```
User Action (HTTP Request)
    ↓
Controller calls Operation
    ↓
Operation executes business logic
    ↓
Operation returns Success(struct) or Failure(error)
    ↓
Controller handles result:
    ├── On Success: Call Broadcaster, redirect
    └── On Failure: Render form with errors
    ↓
Broadcaster wraps struct in Part
    ↓
Broadcaster renders partial with Part
    ↓
Turbo Stream broadcast to all subscribed clients
    ↓
Clients receive HTML, Turbo applies DOM update
```

### Subscribing to Streams

In templates, subscribe to streams with `turbo_stream_from`:

```erb
<%# app/web/templates/races/show.html.erb %>
<%= turbo_stream_from "race_#{@race.id}_incidents" %>

<div id="incidents">
  <%= render partial: "incidents/incident", collection: @incidents, as: :incident %>
</div>
```

### Multi-User Collaboration

For race officials seeing real-time updates:

1. **Subscribe** — Each client subscribes to `race_#{id}_incidents`
2. **Create** — When any official creates an incident:
   - Operation creates the record
   - Controller calls `IncidentBroadcaster.created(incident)`
   - All subscribed clients see the new incident appear
3. **Update/Delete** — Same pattern with `updated`/`deleted`

---

## Turbo Native Support

### Variant Detection

```ruby
# app/web/controllers/application_controller.rb

before_action :set_variant

private

def set_variant
  request.variant = :turbo_native if turbo_native_app?
end

def turbo_native_app?
  request.user_agent.to_s.include?("Turbo Native")
end
```

### Template Variants

Rails automatically picks the right template:

| Request | Template Used |
|---------|---------------|
| Web browser | `index.html.erb` |
| Turbo Native | `index.turbo_native.html.erb` (falls back to `index.html.erb`) |

### Layout Variants

```erb
<%# app/web/templates/layouts/application.html.erb (WEB) %>
<!DOCTYPE html>
<html>
<head>
  <%= render "shared/head" %>
</head>
<body>
  <%= render "shared/navbar" %>
  <%= render "shared/flash" %>
  <main class="container">
    <%= yield %>
  </main>
  <%= render "shared/footer" %>
</body>
</html>
```

```erb
<%# app/web/templates/layouts/application.turbo_native.html.erb (NATIVE) %>
<!DOCTYPE html>
<html>
<head>
  <%= render "shared/head" %>
</head>
<body class="turbo-native">
  <%# No navbar — native app provides navigation %>
  <%= render "shared/flash" %>
  <main class="native-container">
    <%= yield %>
  </main>
  <%# No footer — native app provides bottom nav %>
</body>
</html>
```

### Shared Partials Pattern

Most partials work for both web and native:

```erb
<%# app/web/templates/incidents/index.html.erb (WEB) %>
<div class="page-header">
  <h1>Incidents</h1>
  <div class="breadcrumbs">...</div>
</div>
<%= render "incidents/list", incidents: @incidents %>

<%# app/web/templates/incidents/index.turbo_native.html.erb (NATIVE) %>
<div class="native-page-header">
  <h1>Incidents</h1>
</div>
<%= render "incidents/list", incidents: @incidents %>  <%# Same partial! %>
```

---

## Dependency Injection

### Container Registration

```ruby
# config/initializers/container.rb

class AppContainer
  extend Dry::Container::Mixin

  # ... existing repos ...

  # Parts
  namespace :parts do
    register :factory, memoize: true do
      Web::Parts::Factory.new
    end
  end

  # Broadcasters
  namespace :broadcasters do
    register :incident, memoize: true do
      IncidentBroadcaster.new
    end

    register :user, memoize: true do
      UserBroadcaster.new
    end
  end
end

Import = Dry::AutoInject(AppContainer)
```

### Usage

```ruby
# In broadcasters (via base class)
class IncidentBroadcaster < BaseBroadcaster
  include Import["parts.factory"]  # Injected as `factory`
end

# In controllers (explicit lookup)
def incident_broadcaster
  @incident_broadcaster ||= AppContainer["broadcasters.incident"]
end

def parts_factory
  @parts_factory ||= AppContainer["parts.factory"]
end
```

---

## Data Flow

### Complete Request Flow

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   Browser   │────▶│  Controller │────▶│  Operation  │
└─────────────┘     └─────────────┘     └─────────────┘
                           │                   │
                           │                   ▼
                           │            ┌─────────────┐
                           │            │    Repo     │
                           │            └─────────────┘
                           │                   │
                           │                   ▼
                           │            ┌─────────────┐
                           │            │   Struct    │
                           │            └─────────────┘
                           │                   │
                           ▼                   │
                    ┌─────────────┐            │
                    │ Broadcaster │◀───────────┘
                    └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │    Part     │
                    │  (Factory)  │
                    └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │  Template   │
                    │  (Partial)  │
                    └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │Turbo Stream │
                    │ (Broadcast) │
                    └─────────────┘
                           │
                           ▼
                    ┌─────────────┐
                    │ All Clients │
                    └─────────────┘
```

### Object Transformation

| Layer | Object Type | Example |
|-------|-------------|---------|
| Database | ActiveRecord | `User` |
| Repo | Struct | `Structs::User` |
| Operation | Struct | `Structs::User` |
| Broadcaster | Part | `Web::Parts::User` |
| Template | Part | `Web::Parts::User` |

---

## Implementation Plan

### Phase 1: Fix Immediate Issues

- [ ] Create missing `flash_controller.js`
- [ ] Fix `UsersController` (broken `Infrastructure::Persistence::Records` reference)
- [ ] Fix `DashboardController` to use repos

### Phase 2: Create Parts Infrastructure

- [ ] Create `app/web/parts/` directory
- [ ] Create `Web::Parts::Base`
- [ ] Create `Web::Parts::Factory`
- [ ] Create `Web::Parts::User`
- [ ] Register factory in container

### Phase 3: Create Broadcasters Infrastructure

- [ ] Create `app/broadcasters/` directory
- [ ] Create `BaseBroadcaster`
- [ ] Create `IncidentBroadcaster` (template for future)
- [ ] Register broadcasters in container

### Phase 4: Move Templates

- [ ] Create `app/web/templates/` directory
- [ ] Move `app/views/` → `app/web/templates/`
- [ ] Configure Rails view paths
- [ ] Add Turbo Native layout variant

### Phase 5: Update Controllers

- [ ] Update controllers to use Parts Factory
- [ ] Update controllers to use Broadcasters
- [ ] Add Turbo Native variant detection

---

## Quick Reference

### Parts vs Structs

| Concern | Location | Example |
|---------|----------|---------|
| Domain logic | Struct | `user.can_officialize_incident?` |
| Presentation | Part | `user.role_badge`, `user.avatar_initials` |
| Query | Repo | `user_repo.admins` |
| Business flow | Operation | `Operations::Users::Create` |

### When to Use What

| Need | Use |
|------|-----|
| Format a date for display | Part method |
| Check user permissions | Struct method |
| Fetch data from DB | Repo method |
| Create/update with validation | Operation |
| Broadcast real-time update | Broadcaster |
| Complex UI component | Part + Partial |

### Template Naming

| Type | Path |
|------|------|
| Layout (web) | `app/web/templates/layouts/application.html.erb` |
| Layout (native) | `app/web/templates/layouts/application.turbo_native.html.erb` |
| Page template | `app/web/templates/incidents/index.html.erb` |
| Partial | `app/web/templates/incidents/_incident.html.erb` |
| Shared partial | `app/web/templates/shared/_flash.html.erb` |

### Container Keys

| Key | Class |
|-----|-------|
| `parts.factory` | `Web::Parts::Factory` |
| `broadcasters.incident` | `IncidentBroadcaster` |
| `broadcasters.user` | `UserBroadcaster` |
| `repos.user` | `UserRepo` |
| `repos.incident` | `IncidentRepo` |

---

**Architecture Version**: 1.0  
**Last Updated**: 2025  
**Status**: Approved  
**Related**: [Hanami Hybrid Architecture](./hanami-hybrid-architecture.md)