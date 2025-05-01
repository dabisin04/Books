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
    on<CheckUserSession>(_onCheckUserSession);
    on<UpdateUserDetails>(_onUpdateUserDetails);
    on<ChangePassword>(_onChangePassword);
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
      emit(const UserError(message: "Error al cerrar sesión"));
    }
  }

  Future<void> _onLoadUserData(
      LoadUserData event, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final user = await userRepository.getUserById(event.userId);
      if (user != null) {
        emit(UserAuthenticated(user: user));
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
      final String userId = const Uuid().v4();
      final user = User(
        id: userId,
        username: event.username,
        email: event.email,
        password: event.password,
        bio: '',
        isAdmin: false,
      );

      await userRepository.registerUser(user);

      final loggedUser =
          await userRepository.loginUser(event.email, event.password);
      if (loggedUser != null) {
        emit(UserAuthenticated(user: loggedUser));
      } else {
        emit(const UserError(
            message: "Error al iniciar sesión después del registro"));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  Future<void> _onCheckUserSession(
      CheckUserSession event, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final user = await userRepository.getUserSession();
      if (user != null) {
        emit(UserAuthenticated(user: user));
      } else {
        emit(UserUnauthenticated());
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  Future<void> _onUpdateUserDetails(
      UpdateUserDetails event, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      await userRepository.updateUser(event.updatedUser);
      emit(UserUpdated(user: event.updatedUser));
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }

  Future<void> _onChangePassword(
      ChangePassword event, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      await userRepository.changePassword(event.userId, event.newPassword);
      final updatedUser = await userRepository.getUserById(event.userId);
      if (updatedUser != null) {
        emit(UserPasswordChanged(user: updatedUser));
      } else {
        emit(const UserError(message: "Error al actualizar la contraseña"));
      }
    } catch (e) {
      emit(UserError(message: e.toString()));
    }
  }
}
