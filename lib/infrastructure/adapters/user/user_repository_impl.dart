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
  static String primaryApiUrl =
      (dotenv.env['API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String altApiUrl =
      (dotenv.env['ALT_API_BASE_URL'] ?? '').replaceAll('//api', '/api');
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

  // Unified HTTP methods
  Future<http.Response> _get(String endpoint) async {
    try {
      final futures = [
        http
            .get(
              Uri.parse('$primaryApiUrl/$endpoint'),
              headers: _headers(json: false),
            )
            .timeout(apiTimeout),
        http
            .get(
              Uri.parse('$altApiUrl/$endpoint'),
              headers: _headers(json: false),
            )
            .timeout(apiTimeout),
      ];

      final responses = await Future.wait(futures);
      final primaryResponse = responses[0];
      final altResponse = responses[1];

      // Si ambas respuestas son exitosas, usar la primaria
      if (primaryResponse.statusCode >= 200 &&
          primaryResponse.statusCode < 300) {
        return primaryResponse;
      }

      // Si la primaria falla pero la alternativa funciona, usar la alternativa
      if (altResponse.statusCode >= 200 && altResponse.statusCode < 300) {
        print('⚠️ Primary API failed, using alternative API response');
        return altResponse;
      }

      // Si ambas fallan, lanzar el error de la primaria
      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in GET request: $e');
      rethrow;
    }
  }

  Future<http.Response> _post(
      String endpoint, Map<String, dynamic> body) async {
    try {
      final futures = [
        http
            .post(
              Uri.parse('$primaryApiUrl/$endpoint'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(apiTimeout),
        http
            .post(
              Uri.parse('$altApiUrl/$endpoint'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(apiTimeout),
      ];

      final responses = await Future.wait(futures);
      final primaryResponse = responses[0];
      final altResponse = responses[1];

      // Verificar que ambas APIs respondan correctamente
      if (primaryResponse.statusCode >= 200 &&
          primaryResponse.statusCode < 300 &&
          altResponse.statusCode >= 200 &&
          altResponse.statusCode < 300) {
        return primaryResponse;
      }

      // Si la primaria falla pero la alternativa funciona, intentar sincronizar
      if (altResponse.statusCode >= 200 && altResponse.statusCode < 300) {
        print('⚠️ Primary API failed, syncing with alternative API');
        // Intentar sincronizar la respuesta exitosa con la API primaria
        try {
          await http
              .post(
                Uri.parse('$primaryApiUrl/$endpoint'),
                headers: _headers(),
                body: jsonEncode(body),
              )
              .timeout(apiTimeout);
        } catch (syncError) {
          print('⚠️ Failed to sync with primary API: $syncError');
        }
        return altResponse;
      }

      // Si ambas fallan, lanzar el error de la primaria
      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in POST request: $e');
      rethrow;
    }
  }

  Future<http.Response> _put(String endpoint, Map<String, dynamic> body) async {
    try {
      final futures = [
        http
            .put(
              Uri.parse('$primaryApiUrl/$endpoint'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(apiTimeout),
        http
            .put(
              Uri.parse('$altApiUrl/$endpoint'),
              headers: _headers(),
              body: jsonEncode(body),
            )
            .timeout(apiTimeout),
      ];

      final responses = await Future.wait(futures);
      final primaryResponse = responses[0];
      final altResponse = responses[1];

      // Verificar que ambas APIs respondan correctamente
      if (primaryResponse.statusCode >= 200 &&
          primaryResponse.statusCode < 300 &&
          altResponse.statusCode >= 200 &&
          altResponse.statusCode < 300) {
        return primaryResponse;
      }

      // Si la primaria falla pero la alternativa funciona, intentar sincronizar
      if (altResponse.statusCode >= 200 && altResponse.statusCode < 300) {
        print('⚠️ Primary API failed, syncing with alternative API');
        // Intentar sincronizar la respuesta exitosa con la API primaria
        try {
          await http
              .put(
                Uri.parse('$primaryApiUrl/$endpoint'),
                headers: _headers(),
                body: jsonEncode(body),
              )
              .timeout(apiTimeout);
        } catch (syncError) {
          print('⚠️ Failed to sync with primary API: $syncError');
        }
        return altResponse;
      }

      // Si ambas fallan, lanzar el error de la primaria
      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in PUT request: $e');
      rethrow;
    }
  }

  Future<http.Response> _delete(String endpoint,
      [Map<String, dynamic>? body]) async {
    final headers = body != null ? _headers() : _headers(json: false);
    try {
      final futures = [
        http
            .delete(
              Uri.parse('$primaryApiUrl/$endpoint'),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(apiTimeout),
        http
            .delete(
              Uri.parse('$altApiUrl/$endpoint'),
              headers: headers,
              body: body != null ? jsonEncode(body) : null,
            )
            .timeout(apiTimeout),
      ];

      final responses = await Future.wait(futures);
      final primaryResponse = responses[0];
      final altResponse = responses[1];

      // Verificar que ambas APIs respondan correctamente
      if (primaryResponse.statusCode >= 200 &&
          primaryResponse.statusCode < 300 &&
          altResponse.statusCode >= 200 &&
          altResponse.statusCode < 300) {
        return primaryResponse;
      }

      // Si la primaria falla pero la alternativa funciona, intentar sincronizar
      if (altResponse.statusCode >= 200 && altResponse.statusCode < 300) {
        print('⚠️ Primary API failed, syncing with alternative API');
        // Intentar sincronizar la respuesta exitosa con la API primaria
        try {
          await http
              .delete(
                Uri.parse('$primaryApiUrl/$endpoint'),
                headers: headers,
                body: body != null ? jsonEncode(body) : null,
              )
              .timeout(apiTimeout);
        } catch (syncError) {
          print('⚠️ Failed to sync with primary API: $syncError');
        }
        return altResponse;
      }

      // Si ambas fallan, lanzar el error de la primaria
      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in DELETE request: $e');
      rethrow;
    }
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
        final response = await _post('register', {
          'username': user.username,
          'email': user.email,
          'password': user.password,
          'bio': user.bio,
          'is_admin': user.isAdmin,
        });

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
      final response = await _get('getAllUsers');
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
    final unsyncedFollowers = await db.query(
      'followers',
      where: 'sync = ?',
      whereArgs: [0],
    );
    for (var followerMap in unsyncedFollowers) {
      final userId = followerMap['user_id'] as String;
      final authorId = followerMap['author_id'] as String;
      try {
        final response = await _post(
            'followAuthor', {'user_id': userId, 'author_id': authorId});
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

    final userIds = (await db.query('followers', columns: ['user_id']))
        .map((row) => row['user_id'] as String)
        .toSet();
    for (var userId in userIds) {
      try {
        final response = await _get('getFollowedAuthors/$userId');
        if (response.statusCode == 200) {
          final serverAuthorIds = List<String>.from(jsonDecode(response.body));
          final localAuthorIds = (await db.query(
            'followers',
            where: 'user_id = ?',
            whereArgs: [userId],
          ))
              .map((row) => row['author_id'] as String)
              .toList();

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

    if (await _isOnline()) {
      try {
        print('📤 Registrando usuario primero en Flask...');
        final flaskResponse = await http
            .post(
              Uri.parse('$primaryApiUrl/register'),
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

        if (flaskResponse.statusCode != 201) {
          final error = jsonDecode(flaskResponse.body);
          throw Exception(error['error'] ?? 'Error al registrar en Flask');
        }

        final flaskData = jsonDecode(flaskResponse.body);
        print('✅ Usuario creado en Flask con ID: ${flaskData["id"]}');

        // Ahora registrar en FastAPI incluyendo `from_flask = true`
        final fastapiData = {
          ...flaskData,
          'from_flask': true,
        };
        print('📤 Enviando a FastAPI: ${jsonEncode(fastapiData)}');

        final fastapiResponse = await http
            .post(
              Uri.parse('$altApiUrl/register'),
              headers: _headers(),
              body: jsonEncode(fastapiData),
            )
            .timeout(apiTimeout);

        if (fastapiResponse.statusCode != 200) {
          throw Exception(
              'Error al registrar en FastAPI: ${fastapiResponse.statusCode}');
        }

        final userToInsert = User.fromMap(flaskData).copyWith(sync: true);
        await db.insert('users', userToInsert.toMap());
        print('💾 Usuario guardado en DB local con ID: ${userToInsert.id}');
      } catch (e) {
        print('❌ Error completo en registro dual: $e');
        throw Exception('Error al registrar el usuario: $e');
      }
    } else {
      throw Exception('No hay conexión a internet');
    }
  }

  @override
  Future<User?> loginUser(String email, String password) async {
    final db = await _database;

    if (await _isOnline()) {
      try {
        print('🔑 Intentando login con email: $email');
        final response =
            await _post('login', {'email': email, 'password': password});

        if (response.statusCode == 200) {
          final responseData = jsonDecode(response.body);
          print('📥 Respuesta del servidor: $responseData');

          if (responseData['id'] == null) {
            print('⚠️ El servidor no devolvió un ID válido');
            return null;
          }

          final Map<String, dynamic> processedData =
              Map<String, dynamic>.from(responseData);
          processedData['is_admin'] =
              (responseData['is_admin'] as bool) ? 1 : 0;

          final serverUser = User.fromMap(processedData);
          print('✅ Login exitoso con ID: ${serverUser.id}');

          await db.insert(
            'users',
            serverUser.copyWith(sync: true).toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          );
          print('💾 Usuario actualizado en DB local con ID: ${serverUser.id}');

          await _saveUserSession(serverUser);
          print('🔐 Sesión guardada para usuario: ${serverUser.id}');
          return serverUser;
        } else if (response.statusCode == 404) {
          print('⚠️ Usuario no encontrado en el servidor');
          return null;
        } else {
          final errorData = jsonDecode(response.body);
          print(
              '⚠️ Error en login: ${response.statusCode} - ${errorData['error']}');
          return null;
        }
      } catch (e) {
        print('❌ Error en login: $e');
        return null;
      }
    }

    print('📱 Intentando login local...');
    final result =
        await db.query('users', where: 'email = ?', whereArgs: [email]);

    if (result.isNotEmpty) {
      final userData = result.first;
      final storedSalt = userData['salt']?.toString() ?? '';
      final storedHash = userData['password']?.toString() ?? '';
      final inputHash = _hashPassword(password, storedSalt);

      if (storedHash == inputHash) {
        final user = User.fromMap(userData);
        print('✅ Login local exitoso con ID: ${user.id}');
        await _saveUserSession(user);
        return user;
      }
    }

    print('❌ Login fallido');
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
        final response = await _put('updateUser/${user.id}', {
          'username': user.username,
          'email': user.email,
          'bio': user.bio,
          'is_admin': user.isAdmin,
          'reported_for_name': user.reportedForName,
        });
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
  Future<void> updateUserStatus(
      String userId, String status, DateTime? nameChangeDeadline) async {
    final db = await _database;
    await db.update(
      'users',
      {
        'status': status,
        'name_change_deadline': nameChangeDeadline?.toIso8601String(),
        'sync': 0,
      },
      where: 'id = ?',
      whereArgs: [userId],
    );

    if (await _isOnline()) {
      try {
        final response = await _put('updateUserStatus/$userId', {
          'status': status,
          'name_change_deadline': nameChangeDeadline?.toIso8601String(),
        });
        if (response.statusCode == 200) {
          await db.update(
            'users',
            {'sync': 1},
            where: 'id = ?',
            whereArgs: [userId],
          );
        } else {
          print(
              '⚠️ Failed to update user status for $userId: ${response.statusCode} - ${response.body}');
        }
      } catch (e) {
        print('API error during updateUserStatus: $e');
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
        final response =
            await _put('changePassword/$userId', {'new_password': newPassword});
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
        final response = await _get('getUser/$userId');
        if (response.statusCode == 200) {
          final user =
              User.fromMap(jsonDecode(response.body)).copyWith(sync: true);
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
        final response = await _put('updateBio/$userId', {'bio': bio});
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
        final response = await _delete('deleteUser/$userId');
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
        final response = await _get('searchUsers?query=$query');
        if (response.statusCode == 200) {
          final List<dynamic> data = jsonDecode(response.body);
          final users = data
              .map((map) => User.fromMap(map).copyWith(sync: true))
              .toList();
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
        final response = await _post(
            'followAuthor', {'user_id': userId, 'author_id': authorId});
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
        final response = await _delete(
            'unfollowAuthor', {'user_id': userId, 'author_id': authorId});
        if (response.statusCode == 200) {
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
        final response = await _get('getFollowedAuthors/$userId');
        if (response.statusCode == 200) {
          final List<dynamic> authorIds = jsonDecode(response.body);
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
    print('💾 Guardando sesión para usuario: ${user.id}');
    await sharedPrefs.setValue('user_id', user.id);
    await sharedPrefs.setValue('username', user.username);
    await sharedPrefs.setValue('email', user.email);
    print('✅ Sesión guardada correctamente');
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
      final response = await _get('getAllUsers');
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
