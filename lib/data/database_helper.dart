import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../utils/constants.dart';

class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();

  static const _dbName = 'spendwise.db';
  static const _dbVersion = 2;

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDb();
    return _database!;
  }

  Future<Database> _initDb() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE categories (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL UNIQUE,
        iconKey TEXT NOT NULL,
        colorValue INTEGER NOT NULL,
        isDefault INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE expenses (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        categoryId TEXT NOT NULL,
        date TEXT NOT NULL,
        note TEXT,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id)
      )
    ''');

    await _createRecurringTable(db);

    await db.execute(
      'CREATE INDEX idx_expenses_date ON expenses(date)',
    );
    await db.execute(
      'CREATE INDEX idx_expenses_category ON expenses(categoryId)',
    );

    final batch = db.batch();
    for (final cat in AppConstants.defaultCategories) {
      batch.insert('categories', cat.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createRecurringTable(db);
    }
  }

  Future<void> _createRecurringTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS recurring_expenses (
        id TEXT PRIMARY KEY,
        amount REAL NOT NULL,
        categoryId TEXT NOT NULL,
        note TEXT,
        frequency TEXT NOT NULL,
        startDate TEXT NOT NULL,
        nextRun TEXT NOT NULL,
        isActive INTEGER NOT NULL DEFAULT 1,
        createdAt TEXT NOT NULL,
        updatedAt TEXT NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories (id)
      )
    ''');
  }

  Future<void> clearAllData() async {
    final db = await database;
    await db.delete('expenses');
    await db.delete('recurring_expenses');
    await db.delete('categories');
    final batch = db.batch();
    for (final cat in AppConstants.defaultCategories) {
      batch.insert('categories', cat.toMap());
    }
    await batch.commit(noResult: true);
  }

  Future<void> initForTest(Database db) async {
    _database = db;
  }

  Future<void> close() async {
    final db = _database;
    _database = null;
    await db?.close();
  }
}
