import 'dart:io';
import '../../widgets/app_logo.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/cloudinary_service.dart';
import '../../utils/constants.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final AuthService _authService = AuthService();

  XFile? _idImage;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _idImageTouched = false;
  String? _selectedBarangay;
  String? _errorMsg;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Image picking
  // ---------------------------------------------------------------------------

  Future<void> _pickId(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 60,
      maxWidth: 1024,
      maxHeight: 1024,
    );
    if (picked != null) {
      setState(() {
        _idImage = picked;
        _idImageTouched = false;
      });
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Upload Valid ID',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.camera_alt_outlined, color: gradientStart),
              ),
              title: const Text('Take a Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickId(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.photo_library_outlined, color: gradientStart),
              ),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickId(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Upload to Firebase Storage
  // ---------------------------------------------------------------------------

  Future<String?> _uploadIdImage(String uid) async {
    if (_idImage == null) return null;
    return CloudinaryService.uploadFile(
      _idImage!,
      folder: 'user_ids',
      resourceType: 'image',
    );
  }

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Converts a string to Title Case: "marites almodovar" → "Marites Almodovar"
  String _toTitleCase(String input) {
    if (input.isEmpty) return input;
    return input.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    if (_idImage == null) {
      setState(() {
        _idImageTouched = true;
        _errorMsg = 'Please upload a valid ID photo to continue.';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMsg = null;
    });

    try {
      // 1. Create Firebase Auth account
      final credential = await _authService
          .signUpWithEmail(
            email: _emailController.text.trim(),
            password: _passwordController.text,
          )
          .timeout(const Duration(seconds: 15));

      final uid = credential.user!.uid;

      // 2. Save profile immediately so the resident appears in the admin tab.
      //    On native, we upload the image first and include the URL.
      //    On web, Firebase Storage has CORS issues so we save without the URL
      //    and upload in the background â€” the admin card updates automatically
      //    via the Firestore real-time listener when idImageUrl is written.
      String? idUrl;
      if (!kIsWeb) {
        idUrl = await _uploadIdImage(uid);
      }

      final profile = UserModel(
        uid: uid,
        fullName: _toTitleCase(_nameController.text.trim()),
        email: _emailController.text.trim(),
        barangay: _selectedBarangay ?? _toTitleCase(_addressController.text.trim()),
        address: _toTitleCase(_addressController.text.trim()),
        phoneNumber: _phoneController.text.trim(),
        role: 'resident',
        status: 'pending',
        createdAt: DateTime.now(),
        idImageUrl: idUrl,
      );
      await _authService
          .createUserProfile(profile)
          .timeout(const Duration(seconds: 15));

      // Write admin notification immediately — this fires regardless of
      // which tab the admin currently has open.
      FirebaseFirestore.instance
          .collection('admin_notifications')
          .add({
        'type': 'new_signup',
        'title': 'New Sign-Up: ${profile.fullName}',
        'body':
            '${profile.fullName} from ${profile.barangay.isNotEmpty ? profile.barangay : profile.address} has registered and is waiting for approval.',
        'meta': {
          'userId': uid,
          'residentName': profile.fullName,
          'email': profile.email,
        },
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      }).catchError((Object _) => FirebaseFirestore.instance.collection('admin_notifications').doc());

      // 3. On web: upload image in background after profile is saved
      if (kIsWeb && _idImage != null) {
        _uploadIdImage(uid).then((url) {
          if (url != null) {
            _authService.updateUserProfile(uid, {'idImageUrl': url});
          }
        });
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/pending');
    } on FirebaseAuthException catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = _authService.friendlyError(e);
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _errorMsg = 'Registration failed: $e';
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5EDE4),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Orange header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                      vertical: 32, horizontal: 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [gradientStart, gradientEnd],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: const Column(
                    children: [
                      AppLogo(size: 50, blendWithBackground: false),
                      SizedBox(height: 10),
                      Text(
                        appName,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        municipality,
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),

                // Form body
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1F2937),
                          ),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Fill in your details to register as a resident.',
                          style: TextStyle(
                              fontSize: 13, color: Color(0xFF6B7280)),
                        ),

                        // Error banner
                        if (_errorMsg != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline,
                                    color: Colors.red, size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMsg!,
                                    style: const TextStyle(
                                        color: Colors.red, fontSize: 13),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 24),

                        // Full Name
                        _label('Full Name'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _nameController,
                          textCapitalization: TextCapitalization.words,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Full name is required'
                              : null,
                          decoration: _inputDecoration(
                            hint: 'Juan Dela Cruz',
                            icon: Icons.person_outline,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Email
                        _label('Email Address'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Email is required';
                            }
                            if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                .hasMatch(v.trim())) {
                              return 'Enter a valid email address';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            hint: 'you@example.com',
                            icon: Icons.email_outlined,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Mobile Number
                        _label('Mobile Number'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Mobile number is required';
                            }
                            final digits = v.replaceAll(RegExp(r'\D'), '');
                            if ((digits.length == 11 &&
                                    digits.startsWith('09')) ||
                                (digits.length == 10 &&
                                    digits.startsWith('9'))) {
                              return null;
                            }
                            return 'Enter a valid PH number (09XXXXXXXXX)';
                          },
                          decoration: _inputDecoration(
                            hint: '09XXXXXXXXX',
                            icon: Icons.phone_outlined,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Barangay
                        _label('Barangay'),
                        const SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedBarangay,
                          isExpanded: true,
                          hint: const Text(
                            'Select your barangay',
                            style: TextStyle(
                                color: Color(0xFF9CA3AF), fontSize: 14),
                          ),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(
                              Icons.location_city_outlined,
                              size: 20,
                              color: Color(0xFF9CA3AF),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: gradientStart, width: 2),
                            ),
                            errorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide:
                                  const BorderSide(color: Colors.red),
                            ),
                            focusedErrorBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                              borderSide: const BorderSide(
                                  color: Colors.red, width: 2),
                            ),
                          ),
                          validator: (v) => v == null
                              ? 'Please select your barangay'
                              : null,
                          items: bacnotanBarangays
                              .map((b) => DropdownMenuItem(
                                    value: b,
                                    child: Text(
                                      b,
                                      style: const TextStyle(
                                          fontSize: 14,
                                          color: Color(0xFF1F2937)),
                                    ),
                                  ))
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedBarangay = val),
                        ),

                        const SizedBox(height: 16),

                        // Full Address
                        _label('Full Address'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _addressController,
                          textCapitalization: TextCapitalization.words,
                          maxLines: 3,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? 'Address is required'
                              : null,
                          decoration: _inputDecoration(
                            hint: 'House No., Street',
                            icon: Icons.home_outlined,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Valid ID upload
                        _label('Valid ID (Required)'),
                        const SizedBox(height: 4),
                        if (_idImageTouched && _idImage == null)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 6),
                            child: Text(
                              'Valid ID photo is required',
                              style: TextStyle(
                                  color: Colors.red, fontSize: 12),
                            ),
                          ),
                        const SizedBox(height: 4),
                        GestureDetector(
                          onTap: _showImageSourceSheet,
                          child: Container(
                            width: double.infinity,
                            height: _idImage != null ? 180 : 120,
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFFBF7),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: _idImage != null
                                    ? gradientStart
                                    : (_idImageTouched
                                        ? Colors.red
                                        : Colors.grey[300]!),
                                width:
                                    (_idImage != null || _idImageTouched)
                                        ? 2
                                        : 1,
                              ),
                            ),
                            child: _idImage != null
                                ? _idPreview()
                                : _idPlaceholder(),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Password
                        _label('Password'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Password is required';
                            }
                            if (v.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            hint: 'At least 6 characters',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF9CA3AF),
                                size: 20,
                              ),
                              onPressed: () => setState(() =>
                                  _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Confirm Password
                        _label('Confirm Password'),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          obscureText: _obscureConfirm,
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Please confirm your password';
                            }
                            if (v != _passwordController.text) {
                              return 'Passwords do not match';
                            }
                            return null;
                          },
                          decoration: _inputDecoration(
                            hint: 'Re-enter your password',
                            icon: Icons.lock_outline,
                            suffix: IconButton(
                              icon: Icon(
                                _obscureConfirm
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: const Color(0xFF9CA3AF),
                                size: 20,
                              ),
                              onPressed: () => setState(
                                  () => _obscureConfirm = !_obscureConfirm),
                            ),
                          ),
                        ),

                        const SizedBox(height: 28),

                        // Create Account button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _register,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: gradientStart,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: _loading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Back to login
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'Already have an account? ',
                              style: TextStyle(
                                  fontSize: 13, color: Color(0xFF6B7280)),
                            ),
                            GestureDetector(
                              onTap: () => Navigator.of(context).pop(),
                              child: const Text(
                                'Sign In',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: gradientStart,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Widget helpers
  // ---------------------------------------------------------------------------

  Widget _idPreview() {
    return Stack(
      fit: StackFit.expand,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: kIsWeb
              ? Image.network(
                  _idImage!.path,
                  fit: BoxFit.cover,
                )
              : Image.file(
                  File(_idImage!.path),
                  fit: BoxFit.cover,
                ),
        ),
        // Remove button
        Positioned(
          top: 8,
          right: 8,
          child: GestureDetector(
            onTap: () => setState(() {
              _idImage = null;
              _idImageTouched = true;
            }),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close, color: Colors.white, size: 16),
            ),
          ),
        ),
        // Change button
        Positioned(
          bottom: 8,
          right: 8,
          child: GestureDetector(
            onTap: _showImageSourceSheet,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: gradientStart,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Change',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _idPlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF3E0),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.upload_file_outlined,
            color: gradientStart,
            size: 28,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Tap to upload your valid ID',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF374151),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Required  •  Camera or Gallery  •  JPG, PNG',
          style: TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }

  Widget _label(String text) => Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: Color(0xFF374151),
        ),
      );

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF9CA3AF)),
      suffixIcon: suffix,
      filled: true,
      fillColor: Colors.white,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: gradientStart, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }
}
