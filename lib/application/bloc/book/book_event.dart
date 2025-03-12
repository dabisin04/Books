import 'package:equatable/equatable.dart';
import '../../../domain/entities/book/book.dart';

abstract class BookEvent extends Equatable {
  const BookEvent();

  @override
  List<Object?> get props => [];
}

class LoadBooks extends BookEvent {}

class AddBook extends BookEvent {
  final Book book;

  const AddBook(this.book);

  @override
  List<Object?> get props => [book];
}

class DeleteBook extends BookEvent {
  final String bookId;

  const DeleteBook(this.bookId);

  @override
  List<Object?> get props => [bookId];
}

class UpdateBookViews extends BookEvent {
  final String bookId;

  const UpdateBookViews(this.bookId);

  @override
  List<Object?> get props => [bookId];
}

class RateBook extends BookEvent {
  final String bookId;
  final String userId;
  final int rating;

  const RateBook(this.bookId, this.userId, this.rating);

  @override
  List<Object?> get props => [bookId, userId, rating];
}

class SearchBooks extends BookEvent {
  final String query;

  const SearchBooks(this.query);

  @override
  List<Object?> get props => [query];
}

class GetBooksByAuthor extends BookEvent {
  final String authorId;

  const GetBooksByAuthor(this.authorId);

  @override
  List<Object?> get props => [authorId];
}

class UpdateBookContent extends BookEvent {
  final String bookId;
  final String content;

  const UpdateBookContent(this.bookId, this.content);

  @override
  List<Object?> get props => [bookId, content];
}

class GetTopRatedBooks extends BookEvent {}

class GetMostViewedBooks extends BookEvent {}

class UpdateBookPublicationDate extends BookEvent {
  final String bookId;
  final String? publicationDate;

  const UpdateBookPublicationDate(this.bookId, this.publicationDate);

  @override
  List<Object?> get props => [bookId, publicationDate];
}

class UpdateBookDetails extends BookEvent {
  final String bookId;
  final String? title;
  final List<String>? additionalGenres;
  final String? genre;

  UpdateBookDetails(
      {required this.bookId, this.title, this.additionalGenres, this.genre});
}
