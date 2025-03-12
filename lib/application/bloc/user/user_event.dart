import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  const UserEvent();
  @override
  List<Object?> get props => [];
}

class LoginUser extends UserEvent {
  final String email;
  final String password;

  const LoginUser({required this.email, required this.password});

  @override
  List<Object?> get props => [email, password];
}

class LogoutUser extends UserEvent {}

class LoadUserData extends UserEvent {
  final String userId;

  const LoadUserData({required this.userId});

  @override
  List<Object?> get props => [userId];
}

class RegisterUser extends UserEvent {
  final String username;
  final String email;
  final String password;

  const RegisterUser({
    required this.username,
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [username, email, password];
}

class CheckUserSession extends UserEvent {}
