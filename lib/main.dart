import 'package:books/presentation/screens/home.dart';
import 'package:books/presentation/screens/splash_screen.dart';
import 'package:books/presentation/screens/auth/login.dart';
import 'package:books/presentation/screens/auth/register.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'domain/theme/app_theme.dart';
import 'application/bloc/book/book_bloc.dart';
import 'application/bloc/user/user_bloc.dart';
import 'infrastructure/adapters/book_repository_impl.dart';
import 'infrastructure/adapters/user_repository_impl.dart';
import 'infrastructure/utils/shared_prefs_helper.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefsService().init();

  final userRepository = UserRepositoryImpl(SharedPrefsService());
  final bookRepository = BookRepositoryImpl(SharedPrefsService());

  runApp(MyApp(
    userRepository: userRepository,
    bookRepository: bookRepository,
  ));
}

class MyApp extends StatelessWidget {
  final UserRepositoryImpl userRepository;
  final BookRepositoryImpl bookRepository;

  const MyApp({
    Key? key,
    required this.userRepository,
    required this.bookRepository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UserBloc>(
          create: (_) => UserBloc(userRepository: userRepository),
        ),
        BlocProvider<BookBloc>(
          create: (_) => BookBloc(bookRepository),
        ),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => LoginScreen(),
          '/register': (context) => RegisterScreen(),
          '/home': (context) => const HomeScreen(),
        },
      ),
    );
  }
}
