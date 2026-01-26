# AquaBill TODOs

High-level, sequenced tasks to build AquaBill. Progress snapshot: Phases 0–5 complete ✅; next up is Phase 6 (tests/CI), then Phase 7 (deployment/ops).

## Phase 0 — Foundations (✅ Done)

1. ✅ Draft guidelines and TODOs files
2. ✅ Confirm repo layout (backend/app, migrations, tests)
3. ✅ Initialize pyproject/requirements and virtualenv
4. ✅ Scaffold FastAPI app (routers/services/models)
5. ✅ Configure Alembic and base migration
6. ✅ Set up env config (.env, settings, secrets)

## Phase 1 — Domain & Schema (✅ Done)

1. ✅ Design clients table and CRUD
2. ✅ Design meters table and CRUD
3. ✅ Design meter_assignments (one active per meter constraint)
4. ✅ Design cycles (non-overlap, states enum)
5. ✅ Design readings (precision 4dp, baseline flag)
6. ✅ Design anomalies + conflicts tables
7. ✅ Design ledger_entries, payments, penalties
8. ✅ Design audit_log (immutable)
9. ✅ Design sms_messages + delivery_history
10. ✅ Apply initial Alembic migrations

## Phase 2 — Core Workflows (✅ Done)

1. ✅ Meter assignment workflow + baseline enforcement
2. ✅ Cycle scheduling and OPEN state creation
3. ✅ Reading submission (window checks)
4. ✅ Reading approval and consumption calculation
5. ✅ Rollover detection + verification flow
6. ✅ Auto transition OPEN→PENDING_REVIEW on window close

## Phase 3 — Accounting & Notifications (✅ Done)

1. ✅ Generate cycle charges on APPROVAL
2. ✅ Payments FIFO application + credits
3. ✅ Penalty application (manual + notes)
4. ✅ Compute net balances for SMS and exports
5. ✅ SMS integration: compose + send after APPROVAL
6. ✅ SMS callbacks endpoint + idempotency
7. ✅ SMS retry scheduler (immediate/30m/4h, max 3)
8. ✅ Persist SMS delivery history and alerting

## Phase 4 — Observability & Compliance (✅ Done)

1. ✅ Anomaly logging + admin acknowledgement
2. ✅ Audit logging decorator for admin actions
3. ✅ Exports: monthly cycle completion, annual ledger (CSV/PDF), on-demand
4. ✅ Archive job: move ≥36 months to read-only tables

## Phase 5 — Mobile (Flutter, Offline-First) (✅ Done - January 2026)

### Backend API (✅ Complete)

1. ✅ Mobile API contract design (bootstrap, updates, readings, conflicts)
2. ✅ Backend endpoints implementation:
   - ✅ GET /api/v1/mobile/bootstrap (full 12-cycle snapshot)
   - ✅ GET /api/v1/mobile/updates?since=<timestamp> (incremental with tombstones)
   - ✅ POST /api/v1/mobile/readings (submit with 409 conflict detection)
   - ✅ POST /api/v1/mobile/conflicts/{id}/resolve (accept server value)
3. ✅ Bearer token authentication middleware
4. ✅ Mobile service layer (MobileService) with server-wins merge policy
5. ✅ Integration tests (4/4 passing)

### Mobile Frontend (✅ Complete)

1. ✅ Flutter project scaffold (data/local, data/remote, domain, ui, core)
2. ✅ SQLite schema + DAOs:
   - ✅ 8 tables (clients, meters, assignments, cycles, readings, conflicts, sync_queue, metadata)
   - ✅ Migrations and schema versioning
   - ✅ 12-cycle automatic trimming
3. ✅ REST API client (Dio) with bearer token auth
4. ✅ Domain models with JSON serialization (json_annotation)
5. ✅ Offline capture flow:
   - ✅ Client search by name/phone
   - ✅ Display active assignment + previous approved reading
   - ✅ Validate numeric input (4 decimal places)
   - ✅ Save to SQLite + enqueue to sync_queue
6. ✅ Sync engine:
   - ✅ Bootstrap (first-time full sync)
   - ✅ Sync down (incremental updates with tombstones)
   - ✅ Sync up (upload queue with conflict handling)
   - ✅ Server-wins merge policy
   - ✅ 12-cycle trimming after sync
7. ✅ Background sync service:
   - ✅ Workmanager integration (periodic 30-min sync)
   - ✅ Connectivity checks before sync
   - ✅ User-configurable toggle in settings
8. ✅ Conflicts UI:
   - ✅ List unresolved conflicts
   - ✅ Show local vs server values side-by-side
   - ✅ Accept server or mark for resubmit actions
9. ✅ Settings screen:
   - ✅ Bearer token input and secure storage
   - ✅ Sync status (pending uploads count, last sync timestamp)
   - ✅ Manual "Sync now" button with error handling
   - ✅ Background sync on/off toggle
   - ✅ Device ID display (platform-specific)
10. ✅ Core utilities:
    - ✅ Token storage (flutter_secure_storage with AES-256)
    - ✅ Device ID helper (platform-specific identifiers)
    - ✅ Connectivity service wrapper
    - ✅ Error handler with exception hierarchy

**Status**: Phase 5 complete! Mobile app fully functional with offline capture, bidirectional sync, conflict resolution, and background tasks.

**Known Issues**:

- ⚠️ Linux build fails due to flutter_secure_storage_linux glib conflicts → Use Android/iOS for testing
- ⚠️ Backend URL hardcoded to localhost:8000 → TODO: Make configurable

## Phase 6 — Testing & CI (🚧 In Progress)

### Backend Testing

1. ⬜ Unit tests for domain services:
   - ⬜ Precision calculations (4dp readings, 2dp money)
   - ⬜ Baseline enforcement logic
   - ⬜ FIFO payment application
   - ⬜ Rollover detection (≥90,000 threshold)
2. ⬜ Integration tests for workflows:
   - ⬜ Complete cycle lifecycle (OPEN → PENDING_REVIEW → APPROVED → CLOSED)
   - ⬜ Conflict resolution flow
   - ⬜ SMS retry logic (0s, 30m, 4h)
   - ⬜ Archive job (36+ months)
3. ⬜ API endpoint tests:
   - ✅ Mobile endpoints (4/4 passing)
   - ⬜ Admin endpoints (clients, meters, assignments, cycles)
   - ⬜ Payment and penalty endpoints
   - ⬜ Export endpoints
4. ⬜ Edge case testing:
   - ⬜ Concurrent reading submissions
   - ⬜ Negative consumption handling
   - ⬜ Meter replacement flow
   - ⬜ Tariff changes mid-cycle

### Mobile Testing

1. ⬜ Unit tests for DAOs:
   - ⬜ ClientDao search functionality
   - ⬜ ReadingDao last approved query
   - ⬜ SyncQueueDao enqueue/dequeue
   - ⬜ ConflictDao resolution logic
2. ⬜ Unit tests for sync engine:
   - ⬜ Bootstrap full sync
   - ⬜ Incremental updates with tombstones
   - ⬜ Upload queue processing
   - ⬜ 12-cycle trimming logic
3. ⬜ Widget tests for UI screens:
   - ⬜ Capture screen (search, input validation, save)
   - ⬜ Conflicts screen (list, accept/resubmit)
   - ⬜ Settings screen (token save, manual sync)
4. ⬜ Integration tests:
   - ⬜ End-to-end offline capture → sync flow
   - ⬜ Conflict detection and resolution
   - ⬜ Background sync scheduling

### CI/CD Pipeline

1. ⬜ GitHub Actions workflow:
   - ⬜ Lint (flake8, black, isort for Python; flutter analyze for Dart)
   - ⬜ Run pytest with coverage
   - ⬜ Run flutter test with coverage
   - ⬜ Alembic migration validation
2. ⬜ Code coverage gates:
   - ⬜ Backend: >80% coverage
   - ⬜ Mobile: >70% coverage
3. ⬜ Pre-commit hooks:
   - ⬜ Format check (black, dart format)
   - ⬜ Lint check
   - ⬜ Type check (mypy for Python)
4. ⬜ PR automation:
   - ⬜ Auto-label based on files changed
   - ⬜ Require passing tests before merge
   - ⬜ Coverage report comments

## Phase 7 — Deployment & Operations (⬜ Upcoming)

### Containerization

1. ⬜ Backend Dockerfile optimization:
   - ⬜ Multi-stage build
   - ⬜ Non-root user
   - ⬜ Security scanning (trivy/snyk)
2. ⬜ Docker Compose for local development:
   - ⬜ Backend + PostgreSQL + Redis (future)
   - ⬜ Volume mounts for hot reload
   - ⬜ Seeded test data
3. ⬜ Mobile APK/AAB build automation:
   - ⬜ GitHub Actions for release builds
   - ⬜ Signed APK for Play Store
   - ⬜ Version bump automation

### Cloud Deployment

1. ⬜ Provision infrastructure:
   - ⬜ PostgreSQL managed service (AWS RDS, GCP Cloud SQL)
   - ⬜ Redis for task queue (future)
   - ⬜ VPC and security groups
2. ⬜ Deploy backend:
   - ⬜ Render.com (free tier) ← Current
   - ⬜ AWS ECS/Fargate (scalable)
   - ⬜ GCP Cloud Run (serverless)
3. ⬜ Environment configuration:
   - ⬜ Secrets management (AWS Secrets Manager, GCP Secret Manager)
   - ⬜ Environment-specific configs (dev, staging, prod)
   - ⬜ Database connection pooling
4. ⬜ Networking:
   - ⬜ Load balancer with HTTPS (ALB, Cloud Load Balancing)
   - ⬜ Domain setup and SSL certificates
   - ⬜ CORS configuration for web dashboard (future)

### Observability

1. ⬜ Logging:
   - ⬜ Structured JSON logging (loguru or Python logging)
   - ⬜ Log aggregation (CloudWatch, Stackdriver, Datadog)
   - ⬜ Log retention policies
2. ⬜ Monitoring:
   - ⬜ Health check endpoint improvements
   - ⬜ Metrics (Prometheus, Datadog)
   - ⬜ Dashboards (Grafana, cloud-native tools)
3. ⬜ Alerting:
   - ⬜ Error rate thresholds
   - ⬜ SMS delivery failure alerts
   - ⬜ Database connection issues
   - ⬜ API response time SLAs
4. ⬜ Error tracking:
   - ⬜ Sentry integration
   - ⬜ Exception grouping and deduplication
   - ⬜ Source map uploads for stack traces

### Backup & Recovery

1. ⬜ Database backups:
   - ⬜ Automated daily backups (RDS, Cloud SQL)
   - ⬜ Point-in-time recovery testing
   - ⬜ Backup retention (30 days)
2. ⬜ Export integrity:
   - ⬜ Checksum validation for CSV/PDF exports
   - ⬜ Archive integrity checks
3. ⬜ Disaster recovery runbook:
   - ⬜ Restore procedure documentation
   - ⬜ RTO/RPO targets (Recovery Time/Point Objectives)
   - ⬜ Failover testing

### Performance & Scalability

1. ⬜ Load testing:
   - ⬜ Locust or k6 scripts
   - ⬜ Test 1000 concurrent mobile sync requests
   - ⬜ Identify bottlenecks (DB queries, API endpoints)
2. ⬜ Database optimization:
   - ⬜ Query performance analysis (EXPLAIN ANALYZE)
   - ⬜ Index optimization
   - ⬜ Connection pooling tuning
3. ⬜ API optimization:
   - ⬜ Response caching (Redis)
   - ⬜ Pagination for large result sets
   - ⬜ Rate limiting enforcement
4. ⬜ Auto-scaling:
   - ⬜ Horizontal scaling for API servers
   - ⬜ Read replicas for PostgreSQL
   - ⬜ CDN for static assets (future web dashboard)

## Future Enhancements (📋 Backlog)

### Admin Web Dashboard

- ⬜ React or Vue SPA for admin portal
- ⬜ Client/meter/assignment management UI
- ⬜ Reading approval workflow (bulk actions)
- ⬜ Payment/penalty entry forms
- ⬜ Real-time cycle status dashboard
- ⬜ SMS delivery monitoring
- ⬜ Report builder (custom date ranges, filters)

### Mobile App Enhancements

- ⬜ Biometric authentication (fingerprint, face ID)
- ⬜ QR code scanning for meter serial numbers
- ⬜ Photo capture for meter images (evidence)
- ⬜ Voice notes for submission context
- ⬜ Offline maps for route planning
- ⬜ Bulk import/export of readings (CSV)
- ⬜ Multi-user support (team sync, role-based access)
- ⬜ Push notifications for sync status

### Advanced Features

- ⬜ Multi-tenant support (multiple utilities in one system)
- ⬜ Tariff calculator UI (admin configurable rates)
- ⬜ Consumption forecasting (ML-based)
- ⬜ Anomaly auto-resolution rules
- ⬜ Customer self-service portal (view bills, pay online)
- ⬜ WhatsApp integration (alternative to SMS)
- ⬜ USSD integration for feature phones
- ⬜ GIS integration (map view of meters)

### Technical Debt

- ⬜ JWT authentication for admin endpoints (replace placeholder)
- ⬜ Async SMS retry queue (move to Celery or RQ)
- ⬜ Configurable backend URL in mobile app
- ⬜ Linux build fix for flutter_secure_storage
- ⬜ Centralize environment config (remove hardcoded URLs)
- ⬜ API versioning strategy (v2 preparation)

---

## Notes

- **Precision**: Readings/consumption 4dp (NUMERIC 9,4), tariff 2dp, round TZS at final billing stage (half-up).
- **Authoritative Source**: Server is always authoritative; conflicts require admin resolution via server-wins policy.
- **Immutability**: No deletion of financial records (ledger_entries, payments); audit_log is write-only.
- **Offline-First**: Mobile app works without network; sync happens in background when online.
- **12-Cycle Cache**: Mobile stores last 12 cycles to minimize sync data; older data auto-trimmed.

---

**Last Updated**: January 2026  
**Current Phase**: Phase 5 Complete ✅ → Phase 6 In Progress 🚧 2. Audit logging decorator for admin actions 3. Exports: monthly cycle completion, annual ledger (CSV/PDF), on-demand 4. Archive job: move ≥36 months to read-only tables

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
