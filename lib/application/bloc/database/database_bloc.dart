import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../domain/ports/database/database_repository.dart';
import 'database_event.dart';
import 'database_state.dart';

class DatabaseBloc extends Bloc<DatabaseEvent, DatabaseState> {
  final DatabaseRepository repository;

  DatabaseBloc({required this.repository}) : super(DatabaseInitial()) {
    on<LoadDatabaseData>((event, emit) async {
      emit(DatabaseLoading());
      try {
        final users = await repository.getUsers();
        final books = await repository.getBooks();
        emit(DatabaseLoaded(users: users, books: books));
      } catch (e) {
        emit(DatabaseError(
            message: "Error al cargar los datos: ${e.toString()}"));
      }
    });
  }
}
