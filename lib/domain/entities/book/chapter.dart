import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Chapter extends Equatable {
  final String id;
  final String bookId;
  final String title;
  final Map<String, dynamic>? content;
  final String uploadDate;
  final DateTime? publicationDate;
  final int chapterNumber;
  final int views;
  final double rating;
  final int ratingsCount;
  final int reports;

  static const Uuid _uuid = Uuid();

  Chapter({
    String? id,
    required this.bookId,
    required this.title,
    this.content,
    required this.uploadDate,
    this.publicationDate,
    required this.chapterNumber,
    this.views = 0,
    this.rating = 0.0,
    this.ratingsCount = 0,
    this.reports = 0,
  }) : id = id ?? _uuid.v4();

  Chapter copyWith({
    String? id,
    String? bookId,
    String? title,
    Map<String, dynamic>? content,
    String? uploadDate,
    DateTime? publicationDate,
    int? chapterNumber,
    int? views,
    double? rating,
    int? ratingsCount,
    int? reports,
  }) {
    return Chapter(
      id: id ?? this.id,
      bookId: bookId ?? this.bookId,
      title: title ?? this.title,
      content: content ?? this.content,
      uploadDate: uploadDate ?? this.uploadDate,
      publicationDate: publicationDate ?? this.publicationDate,
      chapterNumber: chapterNumber ?? this.chapterNumber,
      views: views ?? this.views,
      rating: rating ?? this.rating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      reports: reports ?? this.reports,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'book_id': bookId,
      'title': title,
      'content': content != null ? jsonEncode(content) : null,
      'upload_date': uploadDate,
      'publication_date': publicationDate?.toIso8601String(),
      'chapter_number': chapterNumber,
      'views': views,
      'rating': rating,
      'ratings_count': ratingsCount,
      'reports': reports,
    };
  }

  factory Chapter.fromMap(Map<String, dynamic> map) {
    return Chapter(
      id: map['id'] ?? _uuid.v4(),
      bookId: map['book_id'] ?? '',
      title: map['title'] ?? '',
      content: map['content'] != null
          ? jsonDecode(map['content']) as Map<String, dynamic>
          : null,
      uploadDate: map['upload_date'] ?? DateTime.now().toIso8601String(),
      publicationDate: map['publication_date'] != null
          ? DateTime.tryParse(map['publication_date'])
          : null,
      chapterNumber: map['chapter_number'] ?? 0,
      views: map['views'] ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: map['ratings_count'] ?? 0,
      reports: map['reports'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        bookId,
        title,
        content,
        uploadDate,
        publicationDate,
        chapterNumber,
        views,
        rating,
        ratingsCount,
        reports,
      ];
}
