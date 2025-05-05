import 'package:books/domain/entities/book/book.dart';
import 'package:books/domain/ports/user/user_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';
import '../../../domain/ports/book/book_repository.dart';
import 'book_event.dart';
import 'book_state.dart';

class BookBloc extends Bloc<BookEvent, BookState> {
  final BookRepository bookRepository;
  final UserRepository userRepository;

  BookBloc(this.bookRepository, this.userRepository) : super(BookInitial()) {
    on<LoadBooks>(_onLoadBooks);
    on<GetBookByIdEvent>(_onGetBookById);
    on<AddBook>(_onAddBook);
    on<DeleteBook>(_onDeleteBook);
    on<UpdateBookViews>(_onUpdateBookViews);
    on<RateBook>(_onRateBook);
    on<SearchBooks>(_onSearchBooks);
    on<GetBooksByAuthor>(_onGetBooksByAuthor);
    on<GetTopRatedBooks>(_onGetTopRatedBooks);
    on<GetMostViewedBooks>(_onGetMostViewedBooks);
    on<UpdateBookContent>(_onUpdateBookContent);
    on<UpdateBookPublicationDate>(_onUpdateBookPublicationDate);
    on<UpdateBookDetails>(_onUpdateBookDetails);
    on<TrashBook>(_onTrashBook);
    on<GetTrashedBooksByAuthor>(_onGetTrashedBooksByAuthor);
    on<RestoreBook>(_onRestoreBook);
  }

  Future<void> _onLoadBooks(LoadBooks event, Emitter<BookState> emit) async {
    emit(BookLoading());
    try {
      final books = await bookRepository.fetchBooks();
      emit(BookLoaded(books));
    } catch (e, stackTrace) {
      debugPrint('Error en _onLoadBooks: $e\n$stackTrace');
      emit(const BookError("Error al cargar libros"));
    }
  }

  Future<void> _onGetBookById(
    GetBookByIdEvent event,
    Emitter<BookState> emit,
  ) async {
    emit(BookLoading());
    try {
      final book = await bookRepository.getBookById(event.bookId);
      if (book != null) {
        emit(BookFoundById(book));
      } else {
        emit(const BookError('Libro no encontrado.'));
      }
    } catch (e) {
      emit(BookError("Error al obtener el libro: $e"));
    }
  }

  Future<void> _onAddBook(AddBook event, Emitter<BookState> emit) async {
    try {
      final userId = await userRepository.getCurrentUserId();
      if (userId == null) {
        emit(const BookError("Error: Usuario no autenticado"));
        return;
      }

      final newBook = event.book.copyWith(authorId: userId);

      await bookRepository.addBook(newBook);
      emit(BookAdded(newBook));

      final updatedBooks = state is BookLoaded
          ? [...(state as BookLoaded).books, newBook]
          : [newBook];

      emit(BookLoaded(updatedBooks));
    } catch (e, stackTrace) {
      debugPrint('Error en _onAddBook: $e\n$stackTrace');
      emit(BookError("Error al agregar el libro: ${e.toString()}"));
    }
  }

  Future<void> _onDeleteBook(DeleteBook event, Emitter<BookState> emit) async {
    try {
      await bookRepository.deleteBook(event.bookId);
      final updatedBooks = (state as BookLoaded)
          .books
          .where((book) => book.id != event.bookId)
          .toList();
      emit(BookLoaded(updatedBooks));
    } catch (e, stackTrace) {
      debugPrint('Error en _onDeleteBook: $e\n$stackTrace');
      emit(const BookError("Error al eliminar libro"));
    }
  }

  Future<void> _onUpdateBookViews(
      UpdateBookViews event, Emitter<BookState> emit) async {
    try {
      await bookRepository.updateBookViews(event.bookId);
      final updatedBooks = (state as BookLoaded).books.map((book) {
        return book.id == event.bookId
            ? book.copyWith(views: book.views + 1)
            : book;
      }).toList();
      emit(BookLoaded(updatedBooks));
    } catch (e, stackTrace) {
      debugPrint('Error en _onUpdateBookViews: $e\n$stackTrace');
      emit(const BookError("Error al actualizar vistas"));
    }
  }

  Future<void> _onRateBook(RateBook event, Emitter<BookState> emit) async {
    try {
      await bookRepository.rateBook(
          event.bookId, event.userId, event.rating.toDouble());
      final updatedBooks = (state as BookLoaded).books.map((book) {
        return book.id == event.bookId
            ? book.copyWith(rating: event.rating.toDouble())
            : book;
      }).toList();
      emit(BookLoaded(updatedBooks));
    } catch (e, stackTrace) {
      debugPrint('Error en _onRateBook: $e\n$stackTrace');
      emit(const BookError("Error al calificar libro"));
    }
  }

  Future<void> _onSearchBooks(
      SearchBooks event, Emitter<BookState> emit) async {
    try {
      final books = await bookRepository.searchBooks(event.query);
      emit(BookLoaded(books));
    } catch (e, stackTrace) {
      debugPrint('Error en _onSearchBooks: $e\n$stackTrace');
      emit(const BookError("Error en la búsqueda"));
    }
  }

  Future<void> _onGetBooksByAuthor(
      GetBooksByAuthor event, Emitter<BookState> emit) async {
    try {
      final books = await bookRepository.getBooksByAuthor(event.authorId);
      emit(BookLoaded(books));
    } catch (e, stackTrace) {
      debugPrint('Error en _onGetBooksByAuthor: $e\n$stackTrace');
      emit(const BookError("Error al obtener libros por autor"));
    }
  }

  Future<void> _onGetTopRatedBooks(
      GetTopRatedBooks event, Emitter<BookState> emit) async {
    try {
      final books = await bookRepository.getTopRatedBooks();
      emit(BookLoaded(books));
    } catch (e, stackTrace) {
      debugPrint('Error en _onGetTopRatedBooks: $e\n$stackTrace');
      emit(const BookError("Error al obtener libros mejor calificados"));
    }
  }

  Future<void> _onGetMostViewedBooks(
      GetMostViewedBooks event, Emitter<BookState> emit) async {
    try {
      final books = await bookRepository.getMostViewedBooks();
      emit(BookLoaded(books));
    } catch (e, stackTrace) {
      debugPrint('Error en _onGetMostViewedBooks: $e\n$stackTrace');
      emit(const BookError("Error al obtener libros más vistos"));
    }
  }

  Future<void> _onUpdateBookContent(
      UpdateBookContent event, Emitter<BookState> emit) async {
    if (state is BookLoaded) {
      try {
        await bookRepository.updateBookContent(event.bookId, event.content);

        final updatedBooks = (state as BookLoaded).books.map((book) {
          return book.id == event.bookId
              ? book.copyWith(content: event.content)
              : book;
        }).toList();

        emit(BookLoaded(updatedBooks));
      } catch (e, stackTrace) {
        debugPrint('Error en _onUpdateBookContent: $e\n$stackTrace');
        emit(const BookError("Error al actualizar contenido"));
      }
    } else {
      emit(const BookError("Estado inválido para actualizar contenido"));
    }
  }

  Future<void> _onUpdateBookPublicationDate(
      UpdateBookPublicationDate event, Emitter<BookState> emit) async {
    if (state is BookLoaded) {
      try {
        await bookRepository.updateBookPublicationDate(
            event.bookId, event.publicationDate);

        final updatedBooks = (state as BookLoaded).books.map((book) {
          return book.id == event.bookId
              ? book.copyWith(
                  publicationDate: event.publicationDate != null
                      ? DateTime.tryParse(event.publicationDate!)
                      : null)
              : book;
        }).toList();

        emit(BookLoaded(updatedBooks));
      } catch (e, stackTrace) {
        debugPrint('Error en _onUpdateBookPublicationDate: $e\n$stackTrace');
        emit(const BookError("Error al actualizar fecha de publicación"));
      }
    } else {
      emit(const BookError(
          "Estado inválido para actualizar fecha de publicación"));
    }
  }

  Future<void> _onUpdateBookDetails(
      UpdateBookDetails event, Emitter<BookState> emit) async {
    try {
      await bookRepository.updateBookDetails(
        event.bookId,
        title: event.title,
        description: event.description,
        additionalGenres: event.additionalGenres,
        genre: event.genre,
        contentType: event.contentType,
      );

      final updatedBooks = (state as BookLoaded).books.map((book) {
        return book.id == event.bookId
            ? book.copyWith(
                title: event.title ?? book.title,
                description: event.description ?? book.description,
                additionalGenres:
                    event.additionalGenres ?? book.additionalGenres,
                genre: event.genre ?? book.genre,
                contentType: event.contentType ?? book.contentType,
              )
            : book;
      }).toList();

      emit(BookLoaded(updatedBooks));
    } catch (e, stackTrace) {
      debugPrint('Error en _onUpdateBookDetails: $e\n$stackTrace');
      emit(const BookError("Error al actualizar detalles del libro"));
    }
  }

  Future<void> _onTrashBook(TrashBook event, Emitter<BookState> emit) async {
    try {
      await bookRepository.trashBook(event.bookId);
      final updatedBooks = (state as BookLoaded)
          .books
          .where((book) => book.id != event.bookId)
          .toList();
      emit(BookLoaded(updatedBooks));
    } catch (e, stackTrace) {
      debugPrint('Error en _onTrashBook: $e\n$stackTrace');
      emit(const BookError("Error al mover el libro a la papelera"));
    }
  }

  Future<void> _onGetTrashedBooksByAuthor(
      GetTrashedBooksByAuthor event, Emitter<BookState> emit) async {
    emit(BookLoading());
    try {
      final books = await bookRepository.fetchBooks(trashed: true);
      final trashedBooks =
          books.where((book) => book.authorId == event.authorId).toList();
      emit(BookLoaded(trashedBooks));
    } catch (e, stackTrace) {
      debugPrint('Error en _onGetTrashedBooksByAuthor: $e\n$stackTrace');
      emit(const BookError("Error al cargar libros en papelera"));
    }
  }

  Future<void> _onRestoreBook(
      RestoreBook event, Emitter<BookState> emit) async {
    try {
      await bookRepository.restoreBook(event.bookId);
      if (state is BookLoaded) {
        final currentBooks = (state as BookLoaded).books;
        Book? restoredBook;
        try {
          restoredBook = currentBooks.firstWhere((b) => b.id == event.bookId);
        } catch (_) {
          restoredBook = null;
        }
        final updatedBooks =
            currentBooks.where((b) => b.id != event.bookId).toList();
        if (restoredBook != null) {
          emit(BookRestored(restoredBook));
        }
        emit(BookLoaded(updatedBooks));
      }
    } catch (e, stackTrace) {
      debugPrint('Error en _onRestoreBook: $e\n$stackTrace');
      emit(const BookError("Error al restaurar el libro"));
    }
  }
}
