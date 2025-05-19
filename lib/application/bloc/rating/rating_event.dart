import 'package:equatable/equatable.dart';

abstract class RatingEvent extends Equatable {
  const RatingEvent();
}

class ClearRatingsEvent extends RatingEvent {
  const ClearRatingsEvent();

  @override
  List<Object?> get props => [];
}

class LoadRatingsEvent extends RatingEvent {
  final String userId;
  final String bookId;
  final int page;
  final int limit;

  const LoadRatingsEvent(this.userId, this.bookId,
      {this.page = 1, this.limit = 10});

  @override
  List<Object?> get props => [userId, bookId, page, limit];
}

class SubmitRatingEvent extends RatingEvent {
  final String userId;
  final String bookId;
  final double rating;

  const SubmitRatingEvent(this.userId, this.bookId, this.rating);

  @override
  List<Object?> get props => [userId, bookId, rating];
}

class DeleteRatingEvent extends RatingEvent {
  final String userId;
  final String bookId;

  const DeleteRatingEvent(this.userId, this.bookId);

  @override
  List<Object?> get props => [userId, bookId];
}
