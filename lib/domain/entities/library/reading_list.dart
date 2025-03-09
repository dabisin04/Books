import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class ReadingList extends Equatable {
  final String id;
  final String userId;
  final String name;

  static const Uuid _uuid = Uuid();

  ReadingList({
    String? id,
    required this.userId,
    required this.name,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'name': name,
    };
  }

  factory ReadingList.fromMap(Map<String, dynamic> map) {
    return ReadingList(
      id: map['id'],
      userId: map['user_id'],
      name: map['name'],
    );
  }

  @override
  List<Object?> get props => [id, userId, name];
}
