/// Bug 2 Preservation Tests — Personal Notification Read Tracking is Unchanged
///
/// **Validates: Requirements 2.3**
///
/// Property 2 (Preservation): The Bug 2 fix (adding lastSeenAlertsAt-based
/// global-alert counting) MUST NOT break personal notification read tracking,
/// the mark-read helpers, or the existing stream accessors.
///
/// These tests MUST PASS on both UNFIXED and FIXED code — they encode the
/// baseline contract that the fix is not allowed to regress.
///
/// Tests covered:
///   1. [P2-PRESERVATION-1] getUnreadCount returns N for N unread personal
///      notifications when there are no global alerts.
///   2. [P2-PRESERVATION-2] Personal notifications with read == true are NOT
///      counted by getUnreadCount.
///   3. [P2-PRESERVATION-3] markRead() sets read: true on the correct document
///      and the count stream reflects the change.
///   4. [P2-PRESERVATION-4] markAllRead() sets read: true on every unread
///      personal notification; count stream drops to 0.
///   5. [P2-PRESERVATION-5] Mixed: N unread personal + M new global alerts
///      (newer than lastSeenAlertsAt) → count == N + M.
///   6. [P2-PRESERVATION-6] getAlerts() stream returns all global alerts.
///   7. [P2-PRESERVATION-7] getUserNotifications(uid) stream returns all
///      personal notifications.

// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beealert_mobile/services/alert_service.dart';
import 'package:beealert_mobile/models/alert_model.dart';

void main() {
  group('Bug 2 – Preservation: Personal Notification Read Tracking', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AlertService alertService;

    const testUid = 'preservation-notif-user-001';

    /// Deterministic "now" so all relative timestamps are stable.
    final now = DateTime(2025, 6, 1, 12, 0, 0);

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      alertService = AlertService.withFirestore(fakeFirestore);
    });

    // -----------------------------------------------------------------------
    // Helpers
    // -----------------------------------------------------------------------

    /// Create the user document.  [lastSeenAlertsAt] is optional — when null
    /// the field is omitted (simulates a first-time user).
    Future<void> _createUser({DateTime? lastSeenAlertsAt}) async {
      final doc = <String, dynamic>{
        'uid': testUid,
        'fullName': 'Preservation User',
        'email': 'preservation@example.com',
        'barangay': 'Poblacion',
        'address': '1 Test St',
        'phoneNumber': '09111111111',
        'role': 'resident',
        'status': 'approved',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
      };
      if (lastSeenAlertsAt != null) {
        doc['lastSeenAlertsAt'] = Timestamp.fromDate(lastSeenAlertsAt);
      }
      await fakeFirestore.collection('users').doc(testUid).set(doc);
    }

    /// Seed a personal notification for [testUid].
    /// [read] defaults to false (unread).
    Future<void> _addPersonalNotification(
      String id, {
      bool read = false,
      DateTime? createdAt,
    }) async {
      await fakeFirestore
          .collection('users')
          .doc(testUid)
          .collection('notifications')
          .doc(id)
          .set({
        'type': 'report_update',
        'priority': 'medium',
        'title': 'Personal $id',
        'description': 'Body for $id',
        'createdAt': Timestamp.fromDate(
            createdAt ?? now.subtract(const Duration(hours: 1))),
        'read': read,
      });
    }

    /// Seed a global alert document.
    Future<void> _addGlobalAlert(
      String id, {
      required DateTime createdAt,
    }) async {
      await fakeFirestore.collection('alerts').doc(id).set({
        'type': 'announcement',
        'priority': 'low',
        'title': 'Alert $id',
        'description': 'Global alert body',
        'createdAt': Timestamp.fromDate(createdAt),
        'read': false,
      });
    }

    // =========================================================================
    // Test 1 — getUnreadCount returns N for N unread personal notifications
    //           when there are no global alerts at all.
    //
    // This confirms the personal-notification branch in getUnreadCount is
    // intact and unaffected by the global-alert fix.
    // =========================================================================
    test(
      'P2-PRESERVATION-1: getUnreadCount returns N for N unread personal '
      'notifications when there are no global alerts',
      () async {
        // Arrange: user with lastSeenAlertsAt = now; 3 unread personal notifs;
        // no global alerts seeded.
        await _createUser(lastSeenAlertsAt: now);
        await _addPersonalNotification('n1');
        await _addPersonalNotification('n2');
        await _addPersonalNotification('n3');

        // Act: first emission from the stream.
        final count = await alertService
            .getUnreadCount(uid: testUid)
            .first
            .timeout(const Duration(seconds: 5));

        // Assert.
        expect(
          count,
          equals(3),
          reason:
              'getUnreadCount must return 3 for 3 unread personal notifications '
              'with no global alerts',
        );
      },
    );

    // =========================================================================
    // Test 2 — Personal notifications with read == true are NOT counted.
    //
    // Confirms the where('read', isEqualTo: false) predicate still applies.
    // =========================================================================
    test(
      'P2-PRESERVATION-2: Personal notifications with read == true are NOT '
      'counted by getUnreadCount',
      () async {
        await _createUser(lastSeenAlertsAt: now);

        // 2 read, 1 unread.
        await _addPersonalNotification('read-1', read: true);
        await _addPersonalNotification('read-2', read: true);
        await _addPersonalNotification('unread-1', read: false);

        final count = await alertService
            .getUnreadCount(uid: testUid)
            .first
            .timeout(const Duration(seconds: 5));

        expect(
          count,
          equals(1),
          reason:
              'Only 1 notification is unread — getUnreadCount must return 1, '
              'not 3',
        );
      },
    );

    // =========================================================================
    // Test 3 — markRead() sets read: true on the correct document.
    //
    // After calling markRead the stream should drop by 1 and the Firestore
    // document should have read == true.
    // =========================================================================
    test(
      'P2-PRESERVATION-3: markRead(uid, notifId) sets read: true on the '
      'correct document and count stream reflects the change',
      () async {
        await _createUser(lastSeenAlertsAt: now);

        await _addPersonalNotification('target', read: false);
        await _addPersonalNotification('other', read: false);

        // Collect count emissions: we expect [2, 1].
        final counts = <int>[];
        final subscription =
            alertService.getUnreadCount(uid: testUid).listen(counts.add);

        // Wait for initial emission.
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act: mark one notification as read.
        await alertService.markRead(testUid, 'target');

        // Wait for the reactive update to propagate.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await subscription.cancel();

        // Verify Firestore document was updated.
        final doc = await fakeFirestore
            .collection('users')
            .doc(testUid)
            .collection('notifications')
            .doc('target')
            .get();
        expect(
          doc.data()?['read'],
          isTrue,
          reason: 'markRead must set read: true on the target document',
        );

        // Verify the other document is untouched.
        final otherDoc = await fakeFirestore
            .collection('users')
            .doc(testUid)
            .collection('notifications')
            .doc('other')
            .get();
        expect(
          otherDoc.data()?['read'],
          isFalse,
          reason: 'markRead must not affect other documents',
        );

        // Verify count dropped after markRead.
        expect(
          counts.last,
          equals(1),
          reason: 'After marking one notification read, count must be 1',
        );
      },
    );

    // =========================================================================
    // Test 4 — markAllRead() sets read: true on ALL unread notifications.
    //
    // After markAllRead the stream should reach 0 (personal unread = 0,
    // no global alerts).
    // =========================================================================
    test(
      'P2-PRESERVATION-4: markAllRead(uid) sets read: true on every unread '
      'personal notification and count stream drops to 0',
      () async {
        await _createUser(lastSeenAlertsAt: now);

        await _addPersonalNotification('n1');
        await _addPersonalNotification('n2');
        await _addPersonalNotification('n3');

        final counts = <int>[];
        final subscription =
            alertService.getUnreadCount(uid: testUid).listen(counts.add);

        // Wait for initial emission (3).
        await Future<void>.delayed(const Duration(milliseconds: 200));

        // Act.
        await alertService.markAllRead(testUid);

        // Wait for the reactive update.
        await Future<void>.delayed(const Duration(milliseconds: 200));
        await subscription.cancel();

        // Verify all documents are now read.
        final snap = await fakeFirestore
            .collection('users')
            .doc(testUid)
            .collection('notifications')
            .get();
        for (final doc in snap.docs) {
          expect(
            doc.data()['read'],
            isTrue,
            reason: 'markAllRead must set read: true on every document',
          );
        }

        // Count must reach 0.
        expect(
          counts.last,
          equals(0),
          reason: 'After markAllRead, count stream must emit 0',
        );
      },
    );

    // =========================================================================
    // Test 5 — Mixed: N unread personal + M new global alerts = N + M.
    //
    // Validates that personal and global counts are summed correctly after the
    // Bug 2 fix.  [lastSeenAlertsAt] is set to 2.5 h ago; 2 alerts are newer
    // (unread), 1 is older (read); 2 personal notifications are unread.
    // Expected count: 2 personal + 2 new global = 4.
    // =========================================================================
    test(
      'P2-PRESERVATION-5: Mixed — N unread personal + M new global alerts '
      '(newer than lastSeenAlertsAt) gives N + M count',
      () async {
        // lastSeenAlertsAt = 2.5 hours ago.
        final lastSeen = now.subtract(const Duration(hours: 2, minutes: 30));
        await _createUser(lastSeenAlertsAt: lastSeen);

        // 2 unread personal notifications.
        await _addPersonalNotification('p1');
        await _addPersonalNotification('p2');

        // 2 new global alerts (after lastSeen).
        await _addGlobalAlert('new-a1',
            createdAt: now.subtract(const Duration(hours: 1)));
        await _addGlobalAlert('new-a2',
            createdAt: now.subtract(const Duration(hours: 2)));

        // 1 old global alert (before lastSeen — already seen).
        await _addGlobalAlert('old-a1',
            createdAt: now.subtract(const Duration(hours: 3)));

        final count = await alertService
            .getUnreadCount(uid: testUid)
            .first
            .timeout(const Duration(seconds: 5));

        expect(
          count,
          equals(4),
          reason:
              '2 unread personal + 2 unseen global (1 seen global excluded) '
              '= 4 total unread',
        );
      },
    );

    // =========================================================================
    // Test 6 — getAlerts() stream returns all global alerts.
    //
    // This stream must be unaffected by the Bug 2 fix.
    // =========================================================================
    test(
      'P2-PRESERVATION-6: getAlerts() stream returns all global alerts '
      'ordered newest-first',
      () async {
        // Seed 3 alerts with distinct timestamps.
        await _addGlobalAlert('g1',
            createdAt: now.subtract(const Duration(hours: 1)));
        await _addGlobalAlert('g2',
            createdAt: now.subtract(const Duration(hours: 2)));
        await _addGlobalAlert('g3',
            createdAt: now.subtract(const Duration(hours: 3)));

        final alerts = await alertService
            .getAlerts()
            .first
            .timeout(const Duration(seconds: 5));

        expect(
          alerts.length,
          equals(3),
          reason: 'getAlerts() must return all 3 global alert documents',
        );

        // Verify ordered newest-first (Firestore orderBy descending).
        expect(
          alerts[0].id,
          equals('g1'),
          reason: 'First alert should be the most recently created (g1)',
        );
        expect(
          alerts[1].id,
          equals('g2'),
          reason: 'Second alert should be g2',
        );
        expect(
          alerts[2].id,
          equals('g3'),
          reason: 'Third alert should be the oldest (g3)',
        );

        // Verify they parse correctly.
        for (final alert in alerts) {
          expect(alert, isA<AlertModel>());
          expect(alert.title, isNotEmpty);
        }
      },
    );

    // =========================================================================
    // Test 7 — getUserNotifications(uid) stream returns all personal notifs.
    //
    // This stream must be unaffected by the Bug 2 fix.
    // =========================================================================
    test(
      'P2-PRESERVATION-7: getUserNotifications(uid) stream returns all '
      'personal notifications for the user ordered newest-first',
      () async {
        await _createUser();

        // Seed 3 personal notifications with distinct timestamps.
        await _addPersonalNotification('pn1',
            createdAt: now.subtract(const Duration(hours: 1)));
        await _addPersonalNotification('pn2',
            createdAt: now.subtract(const Duration(hours: 2)));
        await _addPersonalNotification('pn3',
            createdAt: now.subtract(const Duration(hours: 3)));

        final notifications = await alertService
            .getUserNotifications(testUid)
            .first
            .timeout(const Duration(seconds: 5));

        expect(
          notifications.length,
          equals(3),
          reason:
              'getUserNotifications() must return all 3 personal notification '
              'documents',
        );

        // Verify ordered newest-first.
        expect(
          notifications[0].id,
          equals('pn1'),
          reason: 'First notification should be the most recent (pn1)',
        );
        expect(
          notifications[2].id,
          equals('pn3'),
          reason: 'Last notification should be the oldest (pn3)',
        );

        // Verify they parse correctly as AlertModel instances.
        for (final notif in notifications) {
          expect(notif, isA<AlertModel>());
          expect(notif.title, isNotEmpty);
        }
      },
    );
  });
}
