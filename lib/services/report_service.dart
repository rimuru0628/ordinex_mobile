import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import '../models/report_model.dart';
import 'cloudinary_service.dart';

class ReportService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Generate a unique report reference: RPT-{timestamp}-{3-digit random}
  String generateReportReference() {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final rand = (Random().nextInt(900) + 100).toString();
    return 'RPT-$ts-$rand';
  }

  /// Submit a report — uploads image/video to Cloudinary then saves to Firestore.
  /// Cloudinary handles web and native without CORS issues.
  Future<String> submitReport(
    ReportModel report, {
    XFile? imageFile,
    XFile? videoFile,
  }) async {
    String? imageUrl;
    String? videoUrl;

    if (imageFile != null) {
      imageUrl = await CloudinaryService.uploadFile(
        imageFile,
        folder: 'reports',
        resourceType: 'image',
      );
    }

    if (videoFile != null) {
      videoUrl = await CloudinaryService.uploadFile(
        videoFile,
        folder: 'reports',
        resourceType: 'video',
      );
    }

    final data = report.toMap();
    if (imageUrl != null) data['imageUrl'] = imageUrl;
    if (videoUrl != null) data['videoUrl'] = videoUrl;

    final docRef = await _db.collection('reports').add(data);
    final docId = docRef.id;

    // Notify admin immediately — fires regardless of which tab is open
    _db.collection('admin_notifications').add({
      'type': 'new_report',
      'title': 'New Report: ${report.category}',
      'body':
          '${report.userName.isNotEmpty ? report.userName : 'A resident'} submitted a ${report.category} report. Ref: ${report.reportReference}',
      'meta': {
        'reportId': docId,
        'reportRef': report.reportReference,
        'userId': report.userId,
        'residentName': report.userName,
        'category': report.category,
      },
      'read': false,
      'createdAt': FieldValue.serverTimestamp(),
    }).catchError((Object _) => _db.collection('admin_notifications').doc());

    return docId;
  }

  /// Real-time stream of all reports for a given user
  Stream<List<ReportModel>> getUserReports(String uid) {
    return _db
        .collection('reports')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) => ReportModel.fromDoc(doc)).toList();
          list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
          return list;
        });
  }

  /// Fetch the 3 most recent reports for home screen
  Stream<List<ReportModel>> getRecentReports(String uid) {
    return _db
        .collection('reports')
        .where('userId', isEqualTo: uid)
        .snapshots()
        .map((snap) {
          final list = snap.docs.map((doc) => ReportModel.fromDoc(doc)).toList();
          list.sort((a, b) => b.submittedAt.compareTo(a.submittedAt));
          return list.take(3).toList();
        });
  }

  /// Update the description of a report
  Future<void> updateDescription(String reportId, String description) async {
    await _db.collection('reports').doc(reportId).update({
      'description': description,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Cancel a report — only allowed when status is still Pending.
  /// Stores the cancellation reason and marks status as 'Cancelled'.
  Future<void> cancelReport(String reportId, String reason) async {
    await _db.collection('reports').doc(reportId).update({
      'status': 'Cancelled',
      'cancellationReason': reason.trim(),
      'updatedAt': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Hard-delete a report document (admin only).
  Future<void> deleteReport(String reportId) async {
    await _db.collection('reports').doc(reportId).delete();
  }

  /// Real-time stream of status history for a report, newest first.
  Stream<List<Map<String, dynamic>>> getStatusHistory(String reportId) {
    return _db
        .collection('reports')
        .doc(reportId)
        .collection('statusHistory')
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => d.data()).toList());
  }
}
