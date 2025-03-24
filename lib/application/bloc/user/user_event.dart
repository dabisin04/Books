import 'package:books/domain/entities/user/user.dart';
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

class UpdateUserDetails extends UserEvent {
  final User updatedUser;
  const UpdateUserDetails({required this.updatedUser});
  @override
  List<Object?> get props => [updatedUser];
}

class ChangePassword extends UserEvent {
  final String userId;
  final String newPassword;

  const ChangePassword({required this.userId, required this.newPassword});

  @override
  List<Object?> get props => [userId, newPassword];
}

class CheckUserSession extends UserEvent {}
