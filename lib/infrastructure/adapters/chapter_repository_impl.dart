import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/book/chapter.dart';
import '../../domain/ports/book/chapter_repository.dart';
import '../database/database_helper.dart';

class ChapterRepositoryImpl implements ChapterRepository {
  Future<Database> get _database async =>
      await DatabaseHelper.instance.database;

  @override
  Future<void> addChapter(Chapter chapter) async {
    final db = await _database;
    await db.insert(
      'chapters',
      chapter.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  @override
  Future<void> updateChapter(Chapter chapter) async {
    final db = await _database;
    await db.update(
      'chapters',
      chapter.toMap(),
      where: 'id = ?',
      whereArgs: [chapter.id],
    );
  }

  @override
  Future<void> deleteChapter(String chapterId) async {
    final db = await _database;
    await db.delete(
      'chapters',
      where: 'id = ?',
      whereArgs: [chapterId],
    );
  }

  @override
  Future<List<Chapter>> fetchChaptersByBook(String bookId) async {
    final db = await _database;
    final List<Map<String, dynamic>> maps = await db.query(
      'chapters',
      where: 'book_id = ?',
      whereArgs: [bookId],
      orderBy: 'chapter_number ASC',
    );
    return maps.map((map) => Chapter.fromMap(map)).toList();
  }

  // Implementaciones de los métodos nuevos:

  @override
  Future<void> updateChapterViews(String chapterId) async {
    final db = await _database;
    await db.rawUpdate(
      'UPDATE chapters SET views = views + 1 WHERE id = ?',
      [chapterId],
    );
  }

  @override
  Future<void> rateChapter(
      String chapterId, String userId, double rating) async {
    final db = await _database;
    // Suponiendo que existe una tabla 'chapter_ratings' similar a 'book_ratings'
    await db.insert(
      'chapter_ratings',
      {
        'id': '$userId-$chapterId',
        'user_id': userId,
        'chapter_id': chapterId,
        'rating': rating,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final List<Map<String, dynamic>> ratings = await db.query(
      'chapter_ratings',
      columns: ['rating'],
      where: 'chapter_id = ?',
      whereArgs: [chapterId],
    );

    if (ratings.isNotEmpty) {
      double avgRating = ratings.fold<double>(
              0, (sum, item) => sum + (item['rating'] as num).toDouble()) /
          ratings.length;
      await db.update(
        'chapters',
        {'rating': avgRating},
        where: 'id = ?',
        whereArgs: [chapterId],
      );
    }
  }

  @override
  Future<void> updateChapterContent(
      String chapterId, Map<String, dynamic> content) async {
    final db = await _database;
    await db.update(
      'chapters',
      {'content': jsonEncode(content)},
      where: 'id = ?',
      whereArgs: [chapterId],
    );
  }

  @override
  Future<void> updateChapterPublicationDate(
      String chapterId, String? publicationDate) async {
    final db = await _database;
    await db.update(
      'chapters',
      {'publication_date': publicationDate},
      where: 'id = ?',
      whereArgs: [chapterId],
    );
  }

  @override
  Future<void> updateChapterDetails(String chapterId,
      {String? title, String? description}) async {
    final db = await _database;
    final Map<String, dynamic> values = {};
    if (title != null) values['title'] = title;
    if (description != null) values['description'] = description;
    if (values.isNotEmpty) {
      await db.update(
        'chapters',
        values,
        where: 'id = ?',
        whereArgs: [chapterId],
      );
    }
  }

  @override
  Future<List<Chapter>> searchChapters(String query) async {
    final db = await _database;
    final List<Map<String, dynamic>> result = await db.query(
      'chapters',
      where: 'title LIKE ? AND is_trashed = 0',
      whereArgs: ['%$query%'],
    );
    return result.map((map) => Chapter.fromMap(map)).toList();
  }
}
