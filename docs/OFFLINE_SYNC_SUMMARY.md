# Offline Sync Strategy - Executive Summary

**Quick Reference for Team & Stakeholders**

---

## What Problem Are We Solving?

Race venues (mountain resorts) often have **poor or no internet connectivity**. We need referees to report incidents on a **Raspberry Pi with touch display** that works 100% offline, then sync with the cloud server when connectivity is restored.

---

## The Solution (One Sentence)

**The Pi runs an identical copy of the Rails app with its own PostgreSQL database, and syncs bi-directionally with the cloud using UUIDs to prevent duplicates.**

---

## Key Decisions

### 1. Same App, Different Mode

```ruby
# Both cloud and Pi run the exact same codebase
SYSTEM_MODE=cloud          # Production server
SYSTEM_MODE=offline_device # Raspberry Pi
```

**Why?** Maximum code reuse, no separate "mobile app" to maintain.

### 2. UUIDs Are Truth, IDs Are Local

Every syncable table gets a `client_uuid`:

```ruby
add_column :incidents, :client_uuid, :uuid, unique: true
add_column :reports, :client_uuid, :uuid, unique: true
# ... etc for all tables
```

- **Integer IDs (1, 2, 3...)** are local-only, differ between cloud/Pi
- **UUIDs** are the real distributed identifier
- Sync API uses UUIDs for all foreign key references

**Why?** Eliminates ID collision problem when both systems create records independently.

### 3. Two Types of Data

| Type | Examples | Sync Rule |
|------|----------|-----------|
| **Reference Data** | Competitions, Races, Athletes | Created in ONE place (cloud OR Pi), never both |
| **Operational Data** | Incidents, Reports | Created in BOTH places, intelligently merged |

**Why?** Reference data avoids conflicts. Operational data needs smart deduplication.

### 4. 3-Layer Deduplication

When Pi syncs an incident to cloud:

```
Layer 1: UUID Match
└─ Same UUID exists? → Idempotent (skip)

Layer 2: Fingerprint Match
└─ Same race+bib+location+time? → Auto-merge

Layer 3: Manual Review
└─ Conflicting decisions? → Flag for admin
```

**Why?** Catches exact duplicates, smart merges, and human judgment for edge cases.

---

## Typical Workflow

### Morning (With Internet)
```
1. Admin opens Pi web interface
2. Clicks "Download Competition: Verbier 2026"
3. Pi downloads all race data for the day
4. Status: "Ready for offline operation"
```

### During Race (May Be Offline)
```
- Referee reports incidents on Pi touch screen
- If online: Auto-syncs every 5 minutes
- If offline: Stores locally, queues for sync
```

### After Race (Back Online)
```
1. Network detected OR click "Sync Now"
2. Pi uploads all pending data
3. Cloud deduplicates and merges
4. Admin reviews any conflicts (rare)
5. Pi database cleared, ready for next race
```

---

## What Gets Synced?

### Download (Cloud → Pi)
- Competition details
- All races for that day
- Athletes and bib assignments
- Race locations

### Upload (Pi → Cloud)
- Incidents reported on Pi
- Reports with video clips
- Any reference data created offline (emergency scenarios)

---

## How Duplicates Are Prevented

### Scenario: Same Incident Reported Twice

**Problem:**
- Pi (offline): Referee reports bib #42 at 10:30
- Cloud (online): VAR operator reports bib #42 at 10:31
- Same incident, different systems

**Solution:**
```ruby
# Layer 2 fingerprint detects match:
fingerprint = hash(race_id, bib_42, location, time_window_30sec)

# Cloud auto-merges:
# - Keep cloud's incident
# - Move Pi's reports to cloud incident
# - No duplicate created ✅
```

### Scenario: Network Fails During Sync

**Problem:**
- Syncing 50 incidents
- Network dies after 30 uploaded
- What happens next?

**Solution:**
```ruby
# sync_queue table tracks status per record:
incidents[1..30]  → status: "synced"
incidents[31..50] → status: "pending"

# Next sync only uploads "pending" records
# Layer 1 catches any accidental re-uploads
```

---

## Edge Cases Handled

| Situation | Resolution |
|-----------|-----------|
| **Same UUID, different data** | Conflict flagged for admin review |
| **Different UUID, same incident** | Auto-merged via fingerprint |
| **Conflicting decisions** | Admin chooses which to keep |
| **Foreign key missing** | Sync in correct order (races before incidents) |
| **Video upload fails** | Report syncs, video retried later |
| **Pi creates competition with same name as cloud** | Both kept (UUID differs), admin can merge manually |

---

## Technology Stack

| Component | Technology | Why |
|-----------|-----------|-----|
| **Pi Database** | PostgreSQL | Same as cloud, maximum compatibility |
| **Sync Protocol** | REST API (JSON) | Simple, uses existing Rails repos/operations |
| **Deduplication** | UUID + SHA256 fingerprint | Industry standard |
| **Background Jobs** | Solid Queue (Rails 8) | Native, no external dependencies |
| **Network Detection** | HTTP health check | Simple ping to `/api/v1/sync/health` |

---

## Implementation Timeline

| Phase | Duration | Deliverable |
|-------|----------|-------------|
| **Phase 1: Foundation** | 2 weeks | Add UUIDs, create sync tables |
| **Phase 2: Download** | 2 weeks | Pi can download competition data |
| **Phase 3: Upload** | 2 weeks | Pi can upload incidents to cloud |
| **Phase 4: Deduplication** | 2 weeks | Smart merging with conflict detection |
| **Phase 5: Full Bi-Directional** | 2 weeks | All tables sync, auto-detection |

**Total:** ~10 weeks for complete implementation

---

## Risks & Mitigations

| Risk | Mitigation |
|------|-----------|
| **UUID migration on production** | Add UUIDs alongside existing IDs, no breaking changes |
| **Sync fails silently** | Admin dashboard shows sync status per device |
| **Conflicts spike** | Alert sent to admin if >10 conflicts in 1 hour |
| **Pi database fills up** | Clear after each sync, monitor SD card space |
| **Video files too large** | Two-phase: metadata first, video separately |

---

## Success Metrics

After implementation, we measure:

- **Sync Success Rate:** Target 99% of syncs complete without errors
- **Duplicate Rate:** Target 0% duplicates created
- **Conflict Rate:** Target <5% of incidents require manual review
- **Sync Duration:** Target <5 minutes for typical race day
- **Offline Capability:** Target 100% functionality for 12+ hours

---

## Next Steps

1. ✅ Review this strategy with technical team
2. ⏳ Review with domain experts (referees, VAR operators)
3. ⏳ Build Phase 1 (UUIDs + infrastructure)
4. ⏳ Test with real Raspberry Pi hardware
5. ⏳ Pilot at small local competition
6. ⏳ Iterate based on real-world feedback

---

## Full Documentation

See **[OFFLINE_SYNC_STRATEGY.md](OFFLINE_SYNC_STRATEGY.md)** for complete technical specification including:
- Detailed API endpoints
- Code examples for all operations
- Complete test suite specifications
- Deployment scripts for Raspberry Pi
- Error handling strategies
- All edge case resolutions

---

**Last Updated:** 2026-01-27  
**Status:** Ready for Implementation  
**Contact:** Tech Team Lead