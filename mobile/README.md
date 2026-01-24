# AquaBill Mobile App Setup

## Installation

### Prerequisites

- Flutter 3.16+
- Dart 3.2+
- Android SDK 21+
- Android Studio or VS Code with Flutter extension

### Get Started

1. **Install dependencies:**

   ```bash
   cd mobile
   flutter pub get
   ```

2. **Configure API Base URL:**
   Edit `lib/core/config.dart`:

   ```dart
   const String apiBaseUrl = 'http://localhost:8000/api/v1';
   ```

3. **Run the app:**

   ```text
   flutter run
   ```

## Project Structure

- `lib/main.dart` - App entry point
- `lib/core/` - Core utilities (auth, storage, networking)
- `lib/features/` - Feature modules
- `lib/models/` - Data models
- `lib/widgets/` - Reusable UI components
- `test/` - Test suite

## Testing

```bash
flutter test
```

## Build APK

```bash
flutter build apk --release
```

The APK will be at: `build/app/outputs/flutter-app.apk`

## Features

- **Offline-first**: Works completely offline
- **Secure**: Token-based authentication
- **Efficient**: SQLite local storage
- **Real-time Sync**: Auto-sync when network available

## Troubleshooting

### Flutter not found

```bash
export PATH="$PATH:~/flutter/bin"
```

### Build fails

```bash
flutter clean
flutter pub get
flutter run
```

### Emulator issues

Use device instead or restart emulator:

```bash
flutter emulators
flutter emulators launch <emulator-id>
```
