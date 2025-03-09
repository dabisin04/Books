import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../application/bloc/user/user_bloc.dart';
import '../../../application/bloc/user/user_event.dart';
import '../../../application/bloc/user/user_state.dart';
import '../../widgets/global/custom_button.dart';
import '../../widgets/global/custom_text_field.dart';

class LoginScreen extends StatelessWidget {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Bienvenido',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
              const SizedBox(height: 20),
              CustomTextField(
                controller: emailController,
                hintText: 'Email',
              ),
              const SizedBox(height: 10),
              CustomTextField(
                controller: passwordController,
                hintText: 'Contraseña',
                obscureText: true,
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: 'Iniciar Sesión',
                onPressed: () {
                  BlocProvider.of<UserBloc>(context).add(
                    LoginUser(
                      email: emailController.text,
                      password: passwordController.text,
                    ),
                  );
                },
              ),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: const Text('¿No tienes cuenta? Regístrate'),
              ),
              BlocConsumer<UserBloc, UserState>(
                listener: (context, state) {
                  if (state is UserAuthenticated) {
                    Navigator.pushReplacementNamed(context, '/home');
                  } else if (state is UserError) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Error: ${state.message}")));
                  }
                },
                builder: (context, state) {
                  if (state is UserLoading) {
                    return const CircularProgressIndicator();
                  } else if (state is UserError) {
                    return Text(
                      state.message,
                      style: const TextStyle(color: Colors.red),
                    );
                  }
                  return Container();
                },
              )
            ],
          ),
        ),
      ),
    );
  }
}
