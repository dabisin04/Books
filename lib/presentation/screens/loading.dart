import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../application/bloc/book/book_bloc.dart';
import '../../application/bloc/book/book_event.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  _LoadingScreenState createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  void _navigateToHome() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted) return;

    // Cargar libros antes de navegar
    context.read<BookBloc>().add(LoadBooks());

    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home',
      (Route<dynamic> route) => false,
      arguments: {'initialTab': 4}, // 4 corresponde a la pestaña de Perfil
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
