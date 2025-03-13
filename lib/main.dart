import 'package:books/presentation/screens/book/book_details.dart';
import 'package:books/presentation/screens/book/write_book.dart';
import 'package:books/presentation/screens/book/write_book_content.dart';
import 'package:books/presentation/screens/book/read_contet.dart';
import 'package:books/presentation/screens/auth/login.dart';
import 'package:books/presentation/screens/auth/register.dart';
import 'package:books/presentation/screens/home.dart';
import 'package:books/presentation/screens/splash_screen.dart';
import 'package:books/presentation/screens/user/profile.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/domain/theme/app_theme.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/comment/comment_bloc.dart';
import 'package:books/infrastructure/adapters/book_repository_impl.dart';
import 'package:books/infrastructure/adapters/user_repository_impl.dart';
import 'package:books/infrastructure/adapters/comment_repository_impl.dart';
import 'package:books/infrastructure/utils/shared_prefs_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'domain/ports/interaction/comment_repository.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPrefsService().init();

  final userRepository = UserRepositoryImpl(SharedPrefsService());
  final bookRepository = BookRepositoryImpl(SharedPrefsService());
  final commentRepository = CommentRepositoryImpl(SharedPrefsService());

  runApp(MyApp(
    userRepository: userRepository,
    bookRepository: bookRepository,
    commentRepository: commentRepository,
  ));
}

class MyApp extends StatelessWidget {
  final UserRepositoryImpl userRepository;
  final BookRepositoryImpl bookRepository;
  final CommentRepository commentRepository;

  const MyApp({
    super.key,
    required this.userRepository,
    required this.bookRepository,
    required this.commentRepository,
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
        BlocProvider<CommentBloc>(
          create: (_) => CommentBloc(commentRepository),
        ),
      ],
      child: MaterialApp(
        scaffoldMessengerKey: scaffoldMessengerKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        darkTheme: AppTheme.dark,
        localizationsDelegates: const [
          quill.FlutterQuillLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
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
          '/read_content': (context) {
            final book = ModalRoute.of(context)!.settings.arguments as Book;
            return ReadBookContentScreen(book: book);
          },
        },
      ),
    );
  }
}
