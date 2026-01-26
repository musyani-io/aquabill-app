# AquaBill Mobile App

Flutter-based offline-first mobile app for water meter reading collection in Tanzania.

## Project Structure

```bash
lib/
├── data/
│   ├── local/          # SQLite database & DAOs
│   ├── remote/         # REST API client
│   └── models/         # Data models (JSON serializable)
├── domain/             # Repositories, use-cases, business logic
├── ui/                 # Screens, widgets, UI logic
├── core/               # Utilities, error handling, connectivity
└── main.dart           # Entry point
```

## Features

- **Offline Capture**: Submit meter readings without network
- **Local SQLite Cache**: Last 12 cycles, assignments, readings
- **Background Sync**: Upload queue when online
- **Conflict Resolution**: Server-wins merge with local conflict tracking
- **Previous Reading Display**: Show last approved reading for context
- **Search**: Find clients by name or phone
- **Settings**: Token storage, sync preferences

## Getting Started

### Prerequisites

- Flutter 3.0+
- Android SDK 21+ or iOS 11+

### Setup

```bash
# Install dependencies
flutter pub get

# Generate code (for JSON serialization, etc.)
dart run build_runner build

# Run app
flutter run
```

## Architecture

- **Repository Pattern**: DAOs for local, REST client for remote
- **Provider/Riverpod**: State management
- **SQLite**: Local storage with server-wins sync strategy

## Key Packages

- `sqflite`: Local database
- `http`/`dio`: API communication
- `provider`/`riverpod`: State management
- `flutter_secure_storage`: Token storage
- `connectivity_plus`: Offline detection
- `workmanager`: Background sync tasks

## Development

### Database Migrations

Modify `lib/data/local/database.dart` and increment `dbVersion`.

### Adding Models

1. Create model in `lib/data/models/`
2. Add JSON serialization: `part 'model.g.dart'`
3. Run: `dart run build_runner build`

### Adding DAOs

1. Create DAO in `lib/data/local/daos/`
2. Implement local CRUD operations
3. Add to AppDatabase initialization

## Testing

```bash
# Unit tests
flutter test

# Integration tests
flutter drive --target=test_driver/app.dart
```

## Deployment

See `../docs/PHASE5_MOBILE_DESIGN.md` for backend sync contract and conflict handling details.
