import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:convert';

/// Uploads files to Cloudinary using unsigned uploads.
/// No Firebase Storage required — works on web and native.
class CloudinaryService {
  static const String _cloudName   = 'zq9gopfc';
  static const String _uploadPreset = 'beealert_uploads';

  static String get _uploadUrl =>
      'https://api.cloudinary.com/v1_1/$_cloudName/upload';

  /// Upload an [XFile] to Cloudinary and return the secure URL.
  /// Returns null if the upload fails.
  static Future<String?> uploadFile(
    XFile file, {
    String resourceType = 'auto',
    String? folder,
  }) async {
    try {
      final bytes = await file.readAsBytes();
      return await uploadBytes(
        bytes,
        filename: file.name,
        resourceType: resourceType,
        folder: folder,
      );
    } catch (_) {
      return null;
    }
  }

  /// Upload raw [Uint8List] bytes to Cloudinary and return the secure URL.
  /// Returns null if the upload fails.
  static Future<String?> uploadBytes(
    Uint8List bytes, {
    required String filename,
    String resourceType = 'auto',
    String? folder,
  }) async {
    try {
      final request = http.MultipartRequest('POST', Uri.parse(_uploadUrl));

      request.fields['upload_preset'] = _uploadPreset;
      request.fields['resource_type'] = resourceType;
      if (folder != null) request.fields['folder'] = folder;

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );

      final response = await request.send().timeout(
        const Duration(minutes: 3),
      );

      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final json = jsonDecode(body) as Map<String, dynamic>;
        return json['secure_url'] as String?;
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
