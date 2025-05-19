import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Strike extends Equatable {
  final String id;
  final String userId;
  final String reason;
  final DateTime dateIssued;
  final String? relatedEntityId; // e.g. commentId, bookId
  final String? entityType; // 'comment', 'book', etc.
  final bool justified; // Si fue confirmado como válido
  final bool resolved;

  static const Uuid _uuid = Uuid();

  Strike({
    String? id,
    required this.userId,
    required this.reason,
    required this.dateIssued,
    this.relatedEntityId,
    this.entityType,
    this.justified = true,
    this.resolved = false,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'reason': reason,
      'date_issued': dateIssued.toIso8601String(),
      'related_entity_id': relatedEntityId,
      'entity_type': entityType,
      'justified': justified ? 1 : 0,
      'resolved': resolved ? 1 : 0,
    };
  }

  factory Strike.fromMap(Map<String, dynamic> map) {
    return Strike(
      id: map['id'],
      userId: map['user_id'],
      reason: map['reason'],
      dateIssued: DateTime.parse(map['date_issued']),
      relatedEntityId: map['related_entity_id'],
      entityType: map['entity_type'],
      justified: map['justified'] == 1,
      resolved: map['resolved'] == 1,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        reason,
        dateIssued,
        relatedEntityId,
        entityType,
        justified,
        resolved
      ];
}
