import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'home_screen.dart';
import '../main.dart'; // import globalIsar

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  final _hostelController = TextEditingController();
  final _blockController = TextEditingController();
  final _floorController = TextEditingController();
  
  final _authService = AuthService();
  bool _isLoading = false;
  bool _isRegistering = false;

  void _submit() async {
    setState(() => _isLoading = true);
    bool success;
    if (_isRegistering) {
      success = await _authService.register(
        _emailController.text,
        _passwordController.text,
        _nameController.text,
        _hostelController.text,
        _blockController.text,
        _floorController.text,
      );
    } else {
      success = await _authService.login(_emailController.text, _passwordController.text);
    }
    setState(() => _isLoading = false);
    
    if (success && mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => HomeScreen(isar: globalIsar)));
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_isRegistering ? 'Registration failed. Email might exist.' : 'Login failed. Please check credentials.'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isRegistering ? 'Warden Registration' : 'Warden Login')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.shield, size: 80, color: Colors.blue),
              const SizedBox(height: 32),
              if (_isRegistering) ...[
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Full Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.person)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _hostelController,
                  decoration: const InputDecoration(labelText: 'Hostel Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.apartment)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _blockController,
                  decoration: const InputDecoration(labelText: 'Block Name', border: OutlineInputBorder(), prefixIcon: Icon(Icons.domain)),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _floorController,
                  decoration: const InputDecoration(labelText: 'Floor Number', border: OutlineInputBorder(), prefixIcon: Icon(Icons.layers)),
                ),
                const SizedBox(height: 16),
              ],
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Warden Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 32),
              if (_isLoading) 
                const CircularProgressIndicator()
              else 
                Column(
                  children: [
                    ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                      child: Text(_isRegistering ? 'Register' : 'Login'),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isRegistering = !_isRegistering;
                        });
                      },
                      child: Text(_isRegistering 
                          ? 'Already have an account? Login' 
                          : 'Need an account? Register'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
