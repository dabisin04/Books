import 'package:equatable/equatable.dart';

abstract class DatabaseState extends Equatable {
  @override
  List<Object> get props => [];
}

class DatabaseInitial extends DatabaseState {}

class DatabaseLoading extends DatabaseState {}

class DatabaseLoaded extends DatabaseState {
  final List<Map<String, dynamic>> users;
  final List<Map<String, dynamic>> books;

  DatabaseLoaded({required this.users, required this.books});

  @override
  List<Object> get props => [users, books];
}

class DatabaseError extends DatabaseState {
  final String message;

  DatabaseError({required this.message});

  @override
  List<Object> get props => [message];
}
