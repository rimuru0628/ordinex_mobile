import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../../models/report_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/report_service.dart';
import '../../utils/constants.dart';

class ReportFormScreen extends StatefulWidget {
  const ReportFormScreen({super.key});

  @override
  State<ReportFormScreen> createState() => _ReportFormScreenState();
}

class _ReportFormScreenState extends State<ReportFormScreen> {
  int _step = 1;
  String? _selectedCategory;
  final _descController     = TextEditingController();
  final _locationController = TextEditingController();

  XFile? _imageFile;
  XFile? _videoFile;

  double? _latitude;
  double? _longitude;
  bool _submitting = false;
  UserModel? _userProfile;

  final AuthService    _authService    = AuthService();
  final ReportService  _reportService  = ReportService();
  final ImagePicker    _picker         = ImagePicker();

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final p = await _authService.getUserProfile(uid);
      if (mounted) setState(() => _userProfile = p);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Step 1 — category selection
  // ---------------------------------------------------------------------------

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'What type of concern are you reporting?',
          style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1F2937)),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: categories.map((cat) {
            final selected = _selectedCategory == cat;
            return GestureDetector(
              onTap: () => setState(() {
                _selectedCategory = cat;
                _step = 2;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  color: selected ? gradientStart : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color:
                        selected ? gradientStart : Colors.grey.shade300,
                    width: selected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_categoryIcon(cat),
                        color: selected ? Colors.white : gradientStart,
                        size: 20),
                    const SizedBox(width: 8),
                    Text(
                      cat,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFF1F2937),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  IconData _categoryIcon(String cat) {
    switch (cat) {
      case 'Health':
        return Icons.health_and_safety_outlined;
      case 'Transportation':
        return Icons.directions_car_outlined;
      case 'Environment':
        return Icons.eco_outlined;
      case 'Consumer Issue':
        return Icons.shopping_bag_outlined;
      default:
        return Icons.report_outlined;
    }
  }

  // ---------------------------------------------------------------------------
  // Step 2 — report details
  // ---------------------------------------------------------------------------

  Widget _buildStep2() {
    final hasMedia = _imageFile != null || _videoFile != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Emergency notice
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('⚠️', style: TextStyle(fontSize: 18)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'IMPORTANT NOTICE: This platform is NOT for emergency '
                  'incidents or life-threatening situations. For emergencies, '
                  'please call 911 or your local emergency hotline immediately.',
                  style: TextStyle(
                      fontSize: 12,
                      color: Colors.red,
                      fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),

        // Category (tap to change)
        const Text('Concern Category',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        GestureDetector(
          onTap: () => setState(() => _step = 1),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: gradientStart.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                  color: gradientStart.withValues(alpha: 0.4)),
            ),
            child: Row(
              children: [
                Icon(_categoryIcon(_selectedCategory ?? ''),
                    color: gradientStart, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_selectedCategory ?? '',
                      style: const TextStyle(
                          color: gradientStart,
                          fontWeight: FontWeight.w600)),
                ),
                const Icon(Icons.edit_outlined,
                    size: 16, color: gradientStart),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        const Text('Description',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextField(
          controller: _descController,
          maxLines: 5,
          decoration: InputDecoration(
            hintText: 'Provide details about your concern...',
            filled: true,
            fillColor: Colors.grey.shade50,
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
              borderSide:
                  const BorderSide(color: gradientStart, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // ── Evidence section ────────────────────────────────────────
        const Text('Evidence (Optional)',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        const Text(
          'Attach a photo or video to support your report.',
          style: TextStyle(fontSize: 11, color: Color(0xFF6B7280)),
        ),
        const SizedBox(height: 10),

        if (!hasMedia) ...[
          // Show both pick buttons when nothing is selected
          Row(
            children: [
              Expanded(
                child: _evidenceButton(
                  icon: Icons.photo_camera_outlined,
                  label: 'Photo',
                  onTap: _pickPhoto,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _evidenceButton(
                  icon: Icons.videocam_outlined,
                  label: 'Video',
                  onTap: _pickVideo,
                ),
              ),
            ],
          ),
        ] else ...[
          // Preview of selected media
          _mediaPreview(),
        ],

        const SizedBox(height: 16),

        // Location
        const Text('Location',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 6),
        TextFormField(
          controller: _locationController,
          validator: (v) => (v == null || v.trim().isEmpty)
              ? 'Location is required'
              : null,
          decoration: InputDecoration(
            hintText: 'Enter location or use GPS',
            filled: true,
            fillColor: Colors.grey.shade50,
            prefixIcon: const Icon(Icons.location_on_outlined),
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
              borderSide:
                  const BorderSide(color: gradientStart, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide:
                  const BorderSide(color: Colors.red, width: 2),
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: _useGpsLocation,
          icon: const Icon(Icons.my_location,
              size: 16, color: gradientStart),
          label: const Text('Use my current GPS location',
              style: TextStyle(color: gradientStart)),
        ),
        if (_latitude != null)
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF0FDF4),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFBBF7D0)),
            ),
            child: Row(
              children: [
                const Icon(Icons.gps_fixed,
                    size: 14, color: Colors.green),
                const SizedBox(width: 6),
                Text(
                  'GPS: ${_latitude!.toStringAsFixed(5)}, '
                  '${_longitude!.toStringAsFixed(5)}',
                  style: const TextStyle(
                      fontSize: 12, color: Colors.green),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Info box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF0F9FF),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFBAE6FD)),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline,
                  size: 16, color: Color(0xFF0284C7)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Your report will be reviewed by Bacnotan LGU officials. '
                  'Barangay staff may recategorize your concern if needed '
                  'for proper routing.',
                  style: TextStyle(
                      fontSize: 11, color: Color(0xFF0369A1)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // Submit button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: gradientStart,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: _submitting
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text('Submit Report',
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Evidence helpers
  // ---------------------------------------------------------------------------

  Widget _evidenceButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Colors.grey.shade300, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Icon(icon, size: 32, color: gradientStart),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(
                  color: gradientStart,
                  fontWeight: FontWeight.w600,
                  fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaPreview() {
    final isVideo = _videoFile != null;
    final file    = isVideo ? _videoFile! : _imageFile!;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: gradientStart.withValues(alpha: 0.5)),
      ),
      child: Stack(
        children: [
          // Preview
          ClipRRect(
            borderRadius: BorderRadius.circular(11),
            child: isVideo
                ? Container(
                    height: 160,
                    width: double.infinity,
                    color: Colors.black,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.videocam,
                            color: Colors.white, size: 48),
                        SizedBox(height: 8),
                        Text('Video selected',
                            style: TextStyle(
                                color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  )
                : kIsWeb
                    ? Image.network(
                        file.path,
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      )
                    : Image.file(
                        File(file.path),
                        height: 160,
                        width: double.infinity,
                        fit: BoxFit.cover,
                      ),
          ),

          // Type badge
          Positioned(
            top: 8,
            left: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isVideo ? Colors.blue : gradientStart,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isVideo
                        ? Icons.videocam
                        : Icons.photo_camera,
                    color: Colors.white,
                    size: 12,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    isVideo ? 'Video' : 'Photo',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          ),

          // Remove button
          Positioned(
            top: 6,
            right: 6,
            child: GestureDetector(
              onTap: () => setState(() {
                _imageFile = null;
                _videoFile = null;
              }),
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.close,
                    color: Colors.white, size: 16),
              ),
            ),
          ),

          // Change button
          Positioned(
            bottom: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => setState(() {
                _imageFile = null;
                _videoFile = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'Change',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Pickers
  // ---------------------------------------------------------------------------

  Future<void> _pickPhoto() async {
    final allowed = await _showMediaConsentDialog(isVideo: false);
    if (!allowed) return;

    final source = await _showSourceSheet(isVideo: false);
    if (source == null) return;

    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 75,
      maxWidth: 1280,
    );
    if (picked != null && mounted) {
      setState(() {
        _imageFile = picked;
        _videoFile = null;
      });
    }
  }

  Future<void> _pickVideo() async {
    final allowed = await _showMediaConsentDialog(isVideo: true);
    if (!allowed) return;

    final source = await _showSourceSheet(isVideo: true);
    if (source == null) return;

    final picked = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 3),
    );
    if (picked != null && mounted) {
      setState(() {
        _videoFile = picked;
        _imageFile = null;
      });
    }
  }

  Future<bool> _showMediaConsentDialog({required bool isVideo}) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text(isVideo
            ? '🎥 Video Access Notice'
            : '📷 Camera Access Notice'),
        content: Text(
          isVideo
              ? 'BEE-Alert will record a video as evidence. '
                'The video will include timestamp and location data '
                'and will be shared with Bacnotan LGU officials. '
                'Maximum duration: 3 minutes. '
                'By proceeding, you consent to video recording.'
              : 'BEE-Alert will use your camera to capture photo evidence. '
                'Photos will include timestamp and location data. '
                'This information will be shared with Bacnotan LGU officials. '
                'By proceeding, you consent to photo capture.',
          style: const TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel',
                style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: gradientStart),
            child: Text(isVideo
                ? 'Allow & Record'
                : 'Allow & Continue'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<ImageSource?> _showSourceSheet({required bool isVideo}) async {
    return showModalBottomSheet<ImageSource>(
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
            const SizedBox(height: 12),
            Text(
              isVideo ? 'Record or Upload Video' : 'Take or Upload Photo',
              style: const TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.camera_alt_outlined,
                    color: gradientStart),
              ),
              title: Text(isVideo ? 'Record a Video' : 'Take a Photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFFFF3E0),
                child: Icon(Icons.photo_library_outlined,
                    color: gradientStart),
              ),
              title: Text(isVideo
                  ? 'Choose from Gallery'
                  : 'Choose from Gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // GPS
  // ---------------------------------------------------------------------------

  Future<void> _useGpsLocation() async {
    try {
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Location permission permanently denied.')),
        );
        return;
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);

      // Store coordinates immediately so GPS pin shows
      setState(() {
        _latitude  = pos.latitude;
        _longitude = pos.longitude;
        _locationController.text =
            '${pos.latitude.toStringAsFixed(5)}, '
            '${pos.longitude.toStringAsFixed(5)}';
      });

      // Reverse-geocode — Nominatim on web, native geocoder on device
      String? address;
      try {
        if (kIsWeb) {
          // Nominatim (OpenStreetMap) — works on web, no API key needed
          final uri = Uri.parse(
            'https://nominatim.openstreetmap.org/reverse'
            '?lat=${pos.latitude}&lon=${pos.longitude}'
            '&format=json&addressdetails=1',
          );
          final response = await http.get(uri, headers: {
            'Accept': 'application/json',
            'User-Agent': 'BEEAlert/1.0',
          });
          if (response.statusCode == 200) {
            final data =
                jsonDecode(response.body) as Map<String, dynamic>;
            final addr =
                data['address'] as Map<String, dynamic>? ?? {};
            final parts = <String>[
              if ((addr['road'] as String?)?.isNotEmpty == true)
                addr['road'] as String,
              if ((addr['suburb'] as String?)?.isNotEmpty == true)
                addr['suburb'] as String,
              if ((addr['village'] as String?)?.isNotEmpty == true)
                addr['village'] as String,
              if ((addr['city'] as String?)?.isNotEmpty == true)
                addr['city'] as String
              else if ((addr['town'] as String?)?.isNotEmpty == true)
                addr['town'] as String
              else if ((addr['municipality'] as String?)?.isNotEmpty ==
                  true)
                addr['municipality'] as String,
              if ((addr['province'] as String?)?.isNotEmpty == true)
                addr['province'] as String,
            ];
            if (parts.isNotEmpty) address = parts.join(', ');
          }
        } else {
          // Native geocoder — works on Android / iOS
          final placemarks = await placemarkFromCoordinates(
            pos.latitude,
            pos.longitude,
          );
          if (placemarks.isNotEmpty) {
            final p = placemarks.first;
            final parts = <String>[
              if (p.street?.isNotEmpty == true) p.street!,
              if (p.subLocality?.isNotEmpty == true) p.subLocality!,
              if (p.locality?.isNotEmpty == true) p.locality!,
              if (p.administrativeArea?.isNotEmpty == true)
                p.administrativeArea!,
            ];
            if (parts.isNotEmpty) address = parts.join(', ');
          }
        }
      } catch (_) {
        // Geocoding failed — raw coordinates remain in the field
      }

      if (address != null && address.isNotEmpty && mounted) {
        setState(() => _locationController.text = address!);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not get location: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Ban dialog
  // ---------------------------------------------------------------------------

  void _showBanDialog(DateTime bannedUntil) {
    final remaining = bannedUntil.difference(DateTime.now());
    final hours     = remaining.inHours;
    final minutes   = remaining.inMinutes % 60;

    String timeLeft;
    if (hours > 0) {
      timeLeft = '$hours hour${hours != 1 ? 's' : ''}'
          '${minutes > 0 ? ' and $minutes minute${minutes != 1 ? 's' : ''}' : ''}';
    } else {
      timeLeft = '$minutes minute${minutes != 1 ? 's' : ''}';
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 26),
            SizedBox(width: 10),
            Text(
              'Account Banned',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.red),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: const Text(
                'Your account has been temporarily banned. '
                'You are not allowed to submit new reports during the ban period.',
                style: TextStyle(fontSize: 13, color: Colors.red),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.timer_outlined,
                    size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Ban lifts in: $timeLeft',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 16, color: Color(0xFF6B7280)),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Until: ${bannedUntil.toLocal().toString().substring(0, 16)}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF6B7280)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Text(
              'If you believe this is a mistake, please contact your barangay office.',
              style: TextStyle(
                  fontSize: 12, color: Color(0xFF9CA3AF)),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('OK, understood'),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Submit
  // ---------------------------------------------------------------------------

  Future<void> _submit() async {
    if (_descController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please describe your concern.')),
      );
      return;
    }

    if (_locationController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Please enter a location or use GPS.')),
      );
      return;
    }

    setState(() => _submitting = true);

    // ── Ban check ─────────────────────────────────────────────────────────
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        final snap = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();
        final data        = snap.data() ?? {};
        final bannedField = data['bannedUntil'];
        if (bannedField != null) {
          final bannedUntil = bannedField is Timestamp
              ? bannedField.toDate()
              : DateTime.tryParse(bannedField.toString());
          if (bannedUntil != null && bannedUntil.isAfter(DateTime.now())) {
            if (!mounted) return;
            setState(() => _submitting = false);
            _showBanDialog(bannedUntil);
            return;
          }
        }
      }
    } catch (_) {
      // If ban check fails, allow submission to proceed
    }
    // ─────────────────────────────────────────────────────────────────────

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final ref  = _reportService.generateReportReference();
      final now  = DateTime.now();

      final report = ReportModel(
        id: '',
        userId: user.uid,
        userName: _userProfile?.fullName ?? '',
        barangay: _userProfile?.barangay ?? '',
        category: _selectedCategory!,
        description: _descController.text.trim(),
        latitude: _latitude,
        longitude: _longitude,
        location: _locationController.text.trim(),
        status: statusPending,
        submittedAt: now,
        updatedAt: now,
        reportReference: ref,
      );

      await _reportService.submitReport(
        report,
        imageFile: _imageFile,
        videoFile: _videoFile,
      );

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed(
        '/report-success',
        arguments: {
          'reportReference': ref,
          'category': _selectedCategory,
          'location': _locationController.text.trim(),
          'submittedAt': now,
        },
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to submit: $e')),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Header helpers
  // ---------------------------------------------------------------------------

  String _stepTitle() {
    switch (_step) {
      case 1:
        return 'Step 1 of 3: Select Category';
      case 2:
        return 'Step 2 of 3: Report Details';
      default:
        return '';
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
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
            child: SafeArea(
              child: Padding(
                padding:
                    const EdgeInsets.fromLTRB(16, 12, 16, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      onPressed: () {
                        if (_step == 2) {
                          setState(() => _step = 1);
                        } else {
                          Navigator.of(context).pop();
                        }
                      },
                      icon: const Icon(
                          Icons.arrow_back_ios_new,
                          color: Colors.white),
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Report Concern',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _stepTitle(),
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    // Progress bar
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: _step >= 2
                                  ? Colors.white
                                  : Colors.white38,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Container(
                            height: 4,
                            decoration: BoxDecoration(
                              color: Colors.white38,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Body
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child:
                  _step == 1 ? _buildStep1() : _buildStep2(),
            ),
          ),
        ],
      ),
    );
  }
}
