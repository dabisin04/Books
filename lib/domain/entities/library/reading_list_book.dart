import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class ReadingListBook extends Equatable {
  final String id;
  final String listId;
  final String bookId;

  static const Uuid _uuid = Uuid();

  ReadingListBook({
    String? id,
    required this.listId,
    required this.bookId,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'list_id': listId,
      'book_id': bookId,
    };
  }

  factory ReadingListBook.fromMap(Map<String, dynamic> map) {
    return ReadingListBook(
      id: map['id'],
      listId: map['list_id'],
      bookId: map['book_id'],
    );
  }

  @override
  List<Object?> get props => [id, listId, bookId];
}
