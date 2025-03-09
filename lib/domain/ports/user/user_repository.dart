import '../../entities/user/user.dart';

abstract class UserRepository {
  Future<void> registerUser(User user);
  Future<User?> loginUser(String email, String password);
  Future<void> updateUserBio(String userId, String bio);
  Future<void> deleteUser(String userId);
  Future<bool> isAdmin(String userId);
  Future<List<User>> searchUsers(String query);
  Future<void> followAuthor(String userId, String authorId);
  Future<void> unfollowAuthor(String userId, String authorId);
  Future<List<String>> getFollowedAuthors(String userId);
  Future<void> logout();
}
