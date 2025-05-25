import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Alert extends Equatable {
  final String id;
  final String bookId;
  final String reportReason;
  final String status; // 'alert', 'removed', 'restored'
  final DateTime createdAt;

  static const Uuid _uuid = Uuid();

  Alert({
    String? id,
    required this.bookId,
    required this.reportReason,
    this.status = 'alert',
    DateTime? createdAt,
  })  : id = id ?? _uuid.v4(),
        createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'report_reason': reportReason,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  factory Alert.fromMap(Map<String, dynamic> map) {
    return Alert(
      id: map['id'],
      bookId: map['book_id'],
      reportReason: map['report_reason'],
      status: map['status'] ?? 'alert',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  @override
  List<Object?> get props => [
        id,
        bookId,
        reportReason,
        status,
        createdAt,
      ];
}
