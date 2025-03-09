import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../../../domain/entities/book/book.dart';

class RecentBooksCarousel extends StatefulWidget {
  final List<Book> books;

  const RecentBooksCarousel({Key? key, required this.books}) : super(key: key);

  @override
  _RecentBooksCarouselState createState() => _RecentBooksCarouselState();
}

class _RecentBooksCarouselState extends State<RecentBooksCarousel> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Inicia un timer que pasa de página cada 3 segundos
    _timer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentPage < widget.books.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }
      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  /// Genera un degradado aleatorio
  LinearGradient _generateRandomGradient() {
    final random = Random();
    Color randomColor() => Color.fromARGB(
          255,
          random.nextInt(256),
          random.nextInt(256),
          random.nextInt(256),
        );
    final color1 = randomColor();
    final color2 = randomColor();
    final begin =
        Alignment(random.nextDouble() * 2 - 1, random.nextDouble() * 2 - 1);
    final end = Alignment(-begin.x, -begin.y);
    return LinearGradient(
      begin: begin,
      end: end,
      colors: [color1, color2],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.books.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      height: 200, // Altura del carrusel
      child: Stack(
        fit: StackFit.expand,
        children: [
          // PageView que muestra cada libro
          PageView.builder(
            controller: _pageController,
            itemCount: widget.books.length,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemBuilder: (context, index) {
              final book = widget.books[index];
              return _buildBanner(book);
            },
          ),
          // Título fijo "Más Recientes"
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Más Recientes',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          // Indicador de páginas (bolitas) en la parte inferior
          Positioned(
            bottom: 10,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(widget.books.length, (index) {
                final isActive = index == _currentPage;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: isActive ? 10 : 6,
                  height: isActive ? 10 : 6,
                  decoration: BoxDecoration(
                    color: isActive ? Colors.white : Colors.white54,
                    shape: BoxShape.circle,
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBanner(Book book) {
    return Container(
      decoration: BoxDecoration(
        gradient: _generateRandomGradient(),
      ),
      child: Center(
        child: Text(
          book.title,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                blurRadius: 4,
                color: Colors.black45,
                offset: Offset(2, 2),
              ),
            ],
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
