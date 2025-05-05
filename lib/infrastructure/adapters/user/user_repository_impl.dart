import 'dart:convert';
import 'dart:math';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../../domain/entities/user/user.dart';
import '../../../domain/ports/user/user_repository.dart';
import '../../database/database_helper.dart';
import '../../utils/shared_prefs_helper.dart';

class UserRepositoryImpl implements UserRepository {
  final SharedPrefsService sharedPrefs;
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final Connectivity _connectivity = Connectivity();
  static String apiUrl =
      (dotenv.env['API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String apiKey = dotenv.env['API_KEY'] ?? '';
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '10') ?? 10,
  );

  UserRepositoryImpl(this.sharedPrefs);

  Future<Database> get _database async => await _dbHelper.database;

  Map<String, String> _headers({bool json = true}) {
    return {
      if (json) 'Content-Type': 'application/json',
      'X-API-KEY': apiKey,
    };
  }

  Future<bool> _isOnline() async {
    final connectivityResult = await _connectivity.checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  Future<void> _syncLocalData() async {
    if (!await _isOnline()) return;

    final db = await _database;
    // Sync local users to server
    final unsyncedUsers =
        await db.query('users', where: 'sync = ?', whereArgs: [0]);
    for (var userMap in unsyncedUsers) {
      final user = User.fromMap(userMap);
      try {
        final response = await http
            .post(
              Uri.parse('$apiUrl/register'),
              headers: _headers(),
              body: jsonEncode({
                'username': user.username,
                'email': user.email,
                'password': user.password, // API handles hashing
                'bio': user.bio,
                'is_admin': user.isAdmin,
              }),
            )
            .timeout(apiTimeout);

        if (response.statusCode == 201) {
          await db.update(
            'users',
            {'sync': 1},
            where: 'id = ?',
            whereArgs: [user.id],
          );
        } else {
          print(
              '⚠️ Failed to sync user ${user.id}: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('Sync error for user ${user.id}: $e');
      }
    }

    // Sync server users to local
    try {
      final response = await http
          .get(Uri.parse('$apiUrl/getAllUsers'), headers: _headers(json: false))
          .timeout(apiTimeout);
      if (response.statusCode == 200) {
        final List<dynamic> serverUsers = jsonDecode(response.body);
        for (var serverUser in serverUsers) {
          final user = User.fromMap(serverUser);
          final existing = await db.query(
            'users',
            where: 'id = ?',
            whereArgs: [user.id],
          );

          final salt = existing.isNotEmpty
              ? (existing.first['salt'] as String?) ?? _generateSalt()
              : _generateSalt();
          final hashedPassword = _hashPassword(user.password, salt);

          if (existing.isEmpty) {
            // Insert new user from server
            await db.insert(
              'users',
              {
                'id': user.id,
                'username': user.username,
                'email': user.email,
                'password': hashedPassword,
                'salt': salt,
                'bio': user.bio,
                'is_admin': user.isAdmin ? 1 : 0,
                'sync': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          } else if (existing.first['sync'] == 0) {
            // Update existing user only if not synced
            await db.update(
              'users',
              {
                'username': user.username,
                'email': user.email,
                'password': hashedPassword,
                'salt': salt,
                'bio': user.bio,
                'is_admin': user.isAdmin ? 1 : 0,
                'sync': 1,
              },
              where: 'id = ?',
              whereArgs: [user.id],
            );
          }
        }

        // Remove local users not on server
        final localUsers = await db.query('users');
        final serverUserIds = serverUsers.map((u) => u['id'] as String).toSet();
        for (var localUser in localUsers) {
          final localUserId = localUser['id'] as String;
          if (!serverUserIds.contains(localUserId)) {
            await db.delete(
              'users',
              where: 'id = ?',
              whereArgs: [localUserId],
            );
            print('🗑️ Removed local user $localUserId not found on server');
          }
        }
      } else {
        print(
            '⚠️ Failed to fetch server users: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Error syncing server users to local: $e');
    }
  }

  Future<void> _syncFollowers() async {
    if (!await _isOnline()) return;

    final db = await _database;
    // Sync local followers to server
    final unsyncedFollowers = await db.query(
      'followers',
      where: 'sync = ?',
      whereArgs: [0],
    );
    for (var followerMap in unsyncedFollowers) {
      final userId = followerMap['user_id'] as String;
      final authorId = followerMap['author_id'] as String;
      try {
        final response = await http
            .post(
              Uri.parse('$apiUrl/followAuthor'),
              headers: _headers(),
              body: jsonEncode({'user_id': userId, 'author_id': authorId}),
            )
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          await db.update(
            'followers',
            {'sync': 1},
            where: 'user_id = ? AND author_id = ?',
            whereArgs: [userId, authorId],
          );
        } else {
          print(
              '⚠️ Failed to sync follower $userId-$authorId: ${response.statusCode}');
        }
      } catch (e) {
        print('Sync error for follower $userId-$authorId: $e');
      }
    }

    // Sync server followers to local
    final userIds = (await db.query('followers', columns: ['user_id']))
        .map((row) => row['user_id'] as String)
        .toSet();
    for (var userId in userIds) {
      try {
        final response = await http
            .get(Uri.parse('$apiUrl/getFollowedAuthors/$userId'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          final serverAuthorIds = List<String>.from(jsonDecode(response.body));
          final localAuthorIds = (await db.query(
            'followers',
            where: 'user_id = ?',
            whereArgs: [userId],
          ))
              .map((row) => row['author_id'] as String)
              .toList();

          // Add missing server followers to local
          for (var authorId in serverAuthorIds) {
            if (!localAuthorIds.contains(authorId)) {
              await db.insert(
                'followers',
                {
                  'user_id': userId,
                  'author_id': authorId,
                  'sync': 1,
                },
                conflictAlgorithm: ConflictAlgorithm.replace,
              );
            }
          }

          // Remove local followers not on server
          for (var authorId in localAuthorIds) {
            if (!serverAuthorIds.contains(authorId)) {
              await db.delete(
                'followers',
                where: 'user_id = ? AND author_id = ?',
                whereArgs: [userId, authorId],
              );
            }
          }
        } else {
          print(
              '⚠️ Failed to sync followers for user $userId: ${response.statusCode}');
        }
      } catch (e) {
        print('Error syncing followers for user $userId: $e');
      }
    }
  }

  @override
  Future<void> registerUser(User user) async {
    final db = await _database;

    final existing = await db.query(
      'users',
      where: 'email = ? OR username = ?',
      whereArgs: [user.email, user.username],
    );

    if (existing.isNotEmpty) {
      throw Exception('El email o usuario ya existe');
    }

    final salt = _generateSalt();
    final hashedPassword = _hashPassword(user.password, salt);
    final userToInsert = user.copyWith(
      password: hashedPassword,
      salt: salt,
      sync: false,
    );

    await db.insert('users', userToInsert.toMap());

    if (await _isOnline()) {
      try {
        final response = await http
            .post(
              Uri.parse('$apiUrl/register'),
              headers: _headers(),
              body: jsonEncode({
                'username': user.username,
                'email': user.email,
                'password': user.password,
                'bio': user.bio,
                'is_admin': user.isAdmin,
              }),
            )
            .timeout(apiTimeout);

        if (response.statusCode == 201) {
          await db.update(
            'users',
            {'sync': 1},
            where: 'id = ?',
            whereArgs: [user.id],
          );
        } else {
          print(
              '⚠️ Failed to register user ${user.id}: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during register: $e');
      }
      await _syncLocalData();
    }
  }

  @override
  Future<User?> loginUser(String email, String password) async {
    final db = await _database;

    if (await _isOnline()) {
      try {
        final response = await http
            .post(
              Uri.parse('$apiUrl/login'),
              headers: _headers(),
              body: jsonEncode({'email': email, 'password': password}),
            )
            .timeout(apiTimeout);

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          final user = User.fromMap(data).copyWith(sync: true);
          // Update local SQLite
          final salt = _generateSalt();
          final hashedPassword = _hashPassword(password, salt);
          await db.insert(
            'users',
            user
                .copyWith(password: hashedPassword, salt: salt, sync: true)
                .toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          await _saveUserSession(user);
          return user;
        } else if (response.statusCode == 404) {
          print('⚠️ User with email $email not found on server');
        } else {
          print('⚠️ Login failed: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during login: $e');
      }
    }

    final result =
        await db.query('users', where: 'email = ?', whereArgs: [email]);

    if (result.isNotEmpty) {
      final userData = result.first;
      final storedSalt = userData['salt']?.toString() ?? '';
      final storedHash = userData['password']?.toString() ?? '';
      final inputHash = _hashPassword(password, storedSalt);

      if (storedHash == inputHash) {
        final user = User.fromMap(userData);
        await _saveUserSession(user);
        return user;
      }
    }

    return null;
  }

  @override
  Future<void> updateUser(User user) async {
    final db = await _database;
    final userToUpdate = user.copyWith(sync: false);
    await db.update(
      'users',
      userToUpdate.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );

    if (await _isOnline()) {
      try {
        final response = await http
            .put(
              Uri.parse('$apiUrl/updateUser/${user.id}'),
              headers: _headers(),
              body: jsonEncode({
                'username': user.username,
                'email': user.email,
                'bio': user.bio,
                'is_admin': user.isAdmin,
              }),
            )
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          await db.update(
            'users',
            {'sync': 1},
            where: 'id = ?',
            whereArgs: [user.id],
          );
        } else {
          print(
              '⚠️ Failed to update user ${user.id}: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during updateUser: $e');
      }
      await _syncLocalData();
    }
  }

  @override
  Future<void> changePassword(String userId, String newPassword) async {
    final db = await _database;
    final salt = _generateSalt();
    final hashedPassword = _hashPassword(newPassword, salt);
    await db.update(
      'users',
      {'password': hashedPassword, 'salt': salt, 'sync': 0},
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (await _isOnline()) {
      try {
        final response = await http
            .put(
              Uri.parse('$apiUrl/changePassword/$userId'),
              headers: _headers(),
              body: jsonEncode({'new_password': newPassword}),
            )
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          await db.update(
            'users',
            {'sync': 1},
            where: 'id = ?',
            whereArgs: [userId],
          );
        } else {
          print(
              '⚠️ Failed to change password for user $userId: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during changePassword: $e');
      }
      await _syncLocalData();
    }
  }

  @override
  Future<User?> getUserById(String userId) async {
    final db = await _database;
    final localResult =
        await db.query('users', where: 'id = ?', whereArgs: [userId]);

    if (localResult.isNotEmpty && localResult.first['sync'] == 1) {
      print('📍 Returning synced user $userId from local database');
      return User.fromMap(localResult.first);
    }

    if (await _isOnline()) {
      try {
        final response = await http
            .get(Uri.parse('$apiUrl/getUser/$userId'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          final user =
              User.fromMap(jsonDecode(response.body)).copyWith(sync: true);
          // Update local SQLite
          final existing =
              await db.query('users', where: 'id = ?', whereArgs: [userId]);
          final salt = existing.isNotEmpty
              ? (existing.first['salt'] as String?) ?? _generateSalt()
              : _generateSalt();
          final hashedPassword = _hashPassword(user.password, salt);
          await db.insert(
            'users',
            user
                .copyWith(password: hashedPassword, salt: salt, sync: true)
                .toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          print('📡 Fetched user $userId from API');
          return user;
        } else if (response.statusCode == 404) {
          print('⚠️ User $userId not found on server');
          // Remove from local database if exists
          if (localResult.isNotEmpty) {
            await db.delete('users', where: 'id = ?', whereArgs: [userId]);
            print('🗑️ Removed local user $userId not found on server');
          }
        } else {
          print(
              '⚠️ Failed to fetch user $userId: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during getUserById: $e');
      }
    }

    return localResult.isNotEmpty ? User.fromMap(localResult.first) : null;
  }

  @override
  Future<void> updateUserBio(String userId, String bio) async {
    final db = await _database;
    await db.update(
      'users',
      {'bio': bio, 'sync': 0},
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (await _isOnline()) {
      try {
        final response = await http
            .put(
              Uri.parse('$apiUrl/updateBio/$userId'),
              headers: _headers(),
              body: jsonEncode({'bio': bio}),
            )
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          await db.update(
            'users',
            {'sync': 1},
            where: 'id = ?',
            whereArgs: [userId],
          );
        } else {
          print(
              '⚠️ Failed to update bio for user $userId: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during updateUserBio: $e');
      }
      await _syncLocalData();
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    final db = await _database;
    await db.delete('users', where: 'id = ?', whereArgs: [userId]);

    if (await _isOnline()) {
      try {
        final response = await http
            .delete(Uri.parse('$apiUrl/deleteUser/$userId'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode != 200) {
          print(
              '⚠️ Failed to delete user $userId from API: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during deleteUser: $e');
      }
      await _syncLocalData();
    }
  }

  @override
  Future<bool> isAdmin(String userId) async {
    final db = await _database;
    final result = await db.query(
      'users',
      where: 'id = ? AND is_admin = 1',
      whereArgs: [userId],
    );
    return result.isNotEmpty;
  }

  @override
  Future<List<User>> searchUsers(String query) async {
    if (await _isOnline()) {
      try {
        final response = await http
            .get(Uri.parse('$apiUrl/searchUsers?query=$query'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final users = data
              .map((map) => User.fromMap(map).copyWith(sync: true))
              .toList();
          // Update local SQLite
          final db = await _database;
          for (var user in users) {
            final existing =
                await db.query('users', where: 'id = ?', whereArgs: [user.id]);
            final salt = existing.isNotEmpty
                ? (existing.first['salt'] as String?) ?? _generateSalt()
                : _generateSalt();
            final hashedPassword = _hashPassword(user.password, salt);
            await db.insert(
              'users',
              user
                  .copyWith(password: hashedPassword, salt: salt, sync: true)
                  .toMap(),
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          return users;
        } else {
          print(
              '⚠️ Failed to search users: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during searchUsers: $e');
      }
    }

    final db = await _database;
    final result = await db.query(
      'users',
      where: 'username LIKE ?',
      whereArgs: ['%$query%'],
    );
    return result.map((user) => User.fromMap(user)).toList();
  }

  @override
  Future<void> followAuthor(String userId, String authorId) async {
    final db = await _database;
    await db.insert(
      'followers',
      {'user_id': userId, 'author_id': authorId, 'sync': 0},
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    if (await _isOnline()) {
      try {
        final response = await http
            .post(
              Uri.parse('$apiUrl/followAuthor'),
              headers: _headers(),
              body: jsonEncode({'user_id': userId, 'author_id': authorId}),
            )
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          await db.update(
            'followers',
            {'sync': 1},
            where: 'user_id = ? AND author_id = ?',
            whereArgs: [userId, authorId],
          );
        } else {
          print(
              '⚠️ Failed to follow author $authorId for user $userId: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during followAuthor: $e');
      }
      await _syncFollowers();
    }
  }

  @override
  Future<void> unfollowAuthor(String userId, String authorId) async {
    final db = await _database;
    await db.delete(
      'followers',
      where: 'user_id = ? AND author_id = ?',
      whereArgs: [userId, authorId],
    );

    if (await _isOnline()) {
      try {
        final response = await http
            .delete(
              Uri.parse('$apiUrl/unfollowAuthor'),
              headers: _headers(),
              body: jsonEncode({'user_id': userId, 'author_id': authorId}),
            )
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          // No sync field to update since record is deleted
        } else {
          print(
              '⚠️ Failed to unfollow author $authorId for user $userId: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during unfollowAuthor: $e');
      }
      await _syncFollowers();
    }
  }

  @override
  Future<List<String>> getFollowedAuthors(String userId) async {
    if (await _isOnline()) {
      try {
        final response = await http
            .get(Uri.parse('$apiUrl/getFollowedAuthors/$userId'),
                headers: _headers(json: false))
            .timeout(apiTimeout);
        if (response.statusCode == 200) {
          final List<dynamic> authorIds = jsonDecode(response.body);
          // Update local SQLite
          final db = await _database;
          await db.delete(
            'followers',
            where: 'user_id = ?',
            whereArgs: [userId],
          );
          for (var authorId in authorIds) {
            await db.insert(
              'followers',
              {
                'user_id': userId,
                'author_id': authorId,
                'sync': 1,
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );
          }
          return authorIds.cast<String>();
        } else {
          print(
              '⚠️ Failed to fetch followed authors for user $userId: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during getFollowedAuthors: $e');
      }
    }

    final db = await _database;
    final result = await db.query(
      'followers',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return result.map((row) => row['author_id'] as String).toList();
  }

  Future<void> _saveUserSession(User user) async {
    await sharedPrefs.setValue('user_id', user.id);
    await sharedPrefs.setValue('username', user.username);
    await sharedPrefs.setValue('email', user.email);
  }

  @override
  Future<void> logout() async {
    await sharedPrefs.removeValue('user_id');
    await sharedPrefs.removeValue('username');
    await sharedPrefs.removeValue('email');
  }

  @override
  Future<User?> getUserSession() async {
    final id = sharedPrefs.getValue<String>('user_id');
    final username = sharedPrefs.getValue<String>('username');
    final email = sharedPrefs.getValue<String>('email');

    if (id != null && username != null && email != null) {
      return User(id: id, username: username, email: email, password: '');
    }
    return null;
  }

  Future<void> testConnection() async {
    try {
      final response = await http
          .get(Uri.parse('$apiUrl/getAllUsers'), headers: _headers(json: false))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        print('✅ Conexión con backend exitosa: ${response.body}');
      } else {
        print(
            '⚠️ Conexión fallida - Código: ${response.statusCode}, Motivo: ${response.reasonPhrase}');
      }
    } catch (e) {
      print('❌ Error al conectar con el backend: $e');
    }
  }

  @override
  Future<bool> isUserLoggedIn() async {
    final id = sharedPrefs.getValue<String>('user_id');
    return id != null;
  }

  @override
  Future<String?> getCurrentUserId() async {
    return sharedPrefs.getValue<String>('user_id');
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
