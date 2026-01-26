# AquaBill — Water Utility Management System

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Python 3.11+](https://img.shields.io/badge/python-3.11+-blue.svg)](https://www.python.org/downloads/)
[![Flutter 3.0+](https://img.shields.io/badge/flutter-3.0+-blue.svg)](https://flutter.dev/)
[![FastAPI](https://img.shields.io/badge/FastAPI-0.100+-green.svg)](https://fastapi.tiangolo.com/)

AquaBill is a complete offline-capable water meter reading and billing management system designed for small-to-medium water utilities in Tanzania. The system digitizes the entire billing cycle: meter reading capture, consumption-based billing, ledger-driven payments, arrears tracking, and SMS notifications.

**Key Features:**

- 📱 **Offline-first mobile app** (Flutter) for field collectors
- 🔄 **Bidirectional sync** with server-authoritative conflict resolution
- 💰 **Ledger-based accounting** with FIFO payment application
- 📊 **Admin dashboard** for approvals, penalties, and exports
- 💬 **SMS integration** with delivery tracking and retry logic
- 📝 **Audit logging** for compliance and accountability
- 🗄️ **Automatic archiving** of data older than 36 months

---

## 🚀 Quick Start

### Backend Setup (FastAPI + PostgreSQL)

1. **Clone and setup environment:**

```bash
git clone https://github.com/your-org/aquabill-app.git
cd aquabill-app
python -m venv .venv
source .venv/bin/activate  # On Windows: .venv\Scripts\activate
pip install -r requirements.txt
```

2. **Configure environment variables:**

```bash
cp .env.example .env
# Edit .env with your database URL, SMS gateway credentials, etc.
```

3. **Run database migrations:**

```bash
alembic upgrade head
```

4. **Start the API server:**

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

5. **Verify health:**

```bash
curl http://localhost:8000/api/v1/health
```

### Mobile App Setup (Flutter)

1. **Navigate to mobile directory:**

```bash
cd mobile
```

2. **Install dependencies:**

```bash
flutter pub get
flutter pub run build_runner build --delete-conflicting-outputs
```

3. **Run on device/emulator:**

```bash
flutter run -d <device-id>
```

**Note:** For Android testing, use `flutter run -d android`. Linux builds have known issues with `flutter_secure_storage` dependencies.

---

## 📚 Documentation

### User Guides

- **[Implementation Guidelines](docs/guideline.md)** — Architecture and design principles
- **[Development Guide](docs/DEVELOPMENT.md)** — Local development setup
- **[Deployment Guide](docs/DEPLOYMENT.md)** — Production deployment on Render/AWS/GCP

### Technical Documentation

- **[API Reference](docs/API_REFERENCE.md)** — Complete REST API documentation
- **[Backend Implementation](docs/BACKEND_IMPLEMENTATION.md)** — FastAPI backend architecture
- **[Mobile Frontend](docs/MOBILE_FRONTEND_IMPLEMENTATION.md)** — Flutter app architecture
- **[Audit Logging](docs/AUDIT_LOGGING_GUIDE.md)** — Compliance and audit trails

### Project Planning

- **[TODOs & Roadmap](docs/TODOs.md)** — Implementation phases and progress
- **[Phase 5 Mobile Design](docs/PHASE5_MOBILE_DESIGN.md)** — Offline-first mobile architecture
- **[Phase 5 Backend Summary](docs/PHASE5_BACKEND_SUMMARY.md)** — Mobile API endpoints

---

## 🏗️ Architecture

### Backend (FastAPI + PostgreSQL)

```bash
app/
├── api/              # REST endpoints (routers)
├── core/             # Config, dependencies, auth
├── domain/           # Business logic (services)
├── models/           # SQLAlchemy ORM models
└── schemas/          # Pydantic schemas
```

**Tech Stack:**

- FastAPI 0.100+
- PostgreSQL 14+
- Alembic for migrations
- SQLAlchemy 2.0 ORM
- Pydantic v2 for validation
- SMS gateway integration (configurable)

### Mobile Frontend (Flutter)

```bash
mobile/lib/
├── core/             # Cross-cutting concerns (auth, storage, errors)
├── data/             # Data layer (SQLite, REST client, models)
├── domain/           # Business logic (sync engine, repositories)
└── ui/               # Flutter screens (capture, conflicts, settings)
```

**Tech Stack:**

- Flutter 3.0+ (Material 3)
- SQLite (sqflite) for offline storage
- Dio for HTTP client
- Workmanager for background sync
- flutter_secure_storage for tokens
- Provider + Riverpod for state management

### Data Flow

```bash
Mobile App (SQLite)
      ↓ Background Sync
REST API (FastAPI)
      ↓ ORM
PostgreSQL (Authoritative)
      ↓ SMS Gateway
Clients receive notifications
```

---

## 📱 Features

### Phase 0-4 (Backend Complete ✅)

#### Domain & Schema

- ✅ Clients, meters, meter assignments with constraints
- ✅ Billing cycles with non-overlapping date validation
- ✅ Readings with 4-decimal precision (NUMERIC 9,4)
- ✅ Anomalies and conflicts tracking
- ✅ Ledger entries, payments, penalties
- ✅ Audit log (immutable, write-only)
- ✅ SMS messages with delivery history

#### Core Workflows

- ✅ Meter assignment with baseline enforcement
- ✅ Cycle scheduling and auto-transitions (OPEN → PENDING_REVIEW → APPROVED)
- ✅ Reading submission with window validation
- ✅ Admin approval and consumption calculation
- ✅ Rollover detection (≥90,000 threshold)
- ✅ Conflict resolution (multiple submissions per assignment/cycle)

#### Accounting & Notifications

- ✅ Auto-generate cycle charges on approval
- ✅ FIFO payment application with credits
- ✅ Manual penalty application with notes
- ✅ SMS integration with retry logic (0s, 30m, 4h)
- ✅ Delivery status tracking and callbacks
- ✅ Balance calculation (charges - payments + penalties)

#### Observability

- ✅ Anomaly logging (negative consumption, large jumps)
- ✅ Audit logging for admin actions
- ✅ Data export (JSON/CSV per cycle)
- ✅ Archive old data (36+ months) to read-only tables

### Phase 5 (Mobile Complete ✅)

#### Mobile Features

- ✅ Offline reading capture (12-cycle cache)
- ✅ Client search by name/phone
- ✅ Display previous approved reading
- ✅ Submit readings to SQLite + sync queue
- ✅ Background sync every 30 minutes (user-configurable)
- ✅ Conflict detection and resolution UI
- ✅ Server-wins merge policy
- ✅ Device identification (platform-specific IDs)
- ✅ Bearer token authentication
- ✅ Sync status indicator (pending uploads count)

#### Backend API

- ✅ Bootstrap endpoint (full 12-cycle snapshot)
- ✅ Incremental updates endpoint (with tombstones)
- ✅ Submit reading endpoint (409 on conflict)
- ✅ Resolve conflict endpoint (accept server value)
- ✅ Mobile token authentication middleware
- ✅ Integration tests (4/4 passing)

---

## 🗂️ Repository Layout

```bash
aquabill-app/
├── app/                      # Backend FastAPI application
│   ├── api/                  # REST endpoints
│   ├── core/                 # Config, auth, dependencies
│   ├── domain/               # Business logic services
│   ├── models/               # SQLAlchemy ORM models
│   └── schemas/              # Pydantic request/response schemas
├── mobile/                   # Flutter mobile app
│   ├── lib/
│   │   ├── core/             # Auth, storage, errors
│   │   ├── data/             # SQLite, API client, models
│   │   ├── domain/           # Sync engine, background tasks
│   │   └── ui/               # Flutter screens
│   ├── pubspec.yaml          # Flutter dependencies
│   └── README.md             # Mobile-specific setup
├── migrations/               # Alembic database migrations
├── tests/                    # Pytest backend tests
│   ├── test_mobile_api.py    # Mobile endpoint tests (4/4 passing)
│   └── ...                   # Other test suites
├── docs/                     # Documentation
│   ├── API_REFERENCE.md      # Complete API docs
│   ├── BACKEND_IMPLEMENTATION.md
│   ├── MOBILE_FRONTEND_IMPLEMENTATION.md
│   ├── guideline.md          # Architecture principles
│   └── TODOs.md              # Project roadmap
├── requirements.txt          # Python dependencies
├── .env.example              # Environment variables template
├── alembic.ini               # Alembic config
├── Dockerfile                # Production container
├── render.yaml               # Render.com deployment
└── README.md                 # This file
```

---

## 🧪 Testing

### Backend Tests

```bash
# Run all tests
pytest

# Run with coverage
pytest --cov=app --cov-report=html

# Run specific test file
pytest tests/test_mobile_api.py -v
```

**Current Status:** 4/4 mobile API integration tests passing ✅

### Mobile Tests

```bash
cd mobile

# Analyze code
flutter analyze

# Run unit tests (TODO: not yet implemented)
flutter test

# Run integration tests (TODO: not yet implemented)
flutter drive --target=test_driver/app.dart
```

---

## 🚢 Deployment

### Render (Free Tier)

1. **Fork this repository**
2. **Connect to Render:**
   - Go to [render.com](https://render.com) and sign up
   - Click "New Web Service" and select your forked repo
3. **Configure environment variables:**
   - `AQUABILL_DATABASE_URL` (PostgreSQL connection string)
   - `AQUABILL_SMS_GATEWAY_URL` (SMS provider API URL)
   - `AQUABILL_SMS_API_KEY` (SMS provider API key)
   - `AQUABILL_SUBMISSION_WINDOW_DAYS` (default: 7)
4. **Deploy:** Render auto-deploys from `render.yaml`

See [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) for AWS, GCP, and Docker Compose options.

---

## 📊 Database Schema

**Core Tables:**

- `clients` — Customer information
- `meters` — Water meter devices
- `meter_assignments` — Meter ↔ Client relationships (one active per meter)
- `cycles` — Billing periods (monthly)
- `readings` — Meter readings (4 decimal places)
- `ledger_entries` — Immutable accounting ledger
- `payments` — Payment records with FIFO application
- `penalties` — Admin-applied penalties
- `conflicts` — Duplicate submission tracking
- `anomalies` — Consumption anomalies (negative, large jumps)
- `audit_log` — Admin action history (write-only)
- `sms_messages` — SMS queue and delivery status

**Precision:**

- Readings: `NUMERIC(9,4)` → max 99,999.9999 m³
- Money: `NUMERIC(12,2)` → max 9,999,999,999.99 TZS

**Indexes:** Optimized for reads on `(meter_assignment_id, cycle_id)`, `(client_id, created_at)`, etc.

See [docs/guideline.md](docs/guideline.md) for full schema documentation.

---

## 🔐 Security

- **Authentication:** Bearer token for mobile, JWT for admin (TODO: implement JWT)
- **Token Storage:** AES-256 encrypted via flutter_secure_storage
- **SQL Injection:** Protected via SQLAlchemy parameterized queries
- **HTTPS Required:** Production must use TLS/SSL
- **Rate Limiting:** 100 req/min for mobile, 1000 req/min for admin
- **Audit Logging:** All admin actions logged immutably

---

## 🐛 Known Issues

### Mobile App

- **Linux Build:** flutter_secure_storage_linux has glib/libsecret conflicts. Use Android/iOS for testing.
- **Backend URL:** Hardcoded to `http://localhost:8000` in API client. TODO: Make configurable.

### Backend

- **SMS Retry:** Currently synchronous. TODO: Move to background task queue (Celery/RQ).
- **JWT Auth:** Placeholder for admin endpoints. TODO: Implement full JWT flow.

See [docs/TODOs.md](docs/TODOs.md) for complete issue tracking.

---

## 🛣️ Roadmap

### Phase 6 — Testing & CI (Next)

- [ ] Unit tests for DAOs and services
- [ ] Integration tests for all workflows
- [ ] CI/CD pipeline (GitHub Actions)
- [ ] Code coverage >80%

### Phase 7 — Production Readiness

- [ ] JWT authentication for admin
- [ ] Rate limiting middleware
- [ ] Logging and monitoring (Sentry, Datadog)
- [ ] Backup and restore procedures
- [ ] Load testing and optimization

### Future Enhancements

- [ ] Admin web dashboard (React/Vue)
- [ ] Biometric auth for mobile
- [ ] QR code scanning for meters
- [ ] Photo capture for meter images
- [ ] Push notifications
- [ ] Multi-tenant support
- [ ] Report builder UI

See [docs/TODOs.md](docs/TODOs.md) for detailed phase breakdown.

---

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'feat: add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

**Commit Convention:** Use [Conventional Commits](https://www.conventionalcommits.org/)

- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation changes
- `test:` Test additions/changes
- `refactor:` Code refactoring

---

## 📄 License

This project is licensed under the MIT License — see [LICENSE](LICENSE) file for details.

---

## 📧 Support

- **Documentation:** See [docs/](docs/) directory
- **Issues:** [GitHub Issues](https://github.com/your-org/aquabill-app/issues)
- **Discussions:** [GitHub Discussions](https://github.com/your-org/aquabill-app/discussions)
- **Email:** support@aquabill.example.com

---

## 🙏 Acknowledgments

Built for small-to-medium water utilities in Tanzania to digitize meter reading and billing workflows.

**Technologies:**

- FastAPI — Modern Python web framework
- Flutter — Cross-platform mobile framework
- PostgreSQL — Robust RDBMS
- SQLite — Embedded database for offline mobile
- Alembic — Database migration tool

---

**Version:** 1.0.0  
**Last Updated:** January 2026  
**Status:** Phase 5 Complete ✅ | Phase 6 In Progress 🚧
