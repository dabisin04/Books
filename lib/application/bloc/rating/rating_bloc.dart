import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:books/domain/ports/interaction/rating_repository.dart';
import 'rating_event.dart';
import 'rating_state.dart';

class RatingBloc extends Bloc<RatingEvent, RatingState> {
  final BookRatingRepository ratingRepository;

  RatingBloc({required this.ratingRepository}) : super(RatingInitial()) {
    on<LoadRatingsEvent>(_onLoadRatings);
    on<SubmitRatingEvent>(_onSubmitRating);
    on<DeleteRatingEvent>(_onDeleteRating);
  }

  Future<void> _onLoadRatings(
    LoadRatingsEvent event,
    Emitter<RatingState> emit,
  ) async {
    emit(RatingLoading());
    try {
      final userRating = await ratingRepository.fetchUserRating(
        userId: event.userId,
        bookId: event.bookId,
      );
      final global = await ratingRepository.fetchGlobalAverage(event.bookId);
      final distribution =
          await ratingRepository.fetchDistribution(event.bookId);

      emit(RatingLoaded(
        userRating: userRating,
        globalAverage: global.average,
        globalCount: global.count,
        distribution: distribution,
      ));
    } catch (e) {
      emit(RatingError("Error al cargar calificaciones: $e"));
    }
  }

  Future<void> _onSubmitRating(
    SubmitRatingEvent event,
    Emitter<RatingState> emit,
  ) async {
    try {
      await ratingRepository.upsertRating(
        userId: event.userId,
        bookId: event.bookId,
        rating: event.rating,
      );
      add(LoadRatingsEvent(event.userId, event.bookId));
    } catch (e) {
      emit(RatingError("Error al enviar calificación: $e"));
    }
  }

  Future<void> _onDeleteRating(
    DeleteRatingEvent event,
    Emitter<RatingState> emit,
  ) async {
    try {
      await ratingRepository.deleteRating(
        userId: event.userId,
        bookId: event.bookId,
      );
      add(LoadRatingsEvent(event.userId, event.bookId));
    } catch (e) {
      emit(RatingError("Error al eliminar calificación: $e"));
    }
  }
}
