import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../env.dart';

class AuthService {
  // Use the local IP address for physical devices
  static String get baseUrl => '${Env.apiBaseUrl}/api';

  Future<bool> register(String email, String password, String name, String hostelName, String blockName, String floorNumber) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email, 
          'password': password,
          'name': name,
          'hostel_name': hostelName,
          'block_name': blockName,
          'floor_number': floorNumber
        }),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('email', data['email']);
        if (data['name'] != null) await prefs.setString('name', data['name']);
        if (data['hostel_name'] != null) await prefs.setString('hostel_name', data['hostel_name']);
        if (data['block_name'] != null) await prefs.setString('block_name', data['block_name']);
        if (data['floor_number'] != null) await prefs.setString('floor_number', data['floor_number']);
        return true;
      }
      return false;
    } catch (e) {
      print('Registration error: $e');
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', data['token']);
        await prefs.setString('email', data['email']);
        if (data['name'] != null) await prefs.setString('name', data['name']);
        if (data['hostel_name'] != null) await prefs.setString('hostel_name', data['hostel_name']);
        if (data['block_name'] != null) await prefs.setString('block_name', data['block_name']);
        if (data['floor_number'] != null) await prefs.setString('floor_number', data['floor_number']);
        return true;
      }
      return false;
    } catch (e) {
      print('Login error: $e');
      return false;
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    await prefs.remove('email');
    await prefs.remove('name');
    await prefs.remove('hostel_name');
    await prefs.remove('block_name');
    await prefs.remove('floor_number');
  }

  Future<String?> getToken() async => (await SharedPreferences.getInstance()).getString('token');
  Future<String?> getEmail() async => (await SharedPreferences.getInstance()).getString('email');
  Future<String?> getName() async => (await SharedPreferences.getInstance()).getString('name');
  Future<String?> getHostelName() async => (await SharedPreferences.getInstance()).getString('hostel_name');
  Future<String?> getBlockName() async => (await SharedPreferences.getInstance()).getString('block_name');
  Future<String?> getFloorNumber() async => (await SharedPreferences.getInstance()).getString('floor_number');

  Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null;
  }
}
