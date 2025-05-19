import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Alert extends Equatable {
  final String id;
  final String targetId;
  final String targetType; // 'book', etc.
  final DateTime alertDate;
  final String reasonSummary;
  final String status; // 'active', 'resolved', 'dismissed'
  final DateTime? resolvedAt;
  final String? adminId;

  static const Uuid _uuid = Uuid();

  Alert({
    String? id,
    required this.targetId,
    required this.targetType,
    required this.alertDate,
    required this.reasonSummary,
    this.status = 'active',
    this.resolvedAt,
    this.adminId,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'target_id': targetId,
      'target_type': targetType,
      'alert_date': alertDate.toIso8601String(),
      'reason_summary': reasonSummary,
      'status': status,
      'resolved_at': resolvedAt?.toIso8601String(),
      'admin_id': adminId,
    };
  }

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'],
      targetId: map['target_id'],
      targetType: map['target_type'],
      alertDate: DateTime.parse(map['alert_date']),
      reasonSummary: map['reason_summary'],
      status: map['status'],
      resolvedAt: map['resolved_at'] != null
          ? DateTime.parse(map['resolved_at'])
          : null,
      adminId: map['admin_id'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        targetId,
        targetType,
        alertDate,
        reasonSummary,
        status,
        resolvedAt,
        adminId,
      ];
}
