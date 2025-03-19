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
  final Map<String, dynamic>? content; // Se almacena el Delta en forma de Map
  final bool isTrashed;

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
  }) : id = id ?? _uuid.v4();

  /// Verifica si el libro ya fue publicado
  bool get isPublished {
    if (publicationDate == null) return false;
    return publicationDate!.isBefore(DateTime.now()) ||
        publicationDate!.isAtSameMomentAs(DateTime.now());
  }

  /// Retorna una nueva instancia de `Book` con valores modificados
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
    );
  }

  /// Convierte el objeto `Book` en un `Map<String, dynamic>` para almacenarlo
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
      // Se codifica el contenido (Delta) a un JSON string
      'content': content != null ? jsonEncode(content) : null,
      'is_trashed': isTrashed ? 1 : 0,
    };
  }

  /// Crea un objeto `Book` a partir de un `Map<String, dynamic>`
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
      // Se decodifica el JSON en un Map
      content: map['content'] != null
          ? jsonDecode(map['content']) as Map<String, dynamic>
          : null,
      isTrashed: map['is_trashed'] == 1,
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
      ];
}
