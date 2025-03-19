import 'package:equatable/equatable.dart';
import '../../../domain/entities/book/book.dart';

abstract class BookState extends Equatable {
  const BookState();

  @override
  List<Object?> get props => [];
}

class BookInitial extends BookState {}

class BookLoading extends BookState {}

class BookLoaded extends BookState {
  final List<Book> books;

  const BookLoaded(this.books);

  @override
  List<Object?> get props => [books];
}

class BookError extends BookState {
  final String message;

  const BookError(this.message);

  @override
  List<Object?> get props => [message];
}

class BookAdded extends BookState {
  final Book book;

  const BookAdded(this.book);

  @override
  List<Object?> get props => [book];
}

class BookUpdated extends BookState {
  final Book book;

  const BookUpdated(this.book);

  @override
  List<Object?> get props => [book];
}

class BookDeleted extends BookState {
  final String bookId;

  const BookDeleted(this.bookId);

  @override
  List<Object?> get props => [bookId];
}

class BookRestored extends BookState {
  final Book book;
  const BookRestored(this.book);
  @override
  List<Object?> get props => [book];
}
