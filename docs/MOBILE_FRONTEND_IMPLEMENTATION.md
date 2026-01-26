# Mobile Frontend Implementation Guide

This document describes the Flutter mobile app implementation for AquaBill Phase 5, including architecture, components, and development workflow.

## Overview

The mobile app is an offline-first Flutter application for field collectors to capture water meter readings. It maintains a local SQLite cache of the last 12 billing cycles and syncs bidirectionally with the backend API.

**Status**: ✅ Complete (January 2026)

## Tech Stack

- **Flutter**: 3.0+ with Material 3 design
- **Local Storage**: SQLite via `sqflite` package
- **HTTP Client**: Dio with interceptors for auth
- **State Management**: Provider + Riverpod
- **Security**: flutter_secure_storage for tokens
- **Background Tasks**: workmanager for periodic sync
- **Connectivity**: connectivity_plus for network detection
- **Device ID**: device_info_plus for unique device identification

## Project Structure

```bash
mobile/
├── lib/
│   ├── core/                    # Cross-cutting concerns
│   │   ├── connectivity.dart    # Network status checker
│   │   ├── device_id.dart       # Device identifier generator
│   │   ├── error_handler.dart   # Exception hierarchy
│   │   └── token_storage.dart   # Secure token persistence
│   ├── data/                    # Data layer
│   │   ├── local/              # SQLite implementation
│   │   │   ├── database.dart   # Schema, migrations, metadata
│   │   │   └── daos/           # Data access objects
│   │   │       ├── base_dao.dart
│   │   │       ├── client_dao.dart
│   │   │       ├── meter_dao.dart
│   │   │       ├── meter_assignment_dao.dart
│   │   │       ├── cycle_dao.dart
│   │   │       ├── reading_dao.dart
│   │   │       ├── conflict_dao.dart
│   │   │       └── sync_queue_dao.dart
│   │   ├── remote/             # REST API client
│   │   │   ├── mobile_api_client.dart
│   │   │   └── dtos.dart       # API payloads
│   │   └── models/             # Domain models
│   │       ├── models.dart
│   │       └── models.g.dart   # Generated JSON serialization
│   ├── domain/                 # Business logic
│   │   └── sync/
│   │       ├── sync_engine.dart           # Orchestrator
│   │       └── background_sync_service.dart
│   ├── ui/                     # User interface
│   │   ├── capture_screen.dart    # Search + reading submission
│   │   ├── conflicts_screen.dart  # Conflict resolution
│   │   └── settings_screen.dart   # Token, sync, device info
│   └── main.dart               # App entry point
├── pubspec.yaml                # Dependencies
└── README.md                   # Mobile-specific docs
```

## Architecture Layers

### 1. Data Layer

#### Local Storage (SQLite)

**Database Schema** (`data/local/database.dart`):

- 8 tables: clients, meters, meter_assignments, cycles, readings, conflicts, sync_queue, metadata
- Auto-incrementing schema_version for migrations
- Metadata table stores: schema_version, last_sync_timestamp, device_id
- Automatic old cycle trimming (keeps last 12 cycles)

**DAOs** (`data/local/daos/*.dart`):

- BaseDao: Common CRUD operations
- ClientDao: Search by name/phone with fuzzy matching
- MeterAssignmentDao: Get active assignments by client
- ReadingDao: Query by assignment, get last approved reading
- ConflictDao: List unresolved, mark resolved
- SyncQueueDao: Enqueue/dequeue operations, pending count

#### Remote API (`data/remote/mobile_api_client.dart`)

REST client with Dio:

- **GET /api/v1/mobile/bootstrap**: Full 12-cycle snapshot (first sync)
- **GET /api/v1/mobile/updates?since=timestamp**: Incremental updates with tombstones
- **POST /api/v1/mobile/readings**: Submit reading (returns 201 or 409 for conflict)
- **POST /api/v1/mobile/conflicts/{id}/resolve**: Accept server value

Bearer token authentication via Authorization header.

#### Models (`data/models/models.dart`)

Domain models with JSON serialization:

- ClientModel, MeterModel, MeterAssignmentModel
- CycleModel, ReadingModel, ConflictModel
- SyncQueueItemModel

Each model has:

- `fromJson()` / `toJson()` for API serialization
- `fromLocalMap()` / `toLocalMap()` for SQLite serialization

### 2. Domain Layer

#### Sync Engine (`domain/sync/sync_engine.dart`)

Orchestrates bidirectional sync:

**Bootstrap** (first-time sync):

- Fetches last 12 cycles with all related data
- Populates local SQLite cache
- Sets last_sync timestamp

**Sync Down** (incremental):

- Fetches updates since last_sync
- Applies tombstones (deletions)
- Upserts clients, meters, assignments, cycles, readings
- Detects conflicts (local vs server)

**Sync Up**:

- Dequeues pending items from sync_queue
- Submits readings to server
- Handles 409 Conflict responses
- Removes successful items from queue

**Conflict Policy**:

- Server wins by default
- Creates ConflictModel record
- User can accept server value or mark for resubmit
- Resubmit creates new sync_queue entry

**12-Cycle Trimming**:

- After every sync, trims cycles older than the last 12
- Cascades to readings, conflicts, assignments

#### Background Sync Service (`domain/sync/background_sync_service.dart`)

Workmanager-based periodic sync:

- Runs every 30 minutes when network connected
- Checks for pending uploads before syncing
- Respects battery and data constraints
- User-controllable toggle in settings

### 3. UI Layer

#### Capture Screen (`ui/capture_screen.dart`)

**Features**:

- Search clients by name or phone
- Display active meter assignment
- Show previous approved reading
- Validate numeric input (absolute reading)
- Optional notes field
- Save to local SQLite + enqueue for sync
- Offline-first: works without network

**Flow**:

1. Type to search → results appear
2. Select client → loads assignment + last reading
3. Enter new reading (validates > 0)
4. Add notes (optional)
5. Tap "Save offline" → persists locally + queues

#### Conflicts Screen (`ui/conflicts_screen.dart`)

**Features**:

- List unresolved conflicts
- Show local vs server values side-by-side
- Display client name, cycle, assignment
- Two actions:
  - **Accept Server**: Marks conflict resolved
  - **Resubmit Local**: Re-adds to sync queue

**Flow**:

1. App checks conflict_dao on load
2. Displays conflicts if any exist
3. User reviews values
4. Accepts server or marks for resubmit
5. Conflict removed from list

#### Settings Screen (`ui/settings_screen.dart`)

**Features**:

- Bearer token input + secure save
- Sync status:
  - Pending uploads count
  - Last sync timestamp
- Manual "Sync now" button
- Background sync toggle (on/off)
- Device ID display
- Connectivity check before sync

### 4. Core Layer

#### Token Storage (`core/token_storage.dart`)

Secure storage wrapper:

- `saveToken(token)` / `getToken()` for auth
- `saveCustom(key, value)` / `getCustom(key)` for generic storage
- Uses flutter_secure_storage (AES-256 encrypted)
- Platform-specific secure storage:
  - Android: EncryptedSharedPreferences
  - iOS: Keychain
  - Linux: libsecret (with fallback to prefs)

#### Device ID (`core/device_id.dart`)

Platform-specific unique identifier:

- Android: `androidInfo.id`
- iOS: `iosInfo.identifierForVendor`
- Linux: `linuxInfo.machineId`
- Format: `<platform>_<id>` (e.g., `android_abc123xyz`)
- Persisted in secure storage for consistency

#### Error Handler (`core/error_handler.dart`)

Exception hierarchy:

- `AppException` (base)
- `NetworkException` (HTTP errors)
- `ValidationException` (input errors)
- `ConflictException` (409 responses)
- `SyncException` (sync failures)

#### Connectivity (`core/connectivity.dart`)

Network status checker:

- `isOnline()` async method
- Uses connectivity_plus to detect mobile/wifi/none
- Validates actual network access (not just connection)

## Data Flow

### Offline Capture Flow

```bash
User → Capture Screen → Reading Input
  ↓
Validate (numeric, non-empty)
  ↓
Save to readings table (status: LOCAL_ONLY)
  ↓
Enqueue to sync_queue (entity_type: READING, operation: CREATE)
  ↓
Success notification → Clear form
```

### Background Sync Flow

```bash
Every 30 minutes (if background sync enabled)
  ↓
Check connectivity → Exit if offline
  ↓
Check token → Exit if missing
  ↓
Check sync_queue.pendingCount() → Exit if 0
  ↓
SyncEngine.syncAll(uploadFirst: true)
  ↓
  ├─ Upload: Dequeue + submit readings
  │   ├─ 201 Created → Remove from queue
  │   └─ 409 Conflict → Create conflict record
  ↓
  └─ Download: Fetch updates since last_sync
      ├─ Upsert clients, meters, assignments, cycles
      ├─ Apply tombstones (deletions)
      ├─ Update readings with server status
      └─ Trim old cycles (keep last 12)
```

### Conflict Resolution Flow

```bash
Sync detects 409 Conflict
  ↓
Create ConflictModel (local_value, server_value)
  ↓
Display in Conflicts Screen
  ↓
User reviews values
  ↓
  ├─ Accept Server → Mark resolved, update reading status
  └─ Resubmit Local → Re-add to sync_queue
```

## API Integration

### Authentication

Bearer token required for all mobile endpoints:

```dart
Authorization: Bearer <token>
```

Token stored securely via flutter_secure_storage.

### Endpoints

#### Bootstrap (First Sync)

```bash
GET /api/v1/mobile/bootstrap
Headers: Authorization: Bearer <token>
Response: {
  cycles: [...],
  clients: [...],
  meters: [...],
  meter_assignments: [...],
  readings: [...],
  conflicts: [...]
}
```

#### Incremental Updates

```bash
GET /api/v1/mobile/updates?since=2025-01-20T10:30:00Z
Headers: Authorization: Bearer <token>
Response: {
  cycles: [...],
  clients: [...],
  meters: [...],
  meter_assignments: [...],
  readings: [...],
  conflicts: [...],
  tombstones: [{entity_type: "reading", entity_id: 123}, ...]
}
```

#### Submit Reading

```bash
POST /api/v1/mobile/readings
Headers: Authorization: Bearer <token>
Body: {
  meter_assignment_id: 5,
  cycle_id: 12,
  absolute_value: 1234.5678,
  submitted_by: "mobile-user",
  submitted_at: "2025-01-26T10:30:00Z",
  source: "mobile",
  previous_approved_reading: 1200.0000,
  device_id: "android_abc123",
  app_version: "1.0.0",
  submission_notes: "Optional notes"
}
Response: 201 Created | 409 Conflict
```

#### Resolve Conflict

```bash
POST /api/v1/mobile/conflicts/{conflict_id}/resolve
Headers: Authorization: Bearer <token>
Body: {action: "accept_server"}
Response: 200 OK
```

## Development Workflow

### Setup

1. Install Flutter SDK (3.0+):

```bash
flutter doctor
```

1. Install dependencies:

```bash
cd mobile
flutter pub get
```

1. Generate JSON serialization code:

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Running

**Development mode**:

```bash
flutter run -d <device-id>
```

**Hot reload**: Press `r` in terminal or use IDE hot reload

**Hot restart**: Press `R` in terminal

### Building

**Android APK**:

```bash
flutter build apk --release
```

**Android App Bundle** (for Play Store):

```bash
flutter build appbundle --release
```

**iOS** (requires macOS + Xcode):

```bash
flutter build ios --release
```

### Testing

**Run all tests**:

```bash
flutter test
```

**Run with coverage**:

```bash
flutter test --coverage
```

**Analyze code**:

```bash
flutter analyze
```

## Configuration

### Backend URL

Hardcoded in multiple files (needs centralization):

- `mobile_api_client.dart`: `http://localhost:8000`
- `background_sync_service.dart`: `http://localhost:8000`

**TODO**: Move to environment config or settings screen.

### Dependencies

Key packages in `pubspec.yaml`:

```yaml
dependencies:
  sqflite: ^2.2.0 # SQLite database
  dio: ^5.3.0 # HTTP client
  provider: ^6.0.0 # State management
  connectivity_plus: ^5.0.0 # Network detection
  flutter_secure_storage: ^9.0.0 # Secure storage
  device_info_plus: ^9.0.0 # Device identification
  workmanager: ^0.5.0 # Background tasks
  json_annotation: ^4.9.0 # JSON serialization
```

## Known Issues & Limitations

### Linux Build Issue

**Problem**: flutter_secure_storage_linux has glib version conflicts with libsecret on some Linux distributions.

**Error**:

```bash
/usr/lib/x86_64-linux-gnu/libsecret-1.so.0: undefined reference to `g_task_set_static_name'
```

**Workaround**: Use Android emulator or physical device for testing. Linux native build not recommended for production.

### Hardcoded Backend URL

Backend URL is hardcoded in API client and background sync service. Should be configurable via:

- Environment variable
- Build flavor
- Settings screen input

### No Unit Tests Yet

Current implementation has:

- ✅ Backend API integration tests (4/4 passing)
- ❌ Mobile unit tests (DAOs, sync engine)
- ❌ Mobile widget tests (UI screens)
- ❌ Mobile integration tests (full flow)

**TODO**: Add comprehensive test coverage in Phase 6.

## Performance Considerations

### Database Optimization

- Indexes on frequently queried columns:
  - `readings(meter_assignment_id, cycle_id)`
  - `conflicts(meter_assignment_id, cycle_id)`
  - `sync_queue(entity_type, created_at)`
- 12-cycle trimming prevents unbounded growth
- Batch upserts for sync operations

### Network Efficiency

- Incremental sync uses `?since=` timestamp
- Tombstones for deletions (avoid full re-downloads)
- Background sync only when network connected
- Retry with exponential backoff (workmanager handles this)

### Memory Management

- Lazy loading of search results (limit 20)
- Streams/futures for async operations
- Dispose controllers in State.dispose()

## Security

### Token Storage

- AES-256 encrypted via flutter_secure_storage
- Never logged or displayed
- Cleared on logout (not implemented yet)

### Device Identification

- Platform-specific IDs persist across app reinstalls
- Used for audit trail and conflict attribution
- Not personally identifiable (no IMEI/phone number)

### Data at Rest

- SQLite database is unencrypted (local device storage)
- Sensitive data: tokens in secure storage only
- No payment or personal financial data on mobile

## Future Enhancements

### Phase 6+ Additions

- [ ] Biometric authentication
- [ ] QR code scanning for meter serial numbers
- [ ] Bulk import/export of readings
- [ ] Offline maps for route planning
- [ ] Photo capture for meter images
- [ ] Voice notes for submission context
- [ ] Multi-user support (team sync)
- [ ] Automatic conflict resolution rules
- [ ] Analytics dashboard (readings per day, etc.)
- [ ] Push notifications for sync status

## Troubleshooting

### "Build process failed" on Linux

See Known Issues above. Use Android instead.

### "Token saved but sync fails"

Check:

1. Backend is running (`http://localhost:8000/api/v1/health`)
2. Token is valid (check with curl or Postman)
3. Network connectivity (Settings → Sync status)

### "No assignments for this client"

Client has no active meter assignment. Check backend:

```sql
SELECT * FROM meter_assignments WHERE client_id = <id> AND status = 'ACTIVE';
```

### "Conflicts not appearing"

1. Check conflicts table: `SELECT * FROM conflicts WHERE resolved = 0;`
2. Verify sync completed successfully
3. Restart app to reload conflicts screen

### Background sync not running

1. Check Settings → Background sync toggle is ON
2. Verify network connection
3. Check pending uploads count > 0
4. Android: Check battery optimization settings (may prevent background tasks)

## Contributing

When modifying mobile code:

1. Run `flutter analyze` before committing
2. Update models? Run `build_runner` to regenerate
3. Database changes? Increment schema_version in database.dart
4. Add migration logic in AppDatabase.\_migrate()
5. Update this document with architectural changes

## References

- [Flutter Documentation](https://flutter.dev/docs)
- [Dio HTTP Client](https://pub.dev/packages/dio)
- [sqflite](https://pub.dev/packages/sqflite)
- [Workmanager](https://pub.dev/packages/workmanager)
- [Phase 5 Mobile Design](./PHASE5_MOBILE_DESIGN.md)
- [Backend Implementation](./BACKEND_IMPLEMENTATION.md)
