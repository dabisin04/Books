import '../../domain/ports/database/database_repository.dart';
import '../database/database_helper.dart';

class DatabaseRepositoryImpl implements DatabaseRepository {
  final DatabaseHelper _databaseHelper = DatabaseHelper.instance;

  @override
  Future<List<Map<String, dynamic>>> getUsers() async {
    try {
      final db = await _databaseHelper.database;
      return await db.query('users');
    } catch (e) {
      throw Exception("Error al obtener usuarios: ${e.toString()}");
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getBooks() async {
    try {
      final db = await _databaseHelper.database;
      return await db.query('books');
    } catch (e) {
      throw Exception("Error al obtener libros: ${e.toString()}");
    }
  }
}
