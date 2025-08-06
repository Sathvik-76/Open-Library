// lib/models/user.dart
class User {
  final int userId;
  final String mobileNo;
  final String userName;
  final String? email; // Optional field

  User({
    required this.userId,
    required this.mobileNo,
    required this.userName,
    this.email,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      userId: json['user_id'],
      mobileNo: json['mobile_no'] ?? '', // Provide default if null
      userName: json['user_name'] ?? '', // Provide default if null
      email: json['email'],
    );
  }

  // If you need to send User data to backend, add a toJson method:
  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'mobile_no': mobileNo,
      'user_name': userName,
      'email': email,
    };
  }
}