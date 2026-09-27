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
        backgroundColor: Colors.red.shade600,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo Section
                Image.asset(
                  'assets/images/logo.png',
                  height: 120,
                  width: 120,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Kalasalingam University',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  _isRegistering ? 'Warden Registration' : 'Warden Portal Login',
                  style: TextStyle(fontSize: 16, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 40),

                // Form Section
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
                    ],
                  ),
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_isRegistering) ...[
                        _buildTextField(_nameController, 'Full Name', Icons.person_outline),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(child: _buildTextField(_hostelController, 'Hostel Name', Icons.apartment_outlined)),
                            const SizedBox(width: 12),
                            Expanded(child: _buildTextField(_blockController, 'Block', Icons.domain)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        _buildTextField(_floorController, 'Floor Number', Icons.layers_outlined),
                        const SizedBox(height: 16),
                      ],
                      
                      _buildTextField(_emailController, 'Warden Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 16),
                      _buildTextField(_passwordController, 'Password', Icons.lock_outline, obscureText: true),
                      
                      const SizedBox(height: 32),
                      
                      if (_isLoading)
                        const Center(child: CircularProgressIndicator())
                      else
                        ElevatedButton(
                          onPressed: _submit,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            elevation: 0,
                          ),
                          child: Text(
                            _isRegistering ? 'Create Account' : 'Sign In',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Toggle Login/Register
                TextButton(
                  onPressed: () {
                    setState(() {
                      _isRegistering = !_isRegistering;
                    });
                  },
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                  child: Text(
                    _isRegistering 
                        ? 'Already have an account? Sign In' 
                        : 'Need an account? Register',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    IconData icon, 
    {bool obscureText = false, TextInputType? keyboardType}
  ) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey.shade500, size: 22),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
    );
  }
}
