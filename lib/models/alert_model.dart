import 'package:cloud_firestore/cloud_firestore.dart';

class AlertModel {
  final String id;
  /// 'emergency' | 'announcement' | 'report_update' | 'report_completed'
  /// | 'account_approved' | 'account_rejected'
  final String type;
  final String priority; // 'high' | 'medium' | 'low'
  final String title;
  final String description;
  final DateTime createdAt;
  final String? actionLink;
  final bool read;
  final Map<String, dynamic>? meta;

  const AlertModel({
    required this.id,
    required this.type,
    required this.priority,
    required this.title,
    required this.description,
    required this.createdAt,
    this.actionLink,
    this.read = false,
    this.meta,
  });

  bool get isPersonal => const {
    'report_update',
    'report_completed',
    'account_approved',
    'account_rejected',
  }.contains(type);

  bool get isEmergency => type == 'emergency';

  factory AlertModel.fromMap(Map<String, dynamic> map, String id) => AlertModel(
        id: id,
        type: map['type'] as String? ?? 'announcement',
        priority: map['priority'] as String? ?? 'low',
        title: map['title'] as String? ?? '',
        description: (map['description'] ?? map['body']) as String? ?? '',
        createdAt: map['createdAt'] is Timestamp
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        actionLink: map['actionLink'] as String?,
        read: map['read'] as bool? ?? false,
        meta: map['meta'] as Map<String, dynamic>?,
      );

  factory AlertModel.fromDoc(DocumentSnapshot doc) =>
      AlertModel.fromMap(doc.data() as Map<String, dynamic>, doc.id);
}
