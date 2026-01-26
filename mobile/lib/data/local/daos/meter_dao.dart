import 'package:sqflite/sqflite.dart';

import '../../models/models.dart';
import '../database.dart';
import 'base_dao.dart';

class MeterDao extends BaseDao {
  static const String table = 'meters';

  Future<void> upsertAll(List<MeterModel> meters) async {
    if (meters.isEmpty) return;
    final database = await db;
    final batch = database.batch();
    for (final meter in meters) {
      batch.insert(
        table,
        meter.toLocalMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    await batch.commit(noResult: true);
  }

  Future<MeterModel?> getById(int id) async {
    final database = await db;
    final rows = await database.query(
      table,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeterModel.fromLocalMap(rows.first);
  }

  Future<MeterModel?> getBySerial(String serial) async {
    final database = await db;
    final rows = await database.query(
      table,
      where: 'serial_number = ?',
      whereArgs: [serial],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return MeterModel.fromLocalMap(rows.first);
  }

  Future<void> clear() async {
    await AppDatabase().deleteAll(table);
  }
}
