import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:books/application/bloc/rating/rating_bloc.dart';
import 'package:books/application/bloc/rating/rating_event.dart';
import 'package:books/application/bloc/rating/rating_state.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/user/user_state.dart';
import 'package:books/domain/entities/interaction/book_rating.dart';

class RatingModal extends StatefulWidget {
  final String bookId;

  // ← Aquí defines el callback opcional
  final void Function()? onRated;

  const RatingModal({
    super.key,
    required this.bookId,
    this.onRated, // ← Lo añades al constructor
  });

  @override
  _RatingModalState createState() => _RatingModalState();
}

class _RatingModalState extends State<RatingModal> {
  double _currentRating = 0.0;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;
  int _currentPage = 1;
  static const int _ratingsPerPage = 10;
  late final RatingBloc _ratingBloc;

  @override
  void initState() {
    super.initState();
    _ratingBloc = context.read<RatingBloc>();
    _loadInitialRatings();
    _scrollController.addListener(_onScroll);
  }

  void _loadInitialRatings() {
    final userState = context.read<UserBloc>().state;
    if (userState is UserAuthenticated) {
      // Primero limpiamos el estado actual
      _ratingBloc.add(ClearRatingsEvent());
      // Luego cargamos las calificaciones
      _ratingBloc.add(LoadRatingsEvent(
        userState.user.id,
        widget.bookId,
        page: 1,
        limit: _ratingsPerPage,
      ));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    // Limpiamos el estado al cerrar el modal
    _ratingBloc.add(ClearRatingsEvent());
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreRatings();
    }
  }

  void _loadMoreRatings() {
    if (!_isLoadingMore) {
      setState(() {
        _isLoadingMore = true;
        _currentPage++;
      });
      final userState = context.read<UserBloc>().state;
      if (userState is UserAuthenticated) {
        _ratingBloc.add(LoadRatingsEvent(
          userState.user.id,
          widget.bookId,
          page: _currentPage,
          limit: _ratingsPerPage,
        ));
      }
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _submitRating() {
    final userState = context.read<UserBloc>().state;
    if (userState is UserAuthenticated) {
      _ratingBloc.add(
        SubmitRatingEvent(userState.user.id, widget.bookId, _currentRating),
      );

      // Esperar un momento para que se actualice la base de datos
      Future.delayed(const Duration(milliseconds: 500), () {
        if (widget.onRated != null) {
          widget.onRated!();
        }
        // Limpiamos el estado antes de cerrar
        _ratingBloc.add(ClearRatingsEvent());
        Navigator.pop(context);
      });
    }
  }

  void _deleteRating() {
    final userState = context.read<UserBloc>().state;
    if (userState is UserAuthenticated) {
      _ratingBloc.add(
        DeleteRatingEvent(
          userState.user.id,
          widget.bookId,
        ),
      );

      // Esperar un momento para que se actualice la base de datos
      Future.delayed(const Duration(milliseconds: 500), () {
        if (widget.onRated != null) {
          widget.onRated!();
        }
        // Limpiamos el estado antes de cerrar
        _ratingBloc.add(ClearRatingsEvent());
        Navigator.pop(context);
      });
    }
  }

  Widget _buildUserRating(BookRating rating) {
    return FutureBuilder<String>(
      future: _getUsername(rating.userId),
      builder: (context, snapshot) {
        final username = snapshot.data ?? 'Usuario';
        final initials = username.isNotEmpty ? username[0].toUpperCase() : 'U';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors
                  .primaries[rating.userId.hashCode % Colors.primaries.length],
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              username,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RatingBar.builder(
                  initialRating: rating.rating,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: true,
                  itemCount: 5,
                  itemSize: 16,
                  ignoreGestures: true,
                  itemBuilder: (context, _) => const Icon(
                    Icons.star,
                    color: Colors.amber,
                  ),
                  onRatingUpdate: (rating) {},
                ),
                Text(
                  DateTime.parse(rating.timestamp).toString().split(' ')[0],
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<String> _getUsername(String userId) async {
    try {
      final userState = context.read<UserBloc>().state;
      if (userState is UserAuthenticated && userState.user.id == userId) {
        return userState.user.username;
      }

      final user =
          await context.read<UserBloc>().userRepository.getUserById(userId);
      if (user != null) {
        return user.username;
      }
      return 'Usuario';
    } catch (e) {
      print('Error obteniendo username: $e');
      return 'Usuario';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withOpacity(0.2)),
          ),
        ),
        DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.8,
          builder: (context, scrollController) {
            return Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
              ),
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 5,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[400],
                          borderRadius: BorderRadius.circular(2.5),
                        ),
                      ),
                    ),
                    const Text(
                      "Calificar libro",
                      textAlign: TextAlign.center,
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    BlocConsumer<RatingBloc, RatingState>(
                      listener: (context, state) {
                        if (state is RatingLoaded && state.userRating != null) {
                          setState(() {
                            _currentRating = state.userRating!;
                          });
                        }
                      },
                      builder: (context, state) {
                        if (state is RatingLoading) {
                          return const Center(
                              child: CircularProgressIndicator());
                        } else if (state is RatingLoaded) {
                          return Column(
                            children: [
                              Text(
                                state.userRating == null
                                    ? "Aún no has calificado este libro."
                                    : "Tu calificación actual:",
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              RatingBar.builder(
                                initialRating: _currentRating,
                                minRating: 1,
                                allowHalfRating: true,
                                itemCount: 5,
                                itemBuilder: (context, _) => const Icon(
                                  Icons.star,
                                  color: Colors.amber,
                                ),
                                onRatingUpdate: (rating) {
                                  setState(() => _currentRating = rating);
                                },
                              ),
                              const SizedBox(height: 8),
                              ElevatedButton.icon(
                                icon: const Icon(Icons.check),
                                label: const Text("Enviar calificación"),
                                onPressed: _submitRating,
                              ),
                              if (state.userRating != null)
                                TextButton.icon(
                                  icon: const Icon(Icons.delete),
                                  label: const Text("Eliminar calificación"),
                                  onPressed: _deleteRating,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Colors.red,
                                  ),
                                ),
                              const Divider(height: 32),
                              Text(
                                "Calificación promedio (${state.globalCount} votos):",
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.star,
                                      color: Colors.amber, size: 32),
                                  const SizedBox(width: 8),
                                  Text(
                                    state.globalAverage.toStringAsFixed(1),
                                    style: const TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Column(
                                children: List.generate(5, (index) {
                                  final star = 5 - index;
                                  final count = state.distribution[star] ?? 0;
                                  final percent = state.globalCount > 0
                                      ? (count / state.globalCount)
                                      : 0.0;
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 2.0),
                                    child: Row(
                                      children: [
                                        Text("$star",
                                            style:
                                                const TextStyle(fontSize: 14)),
                                        const Icon(Icons.star,
                                            color: Colors.amber, size: 16),
                                        Expanded(
                                          child: LinearProgressIndicator(
                                            value: percent,
                                            backgroundColor: Colors.grey[300],
                                            color: Colors.amber,
                                          ),
                                        ),
                                        Padding(
                                          padding:
                                              const EdgeInsets.only(left: 8),
                                          child: Text("$count",
                                              style: const TextStyle(
                                                  fontSize: 14)),
                                        ),
                                      ],
                                    ),
                                  );
                                }),
                              ),
                              const Divider(height: 32),
                              const Text(
                                "Calificaciones recientes:",
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: state.userRatings.length + 1,
                                itemBuilder: (context, index) {
                                  if (index == state.userRatings.length) {
                                    return _isLoadingMore
                                        ? const Center(
                                            child: CircularProgressIndicator())
                                        : const SizedBox();
                                  }
                                  return _buildUserRating(
                                      state.userRatings[index]);
                                },
                              ),
                            ],
                          );
                        } else if (state is RatingError) {
                          return Center(child: Text(state.message));
                        } else {
                          return const SizedBox();
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
