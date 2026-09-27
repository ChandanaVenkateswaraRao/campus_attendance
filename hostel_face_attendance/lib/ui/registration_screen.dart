import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import '../models/models.dart';
import 'face_capture_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final Isar isar;
  final Room room;
  const RegistrationScreen({super.key, required this.isar, required this.room});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _phoneController = TextEditingController();
  final _fatherPhoneController = TextEditingController();
  final _motherPhoneController = TextEditingController();
  final _emailController = TextEditingController();

  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _nameController.dispose();
    _regNoController.dispose();
    _phoneController.dispose();
    _fatherPhoneController.dispose();
    _motherPhoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  void _goToCapture() {
    if (_formKey.currentState!.validate()) {
      // Create unsaved student
      final student = Student()
        ..name = _nameController.text.trim()
        ..studentId = _regNoController.text.trim()
        ..phoneNumber = _phoneController.text.trim()
        ..fatherPhoneNumber = _fatherPhoneController.text.trim()
        ..motherPhoneNumber = _motherPhoneController.text.trim()
        ..email = _emailController.text.trim();
        
      student.room.value = widget.room;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => FaceCaptureScreen(isar: widget.isar, student: student),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text('Register in Room ${widget.room.name}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Container(
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
                  const Text(
                    'Student Details',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please fill in the student contact information.',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 24),

                  _buildTextField(_nameController, 'Student Name', Icons.person_outline, validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    return null;
                  }),
                  const SizedBox(height: 16),
                  
                  _buildTextField(_regNoController, 'Register Number', Icons.badge_outlined, validator: (val) {
                    if (val == null || val.isEmpty) return 'Required';
                    return null;
                  }),
                  const SizedBox(height: 16),
                  
                  _buildTextField(_emailController, 'Email', Icons.email_outlined, keyboardType: TextInputType.emailAddress),
                  const SizedBox(height: 16),

                  _buildTextField(_phoneController, 'Student Phone', Icons.phone_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),

                  _buildTextField(_fatherPhoneController, 'Father Phone', Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: 16),

                  _buildTextField(_motherPhoneController, 'Mother Phone', Icons.phone_android_outlined, keyboardType: TextInputType.phone),
                  const SizedBox(height: 32),

                  ElevatedButton(
                    onPressed: _goToCapture,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                    ),
                    child: const Text(
                      'Next: Capture Face',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label, IconData icon, {TextInputType? keyboardType, String? Function(String?)? validator}) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
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
