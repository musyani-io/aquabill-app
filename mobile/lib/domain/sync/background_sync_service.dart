import 'dart:io' show Platform;

import 'package:workmanager/workmanager.dart';

import '../../core/connectivity.dart';
import '../../core/error_handler.dart';
import '../../core/token_storage.dart';
import '../../data/local/daos/client_dao.dart';
import '../../data/local/daos/conflict_dao.dart';
import '../../data/local/daos/cycle_dao.dart';
import '../../data/local/daos/meter_assignment_dao.dart';
import '../../data/local/daos/meter_dao.dart';
import '../../data/local/daos/reading_dao.dart';
import '../../data/local/daos/sync_queue_dao.dart';
import '../../data/remote/mobile_api_client.dart';
import 'sync_engine.dart';

/// Background sync task name
const String syncTaskName = 'aquabill_background_sync';

/// Background sync dispatcher - called by workmanager
@pragma('vm:entry-point')
void backgroundSyncDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      // Check connectivity first
      final isOnline = await ConnectivityService().isOnline();
      if (!isOnline) {
        return Future.value(true); // Success but skip sync
      }

      // Get token
      final token = await TokenStorage().getToken();
      if (token == null || token.isEmpty) {
        return Future.value(true); // No token, skip sync
      }

      // Check if there's anything to sync
      final pendingCount = await SyncQueueDao().pendingCount();
      if (pendingCount == 0) {
        return Future.value(true); // Nothing to sync
      }

      // Create API client and sync engine
      final apiClient = MobileApiClient(
        baseUrl: 'http://localhost:8000', // TODO: Use configurable base URL
        tokenProvider: () async => token,
      );

      final engine = SyncEngine(
        apiClient: apiClient,
        clientDao: ClientDao(),
        meterDao: MeterDao(),
        assignmentDao: MeterAssignmentDao(),
        cycleDao: CycleDao(),
        readingDao: ReadingDao(),
        conflictDao: ConflictDao(),
        syncQueueDao: SyncQueueDao(),
      );

      // Run sync
      await engine.syncAll(uploadFirst: true);

      return Future.value(true);
    } on NetworkException catch (_) {
      // Network issues - will retry next time
      return Future.value(false);
    } on ConflictException catch (_) {
      // Conflicts detected - mark as success (user needs to resolve in UI)
      return Future.value(true);
    } catch (_) {
      // Unknown error - mark as failure to retry
      return Future.value(false);
    }
  });
}

/// Background sync service
class BackgroundSyncService {
  static final BackgroundSyncService _instance =
      BackgroundSyncService._internal();
  factory BackgroundSyncService() => _instance;
  BackgroundSyncService._internal();

  /// Initialize background sync
  Future<void> initialize() async {
    // Workmanager is only supported on Android and iOS
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    await Workmanager().initialize(
      backgroundSyncDispatcher,
      isInDebugMode: false,
    );
  }

  /// Schedule periodic background sync (every 30 minutes)
  Future<void> schedulePeriodicSync() async {
    // Workmanager is only supported on Android and iOS
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    await Workmanager().registerPeriodicTask(
      syncTaskName,
      syncTaskName,
      frequency: const Duration(minutes: 30),
      constraints: Constraints(networkType: NetworkType.connected),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
  }

  Future<void> cancelSync() async {
    // Workmanager is only supported on Android and iOS
    if (!Platform.isAndroid && !Platform.isIOS) {
      return;
    }
    await Workmanager().cancelByUniqueName(syncTaskName);
  }

  /// Check if background sync is enabled
  Future<bool> isEnabled() async {
    final storage = TokenStorage();
    final value = await storage.getCustom('background_sync_enabled');
    return value == 'true';
  }

  /// Enable background sync
  Future<void> enable() async {
    await schedulePeriodicSync();
    final storage = TokenStorage();
    await storage.saveCustom('background_sync_enabled', 'true');
  }

  /// Disable background sync
  Future<void> disable() async {
    await cancelSync();
    final storage = TokenStorage();
    await storage.saveCustom('background_sync_enabled', 'false');
  }
}
