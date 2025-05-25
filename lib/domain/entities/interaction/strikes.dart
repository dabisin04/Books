import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Strike extends Equatable {
  final String id;
  final String userId;
  final String reason;
  final int strikeCount;
  final bool isActive;

  static const Uuid _uuid = Uuid();

  Strike({
    String? id,
    required this.userId,
    required this.reason,
    this.strikeCount = 1,
    this.isActive = true,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'reason': reason,
      'strike_count': strikeCount,
      'is_active': isActive ? 1 : 0,
    };
  }

  factory Strike.fromMap(Map<String, dynamic> map) {
    return Strike(
      id: map['id'],
      userId: map['user_id'],
      reason: map['reason'],
      strikeCount: map['strike_count'] ?? 1,
      isActive: map['is_active'] == 1,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        reason,
        strikeCount,
        isActive,
      ];
}
