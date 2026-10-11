import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../utils/constants.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final AuthService _authService = AuthService();

  String? _selectedBarangay;
  bool _loading = false;
  String? _errorMsg;
  String _phoneNumber = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _phoneNumber = args?['phoneNumber'] as String? ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('Not authenticated');

      final phone = _phoneNumber.isNotEmpty
          ? _phoneNumber
          : user.phoneNumber ?? '';

      final profile = UserModel(
        uid: user.uid,
        fullName: _nameController.text.trim(),
        email: user.email ?? '',
        barangay: _selectedBarangay!,
        address: _addressController.text.trim(),
        phoneNumber: phone,
        role: 'resident',
        createdAt: DateTime.now(),
      );

      await _authService.createUserProfile(profile);
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Registration failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [gradientStart, gradientEnd],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: const SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '🐝  BEE-Alert',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      'Complete Your Profile',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Form
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Complete Your Profile',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1F2937),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Please fill in your details to complete registration.',
                      style:
                          TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
                    ),
                    const SizedBox(height: 28),

                    // Full Name
                    TextFormField(
                      controller: _nameController,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Full name is required'
                              : null,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        hintText: 'Juan Dela Cruz',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Barangay dropdown
                    DropdownButtonFormField<String>(
                      initialValue: _selectedBarangay,
                      hint: const Text('Select Barangay'),
                      isExpanded: true,
                      validator: (v) =>
                          v == null ? 'Please select your barangay' : null,
                      onChanged: (v) =>
                          setState(() => _selectedBarangay = v),
                      decoration: const InputDecoration(
                        labelText: 'Barangay',
                        prefixIcon: Icon(Icons.location_city_outlined),
                      ),
                      items: bacnotanBarangays
                          .map(
                            (b) => DropdownMenuItem(
                              value: b,
                              child: Text(b),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 16),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      textCapitalization: TextCapitalization.words,
                      validator: (v) =>
                          (v == null || v.trim().isEmpty)
                              ? 'Address is required'
                              : null,
                      decoration: const InputDecoration(
                        labelText: 'Home Address',
                        hintText: 'House No., Street, Barangay',
                        prefixIcon: Icon(Icons.home_outlined),
                      ),
                      maxLines: 2,
                    ),

                    if (_errorMsg != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.error_outline,
                                color: Colors.red, size: 16),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(_errorMsg!,
                                  style: const TextStyle(
                                      color: Colors.red, fontSize: 13)),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 32),

                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _loading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: gradientStart,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: _loading
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2.5, color: Colors.white),
                              )
                            : const Text(
                                'Complete Registration',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
