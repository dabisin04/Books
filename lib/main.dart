import 'package:books/presentation/screens/book/book_details.dart';
import 'package:books/presentation/screens/home.dart';
import 'package:books/presentation/screens/splash_screen.dart';
import 'package:books/presentation/screens/auth/login.dart';
import 'package:books/presentation/screens/auth/register.dart';
import 'package:books/presentation/screens/user/profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'domain/entities/book/book.dart';
import 'domain/theme/app_theme.dart';
import 'application/bloc/book/book_bloc.dart';
import 'application/bloc/user/user_bloc.dart';
import 'infrastructure/adapters/book_repository_impl.dart';
import 'infrastructure/adapters/user_repository_impl.dart';
import 'infrastructure/utils/shared_prefs_helper.dart';
import 'presentation/screens/book/write_book.dart';
import 'presentation/screens/book/write_book_content.dart';

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
    super.key,
    required this.userRepository,
    required this.bookRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<UserBloc>(
          create: (_) => UserBloc(userRepository: userRepository),
        ),
        BlocProvider<BookBloc>(
          create: (_) => BookBloc(bookRepository, userRepository),
        ),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        // Agrega los delegates de localización
        localizationsDelegates: const [
          quill.FlutterQuillLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        // Define los locales soportados
        supportedLocales: const [
          Locale('en'),
          Locale('es'),
        ],
        initialRoute: '/splash',
        routes: {
          '/splash': (context) => const SplashScreen(),
          '/login': (context) => LoginScreen(),
          '/register': (context) => RegisterScreen(),
          '/home': (context) => const HomeScreen(),
          '/bookDetails': (context) {
            final book = ModalRoute.of(context)!.settings.arguments as Book;
            return BookDetailsScreen(book: book);
          },
          '/profile': (context) => const ProfileScreen(),
          '/write_book': (context) => const WriteBookScreen(),
          '/write_content': (context) {
            final book = ModalRoute.of(context)!.settings.arguments as Book;
            return WriteBookContentScreen(book: book);
          },
        },
      ),
    );
  }
}
