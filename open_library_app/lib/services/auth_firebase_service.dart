import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:open_library_app/models/user.dart'; // your custom User model

class AuthService {
  final fb_auth.FirebaseAuth _auth = fb_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // 🔒 Register with Email & Password
  Future<fb_auth.UserCredential> registerWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(email: email, password: password);
  }

  // 🔑 Login with Email & Password
  Future<User?> loginWithEmailAndPassword(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);

      final snapshot = await _firestore
          .collection("Users")
          .where("usr_email_id", isEqualTo: email)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        throw Exception("User not found in Firestore.");
      }

      final data = snapshot.docs.first.data();

      return User(
        userId: 0,
        mobileNo: data["usr_mob_no"].toString(),
        userName: data["usr_name"],
        email: data["usr_email_id"],
      );
    } catch (e) {
      throw Exception("Login failed: ${e.toString()}");
    }
  }

  // 📲 Send OTP to phone number
  Future<void> sendOTP({
    required String phoneNumber,
    required fb_auth.PhoneVerificationCompleted verificationCompleted,
    required fb_auth.PhoneVerificationFailed verificationFailed,
    required fb_auth.PhoneCodeSent codeSent,
    required fb_auth.PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) {
    return _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
    );
  }

  // ✅ Verify OTP and Sign in
  Future<fb_auth.UserCredential> verifyOTP(String verificationId, String smsCode) async {
    final credential = fb_auth.PhoneAuthProvider.credential(
        verificationId: verificationId, smsCode: smsCode);
    return await _auth.signInWithCredential(credential);
  }

  // 🔓 Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // 👤 Get current user
  fb_auth.User? getCurrentUser() {
    return _auth.currentUser;
  }
}
