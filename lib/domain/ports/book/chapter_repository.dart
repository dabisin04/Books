import '../../entities/book/chapter.dart';

abstract class ChapterRepository {
  Future<void> addChapter(Chapter chapter);
  Future<void> updateChapter(Chapter chapter);
  Future<void> deleteChapter(String chapterId);
  Future<List<Chapter>> fetchChaptersByBook(String bookId);
}
