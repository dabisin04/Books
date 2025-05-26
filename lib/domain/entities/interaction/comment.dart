import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Comment extends Equatable {
  final String id;
  final String userId;
  final String bookId;
  final String content;
  final String timestamp;
  final String? parentCommentId;
  final String? rootCommentId;
  final int reports;

  static const Uuid _uuid = Uuid();

  Comment({
    String? id,
    required this.userId,
    required this.bookId,
    required this.content,
    required this.timestamp,
    this.parentCommentId,
    String? rootCommentId,
    this.reports = 0,
  })  : id = id ?? _uuid.v4(),
        rootCommentId =
            rootCommentId ?? (parentCommentId != null ? parentCommentId : null);

  Comment copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? content,
    String? timestamp,
    String? parentCommentId,
    String? rootCommentId,
    int? reports,
  }) {
    return Comment(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      content: content ?? this.content,
      timestamp: timestamp ?? this.timestamp,
      parentCommentId: parentCommentId ?? this.parentCommentId,
      rootCommentId: rootCommentId ?? this.rootCommentId,
      reports: reports ?? this.reports,
    );
  }

  Map<String, dynamic> toMap({bool fromFlask = false}) {
    return {
      'id': id,
      'user_id': userId,
      'book_id': bookId,
      'content': content,
      'timestamp': timestamp,
      'parent_comment_id': parentCommentId,
      'root_comment_id': rootCommentId,
      'reports': reports,
      if (fromFlask) 'from_flask': true,
    };
  }

  factory Comment.fromMap(Map<String, dynamic> map) {
    return Comment(
      id: map['id']?.toString() ?? _uuid.v4(),
      userId: map['user_id']?.toString() ?? '',
      bookId: map['book_id']?.toString() ?? '',
      content: map['content']?.toString() ?? '',
      timestamp: map['timestamp']?.toString() ?? '',
      parentCommentId: map['parent_comment_id']?.toString(),
      rootCommentId: map['root_comment_id']?.toString(),
      reports: (map['reports'] as num?)?.toInt() ?? 0,
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
        rootCommentId,
        reports,
      ];
}
