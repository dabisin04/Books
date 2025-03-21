// ignore_for_file: depend_on_referenced_packages

import 'package:books/application/bloc/chapter/chapter_bloc.dart';
import 'package:books/application/bloc/user/user_event.dart';
import 'package:books/domain/entities/book/chapter.dart';
import 'package:books/domain/ports/book/chapter_repository.dart';
import 'package:books/infrastructure/adapters/chapter_repository_impl.dart';
import 'package:books/presentation/screens/book/writing/write_book_chapter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:books/domain/entities/book/book.dart';
import 'package:books/domain/ports/book/book_repository.dart';
import 'package:books/domain/ports/user/user_repository.dart';
import 'package:books/domain/ports/interaction/comment_repository.dart';
import 'package:books/domain/theme/app_theme.dart';
import 'package:books/application/bloc/book/book_bloc.dart';
import 'package:books/application/bloc/user/user_bloc.dart';
import 'package:books/application/bloc/comment/comment_bloc.dart';
import 'package:books/infrastructure/adapters/book_repository_impl.dart';
import 'package:books/infrastructure/adapters/user_repository_impl.dart';
import 'package:books/infrastructure/adapters/comment_repository_impl.dart';
import 'package:books/infrastructure/utils/shared_prefs_helper.dart';
import 'package:books/presentation/screens/splash_screen.dart';
import 'package:books/presentation/screens/auth/login.dart';
import 'package:books/presentation/screens/auth/register.dart';
import 'package:books/presentation/screens/home.dart';
import 'package:books/presentation/screens/book/reading/book_details.dart';
import 'package:books/presentation/screens/user/profile.dart';
import 'package:books/presentation/screens/book/writing/write_book.dart';
import 'package:books/presentation/screens/book/writing/write_book_content.dart';
import 'package:books/presentation/screens/book/reading/read_contet.dart';
import 'package:books/presentation/screens/book/trashing/thrash_bin.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  await SharedPrefsService().init();

  final userRepository = UserRepositoryImpl(SharedPrefsService());
  final bookRepository = BookRepositoryImpl(SharedPrefsService());
  final commentRepository = CommentRepositoryImpl(SharedPrefsService());
  final chapterRepository = ChapterRepositoryImpl();

  runApp(MyApp(
    userRepository: userRepository,
    bookRepository: bookRepository,
    commentRepository: commentRepository,
    chapterRepository: chapterRepository,
  ));
}

class MyApp extends StatelessWidget {
  final UserRepositoryImpl userRepository;
  final BookRepositoryImpl bookRepository;
  final CommentRepository commentRepository;
  final ChapterRepositoryImpl chapterRepository;

  const MyApp({
    super.key,
    required this.userRepository,
    required this.bookRepository,
    required this.commentRepository,
    required this.chapterRepository,
  });

  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<UserRepository>(
          create: (_) => userRepository,
        ),
        RepositoryProvider<BookRepository>(
          create: (_) => bookRepository,
        ),
        RepositoryProvider<CommentRepository>(
          create: (_) => commentRepository,
        ),
        RepositoryProvider<ChapterRepository>(
          create: (_) => chapterRepository,
        )
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider<UserBloc>(
            create: (_) => UserBloc(userRepository: userRepository)
              ..add(CheckUserSession()),
          ),
          BlocProvider<BookBloc>(
            create: (_) => BookBloc(bookRepository, userRepository),
          ),
          BlocProvider<CommentBloc>(
            create: (_) => CommentBloc(commentRepository),
          ),
          BlocProvider<ChapterBloc>(
              create: (_) => ChapterBloc(chapterRepository: chapterRepository))
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
            '/write_chapter': (context) {
              final args = ModalRoute.of(context)!.settings.arguments
                  as Map<String, dynamic>;
              final book = args['book'] as Book;
              final chapter = args['chapter'] as Chapter?;
              return WriteChapterScreen(book: book, chapter: chapter);
            },
            '/read_content': (context) {
              final contentEntity = ModalRoute.of(context)!.settings.arguments;
              return ReadBookContentScreen(contentEntity: contentEntity);
            },
            '/trash': (context) => const TrashScreen(),
          },
        ),
      ),
    );
  }
}
