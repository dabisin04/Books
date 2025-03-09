import 'dart:convert';
import 'package:equatable/equatable.dart';
import 'package:uuid/uuid.dart';

class Book extends Equatable {
  final String id;
  final String title;
  final String authorId;
  final String? description;
  final String genre;
  final List<String> additionalGenres;
  final String uploadDate;
  final int views;
  final double rating;
  final int ratingsCount;
  final int reports;
  final String? content;

  static const Uuid _uuid = Uuid();

  Book({
    String? id,
    required this.title,
    required this.authorId,
    this.description,
    required this.genre,
    this.additionalGenres = const [],
    required this.uploadDate,
    this.views = 0,
    this.rating = 0.0,
    this.ratingsCount = 0,
    this.reports = 0,
    this.content,
  }) : id = id ?? _uuid.v4();

  Book copyWith({
    String? id,
    String? title,
    String? authorId,
    String? description,
    String? genre,
    List<String>? additionalGenres,
    String? uploadDate,
    int? views,
    double? rating,
    int? ratingsCount,
    int? reports,
    String? content,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      authorId: authorId ?? this.authorId,
      description: description ?? this.description,
      genre: genre ?? this.genre,
      additionalGenres: additionalGenres ?? this.additionalGenres,
      uploadDate: uploadDate ?? this.uploadDate,
      views: views ?? this.views,
      rating: rating ?? this.rating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      reports: reports ?? this.reports,
      content: content ?? this.content,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author_id': authorId,
      'description': description,
      'genre': genre,
      'additional_genres': jsonEncode(additionalGenres),
      'upload_date': uploadDate,
      'views': views,
      'rating': rating,
      'ratings_count': ratingsCount,
      'reports': reports,
      'content': content,
    };
  }

  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'],
      title: map['title'],
      authorId: map['author_id'],
      description: map['description'],
      genre: map['genre'],
      additionalGenres: map['additional_genres'] != null
          ? List<String>.from(jsonDecode(map['additional_genres']))
          : [],
      uploadDate: map['upload_date'],
      views: map['views'],
      rating: (map['rating'] as num).toDouble(),
      ratingsCount: map['ratings_count'],
      reports: map['reports'],
      content: map['content'],
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        authorId,
        description,
        genre,
        additionalGenres,
        uploadDate,
        views,
        rating,
        ratingsCount,
        reports,
        content,
      ];
}
