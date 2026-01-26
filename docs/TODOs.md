# AquaBill TODOs

High-level, sequenced tasks to build AquaBill. Progress snapshot: Phases 0–4 plus exports/archive are done; next up is Phase 5 (mobile), then Phase 6 (tests/CI), then Phase 7 (deployment/ops).

## Phase 0 — Foundations (Done)

1. Draft guidelines and TODOs files
2. Confirm repo layout (backend/app, migrations, tests)
3. Initialize pyproject/requirements and virtualenv
4. Scaffold FastAPI app (routers/services/models)
5. Configure Alembic and base migration
6. Set up env config (.env, settings, secrets)

## Phase 1 — Domain & Schema (Done)

1. Design clients table and CRUD
2. Design meters table and CRUD
3. Design meter_assignments (one active per meter constraint)
4. Design cycles (non-overlap, states enum)
5. Design readings (precision 4dp, baseline flag)
6. Design anomalies + conflicts tables
7. Design ledger_entries, payments, penalties
8. Design audit_log (immutable)
9. Design sms_messages + delivery_history
10. Apply initial Alembic migrations

## Phase 2 — Core Workflows (Done)

1. Meter assignment workflow + baseline enforcement
2. Cycle scheduling and OPEN state creation
3. Reading submission (window checks)
4. Reading approval and consumption calculation
5. Rollover detection + verification flow
6. Auto transition OPEN→PENDING_REVIEW on window close

## Phase 3 — Accounting & Notifications (Done)

1. Generate cycle charges on APPROVAL
2. Payments FIFO application + credits
3. Penalty application (manual + notes)
4. Compute net balances for SMS and exports
5. SMS integration: compose + send after APPROVAL
6. SMS callbacks endpoint + idempotency
7. SMS retry scheduler (immediate/30m/4h, max 3)
8. Persist SMS delivery history and alerting

## Phase 4 — Observability & Compliance (Done)

1. Anomaly logging + admin acknowledgement
2. Audit logging decorator for admin actions
3. Exports: monthly cycle completion, annual ledger (CSV/PDF), on-demand
4. Archive job: move ≥36 months to read-only tables

## Phase 5 — Mobile (Flutter) — Next

1. Finalize mobile API contract (bootstrap, updates, readings, conflicts) and align payloads
2. Implement backend endpoints for bootstrap/updates if not present (deltas + tombstones)
3. Scaffold Flutter app (modules: data/local, data/remote, domain, ui, core)
4. Build SQLite schema + DAOs and trimming for 12-cycle cache; add migrations
5. Offline capture flow: search, show phone, previous approved reading (read-only), absolute input 4dp, notes, enqueue to sync_queue
6. Background sync engine: upload queue with conflict handling; download deltas with server-wins merge; reachability via health
7. Conflicts UI: list, detail, accept server or edit-and-resubmit
8. Settings: token storage, sync preferences (Wi-Fi-only toggle), device id display, last sync time

## Phase 6 — Testing & DevOps — Upcoming

1. Unit tests: precision, baseline, FIFO, rollover math
2. Integration tests: cycles, conflicts, SMS retries
3. CI pipeline: lint, tests, migrations validation
4. Ops: backups and export integrity checks

## Phase 7 — Deployment & Operations — Upcoming

1. Containerize backend (Dockerfile with FastAPI/Uvicorn)
2. Runtime configuration: env vars, secrets, logging levels
3. Provision PostgreSQL (managed service) and networking rules
4. Build/push pipeline for images; deploy to chosen cloud host
5. Health checks, readiness probes, and auto-restart policies
6. Observability: structured logs, metrics, alerting
7. Backup/restore runbooks; export integrity verification

## Notes

- Precision: readings/consumption 4dp, tariff 2dp, round TZS at final billing stage (half-up).
- Server authoritative; conflicts require admin resolution.
- No deletion of financial records; audit log immutable.
