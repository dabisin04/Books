// ignore_for_file: non_constant_identifier_names

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
  final DateTime? publicationDate;
  final int views;
  final double rating;
  final int ratingsCount;
  final int reports;
  final Map<String, dynamic>? content;
  final bool isTrashed;
  final bool has_chapters;
  final String status;
  final String contentType;

  static const Uuid _uuid = Uuid();

  Book({
    String? id,
    required this.title,
    required this.authorId,
    this.description,
    required this.genre,
    this.additionalGenres = const [],
    required this.uploadDate,
    this.publicationDate,
    this.views = 0,
    this.rating = 0.0,
    this.ratingsCount = 0,
    this.reports = 0,
    this.content,
    this.isTrashed = false,
    this.has_chapters = false,
    this.status = 'pending',
    this.contentType = 'book',
  }) : id = id ?? _uuid.v4();

  /// Verifica si el libro ya fue publicado.
  bool get isPublished {
    if (publicationDate == null) return false;
    return publicationDate!.isBefore(DateTime.now()) ||
        publicationDate!.isAtSameMomentAs(DateTime.now());
  }

  /// Retorna una nueva instancia de `Book` con valores modificados.
  Book copyWith({
    String? id,
    String? title,
    String? authorId,
    String? description,
    String? genre,
    List<String>? additionalGenres,
    String? uploadDate,
    DateTime? publicationDate,
    int? views,
    double? rating,
    int? ratingsCount,
    int? reports,
    Map<String, dynamic>? content,
    bool? isTrashed,
    bool? has_chapters,
    String? status,
    String? contentType,
  }) {
    return Book(
      id: id ?? this.id,
      title: title ?? this.title,
      authorId: authorId ?? this.authorId,
      description: description ?? this.description,
      genre: genre ?? this.genre,
      additionalGenres: additionalGenres ?? List.from(this.additionalGenres),
      uploadDate: uploadDate ?? this.uploadDate,
      publicationDate: publicationDate ?? this.publicationDate,
      views: views ?? this.views,
      rating: rating ?? this.rating,
      ratingsCount: ratingsCount ?? this.ratingsCount,
      reports: reports ?? this.reports,
      content: content ?? this.content,
      isTrashed: isTrashed ?? this.isTrashed,
      has_chapters: has_chapters ?? this.has_chapters,
      status: status ?? this.status,
      contentType: contentType ?? this.contentType,
    );
  }

  /// Convierte el objeto `Book` en un `Map<String, dynamic>` para almacenarlo.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'author_id': authorId,
      'description': description,
      'genre': genre,
      'additional_genres': jsonEncode(additionalGenres),
      'upload_date': uploadDate,
      'publication_date': publicationDate?.toIso8601String(),
      'views': views,
      'rating': rating,
      'ratings_count': ratingsCount,
      'reports': reports,
      'content': content != null ? jsonEncode(content) : null,
      'is_trashed': isTrashed ? 1 : 0,
      'has_chapters': has_chapters ? 1 : 0,
      'status': status,
      'content_type': contentType,
    };
  }

  /// Crea un objeto `Book` a partir de un `Map<String, dynamic>`.
  factory Book.fromMap(Map<String, dynamic> map) {
    return Book(
      id: map['id'] ?? _uuid.v4(),
      title: map['title'] ?? 'Sin título',
      authorId: map['author_id'] ?? 'Desconocido',
      description: map['description'],
      genre: map['genre'] ?? 'Sin género',
      additionalGenres: map['additional_genres'] != null
          ? List<String>.from(jsonDecode(map['additional_genres']))
          : [],
      uploadDate: map['upload_date'] ?? DateTime.now().toIso8601String(),
      publicationDate: map['publication_date'] != null
          ? DateTime.tryParse(map['publication_date'])
          : null,
      views: map['views'] ?? 0,
      rating: (map['rating'] as num?)?.toDouble() ?? 0.0,
      ratingsCount: map['ratings_count'] ?? 0,
      reports: map['reports'] ?? 0,
      content: map['content'] != null
          ? jsonDecode(map['content']) as Map<String, dynamic>
          : null,
      isTrashed: map['is_trashed'] == 1,
      has_chapters: map['has_chapters'] == 1,
      status: map['status'] ?? 'pending',
      contentType: map['content_type'] ?? 'book',
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
        publicationDate,
        views,
        rating,
        ratingsCount,
        reports,
        content,
        isTrashed,
        has_chapters,
        status,
        contentType,
      ];
}
