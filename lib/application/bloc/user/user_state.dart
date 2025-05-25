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
  final List<String> followedAuthors;

  const UserAuthenticated({
    required this.user,
    this.followedAuthors = const [],
  });

  @override
  List<Object?> get props => [user, followedAuthors];
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

class UserFollowing extends UserState {
  final String userId;
  final String authorId;
  final bool isFollowing;

  const UserFollowing({
    required this.userId,
    required this.authorId,
    required this.isFollowing,
  });

  @override
  List<Object?> get props => [userId, authorId, isFollowing];
}
