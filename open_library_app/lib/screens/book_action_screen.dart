import 'package:flutter/material.dart';
import 'package:open_library_app/services/api_service.dart';
import 'package:open_library_app/models/qr_scanner_page.dart';

class BookActionScreen extends StatefulWidget {
  final int initialTab;

  const BookActionScreen({super.key, this.initialTab = 0});

  @override
  State<BookActionScreen> createState() => _BookActionScreenState();
}

class _BookActionScreenState extends State<BookActionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _mobileNoController = TextEditingController();
  final TextEditingController _bookIdController = TextEditingController();
  final ApiService _apiService = ApiService();

  String _message = '';
  bool _isLoading = false;
  List<Map<String, dynamic>> _metroStations = [];
  String? _selectedMetroName;
  int? _selectedMetroId;

  @override
  void initState() {
    super.initState();
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: widget.initialTab);
    _loadMetroStations();
  }

  Future<void> _loadMetroStations() async {
    try {
      final metros = await _apiService.fetchMetroStations();
      setState(() => _metroStations = metros);
    } catch (e) {
      debugPrint("Failed to fetch metro stations: $e");
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _mobileNoController.dispose();
    _bookIdController.dispose();
    super.dispose();
  }

  Future<void> _performAction(String actionType) async {
    setState(() {
      _isLoading = true;
      _message = '${actionType}ing book...';
    });

    final mobileNo = int.tryParse(_mobileNoController.text.trim());
    final bookId = _bookIdController.text.trim();
    final metroId = _selectedMetroId;

    if (mobileNo == null || bookId.isEmpty || metroId == null) {
      setState(() {
        _message = 'Please fill all fields correctly.';
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Fill all fields with valid data!'),
            backgroundColor: Colors.orange),
      );
      return;
    }

    try {
      final response =
          await _apiService.performBookAction(mobileNo, bookId, metroId, actionType);
      setState(() {
        _message = 'Success: ${response['message']}';
        _bookIdController.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Book ${actionType}ed successfully!')),
      );
    } catch (e) {
      setState(() => _message = 'Error: ${e.toString()}');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action Failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildActionTab(String actionType) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Card(
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        shadowColor: Colors.black26,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              _buildInputField(
                controller: _mobileNoController,
                label: 'Mobile No',
                icon: Icons.phone,
                keyboardType: TextInputType.phone,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInputField(
                      controller: _bookIdController,
                      label: 'Book ID',
                      icon: Icons.menu_book,
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.qr_code_scanner, size: 30, color: Colors.green),
                    tooltip: 'Scan Book QR',
                    onPressed: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => QRScannerPage(
                            onScanned: (scannedCode) {
                              setState(() => _bookIdController.text = scannedCode);
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: _selectedMetroName,
                decoration: _inputDecoration('Select Metro Station', Icons.train),
                items: _metroStations.map((station) {
                  return DropdownMenuItem<String>(
                    value: station['mtr_name'],
                    child: Text(station['mtr_name']),
                  );
                }).toList(),
                onChanged: (value) {
                  final selected =
                      _metroStations.firstWhere((s) => s['mtr_name'] == value);
                  setState(() {
                    _selectedMetroName = value;
                    _selectedMetroId = selected['mtr_id'];
                  });
                },
              ),
              const SizedBox(height: 24),
              _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ElevatedButton.icon(
                      onPressed: () => _performAction(actionType),
                      icon: Icon(
                          actionType == 'loan' ? Icons.outbox : Icons.inbox,
                          size: 22),
                      label: Text(
                        actionType == 'loan' ? 'Take Book' : 'Deposit Book',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                      ),
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size.fromHeight(55),
                        backgroundColor:
                            actionType == 'loan' ? Colors.blueAccent : Colors.green,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                    ),
              const SizedBox(height: 20),
              AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                opacity: _message.isNotEmpty ? 1.0 : 0.0,
                child: Text(
                  _message,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _message.startsWith('Error') ? Colors.red : Colors.green,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
      filled: true,
      fillColor: Colors.grey.shade100,
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      decoration: _inputDecoration(label, icon),
      keyboardType: keyboardType,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Loan / Return Book'),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.green],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 4,
          tabs: const [
            Tab(icon: Icon(Icons.outbox), text: 'Loan'),
            Tab(icon: Icon(Icons.inbox), text: 'Return'),
          ],
        ),
      ),
      body: Container(
        color: Colors.grey[100],
        child: TabBarView(
          controller: _tabController,
          children: [
            _buildActionTab('loan'),
            _buildActionTab('return'),
          ],
        ),
      ),
    );
  }
}
