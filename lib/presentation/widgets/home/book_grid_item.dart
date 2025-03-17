import 'package:flutter/material.dart';
import 'package:books/domain/entities/book/book.dart';
import 'package:books/presentation/screens/book/book_details.dart';
import 'dart:math';

class BookGridItem extends StatelessWidget {
  final Book book;
  const BookGridItem({super.key, required this.book});

  Color _getRandomGradient() {
    final List<List<Color>> gradients = [
      [Colors.blue, Colors.lightBlueAccent],
      [Colors.purple, Colors.pinkAccent],
      [Colors.green, Colors.lightGreenAccent],
      [Colors.orange, Colors.deepOrangeAccent],
      [Colors.red, Colors.redAccent],
    ];
    return gradients[Random().nextInt(gradients.length)][0];
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => BookDetailsScreen(book: book)),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_getRandomGradient(), Colors.black12],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.book, size: 50, color: Colors.white),
            const SizedBox(height: 8),
            Text(
              book.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}
