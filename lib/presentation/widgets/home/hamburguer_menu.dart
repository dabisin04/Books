import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../application/bloc/user/user_bloc.dart';
import '../../../application/bloc/user/user_event.dart';

class HamburgerMenu extends StatelessWidget {
  const HamburgerMenu({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: ListView(
        // Quita el gran encabezado reemplazándolo por un SizedBox de pequeño tamaño
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
              // Aquí puedes agregar navegación a perfil si es necesario.
            },
          ),
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Cerrar sesión'),
            onTap: () {
              Navigator.pop(context);
              context.read<UserBloc>().add(LogoutUser());
            },
          ),
        ],
      ),
    );
  }
}
