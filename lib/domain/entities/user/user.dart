import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class User extends Equatable {
  final String id;
  final String username;
  final String email;
  final String password;
  final String? salt;
  final String? bio;
  final bool isAdmin;

  static const Uuid _uuid = Uuid();

  User({
    String? id,
    required this.username,
    required this.email,
    required this.password,
    this.salt,
    this.bio,
    this.isAdmin = false,
  }) : id = id ?? _uuid.v4();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'password': password,
      'salt': salt,
      'bio': bio,
      'is_admin': isAdmin ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'],
      username: map['username'],
      email: map['email'],
      password: map['password'],
      salt: map['salt'],
      bio: map['bio'],
      isAdmin: map['is_admin'] == 1,
    );
  }

  @override
  List<Object?> get props =>
      [id, username, email, password, salt, bio, isAdmin];
}
