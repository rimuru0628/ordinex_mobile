import 'package:cloud_firestore/cloud_firestore.dart';

class ReportModel {
  final String id;
  final String userId;
  final String userName;
  final String barangay;
  final String category;
  final String description;
  final String? imageUrl;
  final String? videoUrl;
  final double? latitude;
  final double? longitude;
  final String location;
  final String status;
  final DateTime submittedAt;
  final DateTime updatedAt;
  final String reportReference;
  final String? lastUpdate;
  final String? cancellationReason;

  const ReportModel({
    required this.id,
    required this.userId,
    required this.userName,
    required this.barangay,
    required this.category,
    required this.description,
    this.imageUrl,
    this.videoUrl,
    this.latitude,
    this.longitude,
    required this.location,
    required this.status,
    required this.submittedAt,
    required this.updatedAt,
    required this.reportReference,
    this.lastUpdate,
    this.cancellationReason,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'userName': userName,
        'barangay': barangay,
        'category': category,
        'description': description,
        'imageUrl': imageUrl,
        'videoUrl': videoUrl,
        'latitude': latitude,
        'longitude': longitude,
        'location': location,
        'status': status,
        'submittedAt': Timestamp.fromDate(submittedAt),
        'updatedAt': Timestamp.fromDate(updatedAt),
        'reportReference': reportReference,
        'lastUpdate': lastUpdate,
        'cancellationReason': cancellationReason,
      };

  factory ReportModel.fromMap(Map<String, dynamic> map, String id) =>
      ReportModel(
        id: id,
        userId: map['userId'] as String? ?? '',
        userName: map['userName'] as String? ?? '',
        barangay: map['barangay'] as String? ?? '',
        category: map['category'] as String? ?? '',
        description: map['description'] as String? ?? '',
        imageUrl: map['imageUrl'] as String?,
        videoUrl: map['videoUrl'] as String?,
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
        location: map['location'] as String? ?? '',
        status: map['status'] as String? ?? 'Pending',
        submittedAt: map['submittedAt'] is Timestamp
            ? (map['submittedAt'] as Timestamp).toDate()
            : DateTime.now(),
        updatedAt: map['updatedAt'] is Timestamp
            ? (map['updatedAt'] as Timestamp).toDate()
            : DateTime.now(),
        reportReference: map['reportReference'] as String? ?? '',
        lastUpdate: map['lastUpdate'] as String?,
        cancellationReason: map['cancellationReason'] as String?,
      );

  factory ReportModel.fromDoc(DocumentSnapshot doc) =>
      ReportModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
}
