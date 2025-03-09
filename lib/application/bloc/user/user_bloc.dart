import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import '../../../domain/entities/user/user.dart';
import '../../../domain/ports/user/user_repository.dart';
import 'user_event.dart';
import 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository userRepository;

  UserBloc({required this.userRepository}) : super(UserInitial()) {
    on<LoginUser>(_onLoginUser);
    on<LogoutUser>(_onLogoutUser);
    on<LoadUserData>(_onLoadUserData);
    on<RegisterUser>(_onRegisterUser);
  }

  Future<void> _onLoginUser(LoginUser event, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final user = await userRepository.loginUser(event.email, event.password);
      if (user != null) {
        emit(UserAuthenticated(user: user));
      } else {
        emit(const UserError(message: "Credenciales incorrectas"));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  Future<void> _onLogoutUser(LogoutUser event, Emitter<UserState> emit) async {
    try {
      await userRepository.logout();
      emit(UserUnauthenticated());
    } catch (e) {
      emit(UserError(message: "Error al cerrar sesión"));
    }
  }

  Future<void> _onLoadUserData(
      LoadUserData event, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final users = await userRepository.searchUsers(event.userId);
      if (users.isNotEmpty) {
        emit(UserAuthenticated(user: users.first));
      } else {
        emit(const UserError(message: "Usuario no encontrado"));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  Future<void> _onRegisterUser(
      RegisterUser event, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final String userId = Uuid().v4();
      final user = User(
        id: userId,
        username: event.username,
        email: event.email,
        password: event.password,
        bio: '',
        isAdmin: false,
      );

      await userRepository.registerUser(user);

      // Agregar login automático
      final loggedUser =
          await userRepository.loginUser(event.email, event.password);
      if (loggedUser != null) {
        emit(UserAuthenticated(user: loggedUser));
      } else {
        emit(
            UserError(message: "Error al iniciar sesión después del registro"));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }
}
