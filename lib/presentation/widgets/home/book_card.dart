import 'dart:math';
import 'package:flutter/material.dart';

class BookCard extends StatelessWidget {
  final String title;
  final double?
      rating; // Si se proporciona, se muestra en la esquina inferior izquierda.
  final int?
      views; // Si se proporciona, se muestra en la esquina inferior derecha.

  const BookCard({
    super.key,
    required this.title,
    this.rating,
    this.views,
  });

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
      width: 120,
      height: 150,
      margin: const EdgeInsets.symmetric(horizontal: 8.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: _generateRandomGradient(),
      ),
      child: Stack(
        children: [
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          if (rating != null)
            Positioned(
              bottom: 8,
              left: 8,
              child: Row(
                children: [
                  const Icon(Icons.star, color: Colors.yellow, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    rating!.toStringAsFixed(1),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
          if (views != null)
            Positioned(
              bottom: 8,
              right: 8,
              child: Row(
                children: [
                  const Icon(Icons.remove_red_eye,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    views.toString(),
                    style: const TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
