import 'package:books/domain/ports/book/chapter_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'chapter_event.dart';
import 'chapter_state.dart';

class ChapterBloc extends Bloc<ChapterEvent, ChapterState> {
  final ChapterRepository chapterRepository;

  ChapterBloc({required this.chapterRepository}) : super(ChapterInitial()) {
    on<LoadChaptersByBook>(_onLoadChapters);
    on<AddChapterEvent>(_onAddChapter);
    on<UpdateChapterEvent>(_onUpdateChapter);
    on<DeleteChapterEvent>(_onDeleteChapter);
  }

  Future<void> _onLoadChapters(
      LoadChaptersByBook event, Emitter<ChapterState> emit) async {
    emit(ChapterLoading());
    try {
      final chapters =
          await chapterRepository.fetchChaptersByBook(event.bookId);
      emit(ChapterLoaded(chapters));
    } catch (e) {
      emit(ChapterError("Error al cargar capítulos: $e"));
    }
  }

  Future<void> _onAddChapter(
      AddChapterEvent event, Emitter<ChapterState> emit) async {
    try {
      await chapterRepository.addChapter(event.chapter);
      add(LoadChaptersByBook(event.chapter.bookId));
    } catch (e) {
      emit(ChapterError("Error al agregar capítulo: $e"));
    }
  }

  Future<void> _onUpdateChapter(
      UpdateChapterEvent event, Emitter<ChapterState> emit) async {
    try {
      await chapterRepository.updateChapter(event.chapter);
      add(LoadChaptersByBook(event.chapter.bookId));
    } catch (e) {
      emit(ChapterError("Error al actualizar capítulo: $e"));
    }
  }

  Future<void> _onDeleteChapter(
      DeleteChapterEvent event, Emitter<ChapterState> emit) async {
    try {
      await chapterRepository.deleteChapter(event.chapterId);
      add(LoadChaptersByBook(event.bookId));
    } catch (e) {
      emit(ChapterError("Error al eliminar capítulo: $e"));
    }
  }
}
