import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Report extends Equatable {
  final String id;
  final String reporterId;
  final String targetId;
  final String targetType; // 'book' o 'comment'
  final String reason;
  final String status; // 'pending', 'reviewed', 'dismissed'
  final String? adminId;

  static const Uuid _uuid = Uuid();

  Report({
    String? id,
    required this.reporterId,
    required this.targetId,
    required this.targetType,
    required this.reason,
    this.status = 'pending',
    this.adminId,
  }) : id = id ?? _uuid.v4(); // Genera un UUID si no se proporciona

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'reporter_id': reporterId,
      'target_id': targetId,
      'target_type': targetType,
      'reason': reason,
      'status': status,
      'admin_id': adminId,
    };
  }

  factory Report.fromMap(Map<String, dynamic> map) {
    return Report(
      id: map['id'],
      reporterId: map['reporter_id'],
      targetId: map['target_id'],
      targetType: map['target_type'],
      reason: map['reason'],
      status: map['status'],
      adminId: map['admin_id'],
    );
  }

  @override
  List<Object?> get props =>
      [id, reporterId, targetId, targetType, reason, status, adminId];
}
