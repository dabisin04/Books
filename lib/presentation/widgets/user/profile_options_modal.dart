// ignore_for_file: use_super_parameters

import 'package:flutter/material.dart';

class ProfileOptionsModal extends StatelessWidget {
  const ProfileOptionsModal({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.edit, color: Colors.blue),
            title: const Text("Editar Perfil"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/edit_profile');
            },
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.lock, color: Colors.blue),
            title: const Text("Cambiar Contraseña"),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/change_password');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
