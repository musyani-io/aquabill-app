# Development Setup Guide

This guide covers setting up AquaBill for local development.

## Prerequisites

- Docker & Docker Compose
- Python 3.11+
- Flutter SDK
- Android Studio (for mobile testing)

## Quick Start

### 1. Clone Repository

```bash
git clone <repository-url>
cd aquabill-app
```

### 2. Set Environment Variables

```bash
cp .env.example .env
# Edit .env with your local configuration
```

### 3. Start Services

```bash
docker-compose up -d
```

This will start:

- PostgreSQL (port 5432)
- Redis (port 6379)
- FastAPI Backend (port 8000)
- Celery Worker

### 4. Run Migrations

```bash
docker-compose exec backend alembic upgrade head
```

### 5. Create Demo Data

```bash
docker-compose exec backend python scripts/seed_demo_data.py
```

### 6. Access Services

- **API**: <http://localhost:8000>
- **API Docs**: <http://localhost:8000/docs>
- **Database**: localhost:5432 (user: aquabill, password: aquabill)

## Mobile Development

### Install Flutter

```bash
flutter upgrade
flutter pub get
```

### Run Mobile App

```bash
cd mobile
flutter run
```

### Connect to Backend

Edit `mobile/lib/core/config.dart` and set:

```dart
const String apiBaseUrl = 'http://10.0.2.2:8000/api/v1';  // Android emulator
// or
const String apiBaseUrl = 'http://localhost:8000/api/v1';  // Physical device on same network
```

## Testing

### Backend Tests

```bash
docker-compose exec backend pytest
```

### Mobile Tests

```bash
cd mobile
flutter test
```

## Debugging

### View Backend Logs

```bash
docker-compose logs -f backend
```

### View Database

```bash
docker-compose exec postgres psql -U aquabill -d aquabill_dev
```

### Reset Database

```bash
docker-compose down -v
docker-compose up -d
docker-compose exec backend alembic upgrade head
```

## Common Issues

### Port Already in Use

Change ports in `docker-compose.yml`

### Database Connection Failed

Ensure PostgreSQL container is running: `docker-compose ps`

### Flutter Build Fails

Run `flutter clean` and try again
