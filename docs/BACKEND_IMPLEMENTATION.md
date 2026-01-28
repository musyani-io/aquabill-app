# AquaBill Backend Implementation (Phases 0-4 + Exports/Archive)

## Overview

Production-ready FastAPI backend covering client/meter lifecycle, billing cycles, readings, ledger-based accounting, SMS notifications (Africa's Talking, Tanzania), anomaly/audit logging, exports, and archival.

## Architecture

- **API layer**: FastAPI routers under `/api/v1`
- **Services**: Business logic per domain (cycles, readings, ledger, payments, penalties, SMS, anomaly, audit, exports, archive)
- **Repositories**: SQLAlchemy data access per model
- **Models**: Declarative SQLAlchemy (PostgreSQL)
- **Schemas**: Pydantic v2 for request/response
- **Config**: `app/core/config.py` (env-prefixed `AQUABILL_`)

## Key Domains & Workflows

- **Clients/Meters/Assignments**: CRUD, one-active-assignment constraint, baselines
- **Cycles**: Schedule non-overlapping cycles; auto-transition OPEN→PENDING_REVIEW on target date; manual transitions; overdue bulk transition endpoint
- **Readings**: Submission window enforcement; approval computes consumption; rollover verification; anomaly hooks
- **Anomalies**: Types: NEGATIVE_CONSUMPTION, DOUBLE_SUBMISSION, LATE_SUBMISSION, MISSING_BASELINE, ROLLOVER_WITHOUT_LIMIT; states: DETECTED→ACKNOWLEDGED→RESOLVED
- **Ledger**: Entry types CHARGE, PAYMENT (credit), PENALTY, ADJUSTMENT; idempotent charge generation per assignment+cycle
- **Payments (FIFO)**: Allocates credits to oldest charges; supports remaining credit balance
- **Penalties**: Manual apply/waive with notes; idempotent ledger entry creation
- **Balances**: Derived from ledger (debits - credits) with breakdown (charges, penalties, payments, adjustments)

## SMS (Africa's Talking, Tanzania)

- Gateway client: `https://api.africastalking.com/version1/messaging`
- Phone handling: Tanzania formats (+255, 255, 0-leading), normalized to +255XXXXXXXXX
- Messages: balance alert, payment confirmation, penalty notice (TZS currency)
- Idempotency: idempotency_key on SMS
- Retry policy: 0 min → 30 min → 4 hr (max 3 attempts)
- Endpoints: queue, send now, callbacks (delivered/failed/bounced), retry scheduler, delivery history
- Config: `AQUABILL_SMS_GATEWAY_URL`, `AQUABILL_SMS_GATEWAY_KEY`, `AQUABILL_SMS_USERNAME`, `AQUABILL_SMS_SENDER_ID`

## Exports (CSV)

- Cycle readings: client, phone, meter, reading, consumption, status
- Cycle charges: ledger entries per cycle
- Annual ledger: full-year financial report
- Payments: optional date range
- Client balances: current net balances (derived)
- Endpoints under `/api/v1/exports`

## Archival (≥36 months)

- Eligible: CLOSED cycles older than cutoff (default 36 months)
- Actions: list eligible, archive single, bulk archive (dry-run supported), stats
- Endpoints under `/api/v1/archive`
- Current behavior: mark cycle as ARCHIVED (data stays; ready for future archive tables/moves)

## Audit Logging

- Decorators: `@audit_log`, `@audit_log_async` auto-write immutable audit logs
- Actions cover readings, cycles, conflicts, financial ops, meter/client ops, system actions
- Metadata support; non-blocking on failures

## Anomaly Logging Helpers

- `log_negative_consumption`, `log_rollover_without_limit`, `log_double_submission`, `log_late_submission`, `log_missing_baseline`
- Used during reading approval/consumption calculations to surface issues

## Configuration (.env)

- `AQUABILL_DATABASE_URL`
- `AQUABILL_SMS_GATEWAY_URL`
- `AQUABILL_SMS_GATEWAY_KEY`
- `AQUABILL_SMS_SENDER_ID`
- `AQUABILL_SUBMISSION_WINDOW_DAYS` (default 5)

## Endpoints Map (high level)

- **Health**: `/api/v1/health`
- **Clients/Meters/Assignments**: CRUD + assignments
- **Cycles**: schedule, get open, transitions, auto-transition overdue, generate charges
- **Readings**: submit, approve with consumption, rollover verify
- **Billing**: ledger CRUD, payments, penalties, balances
- **SMS**: queue, send, callbacks, retries, history
- **Anomalies/Conflicts**: create, list, acknowledge, resolve
- **Audit Logs**: list by admin/action/entity
- **Exports**: cycle readings/charges, annual ledger, payments, client balances
- **Archive**: eligible cycles, archive cycle, bulk archive, stats

## Data Model Highlights

- Precision: readings/consumption 4dp; tariffs 2dp; currency TZS, round half-up at billing
- Ledger is source of truth; balances are derived; audit and SMS tables are append-only
- Anomalies and audit logs are immutable (no deletes/updates)

## Deployment Notes (backend)

- FastAPI + Uvicorn
- PostgreSQL required
- Environment-driven config; avoid secrets in code
- Ready for containerization and CI (Phase 7 pending)

## Status & Next Steps

- **Completed**: Phases 0-4, Exports, Archive
- **Pending**: Phase 5 (Flutter app), Phase 6 (unit/integration tests), Phase 7 (DevOps/deployment)
