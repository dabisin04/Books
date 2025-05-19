import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/domain/ports/interaction/rating_repository.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/book/book_event.dart';
import 'rating_event.dart';
import 'rating_state.dart';

class RatingBloc extends Bloc<RatingEvent, RatingState> {
  final BookRatingRepository ratingRepository;
  final BookBloc bookBloc;

  RatingBloc({
    required this.ratingRepository,
    required this.bookBloc,
  }) : super(RatingInitial()) {
    on<LoadRatingsEvent>(_onLoadRatings);
    on<SubmitRatingEvent>(_onSubmitRating);
    on<DeleteRatingEvent>(_onDeleteRating);
    on<ClearRatingsEvent>(_onClearRatings);
  }

  void _onClearRatings(ClearRatingsEvent event, Emitter<RatingState> emit) {
    emit(RatingInitial());
  }

  Future<void> _onLoadRatings(
    LoadRatingsEvent event,
    Emitter<RatingState> emit,
  ) async {
    print('📊 Cargando calificaciones para libro ${event.bookId}');
    emit(RatingLoading());
    try {
      final userRating = await ratingRepository.fetchUserRating(
        userId: event.userId,
        bookId: event.bookId,
      );
      final global = await ratingRepository.fetchGlobalAverage(event.bookId);
      final distribution =
          await ratingRepository.fetchDistribution(event.bookId);
      final userRatings = await ratingRepository.fetchUserRatings(
        bookId: event.bookId,
        page: event.page,
        limit: event.limit,
      );

      print(
          '📊 Calificaciones cargadas - Promedio: ${global.average}, Votos: ${global.count}');
      emit(RatingLoaded(
        userRating: userRating,
        globalAverage: global.average,
        globalCount: global.count,
        distribution: distribution,
        userRatings: userRatings,
      ));
    } catch (e) {
      print('❌ Error al cargar calificaciones: $e');
      emit(RatingError("Error al cargar calificaciones: $e"));
    }
  }

  Future<void> _onSubmitRating(
    SubmitRatingEvent event,
    Emitter<RatingState> emit,
  ) async {
    print(
        '📝 Enviando calificación: ${event.rating} para libro ${event.bookId}');
    try {
      await ratingRepository.upsertRating(
        userId: event.userId,
        bookId: event.bookId,
        rating: event.rating,
      );

      // Recargar calificaciones
      add(LoadRatingsEvent(event.userId, event.bookId));

      // Forzar recarga de libros para actualizar el promedio
      print('🔄 Forzando recarga de libros después de calificar');
      bookBloc.add(LoadBooks());
    } catch (e) {
      print('❌ Error al enviar calificación: $e');
      emit(RatingError("Error al enviar calificación: $e"));
    }
  }

  Future<void> _onDeleteRating(
    DeleteRatingEvent event,
    Emitter<RatingState> emit,
  ) async {
    print('🗑️ Eliminando calificación para libro ${event.bookId}');
    try {
      await ratingRepository.deleteRating(
        userId: event.userId,
        bookId: event.bookId,
      );

      // Recargar calificaciones
      add(LoadRatingsEvent(event.userId, event.bookId));

      // Forzar recarga de libros para actualizar el promedio
      print('🔄 Forzando recarga de libros después de eliminar calificación');
      bookBloc.add(LoadBooks());
    } catch (e) {
      print('❌ Error al eliminar calificación: $e');
      emit(RatingError("Error al eliminar calificación: $e"));
    }
  }
}
