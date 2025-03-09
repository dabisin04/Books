abstract class DatabaseRepository {
  /// Obtiene todos los usuarios de la base de datos.
  Future<List<Map<String, dynamic>>> getUsers();

  /// Obtiene todos los libros de la base de datos.
  Future<List<Map<String, dynamic>>> getBooks();
}
