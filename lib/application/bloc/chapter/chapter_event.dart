import 'package:books/domain/entities/book/chapter.dart';
import 'package:equatable/equatable.dart';

abstract class ChapterEvent extends Equatable {
  const ChapterEvent();
}

class LoadChaptersByBook extends ChapterEvent {
  final String bookId;
  const LoadChaptersByBook(this.bookId);

  @override
  List<Object?> get props => [bookId];
}

class AddChapterEvent extends ChapterEvent {
  final Chapter chapter;
  const AddChapterEvent(this.chapter);

  @override
  List<Object?> get props => [chapter];
}

class UpdateChapterEvent extends ChapterEvent {
  final Chapter chapter;
  const UpdateChapterEvent(this.chapter);

  @override
  List<Object?> get props => [chapter];
}

class DeleteChapterEvent extends ChapterEvent {
  final String chapterId;
  final String bookId; // Para poder recargar los capítulos después
  const DeleteChapterEvent(this.chapterId, this.bookId);

  @override
  List<Object?> get props => [chapterId, bookId];
}
