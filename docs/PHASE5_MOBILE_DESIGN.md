# Phase 5 — Mobile (Flutter, Offline-First)

Design for the collector mobile app: offline-first Flutter (Android-first), local SQLite cache, background sync, server-wins conflict policy, and UX for capture/resolve.

## Goals

- Enable field collectors to capture readings offline for up to the last 12 cycles.
- Keep authoritative state on the server; mobile caches and syncs.
- Make conflicts visible and recoverable (server-wins default; collector can resubmit).
- Keep UX simple: show previous approved reading, phone number, and client identity at capture time.

## Non-Goals (Phase 5)

- Payments, penalties, exports, or archive views on mobile.
- Admin dashboards on mobile.

## Architectural Outline

- Flutter app modules:
  - `data/local`: SQLite database + DAOs.
  - `data/remote`: REST client (authorized via token header when available).
  - `domain`: repositories + use-cases; server-wins merge policy.
  - `ui`: screens for search, capture, conflicts, sync status.
  - `core`: error types, clock, connectivity monitor, retries, logging.
- Background worker: periodic sync when network available; also manual pull-to-sync.

## Local SQLite Schema (12-cycle cache)

- `clients(id, client_code, first_name, other_names, surname, phone_number, updated_at)`
- `meters(id, serial_number, specs, updated_at)`
- `meter_assignments(id, meter_id, client_id, status, start_date, end_date, baseline_reading, updated_at)`
- `cycles(id, name, start_date, end_date, target_date, status, updated_at)`
- `readings(id, meter_assignment_id, cycle_id, absolute_value, submitted_at, submitted_by, status, source, previous_approved_reading, notes, updated_at)`
  - `status`: LOCAL_ONLY, SUBMITTED, ACCEPTED, REJECTED, CONFLICT
  - `source`: LOCAL_CAPTURE or SERVER_SYNC
- `conflicts(id, meter_assignment_id, cycle_id, local_value, server_value, resolved, resolved_at, resolution_note, updated_at)`
- `sync_queue(id, entity_type, entity_id, payload, operation, attempt_count, last_attempt_at, created_at)`
  - `entity_type`: READING
  - `operation`: CREATE
- `metadata(key, value, updated_at)` for app version, last_sync_at, schema_version.

Indexes:

- `readings` on (meter_assignment_id, cycle_id)
- `conflicts` on (meter_assignment_id, cycle_id)
- `cycles` on (status, target_date)
- `sync_queue` on (entity_type, created_at)

## Data Retention

- Cache last 12 cycles per assignment (trim older cycles and their readings locally once safely synced and not conflicted).
- Keep conflicts until explicitly resolved.

## Sync Strategy (Server-Wins)

- **Upload pass**: drain `sync_queue` (oldest first). On success, mark reading `ACCEPTED`. On 400 conflict, mark reading `CONFLICT` and insert conflict row with server payload. On transient errors, retry with backoff.
- **Download pass**: fetch assignments, cycles, and approved readings for cached cycles; merge by id, server overwrites local unless reading is LOCAL_ONLY/CONFLICT. If server deleted/closed a cycle, mark local cycle read-only.
- **Triggering**: app start if online, manual pull, periodic background (e.g., 30m) when on Wi-Fi or user-approved data.
- **Auth**: reuse backend token header (configure once in settings). If unauthenticated, allow read-only cached data and queue uploads until auth is restored.

## Conflict Handling

- Detection: server responds with conflict (e.g., duplicate submission with different value) or different approved reading arrives during download.
- Representation: reading status = CONFLICT; conflict entry stores both values and timestamps.
- UX: conflict list screen; detail shows server vs local values and metadata. Actions: "Accept server" (discard local, mark resolved) or "Edit & resubmit" (creates new local reading, queues upload, marks resolved when accepted).
- Policy: server-wins by default; any resubmit is a new reading record with reference to prior conflict id in payload metadata when possible.

## Capture Flow (Offline)

- Search client by name/phone; show phone number and meter serial.
- Display previous approved reading (from local cache). If missing, warn but allow capture with note.
- Input absolute reading (4dp), auto-fill timestamp, collector identifier.
- Validate numeric bounds (0–99,999.9999) and non-decreasing assumption; if decrease detected, warn and require note (possible rollover/fault).
- Save locally: reading status LOCAL_ONLY, source LOCAL_CAPTURE, enqueue to `sync_queue`.

## Sync Payloads (expected shapes)

## Mobile API Contract (proposed)

- Auth: `Authorization: Bearer <token>` on all endpoints; reject 401/403 gracefully and keep local cache usable.
- **GET /api/v1/mobile/bootstrap**
  - Request: none (optional `if-none-match`/`since` if supported).
  - Response: `{ assignments: [...], cycles: [...], readings: [...], clients: [...], meters: [...], last_sync: <iso8601> }`
- **GET /api/v1/mobile/updates?since=iso8601**
  - Response: same shape as bootstrap but only deltas plus `tombstones` for closed cycles or deactivated assignments.
- **POST /api/v1/mobile/readings**
  - Payload: `{ meter_assignment_id, cycle_id, absolute_value, submitted_at, submitted_by, client_tz, source: "mobile", previous_approved_reading?, device_id?, app_version?, conflict_id? }`
  - Responses:
    - `201` accepted → return reading with server id/status.
    - `409` conflict → include server reading snapshot `{ server_reading, conflict_reason }`.
    - `400/422` validation → map to local validation messages.
- **POST /api/v1/mobile/conflicts/{conflict_id}/resolve** (optional)
  - Payload: `{ resolution: "accept_server" | "resubmit", reading_payload? }` if we keep explicit conflict endpoints.
- **GET /api/v1/health**
  - Used for reachability checks before sync.

## UX Surfaces

- Home: sync status chip (Online/Offline/Syncing), last sync time, sync button.
- Search: client/meter search; tap to open capture.
- Settings: token entry, sync preferences (Wi-Fi only?), device id display.

## Validation & Safeguards

- Prevent capture outside cycle window unless override flag; if override, tag payload.
- Require note when absolute < previous (suspected rollover) or jump > configurable threshold.
- Do not allow edits to readings once status is SUBMITTED/ACCEPTED; instead allow new submission.
- Stop trimming old cycles if unsynced/conflicted readings exist in them.

## Testing Checklist (Phase 5 scope)

- Local DB migrations initialize schema; trimming keeps 12 cycles.
- Capture offline, reboot app, reading persists and syncs when online.
- Conflict path: server has different reading → app marks CONFLICT and shows it.
- Resubmit flow resolves conflict and syncs.
- Incremental updates do not overwrite LOCAL_ONLY/CONFLICT statuses.

## Open Implementation Choices (to finalize in code)

- Exact endpoints: align with existing backend routes; prefer dedicated mobile bootstrap/updates endpoints if available.
- Auth storage: secure storage vs shared prefs; token refresh strategy (if backend supports).
- Background task mechanism: `workmanager` or `flutter_background_service` for periodic sync.
- Connectivity detection: `connectivity_plus` + reachability check against backend health.
