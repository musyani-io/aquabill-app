import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../database.dart';
import 'base_dao.dart';

class MeterAssignmentDao extends BaseDao {
  static const String table = 'meter_assignments';

  Future<void> upsertAll(List<MeterAssignmentModel> assignments) async {
    if (assignments.isEmpty) return;
    final database = await db;
    final batch = database.batch();
    for (final assignment in assignments) {
      batch.insert(
        table,
        assignment.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<MeterAssignmentModel?> getById(int id) async {
    final database = await db;
    final rows = await database.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeterAssignmentModel.fromLocalMap(rows.first);
  }

  Future<List<MeterAssignmentModel>> getActiveByMeter(int meterId) async {
    final database = await db;
    final rows = await database.query(
      table,
      where: 'meter_id = ? AND status = ?',
      whereArgs: [meterId, 'ACTIVE'],
      orderBy: 'start_date DESC',
    );
    return rows.map(MeterAssignmentModel.fromLocalMap).toList();
  }

  Future<List<MeterAssignmentModel>> getByClient(int clientId) async {
    final database = await db;
    final rows = await database.query(
      table,
      where: 'client_id = ?',
      whereArgs: [clientId],
      orderBy: 'start_date DESC',
    );
    return rows.map(MeterAssignmentModel.fromLocalMap).toList();
  }

  Future<void> clear() async {
    await AppDatabase().deleteAll(table);
  }
}
