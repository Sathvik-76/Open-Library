import 'package:flutter/material.dart';
import 'package:open_library_app/models/book_loan.dart';
import 'package:open_library_app/models/user.dart';
import 'package:open_library_app/screens/book_action_screen.dart';
import 'package:open_library_app/screens/login_screen.dart';
import 'package:open_library_app/services/api_service.dart';
import 'package:open_library_app/widgets/book_card.dart';

class HomeScreen extends StatefulWidget {
  final User user;

  const HomeScreen({super.key, required this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<BookLoan> borrowedBooks = [];
  bool isLoading = true;
  String searchQuery = '';

  @override
  void initState() {
    super.initState();
    fetchBorrowedBooks();
  }

  Future<void> fetchBorrowedBooks() async {
    try {
      final jsonList = await ApiService().fetchUserLoans(widget.user.mobileNo);
      setState(() {
        borrowedBooks = jsonList.map((e) => BookLoan.fromJson(e)).toList();
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        borrowedBooks = [];
        isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching loans: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBooks = borrowedBooks.where((book) {
      return book.title.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(120),
        child: AppBar(
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.blueAccent, Colors.green],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          elevation: 0,
          automaticallyImplyLeading: false,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("Open Library",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 24)),
              Text("Welcome, ${widget.user.userName}",
                  style: const TextStyle(fontSize: 16, color: Colors.white70)),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Logout",
              onPressed: () async {
                await ApiService().logoutUser();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const MainLoginScreen()),
                  (_) => false,
                );
              },
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(60),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: _buildSearchBar(),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: fetchBorrowedBooks,
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildMetroBanner(),
                  const SizedBox(height: 20),
                  filteredBooks.isEmpty
                      ? _buildEmptyState()
                      : _buildBorrowedBooksList(filteredBooks),
                  const SizedBox(height: 30),
                  _buildReminder(),
                ],
              ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 45,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
      ),
      child: TextField(
        decoration: const InputDecoration(
          hintText: "Search your borrowed books...",
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: EdgeInsets.symmetric(vertical: 10),
        ),
        onChanged: (value) {
          setState(() => searchQuery = value);
        },
      ),
    );
  }

  Widget _buildMetroBanner() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.blueAccent, Colors.green],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
      child: const Row(
        children: [
          Icon(Icons.train, color: Colors.white, size: 28),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              "Hyderabad Metro • Open Library Initiative",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text("📚 No books loaned yet",
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            SizedBox(height: 10),
            Text(
              "Explore books from our metro station library and make your journey enriching!",
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBorrowedBooksList(List<BookLoan> books) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("📘 Books Currently Loaned",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 10),
        ...books.map((book) => BookCard(book: book)).toList(),
      ],
    );
  }

  Widget _buildReminder() {
    return Column(
      children: const [
        Text("📌 Reminder",
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        SizedBox(height: 8),
        Text(
          "Please return books within the due date so others can enjoy reading too.",
          textAlign: TextAlign.center,
        ),
        SizedBox(height: 10),
        Text(
          "🌟 Read more. Travel more. Grow more.",
          textAlign: TextAlign.center,
          style: TextStyle(fontStyle: FontStyle.italic, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _buildBottomNav() {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      color: Colors.white,
      elevation: 8,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _bottomNavButton(Icons.assignment_return, "Return", () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BookActionScreen(initialTab: 1)),
              );
              fetchBorrowedBooks();
            }),
            _bottomNavButton(Icons.add, "Loan", () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const BookActionScreen(initialTab: 0)),
              );
              fetchBorrowedBooks();
            }),
            _bottomNavButton(Icons.person, "Profile", () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profile coming soon...')),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _bottomNavButton(IconData icon, String label, VoidCallback onTap) {
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.blueAccent),
      label: Text(label, style: const TextStyle(color: Colors.black)),
    );
  }
}
