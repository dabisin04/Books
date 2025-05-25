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
  final bool sync;
  final String status;
  final DateTime? nameChangeDeadline;
  final bool reportedForName;

  static const Uuid _uuid = Uuid();

  User({
    String? id,
    required this.username,
    required this.email,
    required this.password,
    this.salt,
    this.bio,
    this.isAdmin = false,
    this.sync = false,
    this.status = 'active',
    this.nameChangeDeadline,
    this.reportedForName = false,
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
      'sync': sync ? 1 : 0,
      'status': status,
      'name_change_deadline': nameChangeDeadline?.toIso8601String(),
      'reported_for_name': reportedForName ? 1 : 0,
    };
  }

  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      email: map['email'] as String,
      password: map['password'] as String,
      salt: map['salt'] as String?,
      bio: map['bio'] as String?,
      isAdmin: map['is_admin'] is bool
          ? map['is_admin'] as bool
          : (map['is_admin'] as int? ?? 0) == 1,
      sync: map['sync'] is bool ? map['sync'] : (map['sync'] as int? ?? 0) == 1,
      status: map['status'] as String? ?? 'active',
      nameChangeDeadline: map['name_change_deadline'] != null
          ? DateTime.parse(map['name_change_deadline'] as String)
          : null,
      reportedForName: map['reported_for_name'] is bool
          ? map['reported_for_name'] as bool
          : (map['reported_for_name'] as int? ?? 0) == 1,
    );
  }

  User copyWith({
    String? id,
    String? username,
    String? email,
    String? password,
    String? salt,
    String? bio,
    bool? isAdmin,
    bool? sync,
    String? status,
    DateTime? nameChangeDeadline,
    bool? reportedForName,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      email: email ?? this.email,
      password: password ?? this.password,
      salt: salt ?? this.salt,
      bio: bio ?? this.bio,
      isAdmin: isAdmin ?? this.isAdmin,
      sync: sync ?? this.sync,
      status: status ?? this.status,
      nameChangeDeadline: nameChangeDeadline ?? this.nameChangeDeadline,
      reportedForName: reportedForName ?? this.reportedForName,
    );
  }

  @override
  List<Object?> get props => [
        id,
        username,
        email,
        password,
        salt,
        bio,
        isAdmin,
        sync,
        status,
        nameChangeDeadline,
        reportedForName,
      ];
}
