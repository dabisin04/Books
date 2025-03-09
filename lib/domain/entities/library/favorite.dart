import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Favorite extends Equatable {
  final String id;
  final String userId;
  final String bookId;

  static const Uuid _uuid = Uuid();

  Favorite({
    String? id,
    required this.userId,
    required this.bookId,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
    };
  }

  factory Favorite.fromMap(Map<String, dynamic> map) {
    return Favorite(
      id: map['id'],
      userId: map['user_id'],
      bookId: map['book_id'],
    );
  }

  @override
  List<Object?> get props => [id, userId, bookId];
}
