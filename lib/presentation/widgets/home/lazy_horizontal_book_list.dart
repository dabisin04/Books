// ignore_for_file: use_super_parameters, library_private_types_in_public_api

import 'package:flutter/material.dart';
import 'package:books/domain/entities/book/book.dart';
import 'small_book_card.dart';

class LazyHorizontalBookList extends StatefulWidget {
  final String title;
  final List<Book> books;
  final void Function(Book book) onTap;

  const LazyHorizontalBookList({
    Key? key,
    required this.title,
    required this.books,
    required this.onTap,
  }) : super(key: key);

  @override
  _LazyHorizontalBookListState createState() => _LazyHorizontalBookListState();
}

class _LazyHorizontalBookListState extends State<LazyHorizontalBookList> {
  final ScrollController _scrollController = ScrollController();
  int _itemsToShow = 10;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_checkScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_checkScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _checkScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 50 &&
        _itemsToShow < widget.books.length) {
      setState(() {
        _itemsToShow = (_itemsToShow + 10) > widget.books.length
            ? widget.books.length
            : _itemsToShow + 10;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayedBooks = widget.books.take(_itemsToShow).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            widget.title,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8.0),
        SizedBox(
          height: 180,
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            scrollDirection: Axis.horizontal,
            itemCount: displayedBooks.length,
            itemBuilder: (context, index) {
              final book = displayedBooks[index];
              return GestureDetector(
                onTap: () => widget.onTap(book),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: SmallBookCard(book: book),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
