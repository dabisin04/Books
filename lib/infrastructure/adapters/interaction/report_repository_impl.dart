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
  static String baseUrl = dotenv.env['API_BASE_URL'] ?? '';
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

  @override
  Future<void> reportContent(Report report) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('reports', report.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
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

        print('📤 Enviando reporte a API:');
        print('URL: $baseUrl/addReport');
        print('Headers: ${_headers()}');
        print('Body: ${jsonEncode(requestBody)}');

        final response = await http
            .post(
              Uri.parse('$baseUrl/addReport'),
              headers: _headers(),
              body: jsonEncode(requestBody),
            )
            .timeout(apiTimeout);

        print('📥 Respuesta del API:');
        print('Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        if (response.statusCode != 201) {
          throw Exception(
              'Error al reportar contenido: ${response.statusCode}');
        }
      } on TimeoutException {
        print('⏰ Timeout al reportar contenido');
      } catch (e) {
        print('❌ Error al enviar reporte a API: $e');
      }
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
        final response = await http
            .put(
              Uri.parse('$baseUrl/updateReportStatus/$reportId'),
              headers: _headers(),
              body: jsonEncode({
                'status': status,
                'admin_id': adminId,
              }),
            )
            .timeout(apiTimeout);
        if (response.statusCode != 200) {
          throw Exception('Error al actualizar estado: ${response.statusCode}');
        }
      } on TimeoutException {
        print('Timeout al actualizar estado');
      } catch (e) {
        print('Error al actualizar estado en API: $e');
      }
    }
  }

  @override
  Future<void> addStrike(Strike strike) async {
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('user_strikes', strike.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    });

    if (await _isOnline()) {
      try {
        final requestBody = {
          'user_id': strike.userId,
          'reason': strike.reason,
          'strike_count': strike.strikeCount,
          'is_active': strike.isActive,
        };

        print('📤 Enviando strike a API:');
        print('URL: $baseUrl/addStrike');
        print('Headers: ${_headers()}');
        print('Body: ${jsonEncode(requestBody)}');

        final response = await http
            .post(
              Uri.parse('$baseUrl/addStrike'),
              headers: _headers(),
              body: jsonEncode(requestBody),
            )
            .timeout(apiTimeout);

        print('📥 Respuesta del API:');
        print('Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        if (response.statusCode != 201) {
          throw Exception('Error al agregar strike: ${response.statusCode}');
        }
      } on TimeoutException {
        print('⏰ Timeout al agregar strike');
      } catch (e) {
        print('❌ Error al enviar strike a API: $e');
      }
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
    final db = await _database;
    await db.transaction((txn) async {
      await txn.insert('report_alerts', alert.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace);
    });

    if (await _isOnline()) {
      try {
        final requestBody = {
          'book_id': alert.bookId,
          'report_reason': alert.reportReason,
          'status': alert.status,
          'created_at': alert.createdAt.toIso8601String(),
        };

        print('📤 Enviando alerta a API:');
        print('URL: $baseUrl/addAlert');
        print('Headers: ${_headers()}');
        print('Body: ${jsonEncode(requestBody)}');

        final response = await http
            .post(
              Uri.parse('$baseUrl/addAlert'),
              headers: _headers(),
              body: jsonEncode(requestBody),
            )
            .timeout(apiTimeout);

        print('📥 Respuesta del API:');
        print('Status Code: ${response.statusCode}');
        print('Body: ${response.body}');

        if (response.statusCode != 201) {
          throw Exception('Error al agregar alerta: ${response.statusCode}');
        }
      } on TimeoutException {
        print('⏰ Timeout al agregar alerta');
      } catch (e) {
        print('❌ Error al enviar alerta a API: $e');
      }
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
        final response = await http
            .put(
              Uri.parse('$baseUrl/resolveAlert/$alertId'),
              headers: _headers(),
              body: jsonEncode({'status': status}),
            )
            .timeout(apiTimeout);
        if (response.statusCode != 200) {
          throw Exception('Error al resolver alerta: ${response.statusCode}');
        }
      } on TimeoutException {
        print('Timeout al resolver alerta');
      } catch (e) {
        print('Error al resolver alerta en API: $e');
      }
    }
  }
}
