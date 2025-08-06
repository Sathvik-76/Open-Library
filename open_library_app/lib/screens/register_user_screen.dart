import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_otp_text_field/flutter_otp_text_field.dart';

class RegisterUserScreen extends StatefulWidget {
  const RegisterUserScreen({super.key});

  @override
  State<RegisterUserScreen> createState() => _RegisterUserScreenState();
}

class _RegisterUserScreenState extends State<RegisterUserScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _otpSent = false;
  bool _isLoading = false;
  String _verificationId = '';
  String _statusMessage = '';
  String _enteredOtp = '';

  // === Validators ===
  bool isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w]{2,4}$').hasMatch(email);
  }

  bool isValidPhone(String phone) {
    return RegExp(r'^\d{10}$').hasMatch(phone);
  }

  bool isStrongPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#\$&*~]').hasMatch(password);
  }

  Future<void> _sendOTP() async {
    final firstName = _firstNameController.text.trim();
    final lastName = _lastNameController.text.trim();
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();
    final confirmPassword = _confirmPasswordController.text.trim();

    if ([firstName, lastName, phone, password, confirmPassword].any((e) => e.isEmpty)) {
      _showMessage("Please fill all required fields");
      return;
    }

    if (!isValidPhone(phone)) {
      _showMessage("Enter a valid 10-digit mobile number");
      return;
    }

    if (email.isNotEmpty && !isValidEmail(email)) {
      _showMessage("Enter a valid email address");
      return;
    }

    if (!isStrongPassword(password)) {
      _showMessage("Password must be 8+ chars with upper, lower, digit & special char");
      return;
    }

    if (password != confirmPassword) {
      _showMessage("Passwords do not match");
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = 'Checking user...';
    });

    try {
      // Check for duplicate phone/email
      final phoneExists = await _firestore
          .collection("Users")
          .where("usr_mob_no", isEqualTo: int.tryParse(phone))
          .limit(1)
          .get();

      if (phoneExists.docs.isNotEmpty) {
        _showMessage("Phone number already registered");
        setState(() => _isLoading = false);
        return;
      }

      if (email.isNotEmpty) {
        final emailExists = await _firestore
            .collection("Users")
            .where("usr_email_id", isEqualTo: email)
            .limit(1)
            .get();

        if (emailExists.docs.isNotEmpty) {
          _showMessage("Email already registered");
          setState(() => _isLoading = false);
          return;
        }
      }

      // Send OTP
      setState(() => _statusMessage = 'Sending OTP...');
      await _auth.verifyPhoneNumber(
        phoneNumber: "+91$phone",
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
          _registerUser();
        },
        verificationFailed: (FirebaseAuthException e) {
          _showMessage("OTP failed: ${e.message}");
          setState(() => _isLoading = false);
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
            _statusMessage = "OTP sent to +91$phone";
          });
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      _showMessage("Error sending OTP: $e");
      setState(() => _isLoading = false);
    }
  }

  void _verifyOTPAndRegister() async {
    if (_verificationId.isEmpty || _enteredOtp.isEmpty) {
      _showMessage("Please enter the OTP");
      return;
    }

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: _enteredOtp,
      );
      await _auth.signInWithCredential(credential);
      _registerUser();
    } catch (e) {
      _showMessage("Invalid OTP. Try again.");
    }
  }

  Future<void> _registerUser() async {
    final name = "${_firstNameController.text.trim()} ${_lastNameController.text.trim()}";
    final email = _emailController.text.trim();
    final phone = _phoneController.text.trim();
    final password = _passwordController.text.trim();

    try {
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = userCredential.user?.uid;
      if (uid == null) {
        _showMessage("Account creation failed");
        return;
      }

      await _firestore.collection("Users").doc(uid).set({
        "usr_name": name,
        "usr_email_id": email,
        "usr_mob_no": int.parse(phone),
        "usr_status": "Active",
        "usr_created_by": "System",
        "usr_created_on": FieldValue.serverTimestamp(),
        "usr_updated_by": "System",
        "usr_updated_on": FieldValue.serverTimestamp(),
        "usr_reg_dt": FieldValue.serverTimestamp(),
      });

      _showMessage("Registered successfully!", isSuccess: true);
      Navigator.pop(context);
    } catch (e) {
      _showMessage("Registration error: ${e.toString()}");
    }
  }

  void _showMessage(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isSuccess ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1A237E); // Indigo
    const accentColor = Color(0xFF64B5F6); // Blue

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: primaryColor,
        title: const Text("Create Account"),
        centerTitle: true,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.person_add_alt, size: 70, color: primaryColor),
            const SizedBox(height: 12),
            const Text("Join Open Library", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: primaryColor)),
            const SizedBox(height: 20),
            _buildInputRow("First Name", _firstNameController),
            const SizedBox(height: 12),
            _buildInputRow("Last Name", _lastNameController),
            const SizedBox(height: 12),
            _buildInputRow("Email Address", _emailController),
            const SizedBox(height: 12),
            _buildInputRow("Phone Number", _phoneController, keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _buildPasswordInput("Password", _passwordController, _isPasswordVisible,
                () => setState(() => _isPasswordVisible = !_isPasswordVisible)),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                isStrongPassword(_passwordController.text)
                    ? "✅ Strong Password"
                    : "❌ Must include upper, lower, number & special char",
                style: TextStyle(fontSize: 12, color: isStrongPassword(_passwordController.text) ? Colors.green : Colors.redAccent),
              ),
            ),
            const SizedBox(height: 12),
            _buildPasswordInput("Confirm Password", _confirmPasswordController, _isConfirmPasswordVisible,
                () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible)),
            const SizedBox(height: 20),
            if (_otpSent)
              Column(
                children: [
                  const Text("Enter OTP", style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  OtpTextField(
                    numberOfFields: 6,
                    borderColor: primaryColor,
                    focusedBorderColor: accentColor,
                    showFieldAsBox: true,
                    onSubmit: (String code) => _enteredOtp = code,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            _isLoading
                ? const CircularProgressIndicator()
                : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _otpSent ? _verifyOTPAndRegister : _sendOTP,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: Text(_otpSent ? "Verify & Register" : "Send OTP", style: const TextStyle(fontSize: 16)),
                    ),
                  ),
            const SizedBox(height: 12),
            Text(_statusMessage, textAlign: TextAlign.center, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Already have an account? Login"),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputRow(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text}) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2)),
      ),
    );
  }

  Widget _buildPasswordInput(String label, TextEditingController controller, bool isVisible, VoidCallback toggleVisibility) {
    return TextField(
      controller: controller,
      obscureText: !isVisible,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: Color(0xFF1A237E), width: 2)),
        suffixIcon: IconButton(
          icon: Icon(isVisible ? Icons.visibility : Icons.visibility_off, color: Colors.black54),
          onPressed: toggleVisibility,
        ),
      ),
    );
  }
}
