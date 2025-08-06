import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/book_loan.dart';

class BookCard extends StatelessWidget {
  final BookLoan book;

  const BookCard({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final formattedTime = book.loanedAt != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(book.loanedAt!)
        : 'Unknown';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade50, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withOpacity(0.08),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Book Icon Section
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.menu_book, color: Colors.blue, size: 28),
          ),
          const SizedBox(width: 16),

          // Book Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  book.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.qr_code, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text("ID: ${book.isbn}", style: _infoStyle()),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.train, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(book.metro, style: _infoStyle()),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 4),
                    Text(formattedTime, style: _infoStyle()),
                  ],
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Helper TextStyle for secondary info
  TextStyle _infoStyle() {
    return const TextStyle(fontSize: 13, color: Colors.black54);
  }
}
