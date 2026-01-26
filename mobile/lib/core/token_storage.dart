import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';

/// Secure storage for API tokens and settings.
class TokenStorage {
  static final TokenStorage _instance = TokenStorage._internal();
  factory TokenStorage() => _instance;
  TokenStorage._internal();

  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const String _tokenKey = 'auth_token';

  Future<String?> _getStorageDir() async {
    if (kDebugMode && (Platform.isLinux || Platform.isMacOS)) {
      // On Linux/macOS dev, use app documents for testing
      try {
        final dir = await getApplicationDocumentsDirectory();
        return dir.path;
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> saveToken(String token) async {
    final storageDir = await _getStorageDir();
    if (storageDir != null) {
      // Fallback for development on Linux/macOS
      final file = File('$storageDir/.aquabill_token');
      await file.writeAsString(token);
    } else {
      await _storage.write(key: _tokenKey, value: token);
    }
  }

  Future<String?> getToken() async {
    final storageDir = await _getStorageDir();
    if (storageDir != null) {
      try {
        final file = File('$storageDir/.aquabill_token');
        if (await file.exists()) {
          return file.readAsString();
        }
      } catch (_) {
        // Fall back to secure storage
      }
    }
    return _storage.read(key: _tokenKey);
  }

  Future<void> clearToken() async {
    final storageDir = await _getStorageDir();
    if (storageDir != null) {
      try {
        final file = File('$storageDir/.aquabill_token');
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {
        // Fall back to secure storage
      }
    }
    await _storage.delete(key: _tokenKey);
  }

  // Generic storage helpers
  Future<void> saveCustom(String key, String value) async {
    final storageDir = await _getStorageDir();
    if (storageDir != null) {
      try {
        final file = File('$storageDir/.aquabill_$key');
        await file.writeAsString(value);
        return;
      } catch (_) {
        // Fall back to secure storage
      }
    }
    await _storage.write(key: key, value: value);
  }

  Future<String?> getCustom(String key) async {
    final storageDir = await _getStorageDir();
    if (storageDir != null) {
      try {
        final file = File('$storageDir/.aquabill_$key');
        if (await file.exists()) {
          return file.readAsString();
        }
      } catch (_) {
        // Fall back to secure storage
      }
    }
    return _storage.read(key: key);
  }
}
