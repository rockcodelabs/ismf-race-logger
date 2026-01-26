# Feature: FOP Real-Time Performance & Notifications

## Overview

High-performance Field of Play (FOP) interface with real-time incident notifications via Action Cable. This feature ensures sub-second response times for bib number selection, instant incident display, and live notifications when other users add incidents.

---

## Requirements Summary

### User Stories

1. **As a referee**, I need to quickly select a bib number (under 200ms) so I can log incidents without delay during a race.
2. **As a VAR operator**, I need to see incidents displayed instantly so I can review video evidence promptly.
3. **As a jury president**, I need to be notified in real-time when new incidents are logged so I don't miss any during a race.
4. **As a field referee**, I need the interface to work smoothly on a 7" display with touch targets.

### Acceptance Criteria

- [ ] Bib number selection responds in < 200ms (client-side filtering)
- [ ] Incident list loads in < 500ms with 100+ incidents
- [ ] Real-time notifications appear within 1 second of incident creation
- [ ] "New incidents since page load" banner with count
- [ ] Toast notifications for new incidents (dismissible)
- [ ] Badge counter updates on navigation items
- [ ] Works offline-first with sync when connection restored (PWA)
- [ ] Touch-optimized for 7" displays (44px minimum touch targets)

### Environment Simplification

**Development**: `localhost:3003` (Docker Compose)
**Production**: `pi5main.local` (Raspberry Pi 5 via Kamal)

> ⚠️ No staging environment - test thoroughly in development before production deploy.

---

## Technical Approach

### 1. Bib Number Selection - Client-Side Performance

**Strategy**: Pre-load all bib numbers at page load, filter entirely client-side with Stimulus.

```
┌─────────────────────────────────────────────────────────┐
│  BIB NUMBER QUICK SELECT                                │
├─────────────────────────────────────────────────────────┤
│  [___________] Search/Filter                            │
│                                                         │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐     │
│  │ 1  │ │ 2  │ │ 3  │ │ 4  │ │ 5  │ │ 6  │ │ 7  │     │
│  └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘     │
│  ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐ ┌────┐     │
│  │ 8  │ │ 9  │ │ 10 │ │ 11 │ │ 12 │ │ 13 │ │ 14 │     │
│  └────┘ └────┘ └────┘ └────┘ └────┘ └────┘ └────┘     │
│                                                         │
│  Recent: [42] [17] [88]                                │
└─────────────────────────────────────────────────────────┘
```

**Implementation**:
- Load bib numbers as JSON in initial HTML (no extra request)
- Stimulus controller for instant filtering
- Recently selected bibs stored in localStorage
- Numeric keypad option for quick entry

### 2. Incident Display - Server-Side Optimization

**Strategy**: Eager loading, fragment caching, Turbo Frames for partial updates.

```ruby
# Eager loading to prevent N+1
Race.includes(
  incidents: [:race_location, :reports, { reports: :user }]
)

# Fragment caching for incident cards
# app/views/incidents/_incident.html.erb
<% cache [incident, incident.updated_at] do %>
  <%= render Fop::IncidentCardComponent.new(incident: incident) %>
<% end %>
```

### 3. Real-Time Notifications - Action Cable (Solid Cable)

**Strategy**: Race-scoped channels with targeted broadcasts.

```
┌──────────────────┐     ┌─────────────────┐     ┌──────────────────┐
│   Referee A      │     │   Rails Server  │     │   Referee B      │
│   (iPad)         │     │   (Pi5)         │     │   (7" Display)   │
├──────────────────┤     ├─────────────────┤     ├──────────────────┤
│                  │     │                 │     │                  │
│  Creates        ─┼────►│  Saves to DB   ─┼────►│  Receives Toast  │
│  Incident        │     │  Broadcasts     │     │  Notification    │
│                  │     │                 │     │                  │
│                  │     │  IncidentsChannel│    │  Badge Updates   │
│                  │     │  race_123        │     │                  │
└──────────────────┘     └─────────────────┘     └──────────────────┘
```

**Channel Architecture**:
```ruby
# app/channels/incidents_channel.rb
class IncidentsChannel < ApplicationCable::Channel
  def subscribed
    @race = Race.find(params[:race_id])
    stream_for @race
  end
end
```

**Broadcast on Create**:
```ruby
# app/models/incident.rb
after_create_commit :broadcast_new_incident

def broadcast_new_incident
  IncidentsChannel.broadcast_to(
    race,
    {
      type: "new_incident",
      incident_id: id,
      bib_number: bib_number,
      location: race_location.name,
      timestamp: created_at.iso8601,
      html: render_to_string(partial: "incidents/incident", locals: { incident: self })
    }
  )
end
```

---

## Implementation Plan

### Phase 1: Environment Configuration Updates

#### Task 1.1: Update Docker Compose for Port 3003
- **Owner**: Developer
- **Agent**: Direct edit
- **File**: `docker-compose.yml`
- **Details**:
  ```yaml
  services:
    app:
      ports:
        - "3003:3003"
      command: ./bin/thrust ./bin/rails server -p 3003 -b 0.0.0.0
  ```
- **Dependencies**: None

#### Task 1.2: Update Kamal Config for Production Only
- **Owner**: Developer
- **Agent**: Direct edit
- **File**: `config/deploy.yml`
- **Details**:
  - Remove staging destination
  - Configure production for Pi5
  - Set production port
- **Dependencies**: Task 1.1

#### Task 1.3: Remove Staging References
- **Owner**: Developer
- **Agent**: Direct edit
- **Files**: 
  - Delete `config/deploy.staging.yml`
  - Update `config/environments/` (remove staging.rb if exists)
  - Update `.kamal/secrets` to only have production secrets
- **Dependencies**: Task 1.2

---

### Phase 2: Bib Number Quick Select Component

#### Task 2.1: Create Bib Number Stimulus Controller
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/javascript/controllers/bib_selector_controller.js`
- **Details**:
  ```javascript
  // Stimulus controller with:
  // - targets: input, grid, recentList
  // - values: bibs (Array), recent (Array)
  // - filter() - instant client-side filter (< 10ms)
  // - select(bib) - select and emit event
  // - loadRecent() - from localStorage
  // - saveRecent(bib) - to localStorage (max 5)
  ```
- **Performance Target**: Filter 500 bibs in < 10ms
- **Dependencies**: Phase 1

#### Task 2.2: Create BibSelectorComponent (ViewComponent)
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/fop/bib_selector_component.rb`
- **Details**:
  - Accepts race and preloads all bib numbers
  - Renders as JSON in data attribute (no extra request)
  - Touch-optimized grid layout (44px targets)
  - Numeric keypad alternative mode
- **Dependencies**: Task 2.1

#### Task 2.3: Write Bib Selector Tests
- **Owner**: Developer
- **Agent**: @rspec
- **Files**:
  - `spec/components/fop/bib_selector_component_spec.rb`
  - `spec/system/bib_selection_spec.rb` (with Capybara)
- **Details**:
  - Test grid rendering
  - Test recent selections persistence
  - Test filtering performance (< 200ms assertion)
- **Dependencies**: Task 2.2

---

### Phase 3: Incident Display Optimization

#### Task 3.1: Add Database Indexes for Performance
- **Owner**: Developer
- **Agent**: @model
- **File**: `db/migrate/XXXXXX_add_incident_performance_indexes.rb`
- **Details**:
  ```ruby
  add_index :incidents, [:race_id, :created_at], order: { created_at: :desc }
  add_index :incidents, [:race_id, :status]
  add_index :reports, [:incident_id, :created_at]
  add_index :incidents, :race_location_id
  ```
- **Dependencies**: Phase 2

#### Task 3.2: Add Counter Caches
- **Owner**: Developer
- **Agent**: @model
- **File**: `db/migrate/XXXXXX_add_counter_caches.rb`
- **Details**:
  ```ruby
  # Add to races table
  add_column :races, :incidents_count, :integer, default: 0
  add_column :races, :official_incidents_count, :integer, default: 0
  
  # Add to incidents table
  add_column :incidents, :reports_count, :integer, default: 0
  ```
- **Dependencies**: Task 3.1

#### Task 3.3: Create Optimized Incident Query Service
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/incidents/operation/list_for_race.rb`
- **Details**:
  ```ruby
  # Uses dry-monads
  # Eager loads all associations
  # Returns Success(incidents) with pagination
  # Supports filtering by status, location, bib
  # Query time target: < 50ms for 100 incidents
  ```
- **Dependencies**: Task 3.2

#### Task 3.4: Create Incident Card Component with Caching
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/fop/incident_card_component.rb`
- **Details**:
  - Fragment cached by incident + updated_at
  - Displays: bib, location, time, status badge, report count
  - Touch-friendly actions (expand, edit)
  - Color-coded by status (unofficial=yellow, official=green)
- **Dependencies**: Task 3.3

#### Task 3.5: Write Incident Display Tests
- **Owner**: Developer
- **Agent**: @rspec
- **Files**:
  - `spec/components/fop/incident_card_component_spec.rb`
  - `spec/components/incidents/operation/list_for_race_spec.rb`
- **Details**:
  - Test caching behavior
  - Test eager loading (no N+1 with Bullet gem)
  - Test query performance
- **Dependencies**: Task 3.4

---

### Phase 4: Action Cable Real-Time Notifications

#### Task 4.1: Configure Solid Cable
- **Owner**: Developer
- **Agent**: Direct edit
- **File**: `config/cable.yml`
- **Details**:
  ```yaml
  development:
    adapter: solid_cable
    polling_interval: 0.1  # 100ms for quick updates
    
  production:
    adapter: solid_cable
    polling_interval: 0.1
    
  test:
    adapter: test
  ```
- **Dependencies**: Phase 3

#### Task 4.2: Create IncidentsChannel
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/channels/incidents_channel.rb`
- **Details**:
  ```ruby
  class IncidentsChannel < ApplicationCable::Channel
    def subscribed
      @race = Race.find(params[:race_id])
      authorize! :show, @race  # Pundit check
      stream_for @race
    end
    
    def unsubscribed
      stop_all_streams
    end
  end
  ```
- **Dependencies**: Task 4.1

#### Task 4.3: Create Connection Authentication
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/channels/application_cable/connection.rb`
- **Details**:
  ```ruby
  module ApplicationCable
    class Connection < ActionCable::Connection::Base
      identified_by :current_user
      
      def connect
        self.current_user = find_verified_user
      end
      
      private
      
      def find_verified_user
        if (user = User.find_by(id: cookies.encrypted[:user_id]))
          user
        else
          reject_unauthorized_connection
        end
      end
    end
  end
  ```
- **Dependencies**: Task 4.2

#### Task 4.4: Add Broadcast Callbacks to Incident Model
- **Owner**: Developer
- **Agent**: @model
- **File**: `app/models/incident.rb`
- **Details**:
  ```ruby
  after_create_commit :broadcast_created
  after_update_commit :broadcast_updated
  
  private
  
  def broadcast_created
    broadcast_incident_change("created")
  end
  
  def broadcast_updated
    broadcast_incident_change("updated")
  end
  
  def broadcast_incident_change(action)
    IncidentsChannel.broadcast_to(race, {
      action: action,
      incident: IncidentSerializer.new(self).as_json,
      html: ApplicationController.render(
        partial: "incidents/incident",
        locals: { incident: self }
      )
    })
  end
  ```
- **Dependencies**: Task 4.3

#### Task 4.5: Create Client-Side Incidents Subscription
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/javascript/channels/incidents_channel.js`
- **Details**:
  ```javascript
  import consumer from "./consumer"
  
  // Subscribe when entering race view
  export function subscribeToRace(raceId, callbacks) {
    return consumer.subscriptions.create(
      { channel: "IncidentsChannel", race_id: raceId },
      {
        received(data) {
          if (data.action === "created") {
            callbacks.onNewIncident(data)
          } else if (data.action === "updated") {
            callbacks.onIncidentUpdated(data)
          }
        }
      }
    )
  }
  ```
- **Dependencies**: Task 4.4

#### Task 4.6: Create Notifications Stimulus Controller
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/javascript/controllers/incident_notifications_controller.js`
- **Details**:
  - Connects to IncidentsChannel on connect()
  - Shows toast notification for new incidents
  - Updates badge counters
  - Shows "X new incidents" banner
  - Stores initial incident count for comparison
  - disconnect() unsubscribes from channel
- **Dependencies**: Task 4.5

#### Task 4.7: Create Toast Notification Component
- **Owner**: Developer
- **Agent**: @service
- **Files**:
  - `app/components/fop/toast_component.rb`
  - `app/javascript/controllers/toast_controller.js`
- **Details**:
  - Variants: success, warning, danger, info
  - Auto-dismiss after 5 seconds
  - Manual dismiss button
  - Stacks multiple toasts
  - Slide-in animation
- **Dependencies**: Task 4.6

#### Task 4.8: Write Action Cable Tests
- **Owner**: Developer
- **Agent**: @rspec
- **Files**:
  - `spec/channels/incidents_channel_spec.rb`
  - `spec/channels/connection_spec.rb`
  - `spec/system/realtime_notifications_spec.rb`
- **Details**:
  - Test channel subscription
  - Test broadcast on incident create
  - Test authorization (reject unauthorized)
  - System test with two browser sessions
- **Dependencies**: Task 4.7

---

### Phase 5: "New Incidents" Banner Component

#### Task 5.1: Create New Incidents Banner Component
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/fop/new_incidents_banner_component.rb`
- **Details**:
  - Hidden by default
  - Shows: "3 new incidents since you opened this page"
  - Click to refresh incident list (Turbo Frame)
  - Dismiss button
  - Sticky at top of incident list
- **Dependencies**: Phase 4

#### Task 5.2: Create Banner Stimulus Controller
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/javascript/controllers/new_incidents_banner_controller.js`
- **Details**:
  - Tracks count of new incidents
  - Shows/hides banner based on count
  - Refreshes Turbo Frame on click
  - Resets counter after refresh
- **Dependencies**: Task 5.1

#### Task 5.3: Integrate with Turbo Frames
- **Owner**: Developer
- **Agent**: Direct edit
- **File**: `app/views/races/show.html.erb`
- **Details**:
  ```erb
  <%= turbo_frame_tag "incidents_list", 
      src: race_incidents_path(@race), 
      loading: :lazy do %>
    <%= render "shared/loading_spinner" %>
  <% end %>
  
  <div data-controller="incident-notifications new-incidents-banner"
       data-incident-notifications-race-id-value="<%= @race.id %>">
    <!-- Banner appears here when new incidents arrive -->
  </div>
  ```
- **Dependencies**: Task 5.2

#### Task 5.4: Write Banner Tests
- **Owner**: Developer
- **Agent**: @rspec
- **Files**:
  - `spec/components/fop/new_incidents_banner_component_spec.rb`
  - `spec/system/new_incidents_banner_spec.rb`
- **Dependencies**: Task 5.3

---

### Phase 6: Performance Testing & Optimization

#### Task 6.1: Add Performance Monitoring
- **Owner**: Developer
- **Agent**: @service
- **Files**:
  - `config/initializers/performance_monitoring.rb`
  - `app/middleware/request_timing.rb`
- **Details**:
  - Log slow queries (> 100ms)
  - Log slow requests (> 500ms)
  - Track Action Cable message delivery time
- **Dependencies**: Phase 5

#### Task 6.2: Create Performance Test Suite
- **Owner**: Developer
- **Agent**: @rspec
- **File**: `spec/performance/fop_performance_spec.rb`
- **Details**:
  ```ruby
  # Using benchmark-ips or similar
  it "filters 500 bibs in under 10ms" do
    # Client-side JS test with Capybara
  end
  
  it "loads 100 incidents in under 500ms" do
    expect {
      get race_incidents_path(race_with_100_incidents)
    }.to perform_under(500).ms
  end
  
  it "broadcasts incident in under 100ms" do
    # Measure broadcast time
  end
  ```
- **Dependencies**: Task 6.1

#### Task 6.3: Add Bullet Gem for N+1 Detection
- **Owner**: Developer
- **Agent**: @model
- **File**: `Gemfile` (add to development/test)
- **Details**:
  ```ruby
  group :development, :test do
    gem 'bullet'
  end
  ```
  Configure to raise in test, notify in development
- **Dependencies**: Task 6.2

#### Task 6.4: Performance Optimization Pass
- **Owner**: Developer
- **Agent**: @debug
- **Details**:
  - Run performance tests
  - Fix any N+1 queries found by Bullet
  - Optimize slow queries
  - Add missing indexes
  - Tune Solid Cable polling interval
- **Dependencies**: Task 6.3

---

### Phase 7: Integration & Documentation

#### Task 7.1: Create FOP Performance Guide
- **Owner**: Developer
- **Agent**: Direct edit
- **File**: `docs/FOP_PERFORMANCE.md`
- **Details**:
  - Document caching strategy
  - Document Action Cable architecture
  - Performance benchmarks
  - Troubleshooting slow queries
- **Dependencies**: Phase 6

#### Task 7.2: Update Implementation Plan
- **Owner**: Developer
- **Agent**: Direct edit
- **File**: `docs/implementation-plan-rails-8.1.md`
- **Details**:
  - Update port from 3001 to 3003
  - Remove all staging references
  - Add real-time notification tasks
- **Dependencies**: Task 7.1

#### Task 7.3: Full Integration Test
- **Owner**: Developer
- **Agent**: @rspec
- **File**: `spec/system/fop_full_flow_spec.rb`
- **Details**:
  - Test complete flow: login → select race → select bib → log incident
  - Verify real-time notification in second browser
  - Test on simulated slow connection
  - Test PWA offline behavior
- **Dependencies**: Task 7.2

---

## Caching Strategy

### Fragment Caching

```ruby
# Incident card - cached by incident and timestamp
<% cache [incident, incident.updated_at] do %>
  <%= render Fop::IncidentCardComponent.new(incident: incident) %>
<% end %>

# Bib grid - cached by race and participants updated_at
<% cache [race, race.participants.maximum(:updated_at)] do %>
  <%= render Fop::BibSelectorComponent.new(race: race) %>
<% end %>
```

### Redis Caching (Optional Enhancement)

```ruby
# If fragment caching isn't fast enough, consider Redis:
Rails.cache.fetch("race_#{race.id}_bibs", expires_in: 1.hour) do
  race.participants.pluck(:bib_number).sort
end
```

### Client-Side Caching

```javascript
// LocalStorage for recent bibs
const RECENT_BIBS_KEY = 'fop_recent_bibs'
const MAX_RECENT = 5

function saveRecentBib(bib) {
  let recent = JSON.parse(localStorage.getItem(RECENT_BIBS_KEY) || '[]')
  recent = [bib, ...recent.filter(b => b !== bib)].slice(0, MAX_RECENT)
  localStorage.setItem(RECENT_BIBS_KEY, JSON.stringify(recent))
}
```

---

## Request Time Targets

| Endpoint | Target | Method |
|----------|--------|--------|
| `GET /races/:id` | < 200ms | Eager loading, caching |
| `GET /races/:id/incidents` | < 300ms | Fragment caching, pagination |
| `POST /incidents` | < 500ms | Optimistic UI, background broadcast |
| `Action Cable broadcast` | < 100ms | Solid Cable with 100ms polling |
| Bib filter (client) | < 10ms | Pure JavaScript filtering |

---

## Risks & Considerations

### Performance Risks

| Risk | Mitigation |
|------|------------|
| N+1 queries | Bullet gem, eager loading |
| Slow Pi5 | Fragment caching, optimized queries |
| WebSocket overhead | Solid Cable (DB-backed, efficient) |
| Large bib lists | Client-side filtering, pagination if > 500 |

### Real-Time Risks

| Risk | Mitigation |
|------|------------|
| Missed broadcasts | Client polls on reconnect |
| Connection drops | Auto-reconnect with exponential backoff |
| Stale data | Timestamp comparison, refresh on reconnect |
| Concurrent edits | Optimistic locking, last-write-wins for now |

### Production-Only Deployment Risk

| Risk | Mitigation |
|------|------------|
| No staging to test | Comprehensive test suite, feature flags |
| Breaking production | Blue-green deploy consideration, quick rollback |
| Data issues | Regular backups, migration testing in dev |

---

## Deployment Notes

### Environment Variables

```bash
# Production only (no staging)
RAILS_ENV=production
RACK_ENV=production
RAILS_MASTER_KEY=<from credentials>
DATABASE_URL=postgres://...
REDIS_URL=redis://...
ACTION_CABLE_ALLOWED_REQUEST_ORIGINS=https://race-logger.ismf-ski.com
```

### Port Configuration

```yaml
# Development: docker-compose.yml
ports:
  - "3003:3003"

# Production: Kamal
proxy:
  app_port: 3000  # Internal, Kamal proxy handles external
```

### Migration Checklist

- [ ] Run `db:migrate` for performance indexes
- [ ] Run `db:migrate` for counter caches
- [ ] Populate counter caches: `Race.find_each(&:reset_counters)`
- [ ] Verify Solid Cable tables exist
- [ ] Test WebSocket connectivity through Cloudflare

---

## Success Metrics

1. **Bib Selection**: 95th percentile < 200ms response
2. **Incident List**: 95th percentile < 500ms for 100 incidents
3. **Real-Time Delivery**: 95th percentile < 1 second notification delay
4. **User Experience**: Zero missed incidents reported by referees
5. **Uptime**: 99.9% during race events

---

## Appendix: Component Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                         FOP Interface                                │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐ │
│  │ BibSelector     │  │ IncidentList    │  │ NotificationToast   │ │
│  │ Component       │  │ Component       │  │ Component           │ │
│  │                 │  │                 │  │                     │ │
│  │ Stimulus:       │  │ Turbo Frame     │  │ Stimulus:           │ │
│  │ bib_selector    │  │ incidents_list  │  │ toast               │ │
│  └────────┬────────┘  └────────┬────────┘  └──────────┬──────────┘ │
│           │                    │                      │            │
│           │                    │                      │            │
│           v                    v                      v            │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │              Stimulus: incident_notifications               │   │
│  │                                                             │   │
│  │  - Subscribes to IncidentsChannel                          │   │
│  │  - Receives broadcasts                                      │   │
│  │  - Triggers toast and banner updates                        │   │
│  └──────────────────────────────┬──────────────────────────────┘   │
│                                 │                                  │
└─────────────────────────────────┼──────────────────────────────────┘
                                  │
                                  │ WebSocket
                                  v
┌─────────────────────────────────────────────────────────────────────┐
│                         Rails Server (Pi5)                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐ │
│  │ IncidentsChannel│  │ Incident Model  │  │ ListForRace Service │ │
│  │                 │  │                 │  │                     │ │
│  │ stream_for race │◄─┤ after_commit    │  │ Eager loading       │ │
│  │ broadcast_to    │  │ broadcast       │  │ Fragment caching    │ │
│  └─────────────────┘  └─────────────────┘  └─────────────────────┘ │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                     Solid Cable (PostgreSQL)                 │   │
│  │                     polling_interval: 0.1s                   │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```
