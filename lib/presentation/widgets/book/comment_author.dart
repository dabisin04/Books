import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/ports/user/user_repository.dart';

class CommentAuthor extends StatelessWidget {
  final String userId;

  const CommentAuthor({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    // Se asume que UserRepository está disponible mediante RepositoryProvider
    final userRepository = context.read<UserRepository>();
    return FutureBuilder(
      future: userRepository.getUserById(userId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Text(userId,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
        }
        if (snapshot.hasData && snapshot.data != null) {
          // Se muestra el username obtenido
          return Text(snapshot.data!.username,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
        }
        return Text(userId,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));
      },
    );
  }
}
