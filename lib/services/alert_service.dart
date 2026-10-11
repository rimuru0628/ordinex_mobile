import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/rxdart.dart';
import '../models/alert_model.dart';

class AlertService {
  final FirebaseFirestore _db;

  /// Default constructor — uses the real Firebase singleton.
  AlertService() : _db = FirebaseFirestore.instance;

  /// Injectable constructor for testing — accepts a fake/mock Firestore
  /// instance so tests remain hermetic (no live Firebase needed).
  AlertService.withFirestore(FirebaseFirestore db) : _db = db;

  // ── Global alerts (admin broadcast) ───────────────────────────────────────

  Stream<List<AlertModel>> getAlerts() {
    return _db
        .collection('alerts')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AlertModel.fromDoc(d)).toList());
  }

  // ── Per-user notifications (from admin actions) ────────────────────────────

  Stream<List<AlertModel>> getUserNotifications(String uid) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => AlertModel.fromDoc(d)).toList());
  }

  /// Merged stream: global alerts + per-user notifications, sorted newest-first
  Stream<List<AlertModel>> getAllNotifications(String uid) {
    return Rx.combineLatest2<List<AlertModel>, List<AlertModel>, List<AlertModel>>(
      getAlerts(),
      getUserNotifications(uid),
      (global, personal) {
        final merged = [...personal, ...global];
        merged.sort((a, b) => b.createdAt.compareTo(a.createdAt));
        return merged;
      },
    );
  }

  // ── Unread count (personal unread + unseen global alerts) ──────────────────

  Stream<int> getUnreadCount({String? uid}) {
    if (uid == null) {
      return Stream.value(0);
    }

    // Stream lastSeenAlertsAt from the user document
    final userDocStream = _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) {
          final data = doc.data() ?? {};
          final field = data['lastSeenAlertsAt'];
          if (field is Timestamp) return field.toDate();
          return null;
        });

    return Rx.combineLatest3<QuerySnapshot, QuerySnapshot, DateTime?, int>(
      _db
          .collection('users')
          .doc(uid)
          .collection('notifications')
          .where('read', isEqualTo: false)
          .snapshots(),
      _db
          .collection('alerts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      userDocStream,
      (personalSnap, globalSnap, lastSeen) {
        final personalCount = personalSnap.docs.length;
        final globalCount = globalSnap.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final createdAt = data['createdAt'];
          DateTime? alertTime;
          if (createdAt is Timestamp) alertTime = createdAt.toDate();
          if (alertTime == null) return false;
          // If the user has never opened the Alerts tab, all global alerts are unread
          if (lastSeen == null) return true;
          return alertTime.isAfter(lastSeen);
        }).length;
        return personalCount + globalCount;
      },
    );
  }

  // ── Mark global alerts as seen ─────────────────────────────────────────────

  /// Records that the user has seen all global alerts up to now.
  /// Call this when the user opens the Alerts tab.
  Future<void> markAlertsAsSeen(String uid) async {
    await _db.collection('users').doc(uid).update({
      'lastSeenAlertsAt': FieldValue.serverTimestamp(),
    });
  }

  // ── Mark a personal notification as read ──────────────────────────────────

  Future<void> markRead(String uid, String notificationId) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .doc(notificationId)
        .update({'read': true});
  }

  /// Mark all personal notifications as read
  Future<void> markAllRead(String uid) async {
    final snap = await _db
        .collection('users')
        .doc(uid)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
    final batch = _db.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
}
