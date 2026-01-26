import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../database.dart';
import 'base_dao.dart';

class ReadingDao extends BaseDao {
  static const String table = 'readings';

  Future<void> upsertAll(List<ReadingModel> readings) async {
    if (readings.isEmpty) return;
    final database = await db;
    final batch = database.batch();
    for (final reading in readings) {
      batch.insert(
        table,
        reading.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<int> upsert(ReadingModel reading) async {
    final database = await db;
    return database.insert(
      table,
      reading.toLocalMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<ReadingModel>> getByAssignmentAndCycle(
      int assignmentId, int cycleId) async {
    final database = await db;
    final rows = await database.query(
      table,
      where: 'meter_assignment_id = ? AND cycle_id = ?',
      whereArgs: [assignmentId, cycleId],
      orderBy: 'submitted_at DESC',
    );
    return rows.map(ReadingModel.fromLocalMap).toList();
  }

  Future<List<ReadingModel>> getLocalOnly({int limit = 50}) async {
    final database = await db;
    final rows = await database.query(
      table,
      where: 'status = ?',
      whereArgs: ['LOCAL_ONLY'],
      orderBy: 'submitted_at ASC',
      limit: limit,
    );
    return rows.map(ReadingModel.fromLocalMap).toList();
  }

  Future<void> updateStatus(int id, String status) async {
    final database = await db;
    await database.update(
      table,
      {'status': status, 'updated_at': DateTime.now().toIso8601String()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clear() async {
    await AppDatabase().deleteAll(table);
  }
}
