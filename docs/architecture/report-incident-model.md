# Report & Incident Data Model Architecture

## Design Principles

1. **Super Fast** - Report creation < 100ms on FOP devices
2. **Referees don't think** - Just tap bib, report created
3. **Reports are observations** - No status/decision on reports
4. **Incidents are cases** - All status/decision logic here
5. **Two-level status** - Unofficial (VAR/Referee) → Official (Jury President)

---

## Core Concept

```
┌─────────────────────────────────────────────────────────────────────────┐
│  DOMAIN MODEL                                                           │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  REPORT (Observation)              INCIDENT (Case)                      │
│  ═══════════════════               ═══════════════                      │
│  • What was seen                   • What is being decided              │
│  • By whom (referee)               • By whom (VAR → Jury)               │
│  • Where (location)                • Decision outcome                   │
│  • When (timestamp)                • Official status                    │
│  • NO STATUS                       • ALL STATUS HERE                    │
│                                                                         │
│  ┌─────────┐                       ┌─────────────────────┐              │
│  │ Report  │──────────────────────►│      Incident       │              │
│  └─────────┘   belongs_to          │                     │              │
│  ┌─────────┐                       │  status: unofficial │              │
│  │ Report  │──────────────────────►│          │          │              │
│  └─────────┘                       │          ▼          │              │
│  ┌─────────┐                       │  status: official   │              │
│  │ Report  │──────────────────────►│          │          │              │
│  └─────────┘                       │          ▼          │              │
│                                    │  decision: pending  │              │
│                                    │      /   |   \      │              │
│                                    │     ▼    ▼    ▼     │              │
│                                    │  applied │ rejected │              │
│                                    │       no_action     │              │
│                                    └─────────────────────┘              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           WORKFLOW                                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  FOP DEVICE (Referee)                                                   │
│  ════════════════════                                                   │
│  1. Tap bib #34 → Report created                                        │
│  2. Incident auto-created (1:1)                                         │
│  3. Status: UNOFFICIAL                                                  │
│  4. Response: < 100ms                                                   │
│                                                                         │
│       ↓                                                                 │
│                                                                         │
│  DESKTOP (VAR Operator)                                                 │
│  ══════════════════════                                                 │
│  5. See incident in real-time (Action Cable)                            │
│  6. Review video evidence                                               │
│  7. Can MERGE incidents (move reports to single incident)               │
│  8. Status: still UNOFFICIAL                                            │
│                                                                         │
│       ↓                                                                 │
│                                                                         │
│  DESKTOP (Jury President)                                               │
│  ════════════════════════                                               │
│  9. Review incident                                                     │
│  10. OFFICIALIZE → Status: OFFICIAL                                     │
│  11. Make DECISION:                                                     │
│      • Apply Penalty (decision: penalty_applied)                        │
│      • Reject (decision: rejected)                                      │
│      • No Action (decision: no_action)                                  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Models

### Report Model (Observation Only)

```ruby
# == Schema Information
#
# Table name: reports
#
# id               :bigint           not null, primary key
# race_id          :bigint           not null, index
# incident_id      :bigint           not null, index
# user_id          :bigint           not null, index (reporter)
# race_location_id :bigint           optional, index
# participant_id   :bigint           optional, index
# bib_number       :integer          not null, index
# description      :text             optional
# video_clip       :jsonb            optional {start_time, end_time}
# created_at       :datetime         not null, index
# updated_at       :datetime         not null
#
class Report < ApplicationRecord
  # ═══════════════════════════════════════════════════════════════════
  # ASSOCIATIONS
  # ═══════════════════════════════════════════════════════════════════
  belongs_to :race
  belongs_to :incident
  belongs_to :user
  belongs_to :race_location, optional: true
  belongs_to :participant, optional: true

  has_one_attached :video

  # ═══════════════════════════════════════════════════════════════════
  # VALIDATIONS (minimal for speed)
  # ═══════════════════════════════════════════════════════════════════
  validates :race_id, presence: true
  validates :incident_id, presence: true
  validates :user_id, presence: true
  validates :bib_number, presence: true,
                         numericality: { only_integer: true, greater_than: 0 }

  # ═══════════════════════════════════════════════════════════════════
  # NO STATUS ON REPORT
  # Reports are observations, not decisions
  # ═══════════════════════════════════════════════════════════════════

  # ═══════════════════════════════════════════════════════════════════
  # SCOPES
  # ═══════════════════════════════════════════════════════════════════
  scope :ordered, -> { order(created_at: :desc) }
  scope :by_bib, ->(bib) { where(bib_number: bib) }
  scope :recent, -> { where("created_at > ?", 1.hour.ago) }

  # ═══════════════════════════════════════════════════════════════════
  # CALLBACKS (minimal - heavy work in background)
  # ═══════════════════════════════════════════════════════════════════
  after_create_commit :broadcast_created

  private

  def broadcast_created
    Reports::BroadcastJob.perform_later(id)
  end
end
```

### Incident Model (Case with Status/Decision)

```ruby
# == Schema Information
#
# Table name: incidents
#
# id               :bigint           not null, primary key
# race_id          :bigint           not null, index
# race_location_id :bigint           optional
# status           :integer          not null, default: 0 (unofficial)
# decision         :integer          not null, default: 0 (pending)
# description      :text             optional (auto-generated or manual)
# officialized_at  :datetime         optional
# officialized_by  :bigint           optional (user_id)
# decided_at       :datetime         optional
# decided_by       :bigint           optional (user_id)
# reports_count    :integer          default: 0 (counter cache)
# created_at       :datetime         not null
# updated_at       :datetime         not null
#
class Incident < ApplicationRecord
  # ═══════════════════════════════════════════════════════════════════
  # ASSOCIATIONS
  # ═══════════════════════════════════════════════════════════════════
  belongs_to :race
  belongs_to :race_location, optional: true
  belongs_to :officialized_by_user, class_name: "User", 
             foreign_key: :officialized_by, optional: true
  belongs_to :decided_by_user, class_name: "User",
             foreign_key: :decided_by, optional: true

  has_many :reports, dependent: :destroy

  # ═══════════════════════════════════════════════════════════════════
  # ENUMS - Two-Level Status System
  # ═══════════════════════════════════════════════════════════════════
  
  # Level 1: Lifecycle status
  # - unofficial: Being reviewed by VAR/Referee (default)
  # - official: Confirmed by Jury President
  enum :status, {
    unofficial: 0,
    official: 1
  }

  # Level 2: Decision (only meaningful when official)
  # - pending: Awaiting jury decision
  # - penalty_applied: Penalty enforced
  # - rejected: No violation found
  # - no_action: Acknowledged, no penalty
  enum :decision, {
    pending: 0,
    penalty_applied: 1,
    rejected: 2,
    no_action: 3
  }, prefix: :decision

  # ═══════════════════════════════════════════════════════════════════
  # VALIDATIONS
  # ═══════════════════════════════════════════════════════════════════
  validates :race_id, presence: true
  validates :status, presence: true
  validates :decision, presence: true
  validate :decision_change_requires_official

  # ═══════════════════════════════════════════════════════════════════
  # SCOPES
  # ═══════════════════════════════════════════════════════════════════
  scope :ordered, -> { order(created_at: :desc) }
  scope :unofficial, -> { where(status: :unofficial) }
  scope :official, -> { where(status: :official) }
  scope :pending_decision, -> { official.decision_pending }
  scope :decided, -> { official.where.not(decision: :pending) }
  scope :with_reports, -> { includes(:reports) }

  # ═══════════════════════════════════════════════════════════════════
  # INSTANCE METHODS
  # ═══════════════════════════════════════════════════════════════════
  
  def single_report?
    reports_count == 1
  end

  def multiple_reports?
    reports_count > 1
  end

  # For UI: show "Report" for 1-report incidents, "Incident" for merged
  def display_type
    single_report? ? "Report" : "Incident"
  end

  def can_officialize?
    unofficial? && reports.any?
  end

  def can_decide?
    official? && decision_pending?
  end

  def officialize!(by_user:)
    return false unless can_officialize?
    
    update!(
      status: :official,
      officialized_at: Time.current,
      officialized_by: by_user.id
    )
  end

  def apply_penalty!(by_user:)
    return false unless can_decide?
    
    update!(
      decision: :penalty_applied,
      decided_at: Time.current,
      decided_by: by_user.id
    )
  end

  def reject!(by_user:)
    return false unless can_decide?
    
    update!(
      decision: :rejected,
      decided_at: Time.current,
      decided_by: by_user.id
    )
  end

  def mark_no_action!(by_user:)
    return false unless can_decide?
    
    update!(
      decision: :no_action,
      decided_at: Time.current,
      decided_by: by_user.id
    )
  end

  # ═══════════════════════════════════════════════════════════════════
  # CALLBACKS
  # ═══════════════════════════════════════════════════════════════════
  after_update_commit :broadcast_updated

  private

  def decision_change_requires_official
    return unless decision_changed? && !decision_pending?
    
    unless official?
      errors.add(:decision, "can only be set when incident is official")
    end
  end

  def broadcast_updated
    Incidents::BroadcastJob.perform_later(id)
  end
end
```

---

## Speed-Optimized Report Creation

### Service (Minimal Operations)

```ruby
# app/services/reports/create.rb
module Reports
  class Create
    include Dry::Monads[:result]

    # Target: < 50ms database time
    def call(user:, race_id:, bib_number:, race_location_id: nil, description: nil)
      ActiveRecord::Base.transaction do
        # 1. Create incident (1 INSERT)
        incident = Incident.create!(
          race_id: race_id,
          race_location_id: race_location_id,
          status: :unofficial,
          decision: :pending
        )

        # 2. Create report (1 INSERT)
        report = Report.create!(
          race_id: race_id,
          incident_id: incident.id,
          user_id: user.id,
          bib_number: bib_number,
          race_location_id: race_location_id,
          description: description
        )

        # 3. Background job handles broadcast (non-blocking)
        # after_create_commit callback enqueues job

        Success(report)
      end
    rescue ActiveRecord::RecordInvalid => e
      Failure([:validation_failed, e.record.errors.to_h])
    end
  end
end
```

### Controller (Thin, Fast Response)

```ruby
# app/controllers/api/reports_controller.rb
module Api
  class ReportsController < ApplicationController
    # POST /api/races/:race_id/reports
    # Target: < 100ms total response time
    def create
      result = Reports::Create.new.call(
        user: current_user,
        race_id: params[:race_id],
        bib_number: report_params[:bib_number],
        race_location_id: report_params[:race_location_id],
        description: report_params[:description]
      )

      case result
      in Success(report)
        render json: {
          id: report.id,
          incident_id: report.incident_id,
          bib_number: report.bib_number,
          created_at: report.created_at.iso8601
        }, status: :created
      in Failure([:validation_failed, errors])
        render json: { errors: errors }, status: :unprocessable_entity
      end
    end

    private

    def report_params
      params.require(:report).permit(:bib_number, :race_location_id, :description)
    end
  end
end
```

---

## Merge Incidents (Desktop Only)

When VAR operator groups multiple reports into one incident:

```ruby
# app/services/incidents/merge.rb
module Incidents
  class Merge
    include Dry::Monads[:result, :do]

    # Merge source incidents into target, move all reports
    def call(user:, target_incident_id:, source_incident_ids:)
      _      = yield authorize!(user)
      target = yield find_target!(target_incident_id)
      sources = yield find_sources!(source_incident_ids, target)
      _      = yield validate_same_race!(target, sources)
      _      = yield transfer_reports!(sources, target)
      _      = yield delete_empty_incidents!(sources)
      _      = yield broadcast!(target)

      Success(target.reload)
    end

    private

    def authorize!(user)
      return Failure([:forbidden, "Not authorized"]) unless 
        user.admin? || user.var_operator? || user.jury_president?
      Success(user)
    end

    def find_target!(id)
      incident = Incident.find_by(id: id)
      incident ? Success(incident) : Failure([:not_found, "Target incident not found"])
    end

    def find_sources!(ids, target)
      sources = Incident.where(id: ids).where.not(id: target.id)
      sources.any? ? Success(sources) : Failure([:not_found, "No source incidents found"])
    end

    def validate_same_race!(target, sources)
      all_same = sources.all? { |s| s.race_id == target.race_id }
      all_same ? Success(true) : Failure([:invalid, "All incidents must be from same race"])
    end

    def transfer_reports!(sources, target)
      # Bulk update - single query
      Report.where(incident_id: sources.pluck(:id))
            .update_all(incident_id: target.id)
      
      # Reset counter caches
      Incident.reset_counters(target.id, :reports)
      
      Success(true)
    end

    def delete_empty_incidents!(sources)
      sources.destroy_all
      Success(true)
    end

    def broadcast!(target)
      Incidents::BroadcastJob.perform_later(target.id)
      Success(true)
    end
  end
end
```

---

## Database Indexes (Critical for Speed)

```ruby
# db/migrate/XXXXXX_add_report_incident_indexes.rb
class AddReportIncidentIndexes < ActiveRecord::Migration[8.1]
  def change
    # Reports - optimized for FOP queries
    add_index :reports, [:race_id, :created_at], order: { created_at: :desc }
    add_index :reports, [:incident_id]
    add_index :reports, [:race_id, :bib_number]
    add_index :reports, [:user_id, :created_at], order: { created_at: :desc }

    # Incidents - optimized for desktop queries
    add_index :incidents, [:race_id, :status, :created_at], 
              order: { created_at: :desc }
    add_index :incidents, [:race_id, :decision], 
              where: "status = 1" # official only
    add_index :incidents, [:race_id, :created_at], 
              order: { created_at: :desc }
  end
end
```

---

## Status State Machine

```
┌─────────────────────────────────────────────────────────────────────────┐
│                      INCIDENT STATUS STATE MACHINE                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ╔═══════════════════════════════════════════════════════════════════╗ │
│  ║  LEVEL 1: LIFECYCLE STATUS                                        ║ │
│  ╠═══════════════════════════════════════════════════════════════════╣ │
│  ║                                                                    ║ │
│  ║   ┌────────────────┐    officialize!    ┌────────────────┐        ║ │
│  ║   │   UNOFFICIAL   │ ─────────────────► │    OFFICIAL    │        ║ │
│  ║   │                │                    │                │        ║ │
│  ║   │  • Created by  │                    │  • Confirmed   │        ║ │
│  ║   │    system      │                    │    by Jury     │        ║ │
│  ║   │  • VAR reviews │                    │  • Ready for   │        ║ │
│  ║   │  • Can merge   │                    │    decision    │        ║ │
│  ║   └────────────────┘                    └───────┬────────┘        ║ │
│  ║                                                 │                  ║ │
│  ╚═════════════════════════════════════════════════╪══════════════════╝ │
│                                                    │                    │
│  ╔═════════════════════════════════════════════════╪══════════════════╗ │
│  ║  LEVEL 2: DECISION (only when OFFICIAL)         │                  ║ │
│  ╠═════════════════════════════════════════════════╪══════════════════╣ │
│  ║                                                 ▼                  ║ │
│  ║                                    ┌────────────────┐              ║ │
│  ║                                    │    PENDING     │              ║ │
│  ║                                    │   (default)    │              ║ │
│  ║                                    └───────┬────────┘              ║ │
│  ║                                            │                       ║ │
│  ║               ┌────────────────────────────┼────────────────────┐  ║ │
│  ║               │                            │                    │  ║ │
│  ║               ▼                            ▼                    ▼  ║ │
│  ║  ┌────────────────────┐    ┌────────────────────┐  ┌──────────────┐║ │
│  ║  │  PENALTY_APPLIED   │    │      REJECTED      │  │  NO_ACTION   │║ │
│  ║  │                    │    │                    │  │              │║ │
│  ║  │  • Violation       │    │  • No violation    │  │ • Violation  │║ │
│  ║  │    confirmed       │    │    found           │  │   noted      │║ │
│  ║  │  • Penalty given   │    │  • Case dismissed  │  │ • No penalty │║ │
│  ║  └────────────────────┘    └────────────────────┘  └──────────────┘║ │
│  ║         🔴 RED                  ⚫ GRAY              🔵 BLUE       ║ │
│  ║                                                                    ║ │
│  ╚════════════════════════════════════════════════════════════════════╝ │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Query Patterns

### FOP Device (Creation Only)

```ruby
# Minimal query for report creation - no eager loading needed
# Just INSERT incident + INSERT report
```

### Desktop (Viewing)

```ruby
# List incidents for race with report counts
Incident
  .where(race_id: race_id)
  .includes(:reports, :race_location)
  .ordered

# Unofficial incidents (VAR queue)
Incident
  .unofficial
  .where(race_id: race_id)
  .includes(:reports)
  .ordered

# Official incidents pending decision (Jury queue)
Incident
  .official
  .decision_pending
  .where(race_id: race_id)
  .includes(:reports)
  .ordered
```

---

## Performance Targets

| Operation | Target | Method |
|-----------|--------|--------|
| Report creation (FOP) | < 100ms | 2 INSERTs, background broadcast |
| Report list (Desktop) | < 300ms | Eager loading, indexes |
| Incident merge | < 500ms | Bulk UPDATE, background broadcast |
| Officialize incident | < 200ms | Single UPDATE |
| Make decision | < 200ms | Single UPDATE |
| Real-time broadcast | < 100ms | Solid Cable, background job |

---

## Summary

| Aspect | Report | Incident |
|--------|--------|----------|
| **Purpose** | Observation | Case/Decision |
| **Created by** | Referee (FOP) | System (auto) |
| **Has status?** | ❌ No | ✅ Yes (2 levels) |
| **Has decision?** | ❌ No | ✅ Yes |
| **Mutable?** | Description only | Status + Decision |
| **Always has incident?** | ✅ Yes (required) | N/A |
| **Can be merged?** | Via incident merge | ✅ Yes |

**Key Design Decisions:**

1. **1:1 by default** - Every report creates its own incident
2. **No orphan reports** - `incident_id` is required
3. **No status on reports** - Reports are just observations
4. **Two-level status on incidents** - Lifecycle (unofficial/official) + Decision
5. **Merge = transfer reports** - Move reports from source incidents to target
6. **Background broadcasts** - Keep creation fast, notify async