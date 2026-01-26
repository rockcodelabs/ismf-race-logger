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
| **Report grouping** | Desktop only, multi-select | Creates incident from 1+ reports |
| **Incident actions** | Apply/Reject/No Action | Only after officialization, touch-friendly |
| **Touch targets** | 56px minimum | All action buttons, checkboxes |

---

## Requirements Summary

### User Stories

1. **As a field referee (FOP device)**, I need to quickly select a bib number (under 100ms) so I can log reports without delay during a race.
2. **As a VAR operator (desktop)**, I need to see reports displayed instantly so I can review video evidence promptly.
3. **As a jury president (desktop)**, I need to be notified in real-time when new reports are logged so I don't miss any during a race.
4. **As a field referee**, I need the interface to work smoothly on a 7" display with large touch targets.
5. **As a jury member (desktop)**, I need to select multiple reports and group them into a single incident so I can consolidate related violations.
6. **As a jury president (desktop)**, I need to take action on an incident (apply penalty, reject, or mark as no action) so I can document decisions during the race.

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

#### Report Grouping & Incident Actions (Desktop Only)
- [ ] Multi-select reports with touch-friendly checkboxes (56px targets)
- [ ] Floating action bar appears when reports are selected
- [ ] "Group into Incident" creates incident and attaches selected reports
- [ ] Incident detail view shows all attached reports
- [ ] Three action buttons for officialized incidents:
  - [ ] **Apply Penalty** - Red button, marks penalty as applied
  - [ ] **Reject** - Gray button, marks incident as declined (no violation found)
  - [ ] **No Action** - Outline button, acknowledges incident but no penalty
- [ ] Visual feedback for completed decisions (status badges)
- [ ] Real-time broadcast of incident changes to other desktop clients

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

### Phase 8: Report Grouping & Incident Actions (Desktop Only)

This phase adds the ability to select multiple reports and group them into a single incident, then take action on that incident.

#### Task 8.1: Add Incident Status Enum Extension
- **Owner**: Developer
- **Agent**: @model
- **File**: `db/migrate/XXXXXX_add_no_action_to_incident_status.rb`
- **Details**:
  ```ruby
  # Extend official_status enum to support "no action" decisions
  # Current: pending, applied, declined
  # New: pending, applied, declined, no_action
  
  class AddNoActionToIncidentStatus < ActiveRecord::Migration[8.1]
    def up
      # PostgreSQL enum extension
      execute <<-SQL
        ALTER TYPE incident_official_status ADD VALUE IF NOT EXISTS 'no_action';
      SQL
    end
    
    def down
      # Enums cannot easily remove values in PostgreSQL
      # Would need to recreate the type
    end
  end
  ```
  
  Update model enum:
  ```ruby
  enum :official_status, {
    pending: "pending",
    applied: "applied",
    declined: "declined",
    no_action: "no_action"
  }, default: :pending, prefix: true
  ```
- **Dependencies**: Phase 7

#### Task 8.2: Create Report Selection Stimulus Controller
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/javascript/controllers/report_selection_controller.js`
- **Details**:
  ```javascript
  // Stimulus controller for multi-select reports
  // Desktop only - touch-friendly with large checkboxes
  
  import { Controller } from "@hotwired/stimulus"
  
  export default class extends Controller {
    static targets = ["checkbox", "selectAll", "actions", "count", "form"]
    static values = { 
      selectedIds: { type: Array, default: [] }
    }
    
    connect() {
      this.updateUI()
    }
    
    toggle(event) {
      const id = event.target.dataset.reportId
      if (event.target.checked) {
        this.selectedIdsValue = [...this.selectedIdsValue, id]
      } else {
        this.selectedIdsValue = this.selectedIdsValue.filter(i => i !== id)
      }
      this.updateUI()
    }
    
    selectAll(event) {
      const checked = event.target.checked
      this.checkboxTargets.forEach(cb => cb.checked = checked)
      this.selectedIdsValue = checked 
        ? this.checkboxTargets.map(cb => cb.dataset.reportId)
        : []
      this.updateUI()
    }
    
    updateUI() {
      const count = this.selectedIdsValue.length
      
      // Show/hide action bar
      this.actionsTarget.classList.toggle("hidden", count === 0)
      
      // Update count badge
      this.countTarget.textContent = count
      
      // Update select all checkbox state
      const allChecked = this.checkboxTargets.length > 0 && 
                         this.checkboxTargets.every(cb => cb.checked)
      this.selectAllTarget.checked = allChecked
      this.selectAllTarget.indeterminate = count > 0 && !allChecked
      
      // Update hidden form field
      this.formTarget.querySelector('[name="report_ids"]').value = 
        JSON.stringify(this.selectedIdsValue)
    }
    
    clearSelection() {
      this.checkboxTargets.forEach(cb => cb.checked = false)
      this.selectedIdsValue = []
      this.updateUI()
    }
  }
  ```
- **Touch-Friendly Design**:
  - Checkbox hitbox: 56px × 56px (touch-lg)
  - Swipe to select range (future enhancement)
  - Visual feedback on selection (card highlight)
- **Dependencies**: Task 8.1

#### Task 8.3: Create Report Selection Component (Desktop)
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/fop/report_selection_component.rb`
- **Details**:
  ```ruby
  # ViewComponent for selectable report cards
  module Fop
    class ReportSelectionComponent < ViewComponent::Base
      attr_reader :report, :selected
      
      def initialize(report:, selected: false)
        @report = report
        @selected = selected
      end
      
      def checkbox_classes
        # Large touch target
        "w-14 h-14 rounded-lg border-2 border-ismf-navy 
         checked:bg-ismf-navy checked:border-ismf-navy
         focus:ring-2 focus:ring-ismf-blue
         cursor-pointer transition-colors"
      end
      
      def card_classes
        base = "p-4 rounded-xl border-2 transition-all duration-200"
        selected ? "#{base} border-ismf-navy bg-ismf-navy/10" : "#{base} border-gray-200"
      end
    end
  end
  ```
  
  Template (`report_selection_component.html.erb`):
  ```erb
  <div class="<%= card_classes %>" 
       data-report-selection-target="card">
    <div class="flex items-center gap-4">
      <!-- Large checkbox for touch -->
      <input type="checkbox"
             class="<%= checkbox_classes %>"
             data-report-id="<%= report.id %>"
             data-action="change->report-selection#toggle"
             data-report-selection-target="checkbox"
             <%= "checked" if selected %>>
      
      <!-- Report summary -->
      <div class="flex-1 min-w-0">
        <div class="flex items-center gap-2">
          <span class="text-2xl font-bold text-ismf-navy">
            #<%= report.bib_number %>
          </span>
          <span class="text-lg text-gray-600">
            <%= report.participant&.athlete_name || "Unknown" %>
          </span>
        </div>
        <div class="text-sm text-gray-500 mt-1">
          <%= report.race_location&.name %> • 
          <%= time_ago_in_words(report.created_at) %> ago
        </div>
      </div>
      
      <!-- Status badge -->
      <%= render Fop::StatusBadgeComponent.new(status: report.status) %>
    </div>
  </div>
  ```
- **Dependencies**: Task 8.2

#### Task 8.4: Create Floating Action Bar Component
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/fop/floating_action_bar_component.rb`
- **Details**:
  ```ruby
  # Sticky bottom action bar that appears when reports are selected
  # Touch-friendly with large buttons (56px height)
  module Fop
    class FloatingActionBarComponent < ViewComponent::Base
      attr_reader :race
      
      def initialize(race:)
        @race = race
      end
    end
  end
  ```
  
  Template (`floating_action_bar_component.html.erb`):
  ```erb
  <%# Floating action bar - appears when reports selected %>
  <div class="fixed bottom-0 left-0 right-0 bg-white border-t-2 border-gray-200 
              shadow-lg transform transition-transform duration-300 z-50 hidden"
       data-report-selection-target="actions">
    <div class="max-w-4xl mx-auto p-4">
      <div class="flex items-center justify-between gap-4">
        <!-- Selection count -->
        <div class="flex items-center gap-2">
          <span class="bg-ismf-navy text-white rounded-full w-10 h-10 
                       flex items-center justify-center font-bold text-lg"
                data-report-selection-target="count">0</span>
          <span class="text-gray-600 font-medium">selected</span>
        </div>
        
        <!-- Group into Incident button -->
        <%= form_with url: race_incidents_path(race), 
                       method: :post,
                       data: { report_selection_target: "form", turbo_frame: "_top" } do |f| %>
          <%= f.hidden_field :report_ids, value: "[]" %>
          
          <%= f.submit "Group into Incident",
              class: "bg-ismf-navy text-white font-semibold py-4 px-6 
                      rounded-xl text-lg min-h-[56px] 
                      hover:bg-ismf-blue active:scale-95 
                      transition-all duration-150" %>
        <% end %>
        
        <!-- Clear selection -->
        <button type="button"
                class="text-gray-500 hover:text-gray-700 p-3"
                data-action="click->report-selection#clearSelection">
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M6 18L18 6M6 6l12 12"/>
          </svg>
        </button>
      </div>
    </div>
  </div>
  ```
- **Dependencies**: Task 8.3

#### Task 8.5: Create Incident Actions Component
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/components/fop/incident_actions_component.rb`
- **Details**:
  ```ruby
  # Three-button action panel for incident decisions
  # Touch-optimized with 56px buttons and clear visual states
  module Fop
    class IncidentActionsComponent < ViewComponent::Base
      attr_reader :incident
      
      def initialize(incident:)
        @incident = incident
      end
      
      def can_take_action?
        incident.official? && incident.official_status_pending?
      end
    end
  end
  ```
  
  Template (`incident_actions_component.html.erb`):
  ```erb
  <% if can_take_action? %>
    <div class="bg-gray-50 rounded-2xl p-6 mt-6">
      <h3 class="text-lg font-semibold text-gray-700 mb-4">Decision</h3>
      
      <div class="grid grid-cols-1 tablet:grid-cols-3 gap-4">
        <%# Apply Penalty Button - Primary action %>
        <%= button_to incident_apply_path(incident),
            method: :patch,
            class: "flex items-center justify-center gap-3 
                    bg-fop-danger text-white font-bold py-4 px-6 
                    rounded-xl min-h-[56px] text-lg
                    hover:bg-red-700 active:scale-95
                    transition-all duration-150
                    shadow-md hover:shadow-lg",
            data: { turbo_confirm: "Apply penalty to this incident?" } do %>
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z"/>
          </svg>
          <span>Apply Penalty</span>
        <% end %>
        
        <%# Reject Button - Secondary action %>
        <%= button_to incident_reject_path(incident),
            method: :patch,
            class: "flex items-center justify-center gap-3 
                    bg-gray-200 text-gray-700 font-bold py-4 px-6 
                    rounded-xl min-h-[56px] text-lg
                    hover:bg-gray-300 active:scale-95
                    transition-all duration-150",
            data: { turbo_confirm: "Reject this incident? (No violation found)" } do %>
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M6 18L18 6M6 6l12 12"/>
          </svg>
          <span>Reject</span>
        <% end %>
        
        <%# No Action Button - Tertiary action %>
        <%= button_to incident_no_action_path(incident),
            method: :patch,
            class: "flex items-center justify-center gap-3 
                    bg-gray-100 text-gray-600 font-semibold py-4 px-6 
                    rounded-xl min-h-[56px] text-lg border-2 border-gray-200
                    hover:bg-gray-200 active:scale-95
                    transition-all duration-150",
            data: { turbo_confirm: "Mark as no action needed?" } do %>
          <svg class="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                  d="M5 12h14"/>
          </svg>
          <span>No Action</span>
        <% end %>
      </div>
      
      <%# Status explanation %>
      <p class="text-sm text-gray-500 mt-4 text-center">
        This incident has been officialized and requires a decision.
      </p>
    </div>
  <% else %>
    <%# Show current status badge for already-decided incidents %>
    <% if incident.official_status_applied? %>
      <div class="bg-fop-danger/10 border-2 border-fop-danger rounded-xl p-4 mt-6">
        <div class="flex items-center gap-3">
          <span class="bg-fop-danger text-white rounded-full p-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                    d="M12 9v2m0 4h.01"/>
            </svg>
          </span>
          <span class="font-bold text-fop-danger">Penalty Applied</span>
        </div>
      </div>
    <% elsif incident.official_status_declined? %>
      <div class="bg-gray-100 border-2 border-gray-300 rounded-xl p-4 mt-6">
        <div class="flex items-center gap-3">
          <span class="bg-gray-400 text-white rounded-full p-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                    d="M6 18L18 6M6 6l12 12"/>
            </svg>
          </span>
          <span class="font-bold text-gray-600">Rejected</span>
        </div>
      </div>
    <% elsif incident.official_status_no_action? %>
      <div class="bg-fop-info/10 border-2 border-fop-info rounded-xl p-4 mt-6">
        <div class="flex items-center gap-3">
          <span class="bg-fop-info text-white rounded-full p-2">
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
                    d="M5 12h14"/>
            </svg>
          </span>
          <span class="font-bold text-fop-info">No Action Taken</span>
        </div>
      </div>
    <% end %>
  <% end %>
  ```
- **Dependencies**: Task 8.4

#### Task 8.6: Create Incidents::GroupReports Service
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/services/incidents/group_reports.rb`
- **Details**:
  ```ruby
  # Service to create incident from selected reports
  # Extends existing Reports::AttachToIncident pattern
  module Incidents
    class GroupReports
      include Dry::Monads[:result, :do]
      
      def call(user:, report_ids:, description: nil)
        _        = yield authorize!(user)
        reports  = yield find_reports!(report_ids)
        race     = yield validate_same_race!(reports)
        incident = yield create_incident!(race, reports, description)
        _        = yield attach_reports!(reports, incident)
        _        = yield broadcast_update!(incident)
        
        Success(incident)
      end
      
      private
      
      def authorize!(user)
        return Failure([:unauthorized, "Must be logged in"]) unless user
        return Failure([:forbidden, "Not authorized"]) unless 
          user.admin? || user.jury_president? || user.var_operator?
        Success(user)
      end
      
      def find_reports!(report_ids)
        return Failure([:invalid, "No reports selected"]) if report_ids.blank?
        
        reports = Report.where(id: report_ids).includes(:participant, :race_location)
        
        if reports.empty?
          Failure([:not_found, "No reports found"])
        elsif reports.any? { |r| r.incident_id.present? }
          Failure([:already_grouped, "Some reports are already in an incident"])
        else
          Success(reports)
        end
      end
      
      def validate_same_race!(reports)
        race_ids = reports.map(&:race_id).uniq
        if race_ids.size > 1
          Failure([:invalid, "All reports must belong to the same race"])
        else
          Success(reports.first.race)
        end
      end
      
      def create_incident!(race, reports, description)
        # Generate description from reports if not provided
        auto_description = reports.map { |r| 
          "Bib ##{r.bib_number} at #{r.race_location&.name || 'Unknown location'}"
        }.join("; ")
        
        incident = Incident.new(
          race: race,
          description: description.presence || auto_description,
          status: :unofficial,
          official_status: :pending
        )
        
        incident.save ? Success(incident) : Failure([:save_failed, incident.errors.to_h])
      end
      
      def attach_reports!(reports, incident)
        reports.update_all(incident_id: incident.id)
        incident.reload
        Success(incident)
      end
      
      def broadcast_update!(incident)
        # Broadcast to desktop clients
        IncidentsChannel.broadcast_to(incident.race, {
          action: "created",
          incident_id: incident.id,
          reports_count: incident.reports.count,
          html: ApplicationController.render(
            partial: "incidents/incident_card",
            locals: { incident: incident }
          )
        })
        Success(incident)
      end
    end
  end
  ```
- **Dependencies**: Task 8.5

#### Task 8.7: Create Incidents::UpdateStatus Service
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/services/incidents/update_status.rb`
- **Details**:
  ```ruby
  # Service to apply/reject/no-action an incident
  module Incidents
    class UpdateStatus
      include Dry::Monads[:result, :do]
      
      VALID_ACTIONS = %w[apply reject no_action].freeze
      
      def call(user:, incident_id:, action:)
        _        = yield authorize!(user)
        incident = yield find_incident!(incident_id)
        _        = yield validate_action!(action)
        _        = yield validate_incident_state!(incident)
        _        = yield perform_action!(incident, action)
        _        = yield broadcast_update!(incident, action)
        
        Success(incident)
      end
      
      private
      
      def authorize!(user)
        return Failure([:unauthorized, "Must be logged in"]) unless user
        return Failure([:forbidden, "Only jury can take action"]) unless
          user.admin? || user.jury_president?
        Success(user)
      end
      
      def find_incident!(incident_id)
        incident = Incident.find_by(id: incident_id)
        incident ? Success(incident) : Failure([:not_found, "Incident not found"])
      end
      
      def validate_action!(action)
        if VALID_ACTIONS.include?(action.to_s)
          Success(action)
        else
          Failure([:invalid_action, "Invalid action: #{action}"])
        end
      end
      
      def validate_incident_state!(incident)
        unless incident.official?
          return Failure([:not_official, "Incident must be officialized first"])
        end
        
        unless incident.official_status_pending?
          return Failure([:already_decided, "Decision already made on this incident"])
        end
        
        Success(incident)
      end
      
      def perform_action!(incident, action)
        new_status = case action.to_s
                     when "apply" then :applied
                     when "reject" then :declined
                     when "no_action" then :no_action
                     end
        
        incident.update!(official_status: new_status)
        Success(incident)
      rescue ActiveRecord::RecordInvalid => e
        Failure([:save_failed, e.message])
      end
      
      def broadcast_update!(incident, action)
        IncidentsChannel.broadcast_to(incident.race, {
          action: "status_changed",
          incident_id: incident.id,
          new_status: incident.official_status,
          performed_action: action,
          html: ApplicationController.render(
            partial: "incidents/incident_card",
            locals: { incident: incident }
          )
        })
        Success(incident)
      end
    end
  end
  ```
- **Dependencies**: Task 8.6

#### Task 8.8: Create IncidentsChannel for Real-Time Updates
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/channels/incidents_channel.rb`
- **Details**:
  ```ruby
  # Channel for incident updates (grouping, status changes)
  # Desktop only - FOP devices don't subscribe
  class IncidentsChannel < ApplicationCable::Channel
    def subscribed
      @race = Race.find(params[:race_id])
      stream_for @race
    end
    
    def unsubscribed
      stop_all_streams
    end
  end
  ```
- **Dependencies**: Task 8.7

#### Task 8.9: Add Incident Routes
- **Owner**: Developer
- **Agent**: Direct edit
- **File**: `config/routes.rb`
- **Details**:
  ```ruby
  resources :races do
    resources :incidents, only: [:index, :show, :create] do
      member do
        patch :apply    # Apply penalty
        patch :reject   # Reject (no violation)
        patch :no_action # Acknowledged, no action
        patch :officialize # Make official
      end
    end
    resources :reports, only: [:index, :show, :create]
  end
  ```
- **Dependencies**: Task 8.8

#### Task 8.10: Create IncidentsController Actions
- **Owner**: Developer
- **Agent**: @service
- **File**: `app/controllers/incidents_controller.rb`
- **Details**:
  ```ruby
  class IncidentsController < ApplicationController
    before_action :authenticate_user!
    before_action :set_race
    before_action :set_incident, only: [:show, :apply, :reject, :no_action, :officialize]
    
    def index
      @incidents = policy_scope(Incident)
                     .where(race: @race)
                     .includes(:reports, :race_location)
                     .ordered
      authorize Incident
    end
    
    def show
      authorize @incident
    end
    
    def create
      authorize Incident
      
      result = Incidents::GroupReports.new.call(
        user: current_user,
        report_ids: parse_report_ids,
        description: params[:description]
      )
      
      case result
      in Success(incident)
        respond_to do |format|
          format.html { redirect_to race_incident_path(@race, incident), 
                        notice: "Incident created with #{incident.reports.count} reports" }
          format.turbo_stream
        end
      in Failure([:already_grouped, message])
        redirect_to race_reports_path(@race), alert: message
      in Failure([_, message])
        redirect_to race_reports_path(@race), alert: message
      end
    end
    
    def apply
      authorize @incident, :update?
      handle_status_action("apply", "Penalty applied")
    end
    
    def reject
      authorize @incident, :update?
      handle_status_action("reject", "Incident rejected")
    end
    
    def no_action
      authorize @incident, :update?
      handle_status_action("no_action", "Marked as no action")
    end
    
    def officialize
      authorize @incident, :officialize?
      
      result = Incidents::Officialize.new.call(
        user: current_user,
        incident_id: @incident.id
      )
      
      handle_service_result(result, "Incident officialized")
    end
    
    private
    
    def set_race
      @race = Race.find(params[:race_id])
    end
    
    def set_incident
      @incident = @race.incidents.find(params[:id])
    end
    
    def parse_report_ids
      JSON.parse(params[:report_ids] || "[]")
    rescue JSON::ParserError
      []
    end
    
    def handle_status_action(action, success_message)
      result = Incidents::UpdateStatus.new.call(
        user: current_user,
        incident_id: @incident.id,
        action: action
      )
      handle_service_result(result, success_message)
    end
    
    def handle_service_result(result, success_message)
      case result
      in Success(incident)
        respond_to do |format|
          format.html { redirect_to race_incident_path(@race, incident), notice: success_message }
          format.turbo_stream
        end
      in Failure([_, message])
        redirect_to race_incident_path(@race, @incident), alert: message
      end
    end
  end
  ```
- **Dependencies**: Task 8.9

#### Task 8.11: Write Report Grouping Tests
- **Owner**: Developer
- **Agent**: @rspec
- **Files**:
  - `spec/services/incidents/group_reports_spec.rb`
  - `spec/services/incidents/update_status_spec.rb`
  - `spec/components/fop/report_selection_component_spec.rb`
  - `spec/components/fop/incident_actions_component_spec.rb`
  - `spec/system/report_grouping_spec.rb`
- **Details**:
  - Test multi-report selection
  - Test incident creation from reports
  - Test status transitions (apply/reject/no_action)
  - Test authorization (only jury can decide)
  - Test real-time broadcast
  - System test: full flow from selection to decision
- **Dependencies**: Task 8.10

#### Task 8.12: Create Desktop Reports View with Selection
- **Owner**: Developer
- **Agent**: Direct edit
- **File**: `app/views/reports/index.html.erb`
- **Details**:
  ```erb
  <%# Desktop view with report selection for grouping %>
  <div data-controller="report-selection">
    <%# Select all header %>
    <div class="bg-white sticky top-0 z-10 p-4 border-b flex items-center gap-4">
      <input type="checkbox"
             class="w-8 h-8 rounded border-2 border-gray-300"
             data-report-selection-target="selectAll"
             data-action="change->report-selection#selectAll">
      <span class="text-gray-600">Select all</span>
    </div>
    
    <%# Report list with checkboxes %>
    <div class="divide-y">
      <% @reports.each do |report| %>
        <%= render Fop::ReportSelectionComponent.new(report: report) %>
      <% end %>
    </div>
    
    <%# Floating action bar (appears when reports selected) %>
    <%= render Fop::FloatingActionBarComponent.new(race: @race) %>
  </div>
  ```
- **Dependencies**: Task 8.11

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

## Appendix A: Component Diagram (Real-Time Notifications)

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

---

## Appendix B: Report Grouping & Incident Actions Workflow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    DESKTOP: Report Grouping Workflow                     │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Step 1: View Reports List with Selection Checkboxes                   │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ ☐ Select All                                                    │   │
│  ├─────────────────────────────────────────────────────────────────┤   │
│  │ ☑ #34 - Jean Dupont    │ Start Area  │ 2 min ago  │ Submitted  │   │
│  │ ☑ #34 - Jean Dupont    │ Transition  │ 3 min ago  │ Submitted  │   │
│  │ ☐ #56 - Maria Rossi    │ Finish      │ 5 min ago  │ Reviewed   │   │
│  │ ☑ #34 - Jean Dupont    │ Climb 2     │ 8 min ago  │ Submitted  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  Step 2: Floating Action Bar Appears (3 selected)                      │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │  [3] selected          [ Group into Incident ]              ✕   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ POST /races/:id/incidents
                                  │ { report_ids: [1, 2, 3] }
                                  v
┌─────────────────────────────────────────────────────────────────────────┐
│                    Rails Server: Incidents::GroupReports                │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. Authorize user (jury/var_operator)                                 │
│  2. Find reports by IDs                                                │
│  3. Validate all reports belong to same race                           │
│  4. Validate no reports already in incident                            │
│  5. Create Incident (status: unofficial, official_status: pending)     │
│  6. Attach reports to incident                                         │
│  7. Broadcast via IncidentsChannel                                     │
│                                                                         │
└─────────────────────────────────┬───────────────────────────────────────┘
                                  │
                                  v
┌─────────────────────────────────────────────────────────────────────────┐
│                    DESKTOP: Incident Detail View                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Incident #42 - Bib #34 Jean Dupont                                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Status: UNOFFICIAL                                               │   │
│  │ Reports: 3                                                       │   │
│  │ Location: Start Area, Transition, Climb 2                        │   │
│  ├─────────────────────────────────────────────────────────────────┤   │
│  │                                                                  │   │
│  │  Report 1: Start Area - Wrong equipment                         │   │
│  │  Report 2: Transition - Cutting course                          │   │
│  │  Report 3: Climb 2 - Blocking other athlete                     │   │
│  │                                                                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  Step 3: Officialize Incident (Jury President)                         │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │              [ Officialize Incident ]                            │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
                                  │
                                  │ PATCH /incidents/:id/officialize
                                  v
┌─────────────────────────────────────────────────────────────────────────┐
│                    DESKTOP: Incident Decision Panel                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Incident #42 - Bib #34 Jean Dupont                                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │ Status: OFFICIAL              Decision: PENDING                  │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
│  Step 4: Take Action (Touch-Optimized 56px Buttons)                    │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                           Decision                               │   │
│  │                                                                  │   │
│  │  ┌──────────────────┐  ┌──────────────┐  ┌──────────────────┐   │   │
│  │  │                  │  │              │  │                  │   │   │
│  │  │  ⚠ APPLY PENALTY │  │   ✕ REJECT   │  │   ─ NO ACTION    │   │   │
│  │  │                  │  │              │  │                  │   │   │
│  │  │   (RED - 56px)   │  │  (GRAY-56px) │  │  (OUTLINE-56px)  │   │   │
│  │  └──────────────────┘  └──────────────┘  └──────────────────┘   │   │
│  │                                                                  │   │
│  │  This incident has been officialized and requires a decision.   │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                    Incident Status State Machine                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   status (incident lifecycle):                                         │
│                                                                         │
│     ┌────────────┐  officialize   ┌──────────┐                         │
│     │ UNOFFICIAL │ ─────────────► │ OFFICIAL │                         │
│     └────────────┘                └──────────┘                         │
│                                                                         │
│   official_status (decision, only when OFFICIAL):                      │
│                                                                         │
│                          ┌─────────────┐                               │
│                ┌────────►│   APPLIED   │  Penalty enforced             │
│                │         └─────────────┘                               │
│                │                                                        │
│     ┌──────────┴─┐       ┌─────────────┐                               │
│     │  PENDING   │──────►│  DECLINED   │  No violation found           │
│     └──────────┬─┘       └─────────────┘                               │
│                │                                                        │
│                │         ┌─────────────┐                               │
│                └────────►│  NO_ACTION  │  Acknowledged, no penalty     │
│                          └─────────────┘                               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────┐
│                    Touch Target Specifications                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Element                    │ Size      │ Spacing │ Notes             │
│   ───────────────────────────┼───────────┼─────────┼─────────────────  │
│   Report checkbox            │ 56×56px   │ 16px    │ Large tap target  │
│   Action buttons             │ 56px h    │ 16px    │ Full width ok     │
│   Select all checkbox        │ 32×32px   │ 16px    │ Header element    │
│   Floating bar               │ 72px h    │ fixed   │ Sticky bottom     │
│   Group button               │ 56px h    │ auto    │ Primary action    │
│                                                                         │
│   Colors:                                                               │
│   - Apply Penalty: bg-fop-danger (#DC2626)                             │
│   - Reject: bg-gray-200                                                │
│   - No Action: border-2 border-gray-200, bg-gray-100                   │
│   - Selected card: border-ismf-navy, bg-ismf-navy/10                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```
