import '../../entities/library/reading_list.dart';

abstract class ReadingListRepository {
  Future<void> addBookToReadingList(String userId, String bookId);
  Future<void> removeBookFromReadingList(String userId, String bookId);
  Future<List<ReadingList>> getUserReadingLists(String userId);
}
