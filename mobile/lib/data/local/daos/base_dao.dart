import 'package:sqflite/sqflite.dart';

import '../database.dart';

/// Base DAO providing a database getter.
abstract class BaseDao {
  Future<Database> get db => AppDatabase().database;
}
