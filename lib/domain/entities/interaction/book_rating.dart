import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class BookRating extends Equatable {
  final String id;
  final String userId;
  final String bookId;
  final double rating;
  final String timestamp;

  static const Uuid _uuid = Uuid();

  BookRating({
    String? id,
    required this.userId,
    required this.bookId,
    required this.rating,
    String? timestamp,
  })  : assert(rating >= 1 && rating <= 5, 'El rating debe estar entre 1 y 5'),
        id = id ?? _uuid.v4(),
        timestamp = timestamp ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'rating': rating,
      'timestamp': timestamp,
    };
  }

  factory BookRating.fromMap(Map<String, dynamic> map) {
    return BookRating(
      id: map['id'],
      userId: map['user_id'],
      bookId: map['book_id'],
      rating: map['rating'],
      timestamp: map['timestamp'],
    );
  }

  @override
  List<Object?> get props => [id, userId, bookId, rating, timestamp];
}
