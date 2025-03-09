import 'package:equatable/equatable.dart';

abstract class DatabaseEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoadDatabaseData extends DatabaseEvent {}
