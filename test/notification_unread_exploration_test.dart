/// Bug Condition Exploration Test — Bug 2: Notification Unread Count for
/// Global Alerts
///
/// **Validates: Requirements 2.1**
///
/// Property 1 (Bug Condition): Global Alert Count Never Reaches Zero
///
/// The original defective branch in [AlertService.getUnreadCount]:
///
///   ```dart
///   _db.collection('alerts')
///       .orderBy('createdAt', descending: true)
///       .limit(10)
///       .snapshots()
///       .map((snap) => snap.docs.length); // always 1–10, never 0
///   ```
///
/// This returned the raw document count regardless of whether the user had
/// already seen those alerts — so the badge never cleared.
///
/// Counterexample documented:
///   "getUnreadCount returns 3 even though the user has already seen all
///    global alerts — lastSeenAlertsAt was not considered in the count."
///
/// On UNFIXED code: P1-BUG emits 3 → test FAILS (confirms bug exists).
/// On FIXED code  : P1-BUG emits 0 → test PASSES (confirms fix is correct).

// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beealert_mobile/services/alert_service.dart';

void main() {
  group('Bug 2 – Notification Unread Count (Exploration Test)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AlertService alertService;

    const testUid = 'notif-user-001';

    /// Reference point used as "now" across all tests so relative timestamps
    /// are deterministic.
    final now = DateTime(2025, 6, 1, 12, 0, 0);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      alertService = AlertService.withFirestore(fakeFirestore);
    });

    // -----------------------------------------------------------------------
    // Helper: set up the user document with optional lastSeenAlertsAt
    // -----------------------------------------------------------------------
    Future<void> _createUser({DateTime? lastSeenAlertsAt}) async {
      final doc = <String, dynamic>{
        'uid': testUid,
        'fullName': 'Notif Test User',
        'email': 'notif@example.com',
        'barangay': 'Poblacion',
        'address': '1 Alert St',
        'phoneNumber': '09222222222',
        'role': 'resident',
        'status': 'approved',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
      };
      if (lastSeenAlertsAt != null) {
        doc['lastSeenAlertsAt'] = Timestamp.fromDate(lastSeenAlertsAt);
      }
      await fakeFirestore.collection('users').doc(testUid).set(doc);
    }

    // -----------------------------------------------------------------------
    // Helper: seed N global alert documents, each [offsetMinutes] minutes
    // before [now] (negative offset = in the past).
    // -----------------------------------------------------------------------
    Future<void> _addGlobalAlert({
      required String id,
      required DateTime createdAt,
    }) async {
      await fakeFirestore.collection('alerts').doc(id).set({
        'type': 'announcement',
        'priority': 'low',
        'title': 'Test Alert $id',
        'description': 'Body',
        'createdAt': Timestamp.fromDate(createdAt),
        'read': false,
      });
    }

    // -----------------------------------------------------------------------
    // Helper: add an unread personal notification for testUid
    // -----------------------------------------------------------------------
    Future<void> _addPersonalNotification(String id) async {
      await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('notifications')
          .doc(id)
          .set({
        'type': 'report_update',
        'priority': 'medium',
        'title': 'Personal $id',
        'description': 'Body',
        'createdAt': Timestamp.fromDate(now.subtract(const Duration(hours: 1))),
        'read': false,
      });
    }

    // =========================================================================
    // P1-BUG (main): 3 global alerts all older than lastSeenAlertsAt,
    //                0 unread personal notifications → should emit 0.
    //
    // On UNFIXED code: emits 3 (raw docs.length) → FAIL (bug confirmed).
    // On FIXED  code : emits 0 (all alerts precede lastSeenAlertsAt) → PASS.
    // =========================================================================
    test(
      'P1-BUG: getUnreadCount emits 0 when user has seen all 3 global alerts '
      '(lastSeenAlertsAt is newer than every alert)',
      () async {
        // Arrange: lastSeenAlertsAt = now; all 3 alerts are from 1–3 hours ago.
        await _createUser(lastSeenAlertsAt: now);

        await _addGlobalAlert(
          id: 'alert-1',
          createdAt: now.subtract(const Duration(hours: 1)),
        );
        await _addGlobalAlert(
          id: 'alert-2',
          createdAt: now.subtract(const Duration(hours: 2)),
        );
        await _addGlobalAlert(
          id: 'alert-3',
          createdAt: now.subtract(const Duration(hours: 3)),
        );

        // Act: observe the first emission from the count stream.
        final count = await alertService
            .getUnreadCount(uid: testUid)
            .first
            .timeout(const Duration(seconds: 5));

        if (count != 0) {
          print(
            '\n[COUNTEREXAMPLE] getUnreadCount returned $count even though the '
            'user has already seen all global alerts '
            '(lastSeenAlertsAt = $now, all alerts are older).\n'
            'Root cause: global branch used snapshot.docs.length without '
            'comparing createdAt against lastSeenAlertsAt.\n',
          );
        }

        // Assert: fixed code returns 0.
        expect(
          count,
          equals(0),
          reason:
              'All 3 global alerts are older than lastSeenAlertsAt — count '
              'must be 0. On unfixed code this returns 3.',
        );
      },
    );

    // =========================================================================
    // P1-SUPPLEMENTAL: 5 global alerts, 2 are newer than lastSeenAlertsAt
    //                  → should emit 2.
    // =========================================================================
    test(
      'P1-SUPPLEMENTAL: getUnreadCount emits 2 when 2 of 5 global alerts '
      'are newer than lastSeenAlertsAt',
      () async {
        // lastSeenAlertsAt = 2.5 hours ago from now.
        final lastSeen = now.subtract(const Duration(hours: 2, minutes: 30));
        await _createUser(lastSeenAlertsAt: lastSeen);

        // 2 alerts are newer than lastSeen (1 h and 2 h ago).
        await _addGlobalAlert(
          id: 'new-1',
          createdAt: now.subtract(const Duration(hours: 1)),
        );
        await _addGlobalAlert(
          id: 'new-2',
          createdAt: now.subtract(const Duration(hours: 2)),
        );

        // 3 alerts are older than lastSeen (3 h, 4 h, 5 h ago).
        await _addGlobalAlert(
          id: 'old-1',
          createdAt: now.subtract(const Duration(hours: 3)),
        );
        await _addGlobalAlert(
          id: 'old-2',
          createdAt: now.subtract(const Duration(hours: 4)),
        );
        await _addGlobalAlert(
          id: 'old-3',
          createdAt: now.subtract(const Duration(hours: 5)),
        );

        final count = await alertService
            .getUnreadCount(uid: testUid)
            .first
            .timeout(const Duration(seconds: 5));

        expect(
          count,
          equals(2),
          reason:
              'Only 2 alerts are newer than lastSeenAlertsAt — count must be 2',
        );
      },
    );

    // =========================================================================
    // P1-SUPPLEMENTAL: lastSeenAlertsAt is null (user has never opened the
    //                  Alerts tab) → all 3 global alerts count as unread → 3.
    // =========================================================================
    test(
      'P1-SUPPLEMENTAL: getUnreadCount emits 3 when lastSeenAlertsAt is null '
      '(user has never opened the Alerts tab)',
      () async {
        // No lastSeenAlertsAt field in user document.
        await _createUser(lastSeenAlertsAt: null);

        await _addGlobalAlert(
          id: 'a1',
          createdAt: now.subtract(const Duration(hours: 1)),
        );
        await _addGlobalAlert(
          id: 'a2',
          createdAt: now.subtract(const Duration(hours: 2)),
        );
        await _addGlobalAlert(
          id: 'a3',
          createdAt: now.subtract(const Duration(hours: 3)),
        );

        final count = await alertService
            .getUnreadCount(uid: testUid)
            .first
            .timeout(const Duration(seconds: 5));

        expect(
          count,
          equals(3),
          reason:
              'When lastSeenAlertsAt is null all global alerts are unread — '
              'count must be 3',
        );
      },
    );

    // =========================================================================
    // P1-SUPPLEMENTAL: No global alerts, no personal notifications → emit 0.
    // =========================================================================
    test(
      'P1-SUPPLEMENTAL: getUnreadCount emits 0 when there are no global '
      'alerts and no personal notifications',
      () async {
        await _createUser(lastSeenAlertsAt: now);
        // No alerts or notifications seeded.

        final count = await alertService
            .getUnreadCount(uid: testUid)
            .first
            .timeout(const Duration(seconds: 5));

        expect(
          count,
          equals(0),
          reason: 'No alerts or notifications → count must be 0',
        );
      },
    );
  });
}
