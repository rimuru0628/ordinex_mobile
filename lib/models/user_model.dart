import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String fullName;
  final String email;
  final String barangay;
  final String address;
  final String phoneNumber;
  final String role;
  /// 'pending' | 'approved' | 'rejected'
  final String status;
  final DateTime createdAt;
  final String? idImageUrl;
  /// Timestamp of when the user last opened the Alerts tab.
  /// Used to compute the unread global-alert count.
  final DateTime? lastSeenAlertsAt;

  const UserModel({
    required this.uid,
    required this.fullName,
    required this.email,
    required this.barangay,
    required this.address,
    required this.phoneNumber,
    this.role = 'resident',
    this.status = 'pending',
    required this.createdAt,
    this.idImageUrl,
    this.lastSeenAlertsAt,
  });

  /// The admin web app reads `displayName` — expose fullName under that alias.
  String get displayName => fullName;

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'fullName': fullName,
        'displayName': fullName, // alias read by the admin web panel
        'email': email,
        'barangay': barangay,
        'address': address,
        'phoneNumber': phoneNumber,
        'role': role,
        'status': status,
        'createdAt': Timestamp.fromDate(createdAt),
        if (idImageUrl != null) 'idImageUrl': idImageUrl,
      };

  factory UserModel.fromMap(Map<String, dynamic> map, String uid) => UserModel(
        uid: uid,
        fullName: map['fullName'] as String? ?? map['displayName'] as String? ?? '',
        email: map['email'] as String? ?? '',
        barangay: map['barangay'] as String? ?? '',
        address: map['address'] as String? ?? '',
        phoneNumber: map['phoneNumber'] as String? ?? '',
        role: map['role'] as String? ?? 'resident',
        status: map['status'] as String? ?? 'pending',
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        idImageUrl: map['idImageUrl'] as String?,
        lastSeenAlertsAt: map['lastSeenAlertsAt'] is Timestamp
            ? (map['lastSeenAlertsAt'] as Timestamp).toDate()
            : null,
      );

  factory UserModel.fromDoc(DocumentSnapshot doc) =>
      UserModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);

  UserModel copyWith({
    String? uid,
    String? fullName,
    String? email,
    String? barangay,
    String? address,
    String? phoneNumber,
    String? role,
    String? status,
    DateTime? createdAt,
    String? idImageUrl,
    DateTime? lastSeenAlertsAt,
  }) =>
      UserModel(
        uid: uid ?? this.uid,
        fullName: fullName ?? this.fullName,
        email: email ?? this.email,
        barangay: barangay ?? this.barangay,
        address: address ?? this.address,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        role: role ?? this.role,
        status: status ?? this.status,
        createdAt: createdAt ?? this.createdAt,
        idImageUrl: idImageUrl ?? this.idImageUrl,
        lastSeenAlertsAt: lastSeenAlertsAt ?? this.lastSeenAlertsAt,
      );
}
