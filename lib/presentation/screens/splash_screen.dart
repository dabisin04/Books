// ignore_for_file: use_build_context_synchronously
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../application/bloc/user/user_bloc.dart';
import '../../application/bloc/user/user_state.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<UserBloc, UserState>(
      listener: (context, state) async {
        await Future.delayed(const Duration(seconds: 2));
        if (state is UserAuthenticated) {
          Navigator.pushReplacementNamed(context, '/home');
        } else if (state is UserUnauthenticated) {
          Navigator.pushReplacementNamed(context, '/login');
        }
      },
      child: const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}
