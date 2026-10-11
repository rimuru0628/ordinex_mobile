/// Bug Condition Exploration Test — Bug 1: Real-Time Ban Enforcement
///
/// **Validates: Requirements 1.1**
///
/// Property 1 (Bug Condition): Ban Applied While User is on HomeScreen
///
/// This test encodes the expected behavior of [AuthService.watchBanStatus].
/// - On UNFIXED code (no [watchBanStatus] method): this test FAILS to compile,
///   which confirms the bug exists — HomeScreen has no real-time ban listener.
/// - On FIXED code (stream method present): the stream emits a non-null
///   [DateTime] when bannedUntil is written to Firestore, confirming the
///   mechanism that drives the HomeScreen → BannedScreen navigation works.
///
/// Counterexample documented:
///   "HomeScreen remains on screen after bannedUntil was set — no navigation
///    occurred, because AuthService had no watchBanStatus stream and HomeScreen
///    had no real-time Firestore listener on users/{uid}."

// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beealert_mobile/services/auth_service.dart';

void main() {
  group('Bug 1 – Real-Time Ban Enforcement (Exploration Test)', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AuthService authService;

    const testUid = 'test-user-001';

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      // Inject the fake Firestore into AuthService so tests are hermetic.
      authService = AuthService.withFirestore(fakeFirestore);
    });

    // -------------------------------------------------------------------------
    // Helper: write the user document (no ban initially)
    // -------------------------------------------------------------------------
    Future<void> _createUnbannedUser() async {
      await fakeFirestore.collection('users').doc(testUid).set({
        'uid': testUid,
        'fullName': 'Test User',
        'email': 'test@example.com',
        'barangay': 'Poblacion',
        'address': '123 Test St',
        'phoneNumber': '09000000000',
        'role': 'resident',
        'status': 'approved',
        'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
      });
    }

    // -------------------------------------------------------------------------
    // P1-EXPLORATION: stream emits null for a non-banned user, then emits a
    // non-null DateTime once bannedUntil is written to Firestore.
    //
    // On UNFIXED code (no watchBanStatus): compile error — confirms bug.
    // On FIXED code: stream correctly detects the ban → confirms fix.
    // -------------------------------------------------------------------------
    test(
      'P1-BUG: watchBanStatus emits non-null DateTime when bannedUntil is '
      'written to Firestore while the stream is active',
      () async {
        await _createUnbannedUser();

        final emissions = <DateTime?>[];

        // Subscribe to the ban status stream — this is the real-time listener
        // that HomeScreen must hold. On unfixed code this method didn't exist.
        final subscription =
            authService.watchBanStatus(testUid).listen(emissions.add);

        // Allow the initial snapshot to be delivered (user is not banned yet).
        await Future<void>.delayed(Duration.zero);

        // Confirm the initial state: no ban.
        expect(
          emissions,
          contains(isNull),
          reason: 'Initial emission should be null — user is not banned',
        );

        // --- Simulate admin writing bannedUntil while user is on HomeScreen ---
        final bannedUntil = DateTime.now().add(const Duration(hours: 1));
        await fakeFirestore.collection('users').doc(testUid).update({
          'bannedUntil': Timestamp.fromDate(bannedUntil),
        });

        // Allow the snapshot listener to fire.
        await Future<void>.delayed(Duration.zero);

        await subscription.cancel();

        // The stream must have emitted a non-null DateTime.
        final banEmission = emissions.whereType<DateTime>().toList();

        if (banEmission.isEmpty) {
          // On unfixed code — no watchBanStatus stream — this failure fires.
          print(
            '\n[COUNTEREXAMPLE] HomeScreen remains on screen after bannedUntil '
            'was set — no navigation occurred, because AuthService had no '
            'watchBanStatus stream and HomeScreen had no real-time Firestore '
            'listener on users/{uid}.\n',
          );
        }

        expect(
          banEmission,
          isNotEmpty,
          reason:
              'watchBanStatus must emit a non-null DateTime after bannedUntil '
              'is written to Firestore. On unfixed code this fails because '
              'no real-time listener exists.',
        );

        // The emitted DateTime should match (within a second) the value written.
        final emitted = banEmission.first;
        expect(
          emitted.difference(bannedUntil).abs().inSeconds,
          lessThan(2),
          reason: 'Emitted bannedUntil should match the Firestore value',
        );
      },
    );

    // -------------------------------------------------------------------------
    // P1-SUPPLEMENTAL: stream emits null when bannedUntil is in the past
    // (expired ban should NOT trigger navigation to BannedScreen).
    // -------------------------------------------------------------------------
    test(
      'P1-SUPPLEMENTAL: watchBanStatus emits null when bannedUntil is '
      'already expired',
      () async {
        final expiredUntil =
            DateTime.now().subtract(const Duration(minutes: 5));
        await fakeFirestore.collection('users').doc(testUid).set({
          'uid': testUid,
          'fullName': 'Test User',
          'email': 'test@example.com',
          'barangay': 'Poblacion',
          'address': '123 Test St',
          'phoneNumber': '09000000000',
          'role': 'resident',
          'status': 'approved',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
          'bannedUntil': Timestamp.fromDate(expiredUntil),
        });

        final emissions = <DateTime?>[];
        final subscription =
            authService.watchBanStatus(testUid).listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(
          emissions,
          everyElement(isNull),
          reason:
              'An expired bannedUntil must emit null — user is no longer banned',
        );
      },
    );

    // -------------------------------------------------------------------------
    // P1-SUPPLEMENTAL: stream emits null when bannedUntil field is absent.
    // -------------------------------------------------------------------------
    test(
      'P1-SUPPLEMENTAL: watchBanStatus emits null when bannedUntil field '
      'is not present',
      () async {
        await _createUnbannedUser();

        final emissions = <DateTime?>[];
        final subscription =
            authService.watchBanStatus(testUid).listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(
          emissions,
          everyElement(isNull),
          reason: 'No bannedUntil field → stream must emit null',
        );
      },
    );
  });
}
