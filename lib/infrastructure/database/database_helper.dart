import 'dart:async';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = DatabaseHelper._internal();
  static Database? _database;

  factory DatabaseHelper() => _instance;

  DatabaseHelper._internal();

  static DatabaseHelper get instance => _instance;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'biblioteca_virtual.db');

    return await openDatabase(
      path,
      version: 5,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    // Tabla de Usuarios
    await db.execute('''
      CREATE TABLE users (
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        email TEXT UNIQUE NOT NULL,
        password TEXT NOT NULL,
        salt TEXT NOT NULL,  
        bio TEXT,
        is_admin INTEGER DEFAULT 0
      )
    ''');

    // Tabla de Libros
    await db.execute('''
      CREATE TABLE books (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        author_id TEXT NOT NULL,
        description TEXT,
        genre TEXT NOT NULL,
        additional_genres TEXT,
        upload_date TEXT NOT NULL,
        publication_date TEXT,
        views INTEGER DEFAULT 0,
        rating REAL DEFAULT 0,
        ratings_count INTEGER DEFAULT 0,
        reports INTEGER DEFAULT 0,
        content TEXT,
        is_trashed INTEGER DEFAULT 0,
        has_chapters INTEGER DEFAULT 0,
        FOREIGN KEY (author_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE chapters(
        id TEXT PRIMARY KEY,
        book_id TEXT NOT NULL,
        title TEXT,
        content TEXT,
        upload_date TEXT NOT NULL,
        publication_date TEXT,
        chapter_number INTEGER,  -- Para guardar el orden, opcional
        views INTEGER DEFAULT 0,
        rating REAL DEFAULT 0,
        ratings_count INTEGER DEFAULT 0,
        reports INTEGER DEFAULT 0,
        FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
      )
    ''');

    // Tabla de Calificaciones de Libros
    await db.execute('''
    CREATE TABLE book_ratings (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      book_id TEXT NOT NULL,
      rating INTEGER NOT NULL CHECK (rating BETWEEN 1 AND 5),
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
      FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
    )
    ''');

    // Tabla de Comentarios
    await db.execute('''
    CREATE TABLE comments (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      book_id TEXT NOT NULL,
      content TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      parent_comment_id TEXT NULL,
      root_comment_id TEXT NULL,
      reports INTEGER DEFAULT 0,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
      FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE,
      FOREIGN KEY (parent_comment_id) REFERENCES comments (id) ON DELETE CASCADE
    )
    ''');

    // Tabla de Reportes
    await db.execute('''
    CREATE TABLE reports (
      id TEXT PRIMARY KEY,
      reporter_id TEXT NOT NULL,
      target_id TEXT NOT NULL,
      target_type TEXT CHECK (target_type IN ('book', 'comment')) NOT NULL,
      reason TEXT NOT NULL,
      status TEXT DEFAULT 'pending' CHECK (status IN ('pending', 'reviewed', 'dismissed')),
      admin_id TEXT NULL,
      FOREIGN KEY (reporter_id) REFERENCES users (id) ON DELETE CASCADE,
      FOREIGN KEY (admin_id) REFERENCES users (id) ON DELETE SET NULL
    )
    ''');

    // Tabla de Favoritos
    await db.execute('''
    CREATE TABLE favorites (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      book_id TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE,
      FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
    )
    ''');

    // Tabla de Listas de Lectura
    await db.execute('''
    CREATE TABLE reading_lists (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      name TEXT NOT NULL,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
    )
    ''');

    // Relación entre Listas de Lectura y Libros
    await db.execute('''
    CREATE TABLE reading_list_books (
      id TEXT PRIMARY KEY,
      list_id TEXT NOT NULL,
      book_id TEXT NOT NULL,
      FOREIGN KEY (list_id) REFERENCES reading_lists (id) ON DELETE CASCADE,
      FOREIGN KEY (book_id) REFERENCES books (id) ON DELETE CASCADE
    )
    ''');

    // Tabla de Notificaciones
    await db.execute('''
    CREATE TABLE notifications (
      id TEXT PRIMARY KEY,
      user_id TEXT NOT NULL,
      type TEXT NOT NULL CHECK (type IN ('new_comment', 'new_rating', 'report_decision')),
      message TEXT NOT NULL,
      timestamp TEXT NOT NULL,
      is_read INTEGER DEFAULT 0,
      FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
    )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE books ADD COLUMN publication_date TEXT');
    }
    if (oldVersion < 3) {
      await db.execute('ALTER TABLE comments ADD COLUMN root_comment_id TEXT');
    }
    if (oldVersion < 4) {
      await db
          .execute('ALTER TABLE books ADD COLUMN is_trashed INTEGER DEFAULT 0');
    }
    if (oldVersion < 5) {
      await db.execute(
          'ALTER TABLE books ADD COLUMN has_chapters INTEGER DEFAULT 0');
    }
  }
}
