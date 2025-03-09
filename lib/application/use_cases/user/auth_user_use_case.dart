import '../../../domain/entities/user/user.dart';
import '../../../domain/ports/user/user_repository.dart';
import '../../../infrastructure/utils/shared_prefs_helper.dart';

class AuthUserUseCase {
  final UserRepository userRepository;
  final SharedPrefsService sharedPrefsService;

  AuthUserUseCase({
    required this.userRepository,
    required this.sharedPrefsService,
  });

  /// Inicia sesión con correo y contraseña
  Future<User?> login(String email, String password) async {
    final user = await userRepository.loginUser(email, password);
    if (user != null) {
      await sharedPrefsService.setValue('user_id', user.id);
      await sharedPrefsService.setValue('username', user.username);
      await sharedPrefsService.setValue('email', user.email);
    }
    return user;
  }

  /// Cierra sesión eliminando los datos de SharedPreferences
  Future<void> logout() async {
    await sharedPrefsService.clear();
  }

  /// Registra un usuario
  Future<void> register(User user) async {
    await userRepository.registerUser(user);
  }

  /// Obtiene el usuario almacenado en SharedPreferences
  Future<User?> getStoredUser() async {
    final userId = sharedPrefsService.getValue<String>('user_id');
    final username = sharedPrefsService.getValue<String>('username');
    final email = sharedPrefsService.getValue<String>('email');

    if (userId != null && username != null && email != null) {
      return User(
          id: userId,
          username: username,
          email: email,
          password: '',
          bio: '',
          isAdmin: false);
    }
    return null;
  }
}
