import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Comment extends Equatable {
  final String id;
  final String userId;
  final String bookId;
  final String content;
  final String timestamp;
  final String? parentCommentId;
  final int reports;

  static const Uuid _uuid = Uuid();

  Comment({
    String? id,
    required this.userId,
    required this.bookId,
    required this.content,
    required this.timestamp,
    this.parentCommentId,
    this.reports = 0,
  }) : id = id ?? _uuid.v4();

  Comment copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? content,
    String? timestamp,
    String? parentCommentId,
    int? reports,
  }) {
    return Comment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      reports: reports ?? this.reports,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'content': content,
      'timestamp': timestamp,
      'parent_comment_id': parentCommentId,
      'reports': reports,
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id'],
      userId: map['user_id'],
      bookId: map['book_id'],
      content: map['content'],
      timestamp: map['timestamp'],
      parentCommentId: map['parent_comment_id'],
      reports: map['reports'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        bookId,
        content,
        timestamp,
        parentCommentId,
        reports,
      ];
}
