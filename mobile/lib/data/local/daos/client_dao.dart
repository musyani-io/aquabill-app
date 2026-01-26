import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../database.dart';
import 'base_dao.dart';

class ClientDao extends BaseDao {
  static const String table = 'clients';

  Future<void> upsertAll(List<ClientModel> clients) async {
    if (clients.isEmpty) return;
    final database = await db;
    final batch = database.batch();
    for (final client in clients) {
      batch.insert(
        table,
        client.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<ClientModel?> getById(int id) async {
    final database = await db;
    final rows = await database.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return ClientModel.fromLocalMap(rows.first);
  }

  Future<List<ClientModel>> searchByNameOrPhone(String term,
      {int limit = 20}) async {
    final database = await db;
    final like = '%${term.toLowerCase()}%';
    final rows = await database.query(
      table,
      where:
          'LOWER(first_name || " " || COALESCE(other_names, "") || " " || surname) LIKE ? OR phone_number LIKE ?',
      whereArgs: [like, '%$term%'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return rows.map(ClientModel.fromLocalMap).toList();
  }

  Future<int> count() async {
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
