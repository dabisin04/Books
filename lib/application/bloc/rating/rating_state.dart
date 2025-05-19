import 'package:equatable/equatable.dart';
import '../../../domain/entities/interaction/book_rating.dart';

abstract class RatingState extends Equatable {
  const RatingState();

  @override
  List<Object?> get props => [];
}

class RatingInitial extends RatingState {
  @override
  List<Object?> get props => [];
}

class RatingLoading extends RatingState {
  @override
  List<Object?> get props => [];
}

class RatingLoaded extends RatingState {
  final double? userRating;
  final double globalAverage;
  final int globalCount;
  final Map<int, int> distribution;
  final List<BookRating> userRatings;

  const RatingLoaded({
    this.userRating,
    required this.globalAverage,
    required this.globalCount,
    required this.distribution,
    this.userRatings = const [],
  });

  @override
  List<Object?> get props =>
      [userRating, globalAverage, globalCount, distribution, userRatings];
}

class RatingError extends RatingState {
  final String message;

  const RatingError(this.message);

  @override
  List<Object?> get props => [message];
}
