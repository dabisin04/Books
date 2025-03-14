import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../application/bloc/user/user_bloc.dart';
import '../../../application/bloc/user/user_event.dart';

class HamburguerMenu extends StatelessWidget {
  const HamburguerMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 16.0),
          ListTile(
            leading: const Icon(Icons.home),
            title: const Text('Inicio'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/home');
            },
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Perfil'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushReplacementNamed(context, '/profile');
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              Navigator.pop(context); // Cierra el drawer
              context
                  .read<UserBloc>()
                  .add(LogoutUser()); // Dispara el evento de cerrar sesión
              Navigator.pushReplacementNamed(
                  context, '/login'); // Redirige a login
            },
          ),
        ],
      ),
    );
  }
}
