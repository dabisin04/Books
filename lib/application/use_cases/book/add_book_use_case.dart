import '../../../domain/entities/book/book.dart';
import '../../../domain/ports/book/book_repository.dart';

class AddBookUseCase {
  final BookRepository repository;

  AddBookUseCase(this.repository);

  Future<void> call(Book book) {
    return repository.addBook(book);
  }
}
