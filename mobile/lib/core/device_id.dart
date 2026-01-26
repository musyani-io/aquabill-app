import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import 'token_storage.dart';

/// Device ID helper to generate and persist unique device identifier.
class DeviceIdHelper {
  static final DeviceIdHelper _instance = DeviceIdHelper._internal();
  factory DeviceIdHelper() => _instance;
  DeviceIdHelper._internal();

  final DeviceInfoPlugin _deviceInfo = DeviceInfoPlugin();
  static const String _deviceIdKey = 'device_id';

  Future<String> getDeviceId() async {
    // Try to get stored device ID first
    final storage = TokenStorage();
    final stored = await storage.getCustom(_deviceIdKey);
    if (stored != null && stored.isNotEmpty) {
      return stored;
    }

    // Generate new device ID based on platform
    String deviceId;
    try {
      if (Platform.isAndroid) {
        final androidInfo = await _deviceInfo.androidInfo;
        deviceId = 'android_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await _deviceInfo.iosInfo;
        deviceId = 'ios_${iosInfo.identifierForVendor ?? 'unknown'}';
      } else if (Platform.isLinux) {
        final linuxInfo = await _deviceInfo.linuxInfo;
        deviceId = 'linux_${linuxInfo.machineId ?? 'unknown'}';
      } else {
        deviceId = 'unknown_${DateTime.now().millisecondsSinceEpoch}';
      }
    } catch (_) {
      deviceId = 'fallback_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Store for future use
    await storage.saveCustom(_deviceIdKey, deviceId);
    return deviceId;
  }
}
