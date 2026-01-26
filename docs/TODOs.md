# AquaBill TODOs

High-level, sequenced tasks to build AquaBill.

## Phase 0 — Foundations

1. Draft guidelines and TODOs files
2. Confirm repo layout (backend/app, migrations, tests)
3. Initialize pyproject/requirements and virtualenv
4. Scaffold FastAPI app (routers/services/models)
5. Configure Alembic and base migration
6. Set up env config (.env, settings, secrets)

## Phase 1 — Domain & Schema

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

## Phase 2 — Core Workflows

1. Meter assignment workflow + baseline enforcement
2. Cycle scheduling and OPEN state creation
3. Reading submission (window checks)
4. Reading approval and consumption calculation
5. Rollover detection + verification flow
6. Auto transition OPEN→PENDING_REVIEW on window close

## Phase 3 — Accounting & Notifications

1. Generate cycle charges on APPROVAL
2. Payments FIFO application + credits
3. Penalty application (manual + notes)
4. Compute net balances for SMS and exports
5. SMS integration: compose + send after APPROVAL
6. SMS callbacks endpoint + idempotency
7. SMS retry scheduler (immediate/30m/4h, max 3)
8. Persist SMS delivery history and alerting

## Phase 4 — Observability & Compliance

1. Anomaly logging + admin acknowledgement
2. Audit logging decorator for admin actions
3. Exports: monthly cycle completion, annual ledger (CSV/PDF), on-demand
4. Archive job: move ≥36 months to read-only tables

## Phase 5 — Mobile (Flutter)

1. Local SQLite schema for 12 cycles + assignments
2. Offline capture UI: search + show phone number
3. Show previous approved reading (read-only), input absolute up to 4dp
4. Background sync; conflict flagging; server-wins handling

## Phase 6 — Testing & DevOps

1. Unit tests: precision, baseline, FIFO, rollover math
2. Integration tests: cycles, conflicts, SMS retries
3. CI pipeline: lint, tests, migrations validation
4. Ops: backups and export integrity checks

## Phase 7 — Deployment & Operations

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
