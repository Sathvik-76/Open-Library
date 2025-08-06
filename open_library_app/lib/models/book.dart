// lib/models/book.dart
class Book {
  final int bookId;
  final String title;
  final String? author; // Optional field
  final int? metroIdCurr; // Current metro ID, optional as it can be null when loaned out

  Book({
    required this.bookId,
    required this.title,
    this.author,
    this.metroIdCurr,
  });

  factory Book.fromJson(Map<String, dynamic> json) {
    return Book(
      bookId: json['book_id'],
      title: json['title'] ?? 'Unknown Title',
      author: json['author'],
      metroIdCurr: json['met_id_curr'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'book_id': bookId,
      'title': title,
      'author': author,
      'met_id_curr': metroIdCurr,
    };
  }
}