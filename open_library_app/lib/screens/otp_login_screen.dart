import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_library_app/screens/home_screen.dart';
import 'package:open_library_app/models/user.dart';

class OTPLoginScreen extends StatefulWidget {
  const OTPLoginScreen({super.key});

  @override
  State<OTPLoginScreen> createState() => _OTPLoginScreenState();
}

class _OTPLoginScreenState extends State<OTPLoginScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());

  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String _verificationId = '';
  bool _otpSent = false;
  bool _isLoading = false;
  String _statusMessage = '';

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnimation = CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
  }

  void _sendOTP() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) {
      setState(() => _statusMessage = "Enter phone number");
      return;
    }

    final fullPhoneNumber = '+91$phone';
    setState(() {
      _isLoading = true;
      _statusMessage = 'Sending OTP to $fullPhoneNumber...';
    });

    await _auth.verifyPhoneNumber(
      phoneNumber: fullPhoneNumber,
      timeout: const Duration(seconds: 60),
      verificationCompleted: (fb_auth.PhoneAuthCredential credential) async {
        await _auth.signInWithCredential(credential);
        _handleLoginSuccess(_auth.currentUser);
      },
      verificationFailed: (fb_auth.FirebaseAuthException e) {
        setState(() {
          _statusMessage = 'OTP send failed: ${e.message}';
          _isLoading = false;
        });
      },
      codeSent: (String verificationId, int? resendToken) {
        setState(() {
          _verificationId = verificationId;
          _otpSent = true;
          _statusMessage = 'OTP sent successfully.';
          _isLoading = false;
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        _verificationId = verificationId;
      },
    );
  }

  void _verifyOTP() async {
    final smsCode = _otpControllers.map((c) => c.text).join();
    if (_verificationId.isEmpty || smsCode.length != 6) {
      setState(() => _statusMessage = 'Enter all 6 digits of OTP.');
      return;
    }

    try {
      setState(() => _isLoading = true);
      final credential = fb_auth.PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: smsCode,
      );
      fb_auth.UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      _handleLoginSuccess(userCredential.user);
    } catch (e) {
      setState(() {
        _statusMessage = 'OTP verification failed: $e';
        _isLoading = false;
      });
    }
  }

  void _handleLoginSuccess(fb_auth.User? firebaseUser) async {
    if (firebaseUser == null || firebaseUser.phoneNumber == null) {
      setState(() {
        _statusMessage = 'Login failed.';
        _isLoading = false;
      });
      return;
    }

    final mobNo = firebaseUser.phoneNumber!;
    try {
      final doc = await _firestore
          .collection('Users')
          .where('usr_mob_no', isEqualTo: int.tryParse(mobNo.replaceAll("+91", "")))
          .limit(1)
          .get();

      if (doc.docs.isEmpty) {
        setState(() {
          _statusMessage = 'User not found. Please register first.';
          _isLoading = false;
        });
        return;
      }

      final data = doc.docs.first.data();
      final user = User(
        userId: 0,
        mobileNo: data['usr_mob_no'].toString(),
        userName: data['usr_name'] ?? '',
        email: data['usr_email_id'] ?? '',
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    } catch (e) {
      setState(() {
        _statusMessage = 'Failed to fetch user data: $e';
        _isLoading = false;
      });
    }
  }

  Widget _buildOtpBoxes() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          6,
          (index) => SizedBox(
            width: 50,
            child: TextField(
              controller: _otpControllers[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: Colors.grey[200],
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty && index < 5) {
                  FocusScope.of(context).nextFocus();
                }
              },
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text("Quick Login with OTP"),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.indigo,
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            children: [
              const SizedBox(height: 30),
              const Icon(Icons.phone_iphone, size: 70, color: Colors.indigo),
              const SizedBox(height: 12),
              const Text(
                "Open Library",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "Login with your mobile number",
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: "Phone Number",
                  prefixIcon: const Icon(Icons.phone),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              if (_otpSent) _buildOtpBoxes(),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.indigo,
                        minimumSize: const Size.fromHeight(50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _otpSent ? _verifyOTP : _sendOTP,
                      child: Text(
                        _otpSent ? "Verify OTP" : "Send OTP",
                        style: const TextStyle(fontSize: 18),
                      ),
                    ),
              const SizedBox(height: 20),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: _statusMessage.contains("failed") ? Colors.red : Colors.green,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              const Text(
                "Powered by Intrix Data Labs",
                style: TextStyle(color: Colors.grey),
              )
            ],
          ),
        ),
      ),
    );
  }
}
