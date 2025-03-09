import 'dart:convert';
import 'dart:math';
// ignore: depend_on_referenced_packages
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../../domain/entities/user/user.dart';
import '../../domain/ports/user/user_repository.dart';
import '../../main.dart';
import '../database/database_helper.dart';
import '../utils/shared_prefs_helper.dart';

class UserRepositoryImpl implements UserRepository {
  final SharedPrefsService sharedPrefs;

  UserRepositoryImpl(this.sharedPrefs);

  Future<Database> get _database async =>
      await DatabaseHelper.instance.database;

  @override
  Future<void> registerUser(User user) async {
    final db = await _database;
    final existing = await db.query('users',
        where: 'email = ? OR username = ?',
        whereArgs: [user.email, user.username]);

    if (existing.isNotEmpty) {
      throw Exception('El email o usuario ya existe');
    }
    final salt = _generateSalt();
    final hashedPassword = _hashPassword(user.password, salt);

    await db.insert('users', {
      'id': user.id,
      'username': user.username,
      'email': user.email,
      'password': hashedPassword,
      'salt': salt,
      'bio': user.bio,
      'is_admin': user.isAdmin ? 1 : 0,
    });
  }

  @override
  Future<User?> loginUser(String email, String password) async {
    final db = await _database;
    final result =
        await db.query('users', where: 'email = ?', whereArgs: [email]);

    // Muestra el resultado de la consulta en un SnackBar
    scaffoldMessengerKey.currentState?.showSnackBar(
        SnackBar(content: Text("Resultado de consulta para $email: $result")));

    if (result.isNotEmpty) {
      final userData = result.first;
      final storedSalt = userData['salt']?.toString() ?? '';
      final storedHash = userData['password']?.toString() ?? '';
      final inputHash = _hashPassword(password, storedSalt);

      // Muestra el hash almacenado y el hash de entrada en un SnackBar
      scaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
          content: Text("StoredHash: $storedHash - InputHash: $inputHash")));

      if (storedHash == inputHash) {
        final user = User.fromMap(userData);
        await _saveUserSession(user);
        return user;
      }
    }
    return null;
  }

  Future<User?> getUserById(String userId) async {
    final db = await _database;
    final result =
        await db.query('users', where: 'id = ?', whereArgs: [userId]);
    return result.isNotEmpty ? User.fromMap(result.first) : null;
  }

  Future<List<User>> getAllUsers() async {
    final db = await _database;
    final result = await db.query('users');
    return result.map((user) => User.fromMap(user)).toList();
  }

  Future<void> updateUser(User user) async {
    final db = await _database;
    await db
        .update('users', user.toMap(), where: 'id = ?', whereArgs: [user.id]);
  }

  @override
  Future<void> updateUserBio(String userId, String bio) async {
    final db = await _database;
    await db.update('users', {'bio': bio},
        where: 'id = ?', whereArgs: [userId]);
  }

  Future<void> changePassword(String userId, String newPassword) async {
    final db = await _database;
    final salt = _generateSalt();
    final hashedPassword = _hashPassword(newPassword, salt);
    await db.update('users', {'password': hashedPassword, 'salt': salt},
        where: 'id = ?', whereArgs: [userId]);
  }

  @override
  Future<void> deleteUser(String userId) async {
    final db = await _database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);
  }

  @override
  Future<bool> isAdmin(String userId) async {
    final db = await _database;
    final result = await db
        .query('users', where: 'id = ? AND is_admin = 1', whereArgs: [userId]);
    return result.isNotEmpty;
  }

  @override
  Future<List<User>> searchUsers(String query) async {
    final db = await _database;
    final result = await db
        .query('users', where: 'username LIKE ?', whereArgs: ['%$query%']);
    return result.map((user) => User.fromMap(user)).toList();
  }

  @override
  Future<void> followAuthor(String userId, String authorId) async {
    final db = await _database;
    await db.insert('followers', {'user_id': userId, 'author_id': authorId});
  }

  @override
  Future<void> unfollowAuthor(String userId, String authorId) async {
    final db = await _database;
    await db.delete('followers',
        where: 'user_id = ? AND author_id = ?', whereArgs: [userId, authorId]);
  }

  @override
  Future<List<String>> getFollowedAuthors(String userId) async {
    final db = await _database;
    final result =
        await db.query('followers', where: 'user_id = ?', whereArgs: [userId]);
    return result.map((row) => row['author_id'] as String).toList();
  }

  Future<void> _saveUserSession(User user) async {
    await sharedPrefs.setValue("user_id", user.id);
    await sharedPrefs.setValue("username", user.username);
    await sharedPrefs.setValue("email", user.email);
  }

  @override
  Future<void> logout() async {
    await sharedPrefs.clear();
  }

  Future<User?> getUserSession() async {
    final id = sharedPrefs.getValue<String>("user_id");
    final username = sharedPrefs.getValue<String>("username");
    final email = sharedPrefs.getValue<String>("email");

    if (id != null && username != null && email != null) {
      return User(
          id: id,
          username: username,
          email: email,
          password: "",
          bio: "",
          isAdmin: false);
    }
    return null;
  }

  String _generateSalt() {
    final random = Random.secure();
    final values = List<int>.generate(16, (i) => random.nextInt(256));
    return base64Url.encode(values);
  }

  String _hashPassword(String password, String salt) {
    final key = utf8.encode(password + salt);
    final digest = sha1.convert(key);
    return digest.toString();
  }
}
