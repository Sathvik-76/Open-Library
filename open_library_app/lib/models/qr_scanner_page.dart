import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class QRScannerPage extends StatefulWidget {
  final void Function(String) onScanned;

  const QRScannerPage({Key? key, required this.onScanned}) : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage>
    with SingleTickerProviderStateMixin {
  bool _scanned = false;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _showBookDetails(String qrCode) async {
    // Simulated book data (In real use, call API with qrCode)
    final bookData = {
      "title": "Atomic Habits",
      "author": "James Clear",
      "metro": "Central Metro Station"
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.black87,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 5,
                width: 50,
                margin: const EdgeInsets.only(bottom: 15),
                decoration: BoxDecoration(
                  color: Colors.white30,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Icon(Icons.book_rounded, size: 50, color: Colors.greenAccent),
              const SizedBox(height: 15),
              Text(bookData["title"]!,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
              const SizedBox(height: 5),
              Text("by ${bookData["author"]}",
                  style: const TextStyle(color: Colors.white70, fontSize: 16)),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_on, color: Colors.greenAccent, size: 18),
                  const SizedBox(width: 5),
                  Text(bookData["metro"]!,
                      style: const TextStyle(color: Colors.greenAccent)),
                ],
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.greenAccent,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(200, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
                onPressed: () {
                  Navigator.pop(context); // Close modal
                  widget.onScanned(qrCode); // Return scanned QR to parent
                  Navigator.of(context).pop(); // Close scanner
                },
                icon: const Icon(Icons.check),
                label: const Text("Confirm Loan"),
              ),
            ],
          ),
        );
      },
    );
  }

  void _handleDetection(BarcodeCapture capture) {
    if (_scanned) return;
    _scanned = true;

    final barcode = capture.barcodes.first;
    final String? code = barcode.rawValue;
    if (code != null) {
      _showBookDetails(code);
    }
  }

  Widget _buildScannerOverlay(BuildContext context) {
    return Stack(
      children: [
        Align(
          alignment: Alignment.center,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.white.withOpacity(0.8), width: 2),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Positioned(
              top: MediaQuery.of(context).size.height * 0.3 +
                  (_animationController.value * 200),
              left: MediaQuery.of(context).size.width * 0.5 - 125,
              child: Container(
                width: 250,
                height: 2,
                color: Colors.greenAccent.withOpacity(0.7),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text("Scan Book QR Code",
            style: TextStyle(color: Colors.white)),
        centerTitle: true,
        elevation: 0,
      ),
      body: Stack(
        children: [
          MobileScanner(onDetect: _handleDetection, fit: BoxFit.cover),
          _buildScannerOverlay(context),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: const [
                Icon(Icons.qr_code_scanner, size: 48, color: Colors.white70),
                SizedBox(height: 10),
                Text(
                  "Align QR code within the frame to scan",
                  style: TextStyle(color: Colors.white70, fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
