import 'dart:convert';

import '../../core/error_handler.dart';
import '../../data/local/daos/client_dao.dart';
import '../../data/local/daos/conflict_dao.dart';
import '../../data/local/daos/cycle_dao.dart';
import '../../data/local/daos/meter_assignment_dao.dart';
import '../../data/local/daos/meter_dao.dart';
import '../../data/local/daos/reading_dao.dart';
import '../../data/local/daos/sync_queue_dao.dart';
import '../../data/local/database.dart';
import '../../data/models/models.dart';
import '../../data/remote/dtos.dart';
import '../../data/remote/mobile_api_client.dart';

/// SyncEngine orchestrates upload (sync_queue) and download (updates/bootstrap)
/// with a server-wins merge policy.
class SyncEngine {
  SyncEngine({
    required this.apiClient,
    required this.clientDao,
    required this.meterDao,
    required this.assignmentDao,
    required this.cycleDao,
    required this.readingDao,
    required this.conflictDao,
    required this.syncQueueDao,
  });

  final MobileApiClient apiClient;
  final ClientDao clientDao;
  final MeterDao meterDao;
  final MeterAssignmentDao assignmentDao;
  final CycleDao cycleDao;
  final ReadingDao readingDao;
  final ConflictDao conflictDao;
  final SyncQueueDao syncQueueDao;
  final AppDatabase _db = AppDatabase();

  /// Full bootstrap when no prior sync exists.
  Future<DateTime> bootstrap() async {
    final payload = await apiClient.fetchBootstrap();

    await _db.clearCache();
    await _applyBootstrap(payload);
    await _trimOldCycles(12);
    await _db.setMetadata('last_sync', payload.lastSync.toIso8601String());
    return payload.lastSync;
  }

  /// Incremental download since last sync timestamp.
  /// If no last_sync is stored, falls back to bootstrap.
  Future<DateTime> syncDown({DateTime? since}) async {
    final existing = since ?? await _getLastSync();
    if (existing == null) {
      return bootstrap();
    }

    final updates = await apiClient.fetchUpdates(existing);
    await _applyUpdates(updates);
    await _trimOldCycles(12);
    await _db.setMetadata('last_sync', updates.lastSync.toIso8601String());
    return updates.lastSync;
  }

  /// Upload local queued items (readings). Stops on network/validation errors.
  Future<void> syncUp() async {
    while (true) {
      final next = await syncQueueDao.dequeueNext();
      if (next == null) break;

      try {
        if (next.entityType == 'READING') {
          await _uploadReading(next);
        } else {
          // Unknown entity types are discarded to prevent blocking the queue
          await syncQueueDao.deleteById(next.id!);
        }
      } on NetworkException {
        // Stop on network issues; will retry later
        await syncQueueDao.incrementAttempt(next.id!);
        rethrow;
      } on ConflictException {
        // Conflict surfaced; leave item for UI to handle
        await syncQueueDao.incrementAttempt(next.id!);
        rethrow;
      } catch (_) {
        // Unexpected error: increment attempts and continue to next
        await syncQueueDao.incrementAttempt(next.id!);
        rethrow;
      }
    }
  }

  /// Convenience: upload then download.
  Future<DateTime?> syncAll({bool uploadFirst = true}) async {
    DateTime? lastSync;
    if (uploadFirst) {
      try {
        await syncUp();
      } on AppException {
        // Upload failures are surfaced to caller; stop chain
        rethrow;
      }
    }
    lastSync = await syncDown();
    return lastSync;
  }

  // ---------- Internals ----------

  Future<void> _applyBootstrap(BootstrapPayload payload) async {
    await clientDao.upsertAll(payload.clients);
    await meterDao.upsertAll(payload.meters);
    await assignmentDao.upsertAll(payload.assignments);
    await cycleDao.upsertAll(payload.cycles);
    await readingDao.upsertAll(payload.readings);
  }

  Future<void> _applyUpdates(UpdatesPayload payload) async {
    await clientDao.upsertAll(payload.clients);
    await meterDao.upsertAll(payload.meters);
    await assignmentDao.upsertAll(payload.assignments);
    await cycleDao.upsertAll(payload.cycles);
    await readingDao.upsertAll(payload.readings);

    for (final tombstone in payload.tombstones) {
      await _applyTombstone(tombstone);
    }
  }

  /// Keep only the most recent [keepCount] cycles and related readings/conflicts.
  Future<void> _trimOldCycles(int keepCount) async {
    final db = await _db.database;

    final rows = await db.rawQuery(
      'SELECT id FROM cycles ORDER BY target_date DESC LIMIT ?',
      [keepCount],
    );
    final keepIds = rows.map((row) => row['id'] as int).toList();
    if (keepIds.isEmpty) return;

    final placeholders = List.filled(keepIds.length, '?').join(',');

    // Delete readings and conflicts tied to older cycles
    await db.delete(
      'readings',
      where: 'cycle_id NOT IN ($placeholders)',
      whereArgs: keepIds,
    );
    await db.delete(
      'conflicts',
      where: 'cycle_id NOT IN ($placeholders)',
      whereArgs: keepIds,
    );

    // Delete old cycles themselves
    await db.delete(
      'cycles',
      where: 'id NOT IN ($placeholders)',
      whereArgs: keepIds,
    );
  }

  Future<void> _applyTombstone(TombstoneModel tombstone) async {
    final db = await _db.database;
    final ts = tombstone.timestamp.toIso8601String();

    switch (tombstone.entityType) {
      case 'cycle':
        await db.update(
          'cycles',
          {'status': tombstone.action, 'updated_at': ts},
          where: 'id = ?',
          whereArgs: [tombstone.entityId],
        );
        break;
      case 'assignment':
      case 'meter_assignment':
        await db.update(
          'meter_assignments',
          {'status': 'INACTIVE', 'updated_at': ts},
          where: 'id = ?',
          whereArgs: [tombstone.entityId],
        );
        break;
      default:
        // Ignore unknown tombstones
        break;
    }
  }

  Future<void> _uploadReading(SyncQueueItemModel item) async {
    final Map<String, dynamic> payload = jsonDecode(item.payload);

    final result = await apiClient.submitReading(
      meterAssignmentId: payload['meter_assignment_id'] as int,
      cycleId: payload['cycle_id'] as int,
      absoluteValue: _asDouble(payload['absolute_value']),
      submittedBy: payload['submitted_by'] as String,
      submittedAt: DateTime.parse(payload['submitted_at'] as String),
      clientTz: payload['client_tz'] as String?,
      source: payload['source'] as String?,
      previousApprovedReading:
          _asDoubleNullable(payload['previous_approved_reading']),
      deviceId: payload['device_id'] as String?,
      appVersion: payload['app_version'] as String?,
      conflictId: payload['conflict_id'] as int?,
      submissionNotes: payload['submission_notes'] as String?,
    );

    // Mark reading as submitted locally if we have an ID
    final readingId = payload['id'] as int?;
    if (readingId != null) {
      await readingDao.updateStatus(readingId, 'SUBMITTED');
    }

    await syncQueueDao.deleteById(item.id!);

    // Optional: handle server response status/message if needed
    if (result.status == 'CONFLICT') {
      // Keep for conflict UI by throwing
      throw ConflictException(message: 'Conflict returned from server');
    }
  }

  Future<DateTime?> _getLastSync() async {
    final value = await _db.getMetadata('last_sync');
    if (value == null) return null;
    return DateTime.parse(value);
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.parse(value.toString());
  }

  double? _asDoubleNullable(dynamic value) {
    if (value == null) return null;
    return _asDouble(value);
  }
}
