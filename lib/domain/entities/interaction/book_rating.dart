import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class BookRating extends Equatable {
  final String id;
  final String userId;
  final String bookId;
  final int rating;

  static const Uuid _uuid = Uuid();

  BookRating({
    String? id,
    required this.userId,
    required this.bookId,
    required this.rating,
  })  : assert(rating >= 1 && rating <= 5, 'El rating debe estar entre 1 y 5'),
        id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'rating': rating,
    };
  }

  factory BookRating.fromMap(Map<String, dynamic> map) {
    return BookRating(
      id: map['id'],
      userId: map['user_id'],
      bookId: map['book_id'],
      rating: map['rating'],
    );
  }

  @override
  List<Object?> get props => [id, userId, bookId, rating];
}
