/// Bug 1 Preservation Tests — Non-Banned Users Are Unaffected
///
/// **Validates: Requirements 1.3**
///
/// Property 2 (Preservation): users who do NOT meet the bug condition
/// (bannedUntil is null, absent, or expired) must see no change in behavior.
///
/// These tests MUST PASS on both unfixed AND fixed code — they encode the
/// baseline contract that the fix must not break.
///
/// Tests covered:
///   1. `watchBanStatus` emits null when no `bannedUntil` field is present.
///   2. `watchBanStatus` emits null when `bannedUntil` is an expired timestamp.
///   3. `watchBanStatus` emits null when `bannedUntil` is explicitly null.
///   4. `getBanStatus()` returns null for non-banned users (existing login/
///      splash flow is preserved).
///   5. `getBanStatus()` returns a non-null DateTime for an actively banned
///      user (login/splash ban check still works after the fix).

// ignore_for_file: avoid_print

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:beealert_mobile/services/auth_service.dart';

void main() {
  group('Bug 1 – Preservation: Non-Banned Users Are Unaffected', () {
    late FakeFirebaseFirestore fakeFirestore;
    late AuthService authService;

    const testUid = 'preservation-user-001';

    /// Base user document with no ban fields.
    Map<String, dynamic> baseUserDoc() => {
          'uid': testUid,
          'fullName': 'Preservation User',
          'email': 'preservation@example.com',
          'barangay': 'Poblacion',
          'address': '123 Preservation St',
          'phoneNumber': '09111111111',
          'role': 'resident',
          'status': 'approved',
          'createdAt': Timestamp.fromDate(DateTime(2024, 1, 1)),
        };

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      authService = AuthService.withFirestore(fakeFirestore);
    });

    // -----------------------------------------------------------------------
    // Test 1: watchBanStatus emits null — no bannedUntil field present
    // -----------------------------------------------------------------------
    test(
      'P2-PRESERVATION-1: watchBanStatus emits null when bannedUntil field '
      'is absent from the user document',
      () async {
        // Arrange: user document has no bannedUntil key at all.
        await fakeFirestore
            .collection('users')
            .doc(testUid)
            .set(baseUserDoc());

        final emissions = <DateTime?>[];
        final subscription =
            authService.watchBanStatus(testUid).listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        // Assert: every emission must be null — no ban should be detected.
        expect(
          emissions,
          isNotEmpty,
          reason: 'Stream should emit at least one value',
        );
        expect(
          emissions,
          everyElement(isNull),
          reason:
              'watchBanStatus must emit null when bannedUntil is not present',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Test 2: watchBanStatus emits null — bannedUntil is an expired timestamp
    // -----------------------------------------------------------------------
    test(
      'P2-PRESERVATION-2: watchBanStatus emits null when bannedUntil is '
      'an already-expired timestamp (past DateTime)',
      () async {
        // Arrange: bannedUntil is 5 minutes in the past.
        final expiredUntil =
            DateTime.now().subtract(const Duration(minutes: 5));
        final doc = {
          ...baseUserDoc(),
          'bannedUntil': Timestamp.fromDate(expiredUntil),
        };
        await fakeFirestore.collection('users').doc(testUid).set(doc);

        final emissions = <DateTime?>[];
        final subscription =
            authService.watchBanStatus(testUid).listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        // Assert: expired ban must NOT be surfaced.
        expect(
          emissions,
          isNotEmpty,
          reason: 'Stream should emit at least one value',
        );
        expect(
          emissions,
          everyElement(isNull),
          reason:
              'watchBanStatus must emit null when bannedUntil is in the past',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Test 3: watchBanStatus emits null — bannedUntil is explicitly null
    // -----------------------------------------------------------------------
    test(
      'P2-PRESERVATION-3: watchBanStatus emits null when bannedUntil is '
      'explicitly set to null in the user document',
      () async {
        // Arrange: bannedUntil field is present but null.
        final doc = {
          ...baseUserDoc(),
          'bannedUntil': null,
        };
        await fakeFirestore.collection('users').doc(testUid).set(doc);

        final emissions = <DateTime?>[];
        final subscription =
            authService.watchBanStatus(testUid).listen(emissions.add);

        await Future<void>.delayed(Duration.zero);
        await subscription.cancel();

        expect(
          emissions,
          isNotEmpty,
          reason: 'Stream should emit at least one value',
        );
        expect(
          emissions,
          everyElement(isNull),
          reason:
              'watchBanStatus must emit null when bannedUntil is explicitly null',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Test 4: getBanStatus() returns null for non-banned users
    //   — preserves SplashScreen / LoginScreen cold-start behavior
    // -----------------------------------------------------------------------
    test(
      'P2-PRESERVATION-4: getBanStatus() returns null for a user with no '
      'active ban — SplashScreen and LoginScreen flows are unaffected',
      () async {
        // Arrange: user document with no ban.
        await fakeFirestore
            .collection('users')
            .doc(testUid)
            .set(baseUserDoc());

        final result = await authService.getBanStatus(testUid);

        expect(
          result,
          isNull,
          reason:
              'getBanStatus() must return null for users without an active ban',
        );
      },
    );

    test(
      'P2-PRESERVATION-4b: getBanStatus() returns null when bannedUntil is '
      'expired — cold-start correctly admits previously-banned users',
      () async {
        // Arrange: expired ban.
        final expiredUntil =
            DateTime.now().subtract(const Duration(hours: 2));
        final doc = {
          ...baseUserDoc(),
          'bannedUntil': Timestamp.fromDate(expiredUntil),
        };
        await fakeFirestore.collection('users').doc(testUid).set(doc);

        final result = await authService.getBanStatus(testUid);

        expect(
          result,
          isNull,
          reason:
              'getBanStatus() must return null when the ban has already expired',
        );
      },
    );

    // -----------------------------------------------------------------------
    // Test 5: getBanStatus() returns a DateTime for an actively banned user
    //   — existing login/splash ban enforcement still works after the fix
    // -----------------------------------------------------------------------
    test(
      'P2-PRESERVATION-5: getBanStatus() returns a non-null DateTime when '
      'bannedUntil is a future timestamp — login/splash ban check still works',
      () async {
        // Arrange: active ban expires 1 hour from now.
        final bannedUntil = DateTime.now().add(const Duration(hours: 1));
        final doc = {
          ...baseUserDoc(),
          'bannedUntil': Timestamp.fromDate(bannedUntil),
        };
        await fakeFirestore.collection('users').doc(testUid).set(doc);

        final result = await authService.getBanStatus(testUid);

        expect(
          result,
          isNotNull,
          reason:
              'getBanStatus() must return a DateTime when the user is actively banned',
        );
        expect(
          result!.difference(bannedUntil).abs().inSeconds,
          lessThan(2),
          reason:
              'getBanStatus() must return the correct bannedUntil DateTime',
        );
      },
    );
  });
}
