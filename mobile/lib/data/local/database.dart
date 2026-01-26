/// SQLite database manager for AquaBill mobile app.
///
/// Stores local cache of last 12 cycles, assignments, readings, and sync queue.
/// Supports server-wins merge strategy on sync.

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class AppDatabase {
  static const String dbName = 'aquabill.db';
  static const int dbVersion = 1;

  static final AppDatabase _instance = AppDatabase._internal();

  factory AppDatabase() {
    return _instance;
  }

  AppDatabase._internal();

  Database? _database;

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, dbName);

    return await openDatabase(
      path,
      version: dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Create all tables
    await _createClients(db);
    await _createMeters(db);
    await _createMeterAssignments(db);
    await _createCycles(db);
    await _createReadings(db);
    await _createConflicts(db);
    await _createSyncQueue(db);
    await _createMetadata(db);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle migrations here in future versions
    // For now, just recreate on upgrade (dev only)
    await _dropAllTables(db);
    await _onCreate(db, newVersion);
  }

  Future<void> _createClients(Database db) async {
    await db.execute('''
      CREATE TABLE clients (
        id INTEGER PRIMARY KEY,
        client_code TEXT UNIQUE,
        first_name TEXT NOT NULL,
        other_names TEXT,
        surname TEXT NOT NULL,
        phone_number TEXT NOT NULL UNIQUE,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createMeters(Database db) async {
    await db.execute('''
      CREATE TABLE meters (
        id INTEGER PRIMARY KEY,
        serial_number TEXT NOT NULL UNIQUE,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _createMeterAssignments(Database db) async {
    await db.execute('''
      CREATE TABLE meter_assignments (
        id INTEGER PRIMARY KEY,
        meter_id INTEGER NOT NULL,
        client_id INTEGER NOT NULL,
        status TEXT NOT NULL DEFAULT 'ACTIVE',
        start_date TEXT NOT NULL,
        end_date TEXT,
        max_meter_value REAL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(meter_id) REFERENCES meters(id),
        FOREIGN KEY(client_id) REFERENCES clients(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_meter_assignments_meter_client ON meter_assignments(meter_id, client_id)',
    );
  }

  Future<void> _createCycles(Database db) async {
    await db.execute('''
      CREATE TABLE cycles (
        id INTEGER PRIMARY KEY,
        name TEXT,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        target_date TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'OPEN',
        updated_at TEXT NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_cycles_status ON cycles(status)');
    await db
        .execute('CREATE INDEX idx_cycles_target_date ON cycles(target_date)');
  }

  Future<void> _createReadings(Database db) async {
    await db.execute('''
      CREATE TABLE readings (
        id INTEGER PRIMARY KEY,
        meter_assignment_id INTEGER NOT NULL,
        cycle_id INTEGER NOT NULL,
        absolute_value REAL NOT NULL,
        submitted_at TEXT NOT NULL,
        submitted_by TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'LOCAL_ONLY',
        source TEXT NOT NULL DEFAULT 'LOCAL_CAPTURE',
        previous_approved_reading REAL,
        notes TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(meter_assignment_id) REFERENCES meter_assignments(id),
        FOREIGN KEY(cycle_id) REFERENCES cycles(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_readings_assignment_cycle ON readings(meter_assignment_id, cycle_id)',
    );
    await db.execute('CREATE INDEX idx_readings_status ON readings(status)');
  }

  Future<void> _createConflicts(Database db) async {
    await db.execute('''
      CREATE TABLE conflicts (
        id INTEGER PRIMARY KEY,
        meter_assignment_id INTEGER NOT NULL,
        cycle_id INTEGER NOT NULL,
        local_value REAL NOT NULL,
        server_value REAL NOT NULL,
        resolved INTEGER NOT NULL DEFAULT 0,
        resolved_at TEXT,
        resolution_note TEXT,
        updated_at TEXT NOT NULL,
        FOREIGN KEY(meter_assignment_id) REFERENCES meter_assignments(id),
        FOREIGN KEY(cycle_id) REFERENCES cycles(id)
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_conflicts_assignment_cycle ON conflicts(meter_assignment_id, cycle_id)',
    );
  }

  Future<void> _createSyncQueue(Database db) async {
    await db.execute('''
      CREATE TABLE sync_queue (
        id INTEGER PRIMARY KEY,
        entity_type TEXT NOT NULL,
        entity_id INTEGER NOT NULL,
        payload TEXT NOT NULL,
        operation TEXT NOT NULL DEFAULT 'CREATE',
        attempt_count INTEGER NOT NULL DEFAULT 0,
        last_attempt_at TEXT,
        created_at TEXT NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_sync_queue_created ON sync_queue(created_at)');
  }

  Future<void> _createMetadata(Database db) async {
    await db.execute('''
      CREATE TABLE metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
  }

  Future<void> _dropAllTables(Database db) async {
    await db.execute('DROP TABLE IF EXISTS metadata');
    await db.execute('DROP TABLE IF EXISTS sync_queue');
    await db.execute('DROP TABLE IF EXISTS conflicts');
    await db.execute('DROP TABLE IF EXISTS readings');
    await db.execute('DROP TABLE IF EXISTS cycles');
    await db.execute('DROP TABLE IF EXISTS meter_assignments');
    await db.execute('DROP TABLE IF EXISTS meters');
    await db.execute('DROP TABLE IF EXISTS clients');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  // Utility methods for common operations
  Future<int> deleteAll(String table) async {
    final db = await database;
    return db.delete(table);
  }

  Future<void> clearCache() async {
    // Delete all local cache (but keep sync_queue)
    final db = await database;
    await db.delete('readings');
    await db.delete('cycles');
    await db.delete('meter_assignments');
    await db.delete('meters');
    await db.delete('clients');
    await db.delete('conflicts');
  }

  Future<void> setMetadata(String key, String value) async {
    final db = await database;
    await db.insert(
      'metadata',
      {
        'key': key,
        'value': value,
        'updated_at': DateTime.now().toIso8601String(),
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<String?> getMetadata(String key) async {
    final db = await database;
    final result = await db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );
    return result.isNotEmpty ? result.first['value'] as String? : null;
  }
}
