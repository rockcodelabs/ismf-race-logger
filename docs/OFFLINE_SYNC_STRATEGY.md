# ISMF Race Logger - Offline Sync Strategy

**Version:** 2.0  
**Last Updated:** 2026-01-27  
**Status:** Final Design - Ready for Implementation

---

## Table of Contents

- [Executive Summary](#executive-summary)
- [Problem Statement](#problem-statement)
- [Core Decisions](#core-decisions)
- [Architecture Overview](#architecture-overview)
- [Data Model Design](#data-model-design)
- [Sync Protocol](#sync-protocol)
- [Deduplication Strategy](#deduplication-strategy)
- [API Specification](#api-specification)
- [Implementation Guide](#implementation-guide)
- [Error Handling](#error-handling)
- [Testing Strategy](#testing-strategy)
- [Deployment Guide](#deployment-guide)
- [Edge Cases & Solutions](#edge-cases--solutions)

---

## Executive Summary

This document defines a **bulletproof bi-directional sync strategy** for ISMF Race Logger, enabling a Raspberry Pi device to operate as a fully independent copy of the online application, then merge seamlessly when connectivity is restored.

### Key Goals

1. **Full autonomy** - Pi works completely offline for entire competition day
2. **Zero data loss** - All incidents/reports preserved across sync
3. **No duplicates** - Smart deduplication prevents duplicate incidents
4. **Simple operation** - One-click sync, automatic when possible
5. **Same codebase** - Online and offline apps are identical

### Design Principles

- **`client_uuid` is truth** - UUIDs are the real distributed identifier
- **Integer IDs are local** - Database IDs are convenience only
- **Reference data created once** - Competitions/races created in ONE place (cloud OR Pi)
- **Operational data merges** - Incidents/reports created in BOTH places, intelligently merged
- **3-layer deduplication** - UUID match → Fingerprint → Manual review

---

## Problem Statement

### Real-World Scenario

```
┌────────────────────────────────────────────────────────────────┐
│ ONLINE APP (Cloud Server - PostgreSQL)                         │
│ https://race-logger.ismf.cloud                                 │
│                                                                 │
│ - Competition setup (races, athletes, schedules)               │
│ - VAR operators reviewing incidents remotely                   │
│ - Jury president making decisions                              │
└────────────────────────────────────────────────────────────────┘
                              ↕ 
                    (Sometimes connected,
                     sometimes offline)
                              ↕
┌────────────────────────────────────────────────────────────────┐
│ OFFLINE APP (Raspberry Pi - PostgreSQL)                        │
│ At race venue (mountain resort, poor/no connectivity)          │
│                                                                 │
│ - Same Rails app, same database schema                         │
│ - Referee reporting incidents via touch display                │
│ - Video clips from Reolink cameras (local network)             │
│ - Works 100% offline for entire day                            │
└────────────────────────────────────────────────────────────────┘
```

### Challenges

1. **ID Collisions** - Both systems generate database IDs independently
2. **Duplicate Incidents** - Same incident might be reported on both systems
3. **Foreign Key References** - Incident references race, but race IDs differ between systems
4. **Network Unreliability** - Sync might fail midway, must resume
5. **Data Consistency** - Both systems must converge to same state after sync

---

## Core Decisions

Based on analysis of real-world usage patterns, we made these architectural decisions:

### Decision Matrix

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 1 | What data downloads before going offline? | Full competition day (all races) | Typical: one day = one competition with multiple race stages |
| 2 | Who can create incidents during race? | Both Pi AND Cloud (when online), Pi only (when offline) | Some races have internet, some don't |
| 3 | How to prevent duplicate incidents? | 3-layer: UUID → Fingerprint → Manual | UUID for exact match, fingerprint for smart merge, manual for edge cases |
| 4 | When does sync happen? | Auto-detect + Manual button | Most races have internet (auto), fallback to manual |
| 5 | What if sync fails midway? | Incremental/resume sync | Mountain venues have unreliable networks |
| 6 | Database for Pi? | PostgreSQL (same as cloud) | Same app, same DB, maximum compatibility |
| 7 | Initial data download method? | API endpoint (JSON) | Uses existing repo/operation code, maintainable |
| 8 | User authentication on Pi? | Single pre-configured user | Only one referee on Pi, simplifies offline auth |
| 9 | Video handling? | Sync with incidents | Videos are small clips (few seconds), not full race footage |
| 10 | Foreign key references in sync? | Use `client_uuid` instead of IDs | Cloud resolves UUIDs to local IDs on receiving end |
| 11 | Sync order? | Explicit batches (separate requests) | Respects dependencies, easier to debug/resume |
| 12 | After sync completes? | Clear Pi database | Ready for next competition, clean slate |

---

## Architecture Overview

### System Modes

The same Rails application runs in two modes:

```ruby
# config/application.rb
config.system_mode = ENV.fetch("SYSTEM_MODE", "cloud") # "cloud" or "offline_device"
```

| Mode | Environment | Database | Features |
|------|-------------|----------|----------|
| **cloud** | Production server | PostgreSQL (cloud) | Full web interface, multi-user, ActionCable, admin panel |
| **offline_device** | Raspberry Pi | PostgreSQL (local) | Touch UI, single user, sync queue, no ActionCable |

### Data Categories

#### Reference Data (Created Once, Synced)

Data created in **ONE place only** (either cloud or Pi, never both):

- Competitions
- Stages
- Races
- Race Types
- Race Locations
- Athletes
- Teams
- Race Participations

**Sync Direction:** Whoever creates → Other syncs  
**ID Strategy:** Local IDs differ, `client_uuid` is authoritative

#### Operational Data (Created in Both, Merged)

Data created **simultaneously** on cloud and Pi during race:

- Incidents
- Reports

**Sync Direction:** Bi-directional merge  
**ID Strategy:** Deduplication via UUID + fingerprint

#### System Data (Not Synced)

- Users (pre-configured on Pi before race)
- Sessions
- Magic Links

---

## Data Model Design

### Schema Changes

All syncable tables require `client_uuid` column:

```ruby
# db/migrate/YYYYMMDDHHMMSS_add_client_uuid_to_syncable_tables.rb
class AddClientUuidToSyncableTables < ActiveRecord::Migration[8.1]
  def change
    # Reference Data
    add_column :competitions, :client_uuid, :uuid, null: false
    add_index :competitions, :client_uuid, unique: true
    
    add_column :stages, :client_uuid, :uuid, null: false
    add_index :stages, :client_uuid, unique: true
    
    add_column :races, :client_uuid, :uuid, null: false
    add_index :races, :client_uuid, unique: true
    
    add_column :race_locations, :client_uuid, :uuid, null: false
    add_index :race_locations, :client_uuid, unique: true
    
    add_column :athletes, :client_uuid, :uuid, null: false
    add_index :athletes, :client_uuid, unique: true
    
    add_column :teams, :client_uuid, :uuid, null: false
    add_index :teams, :client_uuid, unique: true
    
    add_column :race_participations, :client_uuid, :uuid, null: false
    add_index :race_participations, :client_uuid, unique: true
    
    # Operational Data
    add_column :incidents, :client_uuid, :uuid, null: false
    add_index :incidents, :client_uuid, unique: true
    
    # Reports already has client_uuid!
    # add_column :reports, :client_uuid, :uuid (already exists)
  end
end
```

### Sync Metadata Tables

#### `devices` - Track known devices

```ruby
create_table :devices do |t|
  t.uuid :device_uuid, null: false, index: { unique: true }
  t.string :name, null: false              # "Start Line Pi", "Finish Line Pi"
  t.string :system_mode, null: false       # "cloud", "offline_device"
  t.string :status, default: "active"      # "active", "offline", "decommissioned"
  t.datetime :last_seen_at
  t.string :api_token_digest               # For authentication
  t.jsonb :metadata                        # { hardware, os, app_version }
  t.timestamps
end
```

#### `sync_queue` - Track pending syncs (Pi only)

```ruby
create_table :sync_queue do |t|
  t.uuid :client_uuid, null: false, index: { unique: true }
  t.string :record_type, null: false       # "Competition", "Race", "Incident", "Report"
  t.bigint :local_id, null: false          # ID in local database
  t.jsonb :payload, null: false            # Full record data as JSON
  t.string :status, default: "pending"     # "pending", "synced", "conflict", "failed"
  t.integer :retry_count, default: 0
  t.datetime :last_retry_at
  t.text :error_message
  t.timestamps
end

add_index :sync_queue, :status
add_index :sync_queue, [:record_type, :status]
```

#### `sync_conflicts` - Track conflicts needing review (Cloud only)

```ruby
create_table :sync_conflicts do |t|
  t.references :incident, foreign_key: true # Null if conflict is for reference data
  t.uuid :device_uuid_source, null: false   # Device that sent conflicting data
  t.string :conflict_type, null: false      # See conflict types below
  t.string :record_type, null: false        # "Incident", "Report", "Athlete"
  t.uuid :record_client_uuid, null: false
  t.jsonb :cloud_data, null: false          # Current state on cloud
  t.jsonb :device_data, null: false         # Incoming data from device
  t.string :resolution, default: "pending"  # "pending", "cloud_wins", "device_wins", "manual"
  t.bigint :resolved_by_user_id
  t.datetime :resolved_at
  t.text :resolution_notes
  t.timestamps
end

add_index :sync_conflicts, :resolution
add_index :sync_conflicts, :record_client_uuid
```

### Types Extensions

```ruby
# lib/types.rb
module Types
  SyncStatus = Types::String.enum("pending", "synced", "conflict", "failed")
  
  ConflictType = Types::String.enum(
    "uuid_exists_different_data",    # Same UUID, different content
    "decision_mismatch",              # Different incident decisions
    "fingerprint_match_uuid_differs", # Same incident, different UUIDs
    "foreign_key_not_found"           # References non-existent record
  )
  
  ResolutionStatus = Types::String.enum(
    "pending",
    "cloud_wins",
    "device_wins",
    "manual"
  )
  
  SystemMode = Types::String.enum("cloud", "offline_device")
end
```

---

## Sync Protocol

### Overall Flow

```
┌─────────────────────────────────────────────────────────────────┐
│ PHASE 1: Pre-Race Setup (Morning, with internet)                │
├─────────────────────────────────────────────────────────────────┤
│ 1. Admin opens Pi web interface                                 │
│ 2. Navigates to "Sync" page                                     │
│ 3. Clicks "Download Competition: Verbier 2026"                  │
│ 4. Pi calls: GET /api/v1/sync/download?competition_id=123       │
│ 5. Cloud returns JSON with all race data                        │
│ 6. Pi inserts into local database via repos/operations          │
│ 7. Status: "Ready for offline operation"                        │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ PHASE 2: During Race (May be online or offline)                 │
├─────────────────────────────────────────────────────────────────┤
│ ONLINE (has internet):                                           │
│   - Referee reports incidents on Pi                             │
│   - Pi auto-syncs every 5 minutes                               │
│   - Cloud and Pi stay in sync                                   │
│                                                                  │
│ OFFLINE (no internet):                                           │
│   - Referee reports incidents on Pi                             │
│   - All data stored locally                                     │
│   - Each record added to sync_queue table                       │
│   - Background job checks for network every 5 min               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ PHASE 3: Sync (When internet available)                         │
├─────────────────────────────────────────────────────────────────┤
│ 1. Network detected (auto) or "Sync Now" clicked (manual)       │
│ 2. Pi loads all sync_queue entries with status: "pending"       │
│ 3. Groups by record_type (competitions, races, incidents, etc)  │
│ 4. Syncs in dependency order (see below)                        │
│ 5. For each batch:                                              │
│    a. POST to /api/v1/sync/{record_type}                        │
│    b. Cloud processes with 3-layer deduplication                │
│    c. Cloud returns status for each record                      │
│    d. Pi updates sync_queue status                              │
│    e. On success: mark as "synced"                              │
│    f. On conflict: mark as "conflict", notify user              │
│    g. On error: increment retry_count                           │
│ 6. Repeat until all synced or max retries reached               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│ PHASE 4: Post-Sync Cleanup                                      │
├─────────────────────────────────────────────────────────────────┤
│ 1. Verify all sync_queue entries are "synced"                   │
│ 2. If conflicts exist: Show admin UI for resolution             │
│ 3. Once resolved: Clear Pi database                             │
│ 4. Status: "Ready for next competition"                         │
└─────────────────────────────────────────────────────────────────┘
```

### Sync Order (Dependency Respecting)

```ruby
# app/services/sync_service.rb
SYNC_ORDER = [
  # Reference data (in dependency order)
  "Competition",
  "Stage",
  "Race",
  "RaceLocation",
  "Athlete",
  "Team",
  "RaceParticipation",
  
  # Operational data
  "Incident",
  "Report"
].freeze
```

---

## Deduplication Strategy

### 3-Layer Approach

```
┌──────────────────────────────────────────────────────────────┐
│ LAYER 1: UUID Exact Match (Idempotent)                       │
├──────────────────────────────────────────────────────────────┤
│ Cloud checks: Does record with this client_uuid exist?       │
│ → YES: Compare data                                          │
│   ├─ Same data: Return 200 OK (already synced)              │
│   └─ Different data: Continue to LAYER 3 (conflict)         │
│ → NO: Continue to LAYER 2                                    │
└──────────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────────┐
│ LAYER 2: Content Fingerprint (Auto-Merge)                   │
├──────────────────────────────────────────────────────────────┤
│ For incidents only:                                           │
│ Generate fingerprint = hash(race_id, bib, location, ±30sec) │
│ Cloud checks: Does incident with same fingerprint exist?     │
│ → YES: Auto-merge (move reports to existing incident)        │
│       Create sync_conflict record (type: auto_merged)        │
│       Return 200 OK with existing incident                   │
│ → NO: Continue to LAYER 3 (create new)                       │
└──────────────────────────────────────────────────────────────┘
                         ↓
┌──────────────────────────────────────────────────────────────┐
│ LAYER 3: Create New / Flag Conflict                         │
├──────────────────────────────────────────────────────────────┤
│ If data is clean:                                            │
│   → Create new record, return 201 Created                    │
│                                                              │
│ If conflict detected (Layer 1 found different data):         │
│   → Create sync_conflict record                              │
│   → Return 409 Conflict with details                         │
│   → Admin reviews and resolves manually                      │
└──────────────────────────────────────────────────────────────┘
```

### Fingerprint Algorithm (Incidents Only)

```ruby
# app/services/incident_fingerprint_service.rb
class IncidentFingerprintService
  TIME_WINDOW = 30.seconds
  
  def self.generate(incident_attrs)
    # Normalize data for fingerprinting
    components = [
      incident_attrs[:race_client_uuid],
      incident_attrs[:race_location_client_uuid],
      incident_attrs[:bib_number],
      normalize_timestamp(incident_attrs[:created_at])
    ]
    
    Digest::SHA256.hexdigest(components.join("|"))
  end
  
  def self.normalize_timestamp(timestamp)
    # Round to 30-second buckets
    time = Time.zone.parse(timestamp.to_s)
    bucket = (time.to_i / TIME_WINDOW).floor * TIME_WINDOW
    Time.zone.at(bucket).iso8601
  end
end
```

### Conflict Detection Rules

| Scenario | Detection | Resolution |
|----------|-----------|------------|
| **Same UUID, same data** | Layer 1 | Return 200 OK (idempotent) |
| **Same UUID, different data** | Layer 1 | 409 Conflict → Manual review |
| **Different UUID, same fingerprint** | Layer 2 | Auto-merge reports → Cloud incident wins |
| **Incident decision differs** | Layer 3 | 409 Conflict → Manual review |
| **Foreign key not found** | Layer 3 | 422 Unprocessable → Sync parent first |

---

## API Specification

### Authentication

All sync endpoints require device authentication:

```http
Authorization: Bearer <device_api_token>
X-Device-UUID: <device_uuid>
```

### Endpoints

#### `GET /api/v1/sync/download`

Download competition data to Pi before going offline.

**Request:**
```http
GET /api/v1/sync/download?competition_id=123
Authorization: Bearer abc123...
X-Device-UUID: device-pi-start-line
```

**Response (200 OK):**
```json
{
  "competition": {
    "client_uuid": "comp-uuid-123",
    "name": "ISMF World Cup - Verbier 2026",
    "start_date": "2026-02-15",
    "end_date": "2026-02-15"
  },
  "stages": [...],
  "races": [
    {
      "client_uuid": "race-uuid-456",
      "stage_client_uuid": "stage-uuid-789",
      "name": "Men's Sprint - Qualification",
      "scheduled_at": "2026-02-15T09:00:00Z"
    }
  ],
  "race_locations": [...],
  "athletes": [...],
  "teams": [...],
  "race_participations": [...]
}
```

---

#### `POST /api/v1/sync/competitions`

Upload competitions created on Pi.

**Request:**
```json
{
  "competitions": [
    {
      "client_uuid": "comp-uuid-new",
      "name": "Emergency Competition",
      "place": "Chamonix",
      "country": "FRA",
      "start_date": "2026-02-20",
      "end_date": "2026-02-20",
      "created_at": "2026-02-20T08:00:00Z"
    }
  ]
}
```

**Response (200 OK):**
```json
{
  "results": [
    {
      "client_uuid": "comp-uuid-new",
      "status": "created",
      "cloud_id": 42
    }
  ]
}
```

---

#### `POST /api/v1/sync/incidents`

Upload incidents created on Pi.

**Request:**
```json
{
  "incidents": [
    {
      "client_uuid": "incident-uuid-123",
      "race_client_uuid": "race-uuid-456",
      "race_location_client_uuid": "loc-uuid-789",
      "status": "unofficial",
      "description": "Athlete cut course",
      "created_at": "2026-02-15T10:32:15Z"
    }
  ]
}
```

**Response (200 OK - Mixed Results):**
```json
{
  "results": [
    {
      "client_uuid": "incident-uuid-123",
      "status": "created",
      "cloud_id": 87,
      "deduplication": {
        "layer": "fingerprint_match",
        "merged_with_incident_id": 89,
        "action": "reports_moved_to_existing"
      }
    }
  ]
}
```

**Response (409 Conflict):**
```json
{
  "results": [
    {
      "client_uuid": "incident-uuid-123",
      "status": "conflict",
      "conflict_id": 42,
      "conflict_type": "decision_mismatch",
      "details": {
        "cloud_decision": "no_action",
        "device_decision": "penalty_applied"
      }
    }
  ]
}
```

---

#### `POST /api/v1/sync/reports`

Upload reports created on Pi.

**Request:**
```json
{
  "reports": [
    {
      "client_uuid": "report-uuid-456",
      "incident_client_uuid": "incident-uuid-123",
      "race_client_uuid": "race-uuid-456",
      "race_participation_client_uuid": "part-uuid-789",
      "bib_number": 42,
      "description": "Athlete skipped gate",
      "video_clip": {
        "start_time": "00:15:32",
        "end_time": "00:15:38",
        "file_data": "<base64_encoded_video>"
      },
      "created_at": "2026-02-15T10:32:20Z"
    }
  ]
}
```

**Response (201 Created):**
```json
{
  "results": [
    {
      "client_uuid": "report-uuid-456",
      "status": "created",
      "cloud_id": 203
    }
  ]
}
```

---

## Implementation Guide

### Phase 1: Foundation (Weeks 1-2)

**Goal:** Basic sync infrastructure

1. Add `client_uuid` to all tables (migration)
2. Create `devices`, `sync_queue`, `sync_conflicts` tables
3. Update all `create` operations to generate `client_uuid`
4. Build device registration flow
5. Create `Api::V1::SyncController` base class

**Acceptance Criteria:**
- [ ] All tables have `client_uuid`
- [ ] Creating incident generates UUID automatically
- [ ] Device can register and get API token

---

### Phase 2: Download Flow (Weeks 3-4)

**Goal:** Pi can download competition data

1. Build `GET /api/v1/sync/download` endpoint
2. Create `Operations::Sync::PrepareDownload` operation
3. Build Pi UI: "Download Competition" page
4. Implement `Operations::Sync::ImportDownload` operation
5. Handle foreign key resolution (UUID → local ID)

**Acceptance Criteria:**
- [ ] Pi can download competition with all races
- [ ] Foreign keys resolve correctly
- [ ] UI shows download progress

---

### Phase 3: Upload Flow (Weeks 5-6)

**Goal:** Pi can upload incidents to cloud

1. Build `POST /api/v1/sync/incidents` endpoint
2. Build `POST /api/v1/sync/reports` endpoint
3. Implement Layer 1 deduplication (UUID match)
4. Create `sync_queue` background worker
5. Build Pi UI: "Sync Now" button with progress

**Acceptance Criteria:**
- [ ] Pi can upload incidents to cloud
- [ ] Idempotent: Same incident uploaded twice = no duplicate
- [ ] Sync resumes after network failure

---

### Phase 4: Deduplication (Weeks 7-8)

**Goal:** Smart incident merging

1. Implement `IncidentFingerprintService`
2. Build Layer 2 deduplication (fingerprint match)
3. Create auto-merge logic (move reports to existing incident)
4. Build conflict detection (Layer 3)
5. Create `sync_conflicts` admin UI

**Acceptance Criteria:**
- [ ] Same incident reported on Pi + Cloud → auto-merged
- [ ] Conflicting decisions → flagged for review
- [ ] Admin can resolve conflicts via UI

---

### Phase 5: Full Bi-Directional (Weeks 9-10)

**Goal:** Complete sync for all tables

1. Build sync endpoints for all reference data
2. Implement dependency-ordered sync
3. Add auto-sync detection (network polling)
4. Build "Clear Database" post-sync cleanup
5. Create sync analytics dashboard

**Acceptance Criteria:**
- [ ] Competition created on Pi syncs to cloud
- [ ] All tables sync in correct order
- [ ] Auto-sync works without manual intervention

---

## Error Handling

### Network Errors

```ruby
# app/jobs/sync_queue_worker.rb
class SyncQueueWorker < ApplicationJob
  MAX_RETRIES = 5
  RETRY_DELAY = [1.minute, 5.minutes, 15.minutes, 1.hour, 6.hours]
  
  def perform
    return unless device_mode?
    return unless network_available?
    
    SyncQueue.pending.find_each do |entry|
      sync_entry(entry)
    rescue HTTP::Error, Errno::EHOSTUNREACH => e
      handle_network_error(entry, e)
    end
  end
  
  private
  
  def handle_network_error(entry, error)
    entry.increment!(:retry_count)
    entry.update!(
      last_retry_at: Time.current,
      error_message: error.message
    )
    
    if entry.retry_count >= MAX_RETRIES
      entry.update!(status: "failed")
      notify_admin_sync_failed(entry)
    else
      # Retry with exponential backoff
      delay = RETRY_DELAY[entry.retry_count - 1] || RETRY_DELAY.last
      SyncQueueWorker.set(wait: delay).perform_later
    end
  end
end
```

### Foreign Key Resolution Errors

```ruby
# app/operations/sync/create_incident.rb
module Operations
  module Sync
    class CreateIncident
      def call(attrs)
        # Resolve UUIDs to local IDs
        race = Race.find_by!(client_uuid: attrs[:race_client_uuid])
        location = RaceLocation.find_by!(client_uuid: attrs[:race_location_client_uuid])
        
        incident_repo.create(
          attrs.merge(
            race_id: race.id,
            race_location_id: location.id
          )
        )
      rescue ActiveRecord::RecordNotFound => e
        # Foreign key not found - sync parent first
        Failure([:foreign_key_not_found, e.message])
      end
    end
  end
end
```

### Conflict Resolution

```ruby
# app/operations/sync/resolve_conflict.rb
module Operations
  module Sync
    class ResolveConflict
      def call(conflict_id:, resolution:, user_id:)
        conflict = SyncConflict.find(conflict_id)
        
        case resolution
        when "cloud_wins"
          # Keep cloud data, discard device data
          conflict.update!(
            resolution: "cloud_wins",
            resolved_by_user_id: user_id,
            resolved_at: Time.current
          )
          
        when "device_wins"
          # Apply device data, overwrite cloud
          apply_device_data(conflict)
          conflict.update!(
            resolution: "device_wins",
            resolved_by_user_id: user_id,
            resolved_at: Time.current
          )
          
        when "manual"
          # Admin manually edited - mark as resolved
          conflict.update!(
            resolution: "manual",
            resolved_by_user_id: user_id,
            resolved_at: Time.current
          )
        end
        
        Success(conflict)
      end
    end
  end
end
```

---

## Testing Strategy

### Unit Tests

```ruby
# spec/services/incident_fingerprint_service_spec.rb
RSpec.describe IncidentFingerprintService do
  describe ".generate" do
    it "generates same fingerprint for incidents within 30 seconds" do
      incident1 = {
        race_client_uuid: "race-123",
        bib_number: 42,
        created_at: "2026-02-15T10:32:10Z"
      }
      
      incident2 = {
        race_client_uuid: "race-123",
        bib_number: 42,
        created_at: "2026-02-15T10:32:35Z" # 25 seconds later
      }
      
      fingerprint1 = described_class.generate(incident1)
      fingerprint2 = described_class.generate(incident2)
      
      expect(fingerprint1).to eq(fingerprint2)
    end
    
    it "generates different fingerprint for different bibs" do
      incident1 = { race_client_uuid: "race-123", bib_number: 42 }
      incident2 = { race_client_uuid: "race-123", bib_number: 43 }
      
      fingerprint1 = described_class.generate(incident1)
      fingerprint2 = described_class.generate(incident2)
      
      expect(fingerprint1).not_to eq(fingerprint2)
    end
  end
end
```

### Integration Tests

```ruby
# spec/requests/api/v1/sync/incidents_spec.rb
RSpec.describe "POST /api/v1/sync/incidents" do
  let(:device) { create(:device, device_uuid: "pi-start") }
  let(:headers) { { "Authorization" => "Bearer #{device.api_token}" } }
  
  context "Layer 1: UUID exact match" do
    it "returns 200 OK for duplicate sync (idempotent)" do
      incident = create(:incident, client_uuid: "incident-123")
      
      payload = {
        incidents: [{
          client_uuid: "incident-123",
          race_client_uuid: incident.race.client_uuid,
          status: "unofficial"
        }]
      }
      
      # First sync
      post "/api/v1/sync/incidents", params: payload, headers: headers
      expect(response).to have_http_status(:ok)
      
      # Second sync (duplicate)
      post "/api/v1/sync/incidents", params: payload, headers: headers
      expect(response).to have_http_status(:ok)
      expect(json["results"][0]["status"]).to eq("already_synced")
      
      # Verify no duplicate created
      expect(Incident.where(client_uuid: "incident-123").count).to eq(1)
    end
  end
  
  context "Layer 2: Fingerprint match" do
    it "auto-merges incidents with same fingerprint" do
      race = create(:race, client_uuid: "race-123")
      location = create(:race_location, client_uuid: "loc-456")
      
      # Cloud incident
      cloud_incident = create(:incident,
        race: race,
        race_location: location,
        client_uuid: "incident-cloud",
        bib_number: 42,
        created_at: "2026-02-15T10:32:10Z"
      )
      
      # Pi incident (same race, bib, within 30 sec)
      payload = {
        incidents: [{
          client_uuid: "incident-pi",
          race_client_uuid: "race-123",
          race_location_client_uuid: "loc-456",
          bib_number: 42,
          created_at: "2026-02-15T10:32:25Z"
        }]
      }
      
      post "/api/v1/sync/incidents", params: payload, headers: headers
      
      expect(response).to have_http_status(:ok)
      result = json["results"][0]
      expect(result["status"]).to eq("merged")
      expect(result["deduplication"]["merged_with_incident_id"]).to eq(cloud_incident.id)
      
      # Verify no duplicate created
      expect(Incident.count).to eq(1)
    end
  end
  
  context "Layer 3: Conflict detection" do
    it "flags conflicting decisions for manual review" do
      race = create(:race, client_uuid: "race-123")
      
      # Cloud incident with decision
      cloud_incident = create(:incident,
        race: race,
        client_uuid: "incident-123",
        decision: "no_action",
        status: "official"
      )
      
      # Pi sends different decision
      payload = {
        incidents: [{
          client_uuid: "incident-123",
          race_client_uuid: "race-123",
          decision: "penalty_applied",
          status: "official"
        }]
      }
      
      post "/api/v1/sync/incidents", params: payload, headers: headers
      
      expect(response).to have_http_status(:conflict)
      expect(SyncConflict.count).to eq(1)
      
      conflict = SyncConflict.last
      expect(conflict.conflict_type).to eq("decision_mismatch")
      expect(conflict.cloud_data["decision"]).to eq("no_action")
      expect(conflict.device_data["decision"]).to eq("penalty_applied")
    end
  end
end
```

### System Tests

```ruby
# spec/system/offline_sync_spec.rb
RSpec.describe "Complete offline sync workflow", type: :system do
  it "syncs full competition day from Pi to Cloud" do
    # Setup: Cloud has competition data
    competition = create(:competition, name: "Verbier 2026")
    race = create(:race, competition: competition)
    
    # Pi downloads competition
    pi_device = create(:device, system_mode: "offline_device")
    
    # Simulate Pi going offline and creating incidents
    travel_to Time.zone.parse("2026-02-15 10:00:00") do
      # ... create incidents on Pi ...
    end
    
    # Pi syncs back to cloud
    sync_service = SyncService.new(device: pi_device)
    result = sync_service.sync_all
    
    expect(result).to be_success
    expect(Incident.count).to eq(5)
    expect(Report.count).to eq(12)
    expect(SyncConflict.count).to eq(0)
  end
end
```

---

## Deployment Guide

### Raspberry Pi Setup

#### Hardware Requirements

- Raspberry Pi 5 (4GB RAM minimum)
- 64GB SD card (32GB minimum)
- 7" touch display
- Ethernet cable + switch (for local Reolink network)
- Optional: WiFi adapter for internet

#### Software Installation

```bash
#!/bin/bash
# setup_pi.sh - Run on fresh Raspberry Pi OS

set -e

echo "=== ISMF Race Logger - Pi Setup ==="

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install dependencies
sudo apt-get install -y \
  git curl postgresql postgresql-contrib \
  libpq-dev build-essential nginx

# Install Ruby 3.4.8
curl -fsSL https://get.rvm.io | bash
source ~/.rvm/scripts/rvm
rvm install 3.4.8
rvm use 3.4.8 --default

# Clone application
cd ~
git clone https://github.com/your-org/ismf-race-logger.git
cd ismf-race-logger

# Install gems
bundle install

# Configure environment
cat > .env << EOF
SYSTEM_MODE=offline_device
RAILS_ENV=production
DATABASE_URL=postgresql://ismf:password@localhost/ismf_race_logger_pi
SYNC_SERVER_URL=https://race-logger.ismf.cloud
SECRET_KEY_BASE=$(bin/rails secret)
EOF

# Setup PostgreSQL
sudo -u postgres psql << EOSQL
CREATE USER ismf WITH PASSWORD 'password';
CREATE DATABASE ismf_race_logger_pi OWNER ismf;
EOSQL

# Setup database
RAILS_ENV=production bin/rails db:create db:migrate

# Precompile assets
RAILS_ENV=production bin/rails assets:precompile

# Setup systemd service
sudo cat > /etc/systemd/system/race-logger.service << EOSVC
[Unit]
Description=ISMF Race Logger (Pi)
After=network.target postgresql.service

[Service]
Type=simple
User=pi
WorkingDirectory=/home/pi/ismf-race-logger
Environment="RAILS_ENV=production"
ExecStart=/home/pi/.rvm/wrappers/ruby-3.4.8/bundle exec puma -C config/puma.rb
Restart=always

[Install]
WantedBy=multi-user.target
EOSVC

# Setup sync worker (cron)
crontab -l > mycron || true
echo "*/5 * * * * cd /home/pi/ismf-race-logger && RAILS_ENV=production bin/rails runner 'SyncQueueWorker.perform_now'" >> mycron
crontab mycron
rm mycron

# Enable and start service
sudo systemctl daemon-reload
sudo systemctl enable race-logger
sudo systemctl start race-logger

# Configure nginx
sudo cat > /etc/nginx/sites-available/race-logger << EONGINX
upstream race_logger {
  server unix:///home/pi/ismf-race-logger/tmp/sockets/puma.sock;
}

server {
  listen 80;
  server_name localhost;
  
  root /home/pi/ismf-race-logger/public;
  
  location / {
    proxy_pass http://race_logger;
    proxy_set_header Host \$host;
    proxy_set_header X-Real-IP \$remote_addr;
  }
}
EONGINX

sudo ln -s /etc/nginx/sites-available/race-logger /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx

echo "=== Setup complete! ==="
echo "Access Pi at: http://$(hostname -I | awk '{print $1}')"
```

#### Device Registration

```ruby
# On Pi, in Rails console:
bin/rails runner "
  device = Device.create!(
    device_uuid: SecureRandom.uuid,
    name: 'Start Line Pi',
    system_mode: 'offline_device',
    status: 'active',
    api_token: SecureRandom.hex(32)
  )
  
  puts 'Device UUID: ' + device.device_uuid
  puts 'API Token: ' + device.api_token
  puts 'Store these in config/credentials.yml.enc'
"
```

---

### Cloud Server Configuration

#### Environment Variables

```bash
# .env.production
SYSTEM_MODE=cloud
RAILS_ENV=production
DATABASE_URL=postgresql://...
REDIS_URL=redis://...
SYNC_ENABLED=true
SYNC_CONFLICT_EMAIL=admin@ismf.org
```

#### Monitoring & Alerts

```ruby
# config/initializers/sync_monitoring.rb
if Rails.configuration.system_mode == "cloud"
  # Alert if sync conflicts spike
  ActiveSupport::Notifications.subscribe("sync_conflict.created") do |event|
    if SyncConflict.where("created_at > ?", 1.hour.ago).count > 10
      AdminMailer.sync_conflict_spike_alert.deliver_later
    end
  end
  
  # Track sync success rate
  ActiveSupport::Notifications.subscribe("sync.completed") do |event|
    SyncMetric.create!(
      device_uuid: event.payload[:device_uuid],
      records_synced: event.payload[:count],
      duration_ms: event.duration,
      success: event.payload[:success]
    )
  end
end
```

---

## Edge Cases & Solutions

### Edge Case 1: Pi Creates Competition, Cloud Also Has Competition with Same Name

**Scenario:**
- Pi (offline) creates "Verbier 2026"
- Cloud already has "Verbier 2026"
- Different `client_uuid`, same name

**Solution:**
```ruby
# Cloud accepts both - names can be duplicates
# Admin can merge competitions via UI later if needed
# UUID is the real identifier, not name
```

**Manual Merge UI:**
```
Admin sees:
  [ ] Competition "Verbier 2026" (created on Pi, 2 races)
  [ ] Competition "Verbier 2026" (created on Cloud, 5 races)
  
  [Merge into Single Competition]
  
  After merge:
    - All 7 races belong to one competition
    - Pi's competition marked as "merged_into: other_uuid"
```

---

### Edge Case 2: Network Fails During Sync (Partial Upload)

**Scenario:**
- 50 incidents to sync
- Network dies after 30 incidents uploaded
- Next sync attempt: What happens?

**Solution:**
```ruby
# sync_queue tracks status per record:
# - Incidents 1-30: status = "synced"
# - Incidents 31-50: status = "pending"

# Next sync only uploads status = "pending"
# Idempotent: If 30 was uploaded but status not updated,
# Layer 1 catches duplicate and returns 200 OK
```

---

### Edge Case 3: Pi and Cloud Both Officialize Same Incident

**Scenario:**
- Pi (offline): Referee officializes incident #127 at 10:30
- Cloud (online): VAR operator officializes incident #127 at 10:32
- Pi syncs at 11:00

**Solution:**
```ruby
# This is NOT a conflict - officialize is idempotent
# Cloud keeps its officialize timestamp (earlier action)
# Pi's officialize is ignored (incident already official)

# No conflict created - both wanted same outcome
```

---

### Edge Case 4: Pi and Cloud Make Different Decisions

**Scenario:**
- Cloud: Jury president decides "no_action" at 14:00
- Pi (offline): Different jury president decides "penalty_applied" at 14:15
- Pi syncs at 16:00

**Solution:**
```ruby
# CONFLICT DETECTED (Layer 3)
# Create sync_conflict record
# Admin UI shows:
#   Cloud: "no_action" by User A at 14:00
#   Pi:    "penalty_applied" by User B at 14:15
#   
#   [Keep Cloud] [Keep Pi] [Manual Override]
#
# Admin chooses resolution, system applies it
```

---

### Edge Case 5: Foreign Key Chain Missing

**Scenario:**
- Pi syncs Report, references Incident via `incident_client_uuid`
- But that Incident hasn't synced yet (still in queue)

**Solution:**
```ruby
# Sync in dependency order (see SYNC_ORDER constant)
# Reports always sync AFTER Incidents
# If error occurs:
#   - Return 422 Unprocessable
#   - Pi retries Report sync later
#   - Eventually Incident syncs, then Report succeeds
```

---

### Edge Case 6: Video Upload Fails (Large File)

**Scenario:**
- Report syncs successfully
- Video upload times out (large file, slow network)

**Solution:**
```ruby
# Two-phase commit:
# 1. Sync report metadata (without video)
# 2. Separately upload video, attach to report

# If video fails:
#   - Report exists with video_clip = { status: "pending" }
#   - Background job retries video upload
#   - Admin can manually upload video via UI
```

---

## Summary

This strategy provides:

✅ **Bulletproof deduplication** - 3 layers prevent duplicates  
✅ **Resilient sync** - Incremental, resumes on failure  
✅ **Same codebase** - Cloud and Pi run identical apps  
✅ **Simple operation** - One-click sync, auto when online  
✅ **Conflict safety** - Smart auto-merge with manual review fallback  

### Next Steps

1. **Review this document** with team
2. **Create proof-of-concept** (Phase 1-2, weeks 1-4)
3. **Test with real Raspberry Pi** at office
4. **Pilot at small competition**
5. **Iterate based on feedback**

---

**Document Version:** 2.0  
**Last Updated:** 2026-01-27  
**Authors:** ISMF Tech Team  
**Status:** Ready for Implementation