import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('sudoku.db');
    return _database!;
  }

  Future<Database> _initDB(String path) async {
    final dbPath = await getDatabasesPath();
    final dbLocation = join(dbPath, path);
    return await openDatabase(
      dbLocation,
      version: 2,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future _onCreate(Database db, int version) async {
    const sql = '''
  CREATE TABLE sudoku(
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    name VARCHAR NOT NULL,
    result INTEGER,
    date VARCHAR NOT NULL,
    level INTEGER,
    board TEXT, 
    completed INTEGER 
  );
  ''';
    await db.execute(sql);
  }

  Future _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE sudoku ADD COLUMN board TEXT;');
      await db.execute(
          'ALTER TABLE sudoku ADD COLUMN completed INTEGER DEFAULT 0;');
    }
  }

  Future<void> insertGame(Map<String, dynamic> gameData) async {
    final db = await instance.database;
    await db.insert('sudoku', gameData,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> getGamesByLevel(int level) async {
    final db = await instance.database;
    final result =
        await db.query('sudoku', where: 'level = ?', whereArgs: [level]);
    return result;
  }

  Future<List<Map<String, dynamic>>> getGamesGroupedByPlayer(int level) async {
    final db = await instance.database;

    final result = await db.rawQuery('''
    SELECT 
      name, 
      COUNT(CASE WHEN result = 1 THEN 1 ELSE NULL END) AS victories,
      COUNT(CASE WHEN result = 0 THEN 1 ELSE NULL END) AS defeats
    FROM sudoku
    WHERE level = ?
    GROUP BY name
    ORDER BY name
  ''', [level]);

    return result;
  }

  Future<List<Map<String, dynamic>>> getPlayerGames(
      String playerName, int level) async {
    final db = await instance.database;

    final result = await db.query(
      'sudoku',
      where: 'name = ? AND level = ?',
      whereArgs: [playerName, level],
      orderBy: 'date DESC',
    );

    return result;
  }
}
