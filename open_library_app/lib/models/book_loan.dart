class BookLoan {
  final String title;
  final String isbn;
  final String metro;
  final DateTime? loanedAt;

  BookLoan({
    required this.title,
    required this.isbn,
    required this.metro,
    required this.loanedAt,
  });

  factory BookLoan.fromJson(Map<String, dynamic> json) {
    return BookLoan(
      title: json['book_title'] ?? '',
      isbn: json['book_isbn'] ?? '',
      metro: json['metro_name'] ?? '',
      loanedAt: DateTime.tryParse(json['loan_time'] ?? ''),
    );
  }
}
