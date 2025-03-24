import 'package:equatable/equatable.dart';
import '../../../domain/entities/user/user.dart';

abstract class UserState extends Equatable {
  const UserState();
  @override
  List<Object?> get props => [];
}

class UserInitial extends UserState {}

class UserLoading extends UserState {}

class UserAuthenticated extends UserState {
  final User user;

  const UserAuthenticated({required this.user});

  @override
  List<Object?> get props => [user];
}

class UserUnauthenticated extends UserState {}

class UserError extends UserState {
  final String message;

  const UserError({required this.message});

  @override
  List<Object?> get props => [message];
}

class UserUpdated extends UserState {
  final User user;
  const UserUpdated({required this.user});
  @override
  List<Object?> get props => [user];
}

class UserPasswordChanged extends UserState {
  final User user;
  const UserPasswordChanged({required this.user});
  @override
  List<Object?> get props => [user];
}
