import 'package:equatable/equatable.dart';

abstract class RatingEvent extends Equatable {
  const RatingEvent();
}

class LoadRatingsEvent extends RatingEvent {
  final String userId;
  final String bookId;

  const LoadRatingsEvent(this.userId, this.bookId);

  @override
  List<Object?> get props => [userId, bookId];
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
