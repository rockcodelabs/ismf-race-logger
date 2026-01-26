# V1 Features Overview

This document provides an overview of all planned features for the ISMF Race Logger V1, their dependencies, and implementation priority.

---

## Feature Summary

| Feature | Priority | Status | Dependencies |
|---------|----------|--------|--------------|
| [MSO Import & Athletes](./mso-import-participants.md) | 🔴 Critical | Planned | None |
| [FOP Real-Time Performance](./fop-realtime-performance.md) | 🔴 Critical | Planned | MSO Import |
| Multi-File Video Upload | 🟡 High | Planned | FOP Performance |
| [Video Clip Selector](./video-clip-selector.md) | 🟡 High | Planned | Multi-File Video Upload |
| Report → Incident Workflow | 🟡 High | Planned | FOP Performance |
| Rules Management | 🟢 Medium | Planned | None |
| PDF Report Export | 🟢 Medium | Planned | Report Workflow |

---

## Architecture Decisions

### Environment Simplification

| Environment | Host | Port | Purpose |
|-------------|------|------|---------|
| **Development** | localhost | 3003 | Local Docker dev |
| **Production** | pi5main.local | 3000 (via Kamal proxy) | Raspberry Pi 5 |

> ⚠️ **No staging environment** - Test thoroughly in development before deploying to production.

### Device Roles

| Device Type | Role | Features |
|-------------|------|----------|
| **7" Display** | FOP Creation | Bib selector, location tap, quick report |
| **iPad/Tablet** | FOP Creation | Same + video capture |
| **Phone** | FOP Creation | Quick reports, camera |
| **Desktop** | Viewing Only | Dashboard, notifications, incident management |

### Key Constraints

| Constraint | Value | Impact |
|------------|-------|--------|
| Max athletes per race | 200 | Client-side bib selection trivial |
| Active bibs vary by stage | 8 (finals) to 200 (quali) | Heat-based filtering |
| Team races | Pairs (MM, MW, WW) | Two athletes share one bib |
| Duplicate reports | Allowed | Grouped into incidents |
| Stale reports | Hidden after 5 min | Background job cleanup |
| Video upload | Multiple files per report | File upload only in V1 (no in-app recording) |
| MSO format | CSV of athletes still active | Simple bib list import |

---

## Feature Dependencies

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         FEATURE DEPENDENCY GRAPH                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────┐                                               │
│  │  MSO Import &       │  ◄── Foundation: Athlete, Team,               │
│  │  Athletes           │      RaceParticipation models                 │
│  └──────────┬──────────┘                                               │
│             │                                                          │
│             ▼                                                          │
│  ┌─────────────────────┐                                               │
│  │  FOP Real-Time      │  ◄── Core: Bib selector with flags,          │
│  │  Performance        │      report creation, desktop notifications   │
│  └──────────┬──────────┘                                               │
│             │                                                          │
│       ┌─────┴─────┐                                                    │
│       │           │                                                    │
│       ▼           ▼                                                    │
│  ┌──────────┐ ┌──────────────────┐                                     │
│  │  Multi   │ │ Report→Incident  │                                     │
│  │  Video   │ │ Workflow         │                                     │
│  └──────────┘ └────────┬─────────┘                                     │
│                        │                                               │
│                        ▼                                               │
│                 ┌──────────────┐                                       │
│                 │  PDF Export  │                                       │
│                 └──────────────┘                                       │
│                                                                         │
│  ┌─────────────────────┐                                               │
│  │  Rules Management   │  ◄── Independent, can be built in parallel   │
│  └─────────────────────┘                                               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Implementation Order

### Phase 1: Foundation (Week 1-2)

1. **Athlete Model** - `app/models/athlete.rb`
   - First name, last name
   - Country (ISO 3166-1 alpha-3: SUI, FRA, ITA)
   - License number (optional, ISMF license)
   - Gender (male/female)
   - Flag emoji helper

2. **Team Model** - `app/models/team.rb`
   - For pair races (MM, MW, WW)
   - Two athletes per team
   - Shared bib number
   - Team type validation matches genders

3. **RaceParticipation Model** - `app/models/race_participation.rb`
   - Links race to athlete (individual) or team (pairs)
   - Bib number (unique per race)
   - Heat, active_in_heat for filtering
   - Status tracking (registered, racing, finished, DNF, DNS, DSQ)

4. **MSO Import** - `app/services/mso/import.rb`
   - CSV parser for active athletes
   - Separate formats for individual vs team races
   - Upsert athletes and participations

5. **Report Model Updates** - `app/models/report.rb`
   - Add `race_participation_id`, `bib_number` (denormalized)
   - Add lifecycle: `status`, `stale_at`
   - Multiple videos (`has_many_attached :videos`)
   - Background job for stale detection

### Phase 2: FOP Interface (Week 2-3)

6. **Bib Selector** - `app/components/fop/bib_selector_component.rb` (ViewComponent)
   - Pre-loaded race participation JSON
   - Heat-aware filtering (8-200 bibs)
   - Display: **bib number + country flag** (🇫🇷, 🇮🇹)
   - Team races show both flags: 🇫🇷 🇪🇸 (MW)
   - Touch-optimized (56px targets)
   - Optimistic UI report creation

7. **FOP Layout** - `app/views/layouts/fop.html.erb`
   - Location icons on course view
   - Modal for bib selection
   - Offline queue (IndexedDB)

### Phase 3: Desktop Dashboard (Week 3-4)

8. **Reports Channel** - `app/channels/reports_channel.rb`
   - Desktop-only subscription
   - Broadcast on report create/update

9. **Report Dashboard** - `app/views/races/show.html.erb` (desktop)
   - Live report list
   - "New reports" banner
   - Toast notifications
   - Report → Incident grouping

10. **Stale Reports Job** - `app/jobs/mark_stale_reports_job.rb`
    - Run every minute
    - Mark pending reports as stale after 5 min

### Phase 4: Video & Export (Week 4-5)

11. **Multi-File Video Upload** - `app/services/reports/add_videos.rb`
    - Multiple file upload per report
    - File types: MP4, MOV, WebM
    - Progress indicators per file
    - No in-app recording in V1

12. **Incident Workflow** - `app/services/incidents/create_from_reports.rb`
    - Group reports into incident
    - Add rule reference
    - Set penalty (applies to athlete, cascades to team)

13. **PDF Export** (if time permits)
    - Incident summary PDF
    - Race report PDF

---

## Data Models Overview

```
┌─────────────┐     ┌──────────────┐     ┌─────────────┐
│ Competition │────<│    Stage     │────<│    Race     │
└─────────────┘     └──────────────┘     └──────┬──────┘
                                                │
              ┌─────────────────────────────────┼─────────────────────────────────┐
              │                                 │                                 │
              ▼                                 ▼                                 ▼
       ┌─────────────┐               ┌──────────────────┐               ┌─────────────┐
       │RaceLocation │               │ RaceParticipation│               │   Report    │
       ├─────────────┤               ├──────────────────┤               ├─────────────┤
       │ name        │               │ bib_number       │◄──────────────│ bib_number  │
       │ position    │◄──────────────│ athlete_id (opt) │               │ participation│
       │ has_camera  │               │ team_id (opt)    │               │ location    │
       └─────────────┘               │ heat             │               │ status      │
                                     │ active_in_heat   │               │ stale_at    │
                                     │ status           │               │ videos[]    │
                                     └────────┬─────────┘               └──────┬──────┘
                                              │                                │
                           ┌──────────────────┴──────────────────┐             │
                           │                                     │             │
                           ▼                                     ▼             ▼
                    ┌─────────────┐                       ┌─────────────┐ ┌─────────────┐
                    │   Athlete   │                       │    Team     │ │  Incident   │
                    ├─────────────┤                       ├─────────────┤ ├─────────────┤
                    │ first_name  │◄──────────────────────│ athlete_1_id│ │ reports[]   │
                    │ last_name   │◄──────────────────────│ athlete_2_id│ │ rule        │
                    │ country     │                       │ team_type   │ │ penalty     │
                    │ license_num │                       │ (mm/mw/ww)  │ │ status      │
                    │ gender      │                       └─────────────┘ └─────────────┘
                    └─────────────┘
```

---

## Performance Targets

### FOP Devices (Creation)

| Metric | Target |
|--------|--------|
| Bib modal open | < 50ms |
| Bib selection | < 100ms perceived |
| Offline queue sync | < 30s after reconnection |

### Desktop Devices (Viewing)

| Metric | Target |
|--------|--------|
| Report list load | < 300ms (100 reports) |
| Real-time notification | < 1s delay |
| Dashboard render | < 200ms |

---

## Files to Create

### Models
- [ ] `app/models/athlete.rb`
- [ ] `app/models/team.rb`
- [ ] `app/models/race_participation.rb`
- [ ] `app/models/mso_import.rb`
- [ ] `db/migrate/*_create_athletes.rb`
- [ ] `db/migrate/*_create_teams.rb`
- [ ] `db/migrate/*_create_race_participations.rb`
- [ ] `db/migrate/*_add_race_participation_to_reports.rb`
- [ ] `db/migrate/*_create_mso_imports.rb`

### Services
- [ ] `app/services/mso/parse_csv.rb`
- [ ] `app/services/mso/parse_team_csv.rb`
- [ ] `app/services/mso/import.rb`
- [ ] `app/services/reports/create.rb`
- [ ] `app/services/reports/add_videos.rb`
- [ ] `app/services/reports/list_for_race.rb`

### Jobs
- [ ] `app/jobs/mso_import_job.rb`
- [ ] `app/jobs/mark_stale_reports_job.rb`

### Channels
- [ ] `app/channels/reports_channel.rb`
- [ ] `app/channels/race_participations_channel.rb`

### Components
- [ ] `app/components/fop/bib_selector_component.rb`
- [ ] `app/components/fop/report_card_component.rb`
- [ ] `app/components/fop/toast_component.rb`
- [ ] `app/components/fop/new_reports_banner_component.rb`

### JavaScript
- [ ] `app/javascript/controllers/bib_selector_controller.js`
- [ ] `app/javascript/controllers/report_notifications_controller.js`
- [ ] `app/javascript/controllers/toast_controller.js`
- [ ] `app/javascript/channels/reports_channel.js`
- [ ] `app/javascript/services/offline_queue.js`

### Views
- [ ] `app/views/layouts/fop.html.erb`
- [ ] `app/views/races/show.html.erb` (FOP version)
- [ ] `app/views/races/show.html.erb` (Desktop version)
- [ ] `app/views/mso_imports/index.html.erb`
- [ ] `app/views/reports/_video_upload.html.erb`

---

## Design Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| **Country display** | 3-letter text code (FRA, SUI) | Performance - faster rendering than emoji flags |
| **Team names** | Auto-generated: `DUPONT/GARCIA` | Consistent, no manual entry needed |
| **License number** | Free text, optional | No format validation required |
| **Country validation** | Known ISMF countries only | Prevent typos, ensure data quality |

---

## Bib Selector Display

**Uses text country codes for performance** (no emoji flags)

**Team races**: Report targets specific athlete (12.1 or 12.2), color-coded by gender:
- 🔵 **Blue** = Male
- 🔴 **Pink** = Female

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Individual Race (tap bib)          Team Race (tap specific athlete)    │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────┐ ┌──────────┐          ┌─────────────────────┐            │
│  │    12    │ │    34    │          │ 12  FRA             │            │
│  │   SUI    │ │   FRA    │          │ ┌────────┐┌────────┐│            │
│  └──────────┘ └──────────┘          │ │  12.1  ││  12.2  ││            │
│                                     │ │ BLUE   ││ PINK   ││            │
│                                     │ │ Male   ││ Female ││            │
│                                     │ └────────┘└────────┘│            │
│                                     │        MW           │            │
│                                     └─────────────────────┘            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

### ISMF Member Countries (Validated)

```
AND ARG AUS AUT BEL BGR BIH CAN CHI CHN CRO CZE
ESP FIN FRA GBR GER GRE HUN IND IRN ISR ITA JPN
KAZ KOR LIE LTU MDA MKD NED NOR NZL POL POR ROU
RSA RUS SLO SRB SUI SVK SWE TUR UKR USA
```

---

## Related Documents

- [Implementation Plan](../implementation-plan-rails-8.1.md) - Full Rails 8.1 setup
- [Architecture Overview](../architecture-overview.md) - Data models and authorization
- [MSO Import & Athletes](./mso-import-participants.md) - Detailed MSO feature spec
- [FOP Real-Time Performance](./fop-realtime-performance.md) - Detailed FOP feature spec