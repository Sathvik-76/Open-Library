// lib/services/api_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:open_library_app/utils/constants.dart';
import 'package:open_library_app/models/user.dart'; // User model
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // New import for secure storage

class ApiService {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // --- Helper to get the stored token ---
  Future<String?> getAuthToken() async {
    return await _secureStorage.read(key: 'jwt_token');
  }

  // --- Helper to set the token in headers ---
  Future<Map<String, String>> _getHeaders() async {
    final token = await getAuthToken();
    return {
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  // --- Existing registerUser (no changes needed for now) ---
  Future<User> registerUser(String mobileNo, String name, String password,
      String? email) async {
    final response = await http.post(
      Uri.parse('$API_BASE_URL/register'),
      headers: await _getHeaders(),
      // Use new _getHeaders for registration too (though not protected)
      body: json.encode({
        'mobile_no': mobileNo,
        'name': name,
        'password': password,
        'email': email,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      // In a real app, backend might return full user details
      return User(
        userId: responseData['user_id'],
        mobileNo: mobileNo,
        userName: name,
        email: email,
      );
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(
          'Failed to register user: ${response
              .statusCode} - ${errorBody['detail'] ?? response.body}');
    }
  }

  // --- NEW: Login method ---
  Future<User> loginUser(String mobileNo, String password) async {
    // OAuth2PasswordRequestForm expects form-urlencoded, not JSON
    final response = await http.post(
      Uri.parse('$API_BASE_URL/token'), // The /token endpoint in FastAPI
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {
        'username': mobileNo,
        // FastAPI's OAuth2PasswordRequestForm uses 'username'
        'password': password,
      },
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseData = json.decode(response.body);
      final String accessToken = responseData['access_token'];

      // Store the token securely
      await _secureStorage.write(key: 'jwt_token', value: accessToken);

      // For simplicity, we'll return a dummy user for now.
      // In a real app, you might have a /me endpoint or the token contains user_id.
      // For now, just return a dummy User based on mobileNo for the UI to display.
      return User(
        userId: 0,
        // Placeholder, you'd get this from the token or another endpoint
        mobileNo: mobileNo,
        userName: mobileNo,
        // Placeholder, you'd get this from user data
        email: null,
      );
    } else {
      final errorBody = json.decode(response.body);
      throw Exception(
          'Failed to login: ${response.statusCode} - ${errorBody['detail'] ??
              response.body}');
    }
  }

  // --- NEW: Logout method ---
  Future<void> logoutUser() async {
    await _secureStorage.delete(key: 'jwt_token');
    print('User logged out, token removed.');
  }

  Future<List<Map<String, dynamic>>> fetchUserLoans(String mobileNo) async {
    final headers = await _getHeaders();
    final response = await http.get(
      Uri.parse('$API_BASE_URL/user_loans/$mobileNo'),
      headers: headers,
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> decoded = json.decode(response.body);
      final List<dynamic> rawList = decoded['loans'];
      return rawList.map((item) => Map<String, dynamic>.from(item)).toList();
    } else {
      throw Exception('Failed to fetch user loans');
    }
  }


  Future<Map<String, dynamic>> performBookAction(int mobileNo, String bookId,
      int metroId, String actionType) async {
    final endpoint = actionType == 'loan' ? '/loan_book' : '/return_book';

    final response = await http.post(
      Uri.parse('$API_BASE_URL$endpoint'),
      headers: await _getHeaders(),
      body: json.encode({
        'mobile_no': mobileNo,
        'book_id': bookId,
        'metro_id': metroId,
      }),
    );

    if (response.statusCode == 200) {
      final Map<String, dynamic> responseBody =
      json.decode(response.body) as Map<String, dynamic>;
      return responseBody;
    } else {
      final Map<String, dynamic> errorBody =
      json.decode(response.body) as Map<String, dynamic>;
      throw Exception(
        'Failed to $actionType book: ${response
            .statusCode} - ${errorBody['detail'] ?? response.body}',
      );
    }
  }

  Future<List<Map<String, dynamic>>> fetchMetroStations() async {
    final response = await http.get(Uri.parse('$API_BASE_URL/metro_stations'));
    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.cast<Map<String, dynamic>>();
    } else {
      throw Exception('Failed to load metro stations');
    }
  }
}