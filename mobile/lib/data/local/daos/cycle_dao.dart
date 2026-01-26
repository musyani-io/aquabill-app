import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../database.dart';
import 'base_dao.dart';

class CycleDao extends BaseDao {
  static const String table = 'cycles';

  Future<void> upsertAll(List<CycleModel> cycles) async {
    if (cycles.isEmpty) return;
    final database = await db;
    final batch = database.batch();
    for (final cycle in cycles) {
      batch.insert(
        table,
        cycle.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<CycleModel>> getRecent({int limit = 12}) async {
    final database = await db;
    final rows = await database.query(
      table,
      orderBy: 'target_date DESC',
      limit: limit,
    );
    return rows.map(CycleModel.fromLocalMap).toList();
  }

  Future<void> deleteOlderThan(DateTime cutoff) async {
    final database = await db;
    await database.delete(
      table,
      where: 'target_date < ?',
      whereArgs: [cutoff.toIso8601String()],
    );
  }

  Future<void> clear() async {
    await AppDatabase().deleteAll(table);
  }
}
