# AquaBill Implementation Guidelines

These guidelines translate the AquaBill specification into actionable engineering decisions. They are non-negotiable where the spec mandates behavior.

## Architecture Overview

- Frontend: Flutter (Android-first, offline-first; local SQLite for 12 cycles).
- Backend: Python + FastAPI (always-online source of truth).
- Database: PostgreSQL.
- Messaging: SMS gateway with callbacks, delivery history, and controlled retries.
- Sync: Server authoritative; conflicts resolved server-side.

## Core Principles

- Ledger-first accounting; balances derived from immutable entries.
- Offline-first capture; no network required for collectors.
- Human authority over penalties; never automatic.
- Auditability; history never overwritten or deleted.
- Safety rules enforced (baseline, explicit states, approvals).

## Data Model (Tables)

- `clients`: first_name, other_names, surname, phone_number, reserved `client_code`.
- `meters`: serial_number (unique), specs.
- `meter_assignments`: meter_id, client_id, start_date, end_date (nullable), status (ACTIVE/INACTIVE).
- `cycles`: start_date, end_date, target_date, status (OPEN/PENDING_REVIEW/APPROVED/CLOSED/ARCHIVED), name/id.
- `readings`: meter_assignment_id, cycle_id, absolute_value NUMERIC(9,4), type (BASELINE/NORMAL), submitted_by, submitted_at, approved_by, approved_at, status.
- `rollover_verifications`: reading_id, previous_reading, current_reading, verified_by, verification_type (GENUINE_ROLLOVER/METER_FAULT/REPLACEMENT), timestamp, notes.
- `ledger_entries`: id, client_id, cycle_id (nullable), type (CHARGE/PENALTY/PAYMENT/ADJUSTMENT), amount NUMERIC(12,2), meta (consumption, tariff, notes), created_at.
- `payments`: id, client_id, amount NUMERIC(12,2), received_at, applied_fifo_details.
- `penalties`: id, client_id, amount NUMERIC(12,2), applied_at, resolved_at (nullable), active_flag, notes.
- `anomalies`: client_id, meter_assignment_id, cycle_id, type, details, created_at, acknowledged_at (nullable).
- `conflicts`: meter_assignment_id, cycle_id, submission_ids, selected_submission_id, resolved_by, resolution_timestamp, rejection_reason.
- `sms_messages`: client_id, cycle_id, content_preview, state (PENDING/SENT/DELIVERED/FAILED/PERMANENTLY_FAILED), attempts, last_attempt_at.
- `sms_delivery_history`: sms_message_id, attempt_no, state, gateway_response, timestamp.
- `audit_log`: action_type, performed_by, timestamp, affected_entity refs, old_value/new_value, notes; write-only.
- `archives_*`: read-only copies for data older than 36 months.

## Numeric Precision & Types

- Meter readings: NUMERIC(9,4) to allow up to 99,999.9999.
- Consumption: NUMERIC(9,4).
- Tariff: NUMERIC(10,2).
- Monetary amounts: NUMERIC(12,2); round to nearest whole TZS only at final billing stage (half-up).

## Meter Rules

- A meter must be active for only one client at a time.
- Baseline on install/repair/reassignment: stored permanently, requires approval, no consumption/charges; billing starts from next approved reading.
- Rollover detection: if current < previous and previous ≥ 90,000 → suspected rollover; otherwise anomaly.
- Rollover calculation (if confirmed): (99,999.9999 - previous) + current.
- Alert admin at 90,000.0000; persistent until replaced/acknowledged.

## Billing Cycles

- Target date: 25th; propose nearest prior working day if non-working; admin override allowed.
- Cycles defined by actual reading dates; cannot overlap or leave gaps.
- Submission window: target_date ± 5 days (configurable). Outside window → flag for admin override.
- State machine: OPEN → PENDING_REVIEW → APPROVED → CLOSED → ARCHIVED. Only CLOSED can be archived; only APPROVED can send SMS.

## Consumption

- Absolute-based: consumption = current_absolute − previous_absolute for the same assignment.
- No consumption across different assignments.
- Storage precision 4dp; display 2dp.

## Tariffs & Billing

- Flat rate: 3.00 TZS/liter = 3,000.00 TZS/m³.
- Tariffs centrally configured; changes do not affect CLOSED cycles.
- Charge = consumption × tariff, full precision; round final amount only.

## Ledger & Payments

- Immutable ledger entries: charges (cycle), penalties, payments, adjustments.
- Payments allowed partial; apply FIFO (oldest charges first).
- Overpayments create credits; credits auto-offset future charges; hidden in SMS but visible in exports.

## Penalties (Manual)

- Never auto-applied; system may suggest eligibility.
- Admin must apply with mandatory justification note.
- Fixed amount per business; one active at a time per client.
- Resolves when client_balance ≤ TZS 10,000.

## Anomaly Detection

- Detect high consumption, pattern deviations, rollbacks, suspected faults.
- Alerts are persistent and non-blocking; must be acknowledged manually; billing continues regardless.

## Sync & Offline

- Collector app functions offline; stores last 12 cycles + assignments locally.
- Background sync when network available.
- Server authoritative; conflicts flagged and resolved via admin workflow.

## Conflict Resolution

- Detect duplicate submissions per meter_assignment_id + cycle_id with differing values.
- Lock both; show admin comparison (collector, timestamp, values).
- Admin selects submission or manual override; log rejection reason; proceed via normal approval.

## SMS Notifications

- Send only after admin approval and cycle status = APPROVED.
- Content if net_balance > 0: amount due, consumption, previous balance.
- If net_balance ≤ 0: "No payment due" (do not disclose credit).
- Delivery tracking via callbacks; states: PENDING/SENT/DELIVERED/FAILED.
- Retry policy: immediate, +30min, +4h; max 3 attempts; total window 24h; then PERMANENTLY_FAILED and alert admin. Persist full delivery history.

## Data Retention & Archive

- All ledger entries retained indefinitely; no deletion of financial records.
- Mobile sync: most recent 12 cycles; Admin dashboard: 24 cycles default; full history via archive query.
- Exports: monthly cycle completion, annual full ledger (CSV + PDF), on-demand with date filters.
- Archive ≥36 months: move to archive tables; read-only; included in backups; never deleted.

## Audit & Compliance

- Log all admin actions: action_type, performed_by, timestamp, affected_entity, old/new values, notes.
- Immutable audit table; included in backups and exports.

## Backend Standards

- FastAPI structure: `app/` with modules: domain, schemas (pydantic), services, repositories, api routes, workers.
- Migrations via Alembic; seed data via fixtures.
- Enums for states; validators for precision (4dp readings, 2dp tariff).
- Idempotent endpoints for SMS callbacks and sync; retry-safe.
- Errors: explicit messages for late submission; HTTP 400 with spec-compliant text.

## Mobile App Standards

- Flutter: local SQLite, repository pattern, background sync, conflict flags.
- Collector UX: search by full name; always display phone number; show previous approved reading read-only; capture absolute reading up to 4dp; offline submission queue.

## Testing Strategy

- Unit tests: rollover math, baseline enforcement, FIFO payments, rounding behavior.
- Integration tests: cycle transitions, conflict resolution, SMS retries.
- Property tests for precision and numeric ranges.

## DevOps & Security

- Secrets via env; per-environment configs.
- CI for tests, lint, migrations validation.
- Backups for both main and archive tables; export integrity checks.
