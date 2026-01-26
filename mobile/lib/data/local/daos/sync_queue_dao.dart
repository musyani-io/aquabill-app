import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../database.dart';
import 'base_dao.dart';

class SyncQueueDao extends BaseDao {
  static const String table = 'sync_queue';

  Future<int> enqueue(SyncQueueItemModel item) async {
    final database = await db;
    final map = item.toLocalMap();
    map.remove('id');
    return database.insert(table, map);
  }

  Future<SyncQueueItemModel?> dequeueNext() async {
    final database = await db;
    final rows = await database.query(
      table,
      orderBy: 'attempt_count ASC, created_at ASC',
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return SyncQueueItemModel.fromLocalMap(rows.first);
  }

  Future<void> incrementAttempt(int id) async {
    final database = await db;
    await database.rawUpdate(
      'UPDATE $table SET attempt_count = attempt_count + 1, last_attempt_at = ? WHERE id = ?',
      [DateTime.now().toIso8601String(), id],
    );
  }

  Future<void> deleteById(int id) async {
    final database = await db;
    await database.delete(
      table,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> pendingCount() async {
    final database = await db;
    final result = Sqflite.firstIntValue(
      await database.rawQuery('SELECT COUNT(*) FROM $table'),
    );
    return result ?? 0;
  }

  Future<void> clear() async {
    await AppDatabase().deleteAll(table);
  }
}
