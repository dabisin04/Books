import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Report extends Equatable {
  final String id;
  final String reporterId; // Quien reporta
  final String
      targetId; // A quién o qué se reporta (usuario, libro o comentario)
  final String targetType; // 'user', 'book', 'comment'
  final String reason; // Motivo (texto corto)
  final String? details; // Detalle opcional del problema
  final String status; // 'pending', 'review', 'alert', 'dismissed', etc.
  final DateTime timestamp; // Cuándo se hizo el reporte
  final String? adminId; // Moderador que lo atendió (si aplica)
  final DateTime? resolvedAt; // Cuándo se resolvió (si aplica)

  static const Uuid _uuid = Uuid();

  Report({
    String? id,
    required this.reporterId,
    required this.targetId,
    required this.targetType,
    required this.reason,
    this.details,
    this.status = 'pending',
    DateTime? timestamp,
    this.adminId,
    this.resolvedAt,
  })  : id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'target_id': targetId,
      'target_type': targetType,
      'reason': reason,
      'details': details,
      'status': status,
      'timestamp': timestamp.toIso8601String(),
      'admin_id': adminId,
      'resolved_at': resolvedAt?.toIso8601String(),
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'],
      reporterId: map['reporter_id'],
      targetId: map['target_id'],
      targetType: map['target_type'],
      reason: map['reason'],
      details: map['details'],
      status: map['status'],
      timestamp: DateTime.parse(map['timestamp']),
      adminId: map['admin_id'],
      resolvedAt: map['resolved_at'] != null
          ? DateTime.tryParse(map['resolved_at'])
          : null,
    );
  }

  @override
  List<Object?> get props => [
        id,
        reporterId,
        targetId,
        targetType,
        reason,
        details,
        status,
        timestamp,
        adminId,
        resolvedAt,
      ];
}
