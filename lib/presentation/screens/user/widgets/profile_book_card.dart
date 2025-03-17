import 'dart:math';
import 'package:flutter/material.dart';
import 'package:books/domain/entities/book/book.dart';

class ProfileBookCard extends StatelessWidget {
  final Book book;

  const ProfileBookCard({super.key, required this.book});

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
    return Container(
      width: 150,
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: _generateRandomGradient(),
      ),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Row(
          children: [
            Expanded(
              child: Text(
                book.title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: book.isPublished ? Colors.green : Colors.red,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
