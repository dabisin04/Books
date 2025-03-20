import 'package:books/domain/entities/book/chapter.dart';
import 'package:equatable/equatable.dart';

abstract class ChapterState extends Equatable {
  const ChapterState();
}

class ChapterInitial extends ChapterState {
  @override
  List<Object?> get props => [];
}

class ChapterLoading extends ChapterState {
  @override
  List<Object?> get props => [];
}

class ChapterLoaded extends ChapterState {
  final List<Chapter> chapters;
  const ChapterLoaded(this.chapters);

  @override
  List<Object?> get props => [chapters];
}

class ChapterError extends ChapterState {
  final String message;
  const ChapterError(this.message);

  @override
  List<Object?> get props => [message];
}
