import 'dart:async';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'note.dart';

// Para desktop (Windows/macOS/Linux), descomente:
// import 'package:sqflite_common_ffi/sqflite_common_ffi.dart';

class LocalDb {
  static final LocalDb _instance = LocalDb._internal();
  factory LocalDb() => _instance;
  LocalDb._internal();

  Database? _db;

  Future<void> init() async {
    // Para desktop, descomente:
    // sqfliteFfiInit();
    // databaseFactory = databaseFactoryFfi;

    final dbPath = await getDatabasesPath();
    _db = await openDatabase(
      p.join(dbPath, 'notes.db'),
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE notes(
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            created_at TEXT NOT NULL
          );
        ''');
      },
    );
  }

  Future<int> insertNote(Note note) async {
    final db = _db!;
    return db.insert(
      'notes',
      note.toSqlMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Note>> getAll() async {
    final db = _db!;
    final rows = await db.query('notes', orderBy: 'created_at DESC');
    return rows.map((r) => Note.fromSqlMap(r)).toList();
  }

  Future<void> clear() async {
    final db = _db!;
    await db.delete('notes');
  }
}