import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../database.dart';
import 'base_dao.dart';

class ConflictDao extends BaseDao {
  static const String table = 'conflicts';

  Future<void> upsertAll(List<ConflictModel> conflicts) async {
    if (conflicts.isEmpty) return;
    final database = await db;
    final batch = database.batch();
    for (final conflict in conflicts) {
      batch.insert(
        table,
        conflict.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<List<ConflictModel>> listUnresolved({int limit = 50}) async {
    final database = await db;
    final rows = await database.query(
      table,
      where: 'resolved = 0',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(ConflictModel.fromLocalMap).toList();
  }

  Future<void> resolve(
    int id, {
    required double serverValue,
    String? resolutionNote,
  }) async {
    final database = await db;
    await database.update(
      table,
      {
        'resolved': 1,
        'server_value': serverValue,
        'resolved_at': DateTime.now().toIso8601String(),
        'resolution_note': resolutionNote,
        'updated_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> clear() async {
    await AppDatabase().deleteAll(table);
  }
}
