import 'dart:math';
import 'package:flutter/material.dart';
import '../../../domain/entities/book/book.dart';
import '../../screens/book/book_details.dart';

class SmallBookCard extends StatelessWidget {
  final Book book;

  const SmallBookCard({Key? key, required this.book}) : super(key: key);

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
    return GestureDetector(
      onTap: () {
        print('Clicked on ${book.title}');
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => BookDetailsScreen(book: book),
          ),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.symmetric(horizontal: 8.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: _generateRandomGradient(),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(4.0),
            child: Text(
              book.title,
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ),
    );
  }
}
