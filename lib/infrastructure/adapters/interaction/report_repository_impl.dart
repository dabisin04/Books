import 'dart:convert';
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'package:sqflite/sqflite.dart';
import '../../../domain/ports/interaction/report_repository.dart';
import '../../../domain/entities/interaction/report.dart';
import '../../../domain/entities/interaction/strikes.dart';
import '../../../domain/entities/interaction/alerts.dart';
import '../../database/database_helper.dart';
import '../../utils/shared_prefs_helper.dart';

class ReportRepositoryImpl implements ReportRepository {
  final SharedPrefsService sharedPrefs;
  final Connectivity _connectivity = Connectivity();
  Future<Database> get _database async =>
      await DatabaseHelper.instance.database;
  static String primaryApiUrl =
      (dotenv.env['API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String altApiUrl =
      (dotenv.env['ALT_API_BASE_URL'] ?? '').replaceAll('//api', '/api');
  static String apiKey = dotenv.env['API_KEY'] ?? '';
  static final Duration apiTimeout = Duration(
    seconds: int.tryParse(dotenv.env['API_TIMEOUT'] ?? '5') ?? 5,
  );

  ReportRepositoryImpl(this.sharedPrefs);

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

  bool _isSuccessfulResponse(int statusCode) {
    return statusCode >= 200 && statusCode < 300;
  }

  Future<http.Response> _get(String endpoint) async {
    try {
      print('📤 [GET] Enviando a Flask: $endpoint');
      print('📦 Headers: ${_headers(json: false)}');

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

      print('📥 Respuesta Flask: ${primaryResponse.statusCode}');
      print('📦 Cuerpo Flask: ${primaryResponse.body}');
      print('📥 Respuesta FastAPI: ${altResponse.statusCode}');
      print('📦 Cuerpo FastAPI: ${altResponse.body}');

      if (_isSuccessfulResponse(primaryResponse.statusCode)) {
        return primaryResponse;
      }

      if (_isSuccessfulResponse(altResponse.statusCode)) {
        print('⚠️ Primary API failed, using alternative API response');
        return altResponse;
      }

      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in GET request: $e');
      rethrow;
    }
  }

  Future<http.Response> _post(
      String endpoint, Map<String, dynamic> body) async {
    try {
      print('📤 [POST] Enviando a Flask: $endpoint');
      print('📦 Datos a Flask: ${jsonEncode(body)}');
      print('📦 Headers: ${_headers()}');

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

      print('📥 Respuesta Flask: ${primaryResponse.statusCode}');
      print('📦 Cuerpo Flask: ${primaryResponse.body}');
      print('📥 Respuesta FastAPI: ${altResponse.statusCode}');
      print('📦 Cuerpo FastAPI: ${altResponse.body}');

      if (_isSuccessfulResponse(primaryResponse.statusCode) &&
          _isSuccessfulResponse(altResponse.statusCode)) {
        return primaryResponse;
      }

      if (_isSuccessfulResponse(altResponse.statusCode)) {
        print('⚠️ Primary API failed, syncing with alternative API');
        try {
          print('🔄 Intentando sincronizar con Flask...');
          final syncResponse = await http
              .post(
                Uri.parse('$primaryApiUrl/$endpoint'),
                headers: _headers(),
                body: jsonEncode(body),
              )
              .timeout(apiTimeout);
          print(
              '📥 Respuesta sincronización Flask: ${syncResponse.statusCode}');
          print('📦 Cuerpo sincronización Flask: ${syncResponse.body}');
        } catch (syncError) {
          print('⚠️ Failed to sync with primary API: $syncError');
        }
        return altResponse;
      }

      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in POST request: $e');
      rethrow;
    }
  }

  Future<http.Response> _put(String endpoint, Map<String, dynamic> body) async {
    try {
      print('📤 [PUT] Enviando a Flask: $endpoint');
      print('📦 Datos a Flask: ${jsonEncode(body)}');
      print('📦 Headers: ${_headers()}');

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

      print('📥 Respuesta Flask: ${primaryResponse.statusCode}');
      print('📦 Cuerpo Flask: ${primaryResponse.body}');
      print('📥 Respuesta FastAPI: ${altResponse.statusCode}');
      print('📦 Cuerpo FastAPI: ${altResponse.body}');

      if (_isSuccessfulResponse(primaryResponse.statusCode) &&
          _isSuccessfulResponse(altResponse.statusCode)) {
        return primaryResponse;
      }

      if (_isSuccessfulResponse(altResponse.statusCode)) {
        print('⚠️ Primary API failed, syncing with alternative API');
        try {
          print('🔄 Intentando sincronizar con Flask...');
          final syncResponse = await http
              .put(
                Uri.parse('$primaryApiUrl/$endpoint'),
                headers: _headers(),
                body: jsonEncode(body),
              )
              .timeout(apiTimeout);
          print(
              '📥 Respuesta sincronización Flask: ${syncResponse.statusCode}');
          print('📦 Cuerpo sincronización Flask: ${syncResponse.body}');
        } catch (syncError) {
          print('⚠️ Failed to sync with primary API: $syncError');
        }
        return altResponse;
      }

      throw Exception('Both APIs failed: ${primaryResponse.statusCode}');
    } catch (e) {
      print('❌ Error in PUT request: $e');
      rethrow;
    }
  }

  @override
  Future<void> reportContent(Report report) async {
    print('📝 Iniciando reporte de contenido...');
    print('📦 Datos del reporte: ${report.toMap()}');

    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('reports', report.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      print('💾 Reporte guardado en DB local');
    });

    if (await _isOnline()) {
      try {
        final requestBody = {
          'reporter_id': report.reporterId,
          'target_id': report.targetId,
          'target_type': report.targetType,
          'reason': report.reason,
          'status': report.status ?? 'pending',
        };

        print('📤 Registrando reporte primero en Flask...');
        print('📦 Datos a Flask: ${jsonEncode(requestBody)}');

        final flaskResponse = await http
            .post(
              Uri.parse('$primaryApiUrl/addReport'),
              headers: _headers(),
              body: jsonEncode(requestBody),
            )
            .timeout(apiTimeout);

        print('📥 Respuesta Flask: ${flaskResponse.statusCode}');
        print('📦 Cuerpo Flask: ${flaskResponse.body}');

        if (flaskResponse.statusCode != 201) {
          final error = jsonDecode(flaskResponse.body);
          throw Exception(error['error'] ?? 'Error al registrar en Flask');
        }

        final flaskData = jsonDecode(flaskResponse.body);
        print('✅ Reporte creado en Flask');

        // Ahora registrar en FastAPI incluyendo `from_flask = true`
        final fastapiData = {
          ...flaskData,
          'from_flask': true,
        };
        print('📤 Enviando a FastAPI: ${jsonEncode(fastapiData)}');

        final fastapiResponse = await http
            .post(
              Uri.parse('$altApiUrl/addReport'),
              headers: _headers(),
              body: jsonEncode(fastapiData),
            )
            .timeout(apiTimeout);

        print('📥 Respuesta FastAPI: ${fastapiResponse.statusCode}');
        print('📦 Cuerpo FastAPI: ${fastapiResponse.body}');

        if (fastapiResponse.statusCode != 200) {
          throw Exception(
              'Error al registrar en FastAPI: ${fastapiResponse.statusCode}');
        }

        print('✅ Reporte sincronizado con FastAPI');
      } on TimeoutException {
        print('⏰ Timeout al reportar contenido');
      } catch (e) {
        print('❌ Error completo en registro dual: $e');
        throw Exception('Error al registrar el reporte: $e');
      }
    } else {
      print('📴 Sin conexión. Reporte guardado solo localmente.');
    }
  }

  @override
  Future<List<Report>> getPendingReports() async {
    final db = await _database;
    final result = await db.query(
      'reports',
      where: 'status = ?',
      whereArgs: ['pending'],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => Report.fromMap(map)).toList();
  }

  @override
  Future<List<Report>> getReportsByTarget(String targetId) async {
    final db = await _database;
    final result = await db.query(
      'reports',
      where: 'target_id = ?',
      whereArgs: [targetId],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => Report.fromMap(map)).toList();
  }

  @override
  Future<void> updateReportStatus(
      String reportId, String status, String? adminId) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'reports',
        {
          'status': status,
          'resolved_at': DateTime.now().toIso8601String(),
          'admin_id': adminId,
        },
        where: 'id = ?',
        whereArgs: [reportId],
      );
    });

    if (await _isOnline()) {
      try {
        final response = await _put('updateReportStatus/$reportId', {
          'status': status,
          'admin_id': adminId,
        });

        if (!_isSuccessfulResponse(response.statusCode)) {
          throw Exception('Error al actualizar estado: ${response.statusCode}');
        }
      } on TimeoutException {
        print('⏰ Timeout al actualizar estado');
      } catch (e) {
        print('❌ Error al actualizar estado en APIs: $e');
      }
    }
  }

  @override
  Future<void> addStrike(Strike strike) async {
    print('📝 Iniciando registro de strike...');
    print('📦 Datos del strike: ${strike.toMap()}');

    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('user_strikes', strike.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      print('💾 Strike guardado en DB local');
    });

    if (await _isOnline()) {
      try {
        final requestBody = {
          'user_id': strike.userId,
          'reason': strike.reason,
          'strike_count': strike.strikeCount,
          'is_active': strike.isActive,
        };

        print('📤 Registrando strike primero en Flask...');
        print('📦 Datos a Flask: ${jsonEncode(requestBody)}');

        final flaskResponse = await http
            .post(
              Uri.parse('$primaryApiUrl/addStrike'),
              headers: _headers(),
              body: jsonEncode(requestBody),
            )
            .timeout(apiTimeout);

        print('📥 Respuesta Flask: ${flaskResponse.statusCode}');
        print('📦 Cuerpo Flask: ${flaskResponse.body}');

        if (flaskResponse.statusCode != 201) {
          final error = jsonDecode(flaskResponse.body);
          throw Exception(error['error'] ?? 'Error al registrar en Flask');
        }

        final flaskData = jsonDecode(flaskResponse.body);
        print('✅ Strike creado en Flask');

        // Ahora registrar en FastAPI incluyendo `from_flask = true`
        final fastapiData = {
          ...flaskData,
          'from_flask': true,
        };
        print('📤 Enviando a FastAPI: ${jsonEncode(fastapiData)}');

        final fastapiResponse = await http
            .post(
              Uri.parse('$altApiUrl/addStrike'),
              headers: _headers(),
              body: jsonEncode(fastapiData),
            )
            .timeout(apiTimeout);

        print('📥 Respuesta FastAPI: ${fastapiResponse.statusCode}');
        print('📦 Cuerpo FastAPI: ${fastapiResponse.body}');

        if (fastapiResponse.statusCode != 200) {
          throw Exception(
              'Error al registrar en FastAPI: ${fastapiResponse.statusCode}');
        }

        print('✅ Strike sincronizado con FastAPI');
      } on TimeoutException {
        print('⏰ Timeout al agregar strike');
      } catch (e) {
        print('❌ Error completo en registro dual: $e');
        throw Exception('Error al registrar el strike: $e');
      }
    } else {
      print('📴 Sin conexión. Strike guardado solo localmente.');
    }
  }

  @override
  Future<List<Strike>> getStrikesByUser(String userId) async {
    final db = await _database;
    final result = await db.query(
      'user_strikes',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'timestamp DESC',
    );
    return result.map((map) => Strike.fromMap(map)).toList();
  }

  @override
  Future<void> addAlert(Alert alert) async {
    print('📝 Iniciando registro de alerta...');
    print('📦 Datos de la alerta: ${alert.toMap()}');

    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('report_alerts', alert.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
      print('💾 Alerta guardada en DB local');
    });

    if (await _isOnline()) {
      try {
        final requestBody = {
          'book_id': alert.bookId,
          'report_reason': alert.reportReason,
          'status': alert.status,
          'created_at': alert.createdAt.toIso8601String(),
        };

        print('📤 Registrando alerta primero en Flask...');
        print('📦 Datos a Flask: ${jsonEncode(requestBody)}');

        final flaskResponse = await http
            .post(
              Uri.parse('$primaryApiUrl/addAlert'),
              headers: _headers(),
              body: jsonEncode(requestBody),
            )
            .timeout(apiTimeout);

        print('📥 Respuesta Flask: ${flaskResponse.statusCode}');
        print('📦 Cuerpo Flask: ${flaskResponse.body}');

        if (flaskResponse.statusCode != 201) {
          final error = jsonDecode(flaskResponse.body);
          throw Exception(error['error'] ?? 'Error al registrar en Flask');
        }

        final flaskData = jsonDecode(flaskResponse.body);
        print('✅ Alerta creada en Flask');

        // Ahora registrar en FastAPI incluyendo `from_flask = true`
        final fastapiData = {
          ...flaskData,
          'from_flask': true,
        };
        print('📤 Enviando a FastAPI: ${jsonEncode(fastapiData)}');

        final fastapiResponse = await http
            .post(
              Uri.parse('$altApiUrl/addAlert'),
              headers: _headers(),
              body: jsonEncode(fastapiData),
            )
            .timeout(apiTimeout);

        print('📥 Respuesta FastAPI: ${fastapiResponse.statusCode}');
        print('📦 Cuerpo FastAPI: ${fastapiResponse.body}');

        if (fastapiResponse.statusCode != 200) {
          throw Exception(
              'Error al registrar en FastAPI: ${fastapiResponse.statusCode}');
        }

        print('✅ Alerta sincronizada con FastAPI');
      } on TimeoutException {
        print('⏰ Timeout al agregar alerta');
      } catch (e) {
        print('❌ Error completo en registro dual: $e');
        throw Exception('Error al registrar la alerta: $e');
      }
    } else {
      print('📴 Sin conexión. Alerta guardada solo localmente.');
    }
  }

  @override
  Future<List<Alert>> getAlertsByBook(String bookId) async {
    final db = await _database;
    final result = await db.query(
      'report_alerts',
      where: 'book_id = ? AND status = ?',
      whereArgs: [bookId, 'alert'],
      orderBy: 'alert_date DESC',
    );
    return result.map((map) => Alert.fromMap(map)).toList();
  }

  @override
  Future<void> resolveAlert(String alertId, String status) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.update(
        'report_alerts',
        {
          'status': status,
          'resolved_at': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [alertId],
      );
    });

    if (await _isOnline()) {
      try {
        final response =
            await _put('resolveAlert/$alertId', {'status': status});

        if (!_isSuccessfulResponse(response.statusCode)) {
          throw Exception('Error al resolver alerta: ${response.statusCode}');
        }
      } on TimeoutException {
        print('⏰ Timeout al resolver alerta');
      } catch (e) {
        print('❌ Error al resolver alerta en APIs: $e');
      }
    }
  }
}
