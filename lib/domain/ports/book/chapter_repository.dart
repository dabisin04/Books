import '../../entities/book/chapter.dart';

abstract class ChapterRepository {
  Future<void> addChapter(Chapter chapter);
  Future<void> updateChapter(Chapter chapter);
  Future<void> deleteChapter(String chapterId);
  Future<List<Chapter>> fetchChaptersByBook(String bookId);
  Future<void> updateChapterViews(String chapterId);
  Future<void> rateChapter(String chapterId, String userId, double rating);
  Future<void> updateChapterContent(String chapterId, Map<String, dynamic> content);
  Future<void> updateChapterPublicationDate(String chapterId, String? publicationDate);
  Future<void> updateChapterDetails(String chapterId, {String? title, String? description});
  Future<List<Chapter>> searchChapters(String query);
}
