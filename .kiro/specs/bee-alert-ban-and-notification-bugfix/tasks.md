# Implementation Plan

---

## Bug 1: Real-Time Ban Enforcement

- [x] 1. Write bug condition exploration test (Bug 1)
  - **Property 1: Bug Condition** - Ban Applied While User is on HomeScreen
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **NOTE**: This test encodes the expected behavior — it will validate the fix when it passes after implementation
  - **GOAL**: Surface counterexamples proving a banned HomeScreen user is NOT redirected
  - **Scoped PBT Approach**: Scope to the concrete case: user is authenticated, on HomeScreen, and `bannedUntil` is set to `DateTime.now().add(Duration(hours: 1))` in Firestore
  - Test: simulate `users/{uid}.bannedUntil` being written to Firestore while HomeScreen is mounted; assert that BannedScreen is pushed (NavigatorObserver or mock navigator)
  - On unfixed code: no navigation event fires → test FAILS (confirms bug exists)
  - Document counterexample: "HomeScreen remains mounted with full functionality after bannedUntil is set"
  - _Requirements: 1.1_

- [x] 2. Write preservation property tests (Bug 1, BEFORE implementing fix)
  - **Property 2: Preservation** - Non-Banned Users Are Unaffected
  - **IMPORTANT**: Follow observation-first methodology
  - Observe: non-banned user (bannedUntil = null) stays on HomeScreen normally on unfixed code
  - Observe: user with expired bannedUntil (past timestamp) stays on HomeScreen normally on unfixed code
  - Write property-based test: for all users where `bannedUntil` is null or already expired, `watchBanStatus` emits null and no BannedScreen navigation occurs
  - Write property-based test: `getBanStatus()` (used by SplashScreen/LoginScreen) returns the same result before and after the fix
  - Verify tests PASS on UNFIXED code (confirms baseline behavior to preserve)
  - _Requirements: 1.3_

- [x] 3. Fix for real-time ban enforcement

  - [x] 3.1 Add `watchBanStatus(String uid)` stream to `AuthService`
    - Open `lib/services/auth_service.dart`
    - Add method that subscribes to `_db.collection('users').doc(uid).snapshots()`
    - Map each snapshot: extract `bannedUntil` field (handle both `Timestamp` and `String` types, same logic as `getBanStatus`)
    - Return `bannedUntil` DateTime if `bannedUntil.isAfter(DateTime.now())`, otherwise return `null`
    - _Bug_Condition: isBugCondition(user) where user is on HomeScreen and bannedUntil becomes active_
    - _Expected_Behavior: stream emits non-null DateTime when ban is active, null otherwise_
    - _Preservation: getBanStatus() (one-shot Future) is unchanged — SplashScreen and LoginScreen are unaffected_
    - _Requirements: 1.2, 1.3_

  - [x] 3.2 Add ban watcher to `HomeScreen`
    - Open `lib/screens/home/home_screen.dart`
    - Add `StreamSubscription<DateTime?>? _banSubscription` field to `_HomeScreenState`
    - Add import for `dart:async` if not present
    - Add import for `banned_screen.dart`
    - Add `_startBanWatch()` method: get current uid, subscribe to `_authService.watchBanStatus(uid)`, on non-null emission call `Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BannedScreen(bannedUntil: bannedUntil)))`
    - Call `_startBanWatch()` at end of `initState()`
    - Cancel `_banSubscription` in `dispose()`
    - _Bug_Condition: no active listener on users/{uid} while HomeScreen is mounted_
    - _Expected_Behavior: BannedScreen replaces HomeScreen immediately when ban is applied_
    - _Requirements: 1.2_

  - [x] 3.3 Fix `BannedScreen` expiry redirect from `/login` to `/home`
    - Open `lib/screens/auth/banned_screen.dart`
    - In `_BannedScreenState.initState()` timer callback, when `remaining.isNegative`:
      - Change `Navigator.of(context).pushReplacementNamed('/login')` → `Navigator.of(context).pushReplacementNamed('/home')`
    - This ensures the user returns to HomeScreen on natural ban expiry without needing to re-authenticate
    - Sign-out button continues to navigate to `/login` (unchanged)
    - _Bug_Condition: BannedScreen's timer redirected to /login even when user is still authenticated_
    - _Expected_Behavior: on natural expiry, user is taken to /home; on sign-out, user is taken to /login_
    - _Requirements: 1.2, 1.3_

  - [x] 3.4 Verify bug condition exploration test (Bug 1) now passes
    - **Property 1: Expected Behavior** - Ban Applied While User is on HomeScreen
    - **IMPORTANT**: Re-run the SAME test from task 1 — do NOT write a new test
    - The test from task 1 encodes the expected behavior
    - When this test passes, it confirms BannedScreen is navigated to when ban is applied at runtime
    - Run the exploration test from step 1
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: 1.2_

  - [x] 3.5 Verify preservation tests (Bug 1) still pass
    - **Property 2: Preservation** - Non-Banned Users Are Unaffected
    - **IMPORTANT**: Re-run the SAME tests from task 2 — do NOT write new tests
    - Run preservation property tests from step 2
    - **EXPECTED OUTCOME**: Tests PASS (confirms no regressions for non-banned users)
    - Confirm SplashScreen and LoginScreen ban checks still pass their own existing tests

---

## Bug 2: Notification Unread Count for Global Alerts

- [x] 4. Write bug condition exploration test (Bug 2)
  - **Property 1: Bug Condition** - Global Alert Count Never Reaches Zero
  - **CRITICAL**: This test MUST FAIL on unfixed code — failure confirms the bug exists
  - **DO NOT attempt to fix the test or the code when it fails**
  - **GOAL**: Surface counterexamples proving the badge count stays non-zero after reading all alerts
  - **Scoped PBT Approach**: Scope to concrete case: Firestore `alerts` collection has 3 documents, user has zero unread personal notifications, user has "seen" all alerts (simulated via any future `lastSeenAlertsAt`)
  - Test: mock Firestore with 3 alert documents all older than a simulated `lastSeenAlertsAt`; observe `getUnreadCount(uid: uid)` stream; assert it emits 0
  - On unfixed code: count emits 3 (snapshot.docs.length = 3) → test FAILS (confirms bug)
  - Document counterexample: "getUnreadCount returns 3 even though user has already seen all global alerts"
  - _Requirements: 2.1_

- [x] 5. Write preservation property tests (Bug 2, BEFORE implementing fix)
  - **Property 2: Preservation** - Personal Notification Read Tracking is Unchanged
  - **IMPORTANT**: Follow observation-first methodology
  - Observe: `getUnreadCount(uid: uid)` with 2 unread personal notifications and 0 global alerts returns 2 on unfixed code
  - Observe: `markRead()` and `markAllRead()` correctly flip `read` to `true` on unfixed code
  - Observe: `getAlerts()`, `getUserNotifications()`, `getAllNotifications()` streams return correct data on unfixed code
  - Write property-based test: for all users with N unread personal notifications and lastSeenAlertsAt >= all global alert createdAt timestamps, `getUnreadCount` returns N
  - Verify tests PASS on UNFIXED code
  - _Requirements: 2.3_

- [x] 6. Fix for notification unread count

  - [x] 6.1 Add `lastSeenAlertsAt` field to `UserModel`
    - Open `lib/models/user_model.dart`
    - Add `final DateTime? lastSeenAlertsAt;` field
    - Add optional parameter `this.lastSeenAlertsAt` to constructor
    - In `fromMap`: parse `lastSeenAlertsAt` — if value is `Timestamp`, call `.toDate()`; otherwise `null`
    - In `copyWith`: add optional `DateTime? lastSeenAlertsAt` parameter
    - Do NOT add `lastSeenAlertsAt` to `toMap()` — it is managed exclusively by `markAlertsAsSeen` via `update()`
    - _Bug_Condition: no lastSeenAlertsAt field tracked per user_
    - _Expected_Behavior: UserModel can carry lastSeenAlertsAt parsed from Firestore_
    - _Requirements: 2.2_

  - [x] 6.2 Add `markAlertsAsSeen(String uid)` to `AlertService`
    - Open `lib/services/alert_service.dart`
    - Add method that calls `_db.collection('users').doc(uid).update({'lastSeenAlertsAt': FieldValue.serverTimestamp()})`
    - This writes the server timestamp at the moment the user opens the Alerts tab
    - _Expected_Behavior: lastSeenAlertsAt is updated so subsequent getUnreadCount sees 0 new global alerts_
    - _Requirements: 2.2_

  - [x] 6.3 Fix `getUnreadCount` in `AlertService`
    - Open `lib/services/alert_service.dart`
    - Replace the current global alerts branch (`.limit(10).snapshots().map((snap) => snap.docs.length)`) with a `Rx.combineLatest3` approach
    - Stream 1: personal unread notifications (unchanged — `where('read', isEqualTo: false)`)
    - Stream 2: all global alerts ordered by `createdAt` descending (no limit)
    - Stream 3: user document snapshot mapped to `lastSeenAlertsAt` DateTime? 
    - Combine: `personalCount + globalSnap.docs.where((doc) { alertTime > lastSeen }).length`
    - If `lastSeen` is null, all global alerts count as unread (first-time user)
    - If `uid` is null, return `Stream.value(0)` (or keep existing behavior)
    - _Bug_Condition: global count used snapshot.docs.length regardless of whether user had seen them_
    - _Expected_Behavior: count reflects only alerts created after lastSeenAlertsAt_
    - _Preservation: personal notification count via read flag is unchanged_
    - _Requirements: 2.1, 2.2, 2.3_

  - [x] 6.4 Call `markAlertsAsSeen` when Alerts tab is opened in `HomeScreen`
    - Open `lib/screens/home/home_screen.dart`
    - Update `_onNavTap`: when `index == 2`, call `_alertService.markAlertsAsSeen(uid)` (fire-and-forget)
    - Update the "View Alerts" button `onPressed` callback to also call `markAlertsAsSeen` before (or after) setting `_currentIndex = 2`
    - Update the bell icon `onPressed` callback similarly
    - _Expected_Behavior: lastSeenAlertsAt is updated when user navigates to Alerts tab, clearing the badge_
    - _Requirements: 2.2_

  - [x] 6.5 Verify bug condition exploration test (Bug 2) now passes
    - **Property 1: Expected Behavior** - Global Alert Count Reaches Zero After Seeing All Alerts
    - **IMPORTANT**: Re-run the SAME test from task 4 — do NOT write a new test
    - When this test passes, it confirms `getUnreadCount` returns 0 when lastSeenAlertsAt >= all global alert timestamps
    - **EXPECTED OUTCOME**: Test PASSES (confirms bug is fixed)
    - _Requirements: 2.2_

  - [x] 6.6 Verify preservation tests (Bug 2) still pass
    - **Property 2: Preservation** - Personal Notification Read Tracking is Unchanged
    - **IMPORTANT**: Re-run the SAME tests from task 5 — do NOT write new tests
    - Run preservation property tests from step 5
    - **EXPECTED OUTCOME**: Tests PASS (confirms personal notification tracking is unaffected)

- [x] 7. Checkpoint — Ensure all tests pass
  - Run `flutter analyze` to confirm no static errors
  - Run all widget/unit tests: `flutter test`
  - Manually verify on a test device or emulator:
    - [x] Ban a logged-in user from the admin panel → BannedScreen appears immediately on the device without restart
    - [x] Wait for the ban to expire (use a short ban, e.g. 1 minute) → HomeScreen reappears automatically
    - [x] Open the Alerts tab → bell badge clears to 0
    - [x] Send a new global alert after clearing → badge shows 1 again
    - [x] Non-banned user browses all tabs normally
  - Ensure all tests pass; ask the user if questions arise.
