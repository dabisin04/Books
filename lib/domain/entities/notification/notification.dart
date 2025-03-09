import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class NotificationModel extends Equatable {
  final String id;
  final String userId;
  final String type; // 'new_comment', 'new_rating', 'report_decision'
  final String message;
  final String timestamp;
  final bool isRead;

  static const Uuid _uuid = Uuid();

  NotificationModel({
    String? id,
    required this.userId,
    required this.type,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'type': type,
      'message': message,
      'timestamp': timestamp,
      'is_read': isRead ? 1 : 0,
    };
  }

  factory NotificationModel.fromMap(Map<String, dynamic> map) {
    return NotificationModel(
      id: map['id'],
      userId: map['user_id'],
      type: map['type'],
      message: map['message'],
      timestamp: map['timestamp'],
      isRead: map['is_read'] == 1,
    );
  }

  @override
  List<Object?> get props => [id, userId, type, message, timestamp, isRead];
}
