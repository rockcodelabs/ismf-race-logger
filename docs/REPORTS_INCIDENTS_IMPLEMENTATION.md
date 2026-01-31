# Reports & Incidents Implementation Plan

> Implementation plan for the reporting and incident management system with race location integration.

---

## Table of Contents

1. [Overview](#overview)
2. [Requirements Summary](#requirements-summary)
3. [Database Schema](#database-schema)
4. [Types](#types)
5. [Implementation Phases](#implementation-phases)
6. [UI/UX Designs](#uiux-designs)
7. [Authorization Matrix](#authorization-matrix)
8. [Business Rules](#business-rules)
9. [Files Summary](#files-summary)
10. [Deferred Features](#deferred-features)
11. [Progress Tracking](#progress-tracking)

---

## Overview

Build a complete reporting and incident management system where:

1. **Reports** are quick captures (location + bib) created during live races
2. **Reports** are reviewed and merged into **Incidents**
3. **Incidents** receive decisions (approved/rejected) with attached **Penalties**
4. Both Touch (7") and Desktop UIs support the full workflow

### Workflow Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                                                                             │
│   TOUCH / DESKTOP                    REVIEW                    DECISION    │
│                                                                             │
│   ┌─────────────┐     ┌─────────────┐     ┌─────────────┐     ┌──────────┐ │
│   │   Create    │     │   Review    │     │   Merge     │     │  Decide  │ │
│   │   Report    │ ──▶ │   Report    │ ──▶ │   Reports   │ ──▶ │ Incident │ │
│   │             │     │             │     │             │     │          │ │
│   │ Location +  │     │  Confirm /  │     │  1+ Reports │     │ Approve/ │ │
│   │ Bib Number  │     │   Reject    │     │  = Incident │     │  Reject  │ │
│   └─────────────┘     └─────────────┘     └─────────────┘     └──────────┘ │
│                                                    │                 │      │
│                                                    │                 ▼      │
│                                                    │          ┌──────────┐  │
│                                                    └────────▶ │ Attach   │  │
│                                                               │ Penalties│  │
│                                                               └──────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Requirements Summary

| Aspect | Decision |
|--------|----------|
| **Reports** | Location (required) + bib + optional description |
| **Incidents** | Created from 1+ merged reports |
| **Penalties** | Attach to incidents (multiple allowed), select by number (C1), display name |
| **Platforms** | Touch (7") + Desktop - both can create reports, review, merge, decide |
| **Authorization** | All roles create/review reports; Admin+VAR merge & decide incidents |
| **Real-time** | Deferred to later phase |
| **Video** | Deferred to later phase |
| **Status flow** | Report (pending_review/confirmed/rejected) → Incident (pending/approved/rejected) |
| **Race restriction** | Cannot create reports after race ends |
| **Reopening** | Reports and incident decisions can be changed |

---

## Database Schema

### New Tables

#### 1. `incidents`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | bigint | PK | |
| `client_uuid` | uuid | NOT NULL, UNIQUE | Offline sync |
| `race_id` | references | NOT NULL, FK | Which race |
| `race_location_id` | references | FK | Primary location (from first report) |
| `status` | string | NOT NULL, DEFAULT 'pending' | pending, approved, rejected |
| `description` | text | | Combined/summary description |
| `decided_by_user_id` | references | FK | Who made the decision |
| `decided_at` | datetime | | When decision was made |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

**Indexes:**
- `index_incidents_on_client_uuid` (unique)
- `index_incidents_on_race_id`
- `index_incidents_on_race_location_id`
- `index_incidents_on_status`

#### 2. `reports`

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | bigint | PK | |
| `client_uuid` | uuid | NOT NULL, UNIQUE | Offline sync/idempotency |
| `race_id` | references | NOT NULL, FK | Which race |
| `incident_id` | references | FK | Linked after merge (nullable) |
| `user_id` | references | NOT NULL, FK | Who created |
| `race_location_id` | references | NOT NULL, FK | Where on course |
| `race_participation_id` | references | NOT NULL, FK | Links to athlete via bib |
| `bib_number` | integer | NOT NULL | Denormalized for display |
| `athlete_position` | integer | | 1 or 2 for team races |
| `description` | text | | Notes about what happened |
| `status` | string | NOT NULL, DEFAULT 'pending_review' | pending_review, confirmed, rejected |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

**Indexes:**
- `index_reports_on_client_uuid` (unique)
- `index_reports_on_race_id`
- `index_reports_on_incident_id`
- `index_reports_on_user_id`
- `index_reports_on_race_location_id`
- `index_reports_on_race_participation_id`
- `index_reports_on_status`
- `index_reports_on_bib_number`

#### 3. `incident_penalties` (Join Table)

| Column | Type | Constraints | Notes |
|--------|------|-------------|-------|
| `id` | bigint | PK | |
| `incident_id` | references | NOT NULL, FK | |
| `penalty_id` | references | NOT NULL, FK | |
| `created_at` | datetime | NOT NULL | |
| `updated_at` | datetime | NOT NULL | |

**Indexes:**
- `index_incident_penalties_on_incident_id_and_penalty_id` (unique)
- `index_incident_penalties_on_penalty_id`

---

## Types

Add to `lib/ismf_race_logger/types.rb`:

```ruby
# Report statuses
ReportStatus = Strict::String.enum("pending_review", "confirmed", "rejected")

# Update IncidentStatus to simpler flow
IncidentStatus = Strict::String.enum("pending", "approved", "rejected")
```

---

## Implementation Phases

### Phase 1: Database & Types ⏱️ ~1 hour

- [ ] Migration: `create_incidents`
- [ ] Migration: `create_reports`
- [ ] Migration: `create_incident_penalties`
- [ ] Update `types.rb`: Add `ReportStatus`, update `IncidentStatus`

### Phase 2: Models ⏱️ ~30 min

- [ ] `app/models/incident.rb` (associations only)
- [ ] `app/models/report.rb` (associations only)
- [ ] `app/models/incident_penalty.rb` (associations only)
- [ ] Update `app/models/penalty.rb` (add `has_many :incident_penalties`)
- [ ] Update `app/models/race.rb` (add associations)
- [ ] Update `app/models/race_location.rb` (add associations)
- [ ] Update `app/models/race_participation.rb` (add association)
- [ ] Update `app/models/user.rb` (add association)

### Phase 3: Structs ⏱️ ~1 hour

- [ ] `app/db/structs/incident.rb` (dry-struct, full)
- [ ] `app/db/structs/incident_summary.rb` (Data.define, collections)
- [ ] `app/db/structs/report.rb` (dry-struct, full)
- [ ] `app/db/structs/report_summary.rb` (Data.define, collections)

### Phase 4: Repos ⏱️ ~1 hour

- [ ] `app/db/repos/incident_repo.rb`
- [ ] `app/db/repos/report_repo.rb`
- [ ] Register in AppContainer

### Phase 5: Contracts ⏱️ ~1 hour

- [ ] `app/operations/contracts/create_report.rb`
- [ ] `app/operations/contracts/update_report.rb`
- [ ] `app/operations/contracts/create_incident.rb` (merge)
- [ ] `app/operations/contracts/decide_incident.rb`
- [ ] `app/operations/contracts/attach_penalties.rb`

### Phase 6: Operations ⏱️ ~2 hours

- [ ] `app/operations/reports/create.rb`
- [ ] `app/operations/reports/confirm.rb`
- [ ] `app/operations/reports/reject.rb`
- [ ] `app/operations/reports/reopen.rb`
- [ ] `app/operations/incidents/create.rb` (merge reports)
- [ ] `app/operations/incidents/decide.rb` (approve/reject + penalties)
- [ ] `app/operations/incidents/attach_penalties.rb`
- [ ] `app/operations/incidents/reopen.rb`

### Phase 7: Parts ⏱️ ~1 hour

- [ ] `app/web/parts/report.rb`
- [ ] `app/web/parts/incident.rb`

### Phase 8: Desktop Admin Controllers ⏱️ ~2 hours

- [ ] `app/web/controllers/admin/reports_controller.rb`
- [ ] `app/web/controllers/admin/incidents_controller.rb`
- [ ] Routes configuration

### Phase 9: Desktop Admin Views ⏱️ ~3 hours

- [ ] Reports: index, show, new, edit
- [ ] Incidents: index, show
- [ ] Merge UI (select reports → create incident)
- [ ] Penalty selection UI (searchable by number C1, shows name)

### Phase 10: Touch Controllers ⏱️ ~2 hours

- [ ] `app/web/controllers/touch/reports_controller.rb`
- [ ] `app/web/controllers/touch/incidents_controller.rb`
- [ ] Routes configuration

### Phase 11: Touch Views ⏱️ ~4 hours

- [ ] Report creation: location sidebar + bib selector
- [ ] Pending reports queue
- [ ] Report review/confirm
- [ ] Merge UI (touch-optimized)
- [ ] Incident decision + penalty selection

### Phase 12: Authorization ⏱️ ~1 hour

- [ ] `app/policies/report_policy.rb`
- [ ] `app/policies/incident_policy.rb`

### Phase 13: Testing ⏱️ ~3 hours

- [ ] Model specs
- [ ] Struct specs
- [ ] Repo specs
- [ ] Operation specs
- [ ] Request specs (authorization)

---

## UI/UX Designs

### Touch: Report Creation (Split Screen Layout)

The main reporting interface for the 7" touch display (1280×720):

```
┌─────────────────────────────────────────────────────────────────┐
│ ┌─LOCATIONS──┐  ┌─REPORT CREATION─────────────────────────────┐ │
│ │            │  │                                             │ │
│ │ [Start]    │  │  Select Bib:  [Participant List]            │ │
│ │ [Uphill-T] │  │  ┌─────────────────────────────────────────┐│ │
│ │ [Gate 5]   │  │  │ 1  Maria SMITH (ITA)                   ││ │
│ │ [Transit]  │  │  │ 2  John DOE (FRA)                      ││ │
│ │ [Descent]  │  │  │ 3  Anna CHEN (CHN)           ▼ scroll  ││ │
│ │ [Finish]   │  │  └─────────────────────────────────────────┘│ │
│ │            │  │                                             │ │
│ │ ─selected──│  │  ┌─Pending Reports (3)──────────────────────┐│ │
│ │ [Transit]  │  │  │ #12 @ Uphill-Top    10:34  [review]     ││ │
│ │ ───────────│  │  │ #25 @ Descent       10:35  [review]     ││ │
│ │            │  │  │ #7  @ Transition    10:36  [review]     ││ │
│ └────────────┘  │  └─────────────────────────────────────────┘│ │
│                 └─────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────┘
```

**Workflow:**
1. Tap location button (left sidebar) - always visible
2. Location becomes "selected" (highlighted)
3. Tap bib number from participant list
4. Report created automatically with `pending_review` status
5. Report appears in pending queue

**Layout Dimensions (1280×720):**
- Location sidebar: ~320px width
- Report creation area: ~960px width
- Bib selector: scrollable list, 64px per item
- Pending reports: bottom section, scrollable

### Touch: Merge & Decision Screen

```
┌─────────────────────────────────────────────────────────────────┐
│  MERGE REPORTS INTO INCIDENT                                    │
│  ┌─Select Reports────────────────────────────────────────────┐  │
│  │ ☑ #12 @ Uphill-Top   Maria SMITH                         │  │
│  │ ☐ #25 @ Descent      John DOE                            │  │
│  │ ☑ #7  @ Transition   Maria SMITH (same athlete!)         │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─Attach Penalties (tap to add)─────────────────────────────┐  │
│  │ [C1] False Start - 30s │ [×]                              │  │
│  │ [+ Add Penalty]                                           │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────────────────┐  │
│  │   REJECT    │  │  PENDING    │  │       APPROVE           │  │
│  │   (red)     │  │  (yellow)   │  │       (green)           │  │
│  └─────────────┘  └─────────────┘  └─────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

**Workflow:**
1. Select reports to merge (checkboxes)
2. Add penalties (opens penalty selector modal)
3. Choose decision: Reject / Keep Pending / Approve

### Touch: Penalty Selection Modal

```
┌─────────────────────────────────────────────────────────────────┐
│  SELECT PENALTY                                      [×]        │
│  ┌─Search: [C1_________________]────────────────────────────┐  │
│  │                                                          │  │
│  │  C1  False Start                              30s        │  │
│  │  C2  Early transition entry                   30s        │  │
│  │  C3  Incorrect ski carry                      60s        │  │
│  │  C4  Missing equipment                        DSQ        │  │
│  │                                               ▼ scroll   │  │
│  └──────────────────────────────────────────────────────────┘  │
│                                                                 │
│  Virtual keyboard appears when search input is focused          │
└─────────────────────────────────────────────────────────────────┘
```

**UX Requirements:**
- Search by penalty number (C1, A2, etc.) - primary method
- Display penalty name alongside number
- Show penalty time/DSQ for race type context
- Large touch targets (64px minimum)

### Desktop: Reports Index

Standard admin table with filters:

```
┌─────────────────────────────────────────────────────────────────┐
│  Reports for: [Race Selector ▼]                                 │
│                                                                 │
│  Filter: [All ▼] [pending_review] [confirmed] [rejected]        │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ Bib │ Athlete      │ Location    │ Status  │ Time  │ Act │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │ 12  │ M. SMITH     │ Uphill-Top  │ pending │ 10:34 │ [·] │  │
│  │ 25  │ J. DOE       │ Descent     │ confirm │ 10:35 │ [·] │  │
│  │ 7   │ A. CHEN      │ Transition  │ reject  │ 10:36 │ [·] │  │
│  └───────────────────────────────────────────────────────────┘  │
│                                                                 │
│  [ ] Select All    [Merge Selected]  [+ New Report]             │
└─────────────────────────────────────────────────────────────────┘
```

### Desktop: Incidents Index

```
┌─────────────────────────────────────────────────────────────────┐
│  Incidents for: [Race Selector ▼]                               │
│                                                                 │
│  Filter: [All ▼] [pending] [approved] [rejected]                │
│                                                                 │
│  ┌───────────────────────────────────────────────────────────┐  │
│  │ ID │ Reports │ Location    │ Penalties │ Status  │ Action │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │ 1  │ 2       │ Uphill-Top  │ C1, C3    │ approved│ [View] │  │
│  │ 2  │ 1       │ Descent     │ -         │ pending │ [View] │  │
│  │ 3  │ 1       │ Transition  │ -         │ rejected│ [View] │  │
│  └───────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

---

## Authorization Matrix

| Action | Admin | Referee | VAR Operator |
|--------|:-----:|:-------:|:------------:|
| Create report | ✅ | ✅ | ✅ |
| Confirm/Reject report | ✅ | ✅ | ✅ |
| Reopen report | ✅ | ✅ | ✅ |
| Merge reports → incident | ✅ | ❌ | ✅ |
| Decide incident | ✅ | ❌ | ✅ |
| Attach/change penalties | ✅ | ❌ | ✅ |
| Reopen incident | ✅ | ❌ | ✅ |

### Policy Implementation

```ruby
# app/policies/report_policy.rb
class ReportPolicy
  def create?
    race_in_progress? && any_role?
  end

  def confirm?
    any_role?
  end

  def reject?
    any_role?
  end

  def reopen?
    any_role?
  end
end

# app/policies/incident_policy.rb
class IncidentPolicy
  def create? # merge
    admin_or_var?
  end

  def decide?
    admin_or_var?
  end

  def attach_penalties?
    admin_or_var?
  end

  def reopen?
    admin_or_var?
  end

  private

  def admin_or_var?
    user.admin? || user.var_operator?
  end
end
```

---

## Business Rules

### 1. Report Creation

- Race must be `in_progress` status
- Location must belong to the race
- Bib must exist in race participations for that race
- `client_uuid` ensures idempotency (prevents duplicate reports)

### 2. Report Status Transitions

```
                    ┌──────────────┐
                    │              │
         ┌──────────│ pending_review│◀──────────┐
         │          │              │            │
         │          └──────────────┘            │
         │               │    │                 │
         ▼               ▼    ▼                 │
  ┌──────────┐    ┌──────────────┐              │
  │          │    │              │              │
  │ rejected │    │  confirmed   │──────────────┘
  │          │    │              │   (reopen)
  └──────────┘    └──────────────┘
         │               │
         │               │
         └───────────────┘
              (reopen)
```

### 3. Incident Creation (Merge)

- Requires at least 1 confirmed report
- All reports must be from the same race
- Reports get linked to the incident (`incident_id` set)
- Incident inherits `race_location_id` from first report
- Status starts as `pending`

### 4. Incident Decision

- Can attach multiple penalties from penalty reference table
- Status transitions: `pending` → `approved` | `rejected`
- Decision records who decided (`decided_by_user_id`) and when (`decided_at`)
- Can be reopened to change decision

### 5. Penalty Attachment

- Penalties can be attached/changed at any time
- Multiple penalties per incident allowed
- Each penalty can only be attached once per incident (unique constraint)

---

## Files Summary

| Layer | Count | Files |
|-------|-------|-------|
| Migrations | 3 | incidents, reports, incident_penalties |
| Models | 3 | incident, report, incident_penalty |
| Structs | 4 | incident, incident_summary, report, report_summary |
| Repos | 2 | incident_repo, report_repo |
| Contracts | 5 | create_report, update_report, create_incident, decide_incident, attach_penalties |
| Operations | 8 | reports (4), incidents (4) |
| Controllers | 4 | admin (2), touch (2) |
| Parts | 2 | report, incident |
| Views | ~16 | admin (8), touch (8) |
| Policies | 2 | report_policy, incident_policy |
| Tests | ~12 | models, repos, operations, requests |

**Total: ~55 files**

---

## Deferred Features

These features are planned for future phases:

### Video Attachments (Phase 2)
- Add Active Storage attachment to reports
- VAR operator uploads video clips
- Video review during incident decision

### Real-time Broadcasting (Phase 2)
- Turbo Streams for live updates
- New reports appear instantly on all devices
- Status changes broadcast to all viewers
- Incident decisions sync in real-time

### Offline Sync (Phase 3)
- Full PWA support for touch devices
- Local queue for reports created offline
- Sync when network available
- Conflict resolution for concurrent edits

---

## Progress Tracking

### Phase 1: Database & Types ✅ COMPLETE
- [x] Migration: create_incidents
- [x] Migration: create_reports
- [x] Migration: create_incident_penalties
- [x] Update types.rb (ReportStatus, IncidentStatus)

### Phase 2: Models ✅ COMPLETE
- [x] Incident model
- [x] Report model
- [x] IncidentPenalty model
- [x] Update existing models (Race, RaceLocation, RaceParticipation, User, Penalty)

### Phase 3: Structs ✅ COMPLETE
- [x] Structs::Incident
- [x] Structs::IncidentSummary
- [x] Structs::Report
- [x] Structs::ReportSummary

### Phase 4: Repos ✅ COMPLETE
- [x] IncidentRepo
- [x] ReportRepo
- [x] AppContainer registration

### Phase 5: Contracts ✅ COMPLETE
- [x] CreateReport
- [x] UpdateReport
- [x] CreateIncident
- [x] DecideIncident
- [x] AttachPenalties

### Phase 6: Operations ✅ COMPLETE
- [x] Reports::Create
- [x] Reports::Confirm
- [x] Reports::Reject
- [x] Reports::Reopen
- [x] Incidents::Create
- [x] Incidents::Decide
- [x] Incidents::AttachPenalties
- [x] Incidents::Reopen

### Phase 7: Parts ✅ COMPLETE
- [x] Web::Parts::Report
- [x] Web::Parts::Incident

### Phase 8: Desktop Admin Controllers ✅ COMPLETE
- [x] Admin::Races::ReportsController
- [x] Admin::Races::IncidentsController
- [x] Routes (nested under races)

### Phase 9: Desktop Admin Views ✅ COMPLETE
- [x] Reports index
- [x] Reports show
- [x] Reports new
- [x] Incidents index
- [x] Incidents show
- [x] Incidents new (merge UI)
- [x] Incidents edit (decision + penalty selector)

### Phase 10: Touch Controllers
- [ ] Touch::ReportsController
- [ ] Touch::IncidentsController
- [ ] Routes

### Phase 11: Touch Views
- [ ] Report creation (location + bib)
- [ ] Pending reports queue
- [ ] Report review
- [ ] Merge UI
- [ ] Incident decision
- [ ] Penalty selector modal

### Phase 12: Authorization
- [ ] ReportPolicy
- [ ] IncidentPolicy

### Phase 13: Testing
- [ ] Model specs
- [ ] Struct specs
- [ ] Repo specs
- [ ] Operation specs
- [ ] Request specs

---

## Estimated Timeline

| Phase | Effort |
|-------|--------|
| Phase 1-4 (DB, Models, Structs, Repos) | ~3.5 hours |
| Phase 5-6 (Contracts, Operations) | ~3 hours |
| Phase 7-9 (Parts, Desktop Admin) | ~6 hours |
| Phase 10-11 (Touch UI) | ~6 hours |
| Phase 12-13 (Auth, Testing) | ~4 hours |
| **Total** | **~22-25 hours** |

---

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Overall system architecture
- [DATABASE_DESIGN.md](./DATABASE_DESIGN.md) - Full database schema
- [RACE_LOCATIONS.md](./RACE_LOCATIONS.md) - Race location system
- [TOUCH_SCREEN_IMPLEMENTATION.md](./TOUCH_SCREEN_IMPLEMENTATION.md) - Touch UI patterns
- [FEATURE_WORKFLOW.md](./FEATURE_WORKFLOW.md) - Development workflow