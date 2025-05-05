import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:books/application/bloc/rating/rating_bloc.dart';
import 'package:books/application/bloc/rating/rating_event.dart';
import 'package:books/application/bloc/rating/rating_state.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/user/user_state.dart';

class RatingModal extends StatefulWidget {
  final String bookId;

  const RatingModal({super.key, required this.bookId});

  @override
  _RatingModalState createState() => _RatingModalState();
}

class _RatingModalState extends State<RatingModal> {
  double _currentRating = 0.0;

  @override
  void initState() {
    super.initState();
    final userState = context.read<UserBloc>().state;
    if (userState is UserAuthenticated) {
      context.read<RatingBloc>().add(LoadRatingsEvent(
            userState.user.id,
            widget.bookId,
          ));
    }
  }

  void _submitRating() {
    final userState = context.read<UserBloc>().state;
    if (userState is UserAuthenticated) {
      context.read<RatingBloc>().add(
            SubmitRatingEvent(
              userState.user.id,
              widget.bookId,
              _currentRating,
            ),
          );
    }
  }

  void _deleteRating() {
    final userState = context.read<UserBloc>().state;
    if (userState is UserAuthenticated) {
      context.read<RatingBloc>().add(
            DeleteRatingEvent(
              userState.user.id,
              widget.bookId,
            ),
          );
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
