# Feature: FOP Real-Time Performance & Notifications

## Overview

High-performance Field of Play (FOP) interface with real-time incident notifications via Action Cable. This feature ensures sub-second response times for bib number selection on FOP devices (creation only) and live notifications on desktop devices (viewing only).

---

## Key Constraints (Clarified)

| Constraint | Value | Impact |
|------------|-------|--------|
| **Max athletes per race** | 200 | Client-side bib grid is trivial, no pagination |
| **Active bibs vary by stage** | Quali=all (200), Sprint Finals=8 | Heat-based filtering |
| **Duplicate reports** | Allowed, grouped into incidents | No uniqueness constraint |
| **Stale reports** | Hidden after ~5 min if not processed | Background job marks stale |
| **FOP devices** | Creation only (7", iPad, phone) | No incident list, just bib selector |
| **Desktop devices** | Viewing only | Full dashboard, Action Cable notifications |
| **Video** | Added AFTER report creation | Two-step: create report, then attach video |

---

## Requirements Summary

### User Stories

1. **As a field referee (FOP device)**, I need to quickly select a bib number (under 100ms) so I can log reports without delay during a race.
2. **As a VAR operator (desktop)**, I need to see reports displayed instantly so I can review video evidence promptly.
3. **As a jury president (desktop)**, I need to be notified in real-time when new reports are logged so I don't miss any during a race.
4. **As a field referee**, I need the interface to work smoothly on a 7" display with large touch targets.

### Acceptance Criteria

#### FOP Devices (Creation Only)
- [ ] Bib number selection responds in < 100ms (max 200 bibs, often just 8 in finals)
- [ ] Report creation appears instant (< 100ms perceived, optimistic UI)
- [ ] Works offline with IndexedDB queue
- [ ] Touch-optimized for 7" displays (56px minimum touch targets)
- [ ] No incident/report list (creation only)

#### Desktop Devices (Viewing Only)
- [ ] Report list loads in < 300ms with 100+ reports
- [ ] Real-time notifications appear within 1 second of report creation
- [ ] "New reports since page load" banner with count
- [ ] Toast notifications for new reports (dismissible)
- [ ] Badge counter updates on navigation items
- [ ] Report → Incident grouping workflow

### Environment Simplification

**Development**: `localhost:3003` (Docker Compose)
**Production**: `pi5main.local` (Raspberry Pi 5 via Kamal)

> ⚠️ No staging environment - test thoroughly in development before production deploy.

---

## Technical Approach

### 1. Bib Number Selection - Client-Side Performance (FOP Devices Only)

**Strategy**: Pre-load active bibs for current heat at page load, filter entirely client-side with Stimulus.

**Scale**: Max 200 bibs (qualification), as few as 8 (sprint finals) - trivial for client-side.

```
┌─────────────────────────────────────────────────────────────────────────┐
│  BIB NUMBER QUICK SELECT                     [8 athletes in Final]      │
├─────────────────────────────────────────────────────────────────────────┤
│  [___________] Search/Filter                                            │
│                                                                         │
│  Sprint Final (8 athletes):                                             │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                                   │
│  │  12  │ │  34  │ │  56  │ │  78  │                                   │
│  │ SUI  │ │ FRA  │ │ ITA  │ │ AUT  │                                   │
│  └──────┘ └──────┘ └──────┘ └──────┘                                   │
│  ┌──────┐ ┌──────┐ ┌──────┐ ┌──────┐                                   │
│  │  23  │ │  45  │ │  67  │ │  89  │                                   │
│  │ ESP  │ │ GER  │ │ NOR  │ │ SWE  │                                   │
│  └──────┘ └──────┘ └──────┘ └──────┘                                   │
│                                                                         │
│  Recent: [34] [12]                                                     │
└─────────────────────────────────────────────────────────────────────────┘
```

**Implementation**:
- Load only `active_in_heat` bibs as JSON in initial HTML
- Stimulus controller for instant filtering (< 10ms for 200 bibs)
- Recently selected bibs stored in localStorage
- Heat label shown: "8 athletes in Final" or "156 athletes in Qualification"

### 2. Report/Incident Display - Desktop Only

**Strategy**: Eager loading, fragment caching, Turbo Frames for partial updates. Only shown on desktop devices.

```ruby
# Eager loading to prevent N+1
Race.includes(
  reports: [:race_location, :participant, :user, :incident]
)

# Fragment caching for report cards
# app/views/reports/_report.html.erb
<% cache [report, report.updated_at] do %>
  <%= render Fop::ReportCardComponent.new(report: report) %>
<% end %>

# Scope for desktop view (hide stale reports)
Report.active.for_desktop_view
```

### 3. Real-Time Notifications - Action Cable (Solid Cable) - Desktop Only

**Strategy**: Race-scoped channels with targeted broadcasts. FOP devices don't subscribe - they only create.

```
┌──────────────────┐     ┌─────────────────┐     ┌──────────────────┐
│   Referee A      │     │   Rails Server  │     │   Desktop        │
│   (FOP Device)   │     │   (Pi5)         │     │   (VAR/Jury)     │
├──────────────────┤     ├─────────────────┤     ├──────────────────┤
│                  │     │                 │     │                  │
│  Creates        ─┼────►│  Saves to DB   ─┼────►│  Receives Toast  │
│  Report          │     │  Broadcasts     │     │  Notification    │
│                  │     │                 │     │                  │
│  (no receive)    │     │  ReportsChannel │     │  Badge Updates   │
│                  │     │  race_123       │     │  Live Report List│
└──────────────────┘     └─────────────────┘     └──────────────────┘
```

**Note**: FOP devices (7", iPad, phone) do NOT receive notifications - they only create reports.
Desktop devices receive all notifications and see live updates.

**Channel Architecture**:
```ruby
# app/channels/reports_channel.rb
class ReportsChannel < ApplicationCable::Channel
  def subscribed
    @race = Race.find(params[:race_id])
    stream_for @race
  end
end
```

**Broadcast on Create**:
```ruby
# app/models/report.rb
after_create_commit :broadcast_new_report

def broadcast_new_report
  ReportsChannel.broadcast_to(
    race,
    {
      type: "new_report",
      report_id: id,
      bib_number: bib_number,
      athlete_name: participant&.athlete_name,
      location: race_location&.name,
      timestamp: created_at.iso8601,
      html: ApplicationController.render(
        partial: "reports/report",
        locals: { report: self }
      )
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

### Phase 2: Bib Number Quick Select Component (FOP Devices Only)

#### Task 2.1: Create Bib Number Stimulus Controller
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/javascript/controllers/bib_selector_controller.js`
- **Details**:
  ```javascript
  // Stimulus controller with:
  // - targets: input, grid, recentList, heatLabel
  // - values: participants (Array), locationId, raceId
  // - filter() - instant client-side filter (< 10ms for 200 bibs)
  // - select(bib) - create report and close modal
  // - loadRecent() - from localStorage
  // - saveRecent(bib) - to localStorage (max 5)
  // - NO subscription to channels (creation only)
  ```
- **Performance Target**: Filter 200 bibs in < 10ms, open modal in < 50ms
- **Scale**: Often just 8 bibs (sprint final) - trivial
- **Dependencies**: Phase 1

#### Task 2.2: Create BibSelectorComponent (ViewComponent)
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/fop/bib_selector_component.rb`
- **Details**:
  - Accepts race and location
  - Preloads only `active_in_heat` participants (8-200)
  - Renders as JSON in data attribute (no extra request)
  - Touch-optimized grid layout (56px targets)
  - Shows heat label: "8 athletes in Final"
  - Optimistic UI: report created immediately, syncs in background
- **Dependencies**: Task 2.1

#### Task 2.3: Write Bib Selector Tests
- **Owner**: Developer
- **Agent**: @rspec
- **Files**:
  - `spec/components/fop/bib_selector_component_spec.rb`
  - `spec/system/bib_selection_spec.rb` (with Capybara)
- **Details**:
  - Test grid rendering with 8 bibs (sprint final)
  - Test grid rendering with 200 bibs (qualification)
  - Test heat filtering (only active_in_heat shown)
  - Test recent selections persistence
  - Test filtering performance (< 100ms assertion)
  - Test report creation via bib tap
- **Dependencies**: Task 2.2

---

### Phase 3: Report/Incident Display Optimization (Desktop Only)

#### Task 3.1: Add Database Indexes for Performance
- **Owner**: Developer
- **Agent**: @model
- **File**: `db/migrate/XXXXXX_add_report_performance_indexes.rb`
- **Details**:
  ```ruby
  add_index :reports, [:race_id, :created_at], order: { created_at: :desc }
  add_index :reports, [:race_id, :status]
  add_index :reports, :stale_at
  add_index :reports, :bib_number
  add_index :incidents, [:race_id, :created_at], order: { created_at: :desc }
  add_index :incidents, [:race_id, :status]
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

#### Task 3.3: Create Optimized Report Query Service
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/services/reports/list_for_race.rb`
- **Details**:
  ```ruby
  # Uses dry-monads
  # Eager loads all associations
  # Returns Success(reports) with pagination
  # Filters: active only (not stale), by location, by bib
  # Query time target: < 50ms for 100 reports
  # Desktop only - not used on FOP devices
  ```
- **Dependencies**: Task 3.2

#### Task 3.4: Create Report Card Component with Caching (Desktop)
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/fop/report_card_component.rb`
- **Details**:
  - Fragment cached by report + updated_at
  - Displays: bib, athlete name, location, time, status badge
  - Desktop actions (review, group into incident, mark stale)
  - Color-coded by status (pending=yellow, reviewed=green, stale=gray)
  - NOT used on FOP devices
- **Dependencies**: Task 3.3

#### Task 3.5: Write Report Display Tests
- **Owner**: Developer
- **Agent**: @rspec
- **Files**:
  - `spec/components/fop/report_card_component_spec.rb`
  - `spec/services/reports/list_for_race_spec.rb`
- **Details**:
  - Test caching behavior
  - Test eager loading (no N+1 with Bullet gem)
  - Test query performance
  - Test stale reports are excluded from active view
- **Dependencies**: Task 3.4

---

### Phase 4: Action Cable Real-Time Notifications (Desktop Only)

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

#### Task 4.2: Create ReportsChannel (Desktop Only)
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/channels/reports_channel.rb`
- **Details**:
  ```ruby
  # Only desktop devices subscribe to this channel
  # FOP devices (7", iPad, phone) do NOT subscribe
  class ReportsChannel < ApplicationCable::Channel
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

#### Task 4.4: Add Broadcast Callbacks to Report Model
- **Owner**: Developer
- **Agent**: @model
- **File**: `app/models/report.rb`
- **Details**:
  ```ruby
  # Broadcasts to desktop devices only (they subscribe to ReportsChannel)
  after_create_commit :broadcast_created
  after_update_commit :broadcast_updated
  
  private
  
  def broadcast_created
    broadcast_report_change("created")
  end
  
  def broadcast_updated
    broadcast_report_change("updated")
  end
  
  def broadcast_report_change(action)
    ReportsChannel.broadcast_to(race, {
      action: action,
      report: ReportSerializer.new(self).as_json,
      bib_number: bib_number,
      athlete_name: participant&.athlete_name,
      html: ApplicationController.render(
        partial: "reports/report",
        locals: { report: self }
      )
    })
  end
  ```
- **Dependencies**: Task 4.3

#### Task 4.5: Create Client-Side Reports Subscription (Desktop Only)
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/javascript/channels/reports_channel.js`
- **Details**:
  ```javascript
  import consumer from "./consumer"
  
  // Only used on desktop devices
  // FOP devices do NOT include this subscription
  export function subscribeToRace(raceId, callbacks) {
    return consumer.subscriptions.create(
      { channel: "ReportsChannel", race_id: raceId },
      {
        received(data) {
          if (data.action === "created") {
            callbacks.onNewReport(data)
          } else if (data.action === "updated") {
            callbacks.onReportUpdated(data)
          }
        }
      }
    )
  }
  ```
- **Dependencies**: Task 4.4

#### Task 4.6: Create Notifications Stimulus Controller (Desktop Only)
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/javascript/controllers/report_notifications_controller.js`
- **Details**:
  - Only loaded on desktop views (not FOP)
  - Connects to ReportsChannel on connect()
  - Shows toast notification for new reports
  - Updates badge counters
  - Shows "X new reports" banner
  - Stores initial report count for comparison
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
  - `spec/channels/reports_channel_spec.rb`
  - `spec/channels/connection_spec.rb`
  - `spec/system/realtime_notifications_spec.rb`
- **Details**:
  - Test channel subscription (desktop only)
  - Test broadcast on report create
  - Test authorization (reject unauthorized)
  - System test: FOP creates, desktop receives notification
- **Dependencies**: Task 4.7

---

### Phase 5: "New Reports" Banner Component (Desktop Only)

#### Task 5.1: Create New Reports Banner Component
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/fop/new_reports_banner_component.rb`
- **Details**:
  - Hidden by default
  - Shows: "3 new reports since you opened this page"
  - Click to refresh report list (Turbo Frame)
  - Dismiss button
  - Sticky at top of report list
  - Desktop only - not used on FOP devices
- **Dependencies**: Phase 4

#### Task 5.2: Create Banner Stimulus Controller (Desktop)
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/javascript/controllers/new_reports_banner_controller.js`
- **Details**:
  - Tracks count of new reports
  - Shows/hides banner based on count
  - Refreshes Turbo Frame on click
  - Resets counter after refresh
  - Only loaded on desktop views
- **Dependencies**: Task 5.1

#### Task 5.3: Integrate with Turbo Frames (Desktop View)
- **Owner**: Developer
- **Agent**: Direct edit
- **File**: `app/views/races/show.html.erb` (desktop layout)
- **Details**:
  ```erb
  <%# Desktop view only - FOP devices get a different view %>
  <%= turbo_frame_tag "reports_list", 
      src: race_reports_path(@race), 
      loading: :lazy do %>
    <%= render "shared/loading_spinner" %>
  <% end %>
  
  <div data-controller="report-notifications new-reports-banner"
       data-report-notifications-race-id-value="<%= @race.id %>">
    <!-- Banner appears here when new reports arrive -->
  </div>
  ```
- **Dependencies**: Task 5.2

#### Task 5.4: Write Banner Tests
- **Owner**: Developer
- **Agent**: @rspec
- **Files**:
  - `spec/components/fop/new_reports_banner_component_spec.rb`
  - `spec/system/new_reports_banner_spec.rb`
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

| Endpoint | Target | Device | Method |
|----------|--------|--------|--------|
| `GET /races/:id` (FOP) | < 100ms | FOP | Minimal view, pre-loaded bibs |
| `GET /races/:id` (Desktop) | < 200ms | Desktop | Eager loading, caching |
| `GET /races/:id/reports` | < 300ms | Desktop | Fragment caching, pagination |
| `POST /reports` | < 100ms perceived | FOP | Optimistic UI, background sync |
| `Action Cable broadcast` | < 100ms | Desktop | Solid Cable with 100ms polling |
| Bib modal open | < 50ms | FOP | Pre-loaded JSON, no network |
| Bib filter (client) | < 10ms | FOP | Pure JavaScript (max 200 bibs) |

---

## Risks & Considerations

### Performance Risks

| Risk | Mitigation |
|------|------------|
| N+1 queries | Bullet gem, eager loading |
| Slow Pi5 | Fragment caching, optimized queries |
| WebSocket overhead | Solid Cable (DB-backed, efficient), desktop only |
| ~~Large bib lists~~ | **Max 200 bibs** - trivial for client-side |
| Sprint finals | Only 8 bibs - instant |

### Real-Time Risks

| Risk | Mitigation |
|------|------------|
| Missed broadcasts | Client polls on reconnect (desktop only) |
| Connection drops | Auto-reconnect with exponential backoff |
| Stale data | Timestamp comparison, refresh on reconnect |
| Concurrent edits | Duplicates allowed, grouped into incidents |
| FOP offline | IndexedDB queue, sync on reconnect |

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

### FOP Devices (Creation)
1. **Bib Modal Open**: 95th percentile < 50ms
2. **Bib Selection**: 95th percentile < 100ms perceived
3. **Offline Queue**: Reports sync within 30s of reconnection
4. **User Experience**: Zero failed report creations during race

### Desktop Devices (Viewing)
1. **Report List**: 95th percentile < 300ms for 100 reports
2. **Real-Time Delivery**: 95th percentile < 1 second notification delay
3. **User Experience**: Zero missed reports during race
4. **Uptime**: 99.9% during race events

---

## Appendix: Component Diagram

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    FOP DEVICE (7", iPad, Phone)                          │
│                         CREATION ONLY                                    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ BibSelector Component                                            │   │
│  │                                                                  │   │
│  │ Stimulus: bib_selector                                          │   │
│  │ - Pre-loaded participants (8-200)                               │   │
│  │ - Client-side filter                                            │   │
│  │ - Creates report on tap                                         │   │
│  │ - NO channel subscription                                       │   │
│  └──────────────────────────────┬──────────────────────────────────┘   │
│                                 │                                       │
│                                 │ POST /reports (optimistic)            │
│                                 │ + IndexedDB queue for offline         │
│                                 │                                       │
└─────────────────────────────────┼───────────────────────────────────────┘
                                  │
                                  │
                                  v
┌─────────────────────────────────────────────────────────────────────────┐
│                         Rails Server (Pi5)                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐     │
│  │ ReportsChannel  │  │ Report Model    │  │ ListForRace Service │     │
│  │                 │  │                 │  │                     │     │
│  │ stream_for race │◄─┤ after_commit    │  │ Eager loading       │     │
│  │ broadcast_to    │  │ broadcast       │  │ Fragment caching    │     │
│  └────────┬────────┘  └─────────────────┘  └─────────────────────┘     │
│           │                                                             │
│           │ WebSocket (desktop only)                                   │
│           │                                                             │
│  ┌────────┴────────────────────────────────────────────────────────┐   │
│  │                     Solid Cable (PostgreSQL)                     │   │
│  │                     polling_interval: 0.1s                       │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  │ WebSocket
                                  v
┌─────────────────────────────────────────────────────────────────────────┐
│                         DESKTOP DEVICE                                   │
│                         VIEWING ONLY                                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐     │
│  │ ReportList      │  │ NewReportsBanner│  │ NotificationToast   │     │
│  │ Component       │  │ Component       │  │ Component           │     │
│  │                 │  │                 │  │                     │     │
│  │ Turbo Frame     │  │ Shows count of  │  │ Appears on new      │     │
│  │ reports_list    │  │ new reports     │  │ report received     │     │
│  └────────┬────────┘  └────────┬────────┘  └──────────┬──────────┘     │
│           │                    │                      │                │
│           └────────────────────┴──────────────────────┘                │
│                                │                                       │
│                                v                                       │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │              Stimulus: report_notifications                      │   │
│  │                                                                  │   │
│  │  - Subscribes to ReportsChannel                                 │   │
│  │  - Receives broadcasts                                          │   │
│  │  - Triggers toast and banner updates                            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```
