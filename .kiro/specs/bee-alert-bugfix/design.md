# BEE-Alert Bugfix Design

## Overview

This document covers two distinct bugs in the BEE-Alert Flutter app.

**Bug 1 — Ban not enforced while app is running**
A user who is banned by an admin while they are already on the HomeScreen is never redirected. The ban check only runs at cold-start (`SplashScreen._navigate`) and at login (`LoginScreen._signIn`). Once on HomeScreen, the user can browse all tabs freely. The fix adds a real-time Firestore stream (`watchBanStatus`) on the user's document and wires it into HomeScreen so the app immediately redirects to `BannedScreen` the moment a ban is written. When the ban expires in real-time, `BannedScreen` redirects to `/home` (not `/login`) because the user is still authenticated.

**Bug 2 — Notification unread count never reaches zero**
`AlertService.getUnreadCount()` computes the global-alerts portion of the badge count as `.limit(10).snapshots().map((snap) => snap.docs.length)`, which always returns up to 10, even if the user has already viewed all of them. The fix introduces per-user seen-tracking via a `lastSeenAlertsAt` timestamp stored on the user's Firestore document. Global alerts created before that timestamp are considered seen. `markAlertsAsSeen(uid)` writes the current timestamp when the user opens the Alerts tab. `getUnreadCount` then filters global alerts to those whose `createdAt` is after `lastSeenAlertsAt`.

---

## Glossary

- **Bug_Condition (C)**: The predicate that identifies inputs that trigger a bug.
- **Property (P)**: The desired correct behavior when the bug condition holds.
- **Preservation**: Existing behaviors that must remain unchanged after the fix.
- **watchBanStatus(uid)**: New stream method on `AuthService` that emits `DateTime?` from a live Firestore snapshot on `users/{uid}`. Emits non-null when ban is active, null when not banned.
- **lastSeenAlertsAt**: A `Timestamp` field stored at `users/{uid}.lastSeenAlertsAt`. Records the moment the user last opened the Alerts tab.
- **markAlertsAsSeen(uid)**: New method on `AlertService` that writes `lastSeenAlertsAt = FieldValue.serverTimestamp()` to the user document.
- **bannedUntil**: Existing `Timestamp` field on `users/{uid}` set by the admin when issuing a ban.
- **BannedScreen**: Existing screen that displays a live countdown; currently redirects to `/login` on expiry.
- **HomeScreen**: Main resident screen. Currently has no live ban listener.

---

## Bug Details

### Bug 1 — Real-time Ban Enforcement

#### Bug Condition

The bug manifests when an admin writes a `bannedUntil` field to a user's Firestore document while that user is already on HomeScreen. There is no live listener on the user document inside HomeScreen, so the ban is never detected until the next cold start or login.

**Formal Specification:**
```
FUNCTION isBugCondition_ban(input)
  INPUT: input of type AppState
  OUTPUT: boolean

  RETURN input.currentScreen == HomeScreen
         AND input.user.bannedUntil IS NOT NULL
         AND input.user.bannedUntil > DateTime.now()
         AND NOT realTimeListenerAttached(input.user.uid)
END FUNCTION
```

#### Examples

- Admin bans user for 24 hours while the user is browsing the Reports tab → user sees no change and can keep submitting reports *(bug)*
- Admin bans user while app is closed → user is redirected on next cold start (works correctly — not in scope)
- Admin bans user, user relaunches the app → SplashScreen redirects to BannedScreen (works correctly — not in scope)
- Ban expires while user is on BannedScreen → currently redirects to `/login`, forcing a re-login *(secondary bug)*

---

### Bug 2 — Notification Unread Count

#### Bug Condition

The bug manifests when a logged-in user has already viewed all global alerts but the badge still shows a non-zero count, because `getUnreadCount` counts the raw length of the last 10 global alerts documents regardless of whether the user has seen them.

**Formal Specification:**
```
FUNCTION isBugCondition_unread(input)
  INPUT: input of type UnreadCountQuery
  OUTPUT: boolean

  RETURN input.uid IS NOT NULL
         AND globalAlertsExist()
         AND input.lastSeenAlertsAt >= mostRecentAlert.createdAt
         AND getUnreadCount(uid) > 0   // should be 0 but isn't
END FUNCTION
```

#### Examples

- User opens Alerts tab, reads all 8 global alerts → badge still shows 8 *(bug)*
- 3 new global alerts are published after `lastSeenAlertsAt` → badge should show 3 *(expected correct behavior after fix)*
- All personal notifications are marked read AND all global alerts are seen → badge should show 0 *(expected correct behavior after fix)*
- uid is null (logged-out context) → behavior unchanged (no per-user tracking needed)

---

## Expected Behavior

### Preservation Requirements

**Unchanged Behaviors (Bug 1):**
- Cold-start ban check in `SplashScreen._navigate()` must continue to work exactly as before.
- Login-time ban check in `LoginScreen._signIn()` must continue to work exactly as before.
- `HomeScreen._onReportConcernTap()` dialog behavior is superseded by the real-time redirect, but the dialog code can remain as a fallback.
- Sign-out from BannedScreen must continue to work and navigate to `/login`.

**Unchanged Behaviors (Bug 2):**
- Personal notification unread count (using `where('read', isEqualTo: false)`) must continue to work.
- `markRead(uid, notificationId)` and `markAllRead(uid)` must continue to work.
- `getAlerts()`, `getUserNotifications(uid)`, and `getAllNotifications(uid)` streams must remain unchanged.
- The Alerts tab full list display must remain unchanged.

**Scope:**
All inputs that do NOT involve an active ban written to Firestore, or do not involve global alert read-state, are completely unaffected by these fixes. This includes:
- Users who are not banned
- Mouse/tap interactions on other tabs
- Profile updates
- Report submissions (for non-banned users)
- Personal notification read/unread state

---

## Hypothesized Root Cause

### Bug 1 — Real-time Ban Enforcement

1. **No Firestore stream on user document in HomeScreen**: `HomeScreen.initState` loads the profile once with a `Future` (`_loadProfile`) and never sets up a live `Stream` on `users/{uid}`. There is no mechanism to react to changes pushed by the admin.

2. **Missing `watchBanStatus` method on `AuthService`**: `AuthService` only exposes a one-shot `getBanStatus(uid)` Future. There is no streaming equivalent that HomeScreen could subscribe to.

3. **BannedScreen redirects to `/login` on expiry**: When the ban timer reaches zero, `_BannedScreenState` calls `Navigator.of(context).pushReplacementNamed('/login')`. For real-time release (ban removed/expired while app is open), the user should go to `/home` because they are still authenticated — forcing `/login` is an unnecessary friction.

### Bug 2 — Notification Unread Count

1. **No per-user read-tracking for global alerts**: Global alerts live in the top-level `alerts` collection, not per-user. The `AlertModel.read` field exists but is only meaningful for personal notifications in `users/{uid}/notifications`. For global alerts, `read` is never set per-user.

2. **`getUnreadCount` uses raw document count**: The query `.limit(10).snapshots().map((snap) => snap.docs.length)` counts documents, not unseen documents. Even after the user visits the Alerts tab, the count stays the same.

3. **No `markAlertsAsSeen` method**: There is no API to record "this user has seen alerts up to this point in time", so the count can never be cleared.

---

## Correctness Properties

Property 1: Bug Condition — Real-time Ban Redirect

_For any_ app state where the current user's `bannedUntil` field in Firestore becomes set (or updated) to a future timestamp while the user is on HomeScreen, the fixed HomeScreen SHALL immediately navigate to `BannedScreen` — without requiring the user to restart the app or log out.

**Validates: Requirements 2.1, 2.2**

Property 2: Preservation — Cold-start and Login Ban Checks Unchanged

_For any_ scenario where the user is NOT currently on HomeScreen (i.e., cold start via SplashScreen, or login via LoginScreen), the fixed code SHALL produce exactly the same ban-check behavior as the original code — no changes to `SplashScreen._navigate` or `LoginScreen._signIn`.

**Validates: Requirements 3.1, 3.2**

Property 3: Bug Condition — Unread Count Reaches Zero When All Seen

_For any_ user state where all global alerts were published before `lastSeenAlertsAt` AND all personal notifications have `read == true`, the fixed `getUnreadCount(uid: uid)` SHALL emit `0`.

**Validates: Requirements 2.3, 2.4**

Property 4: Preservation — Unread Count Correctly Reflects New Alerts

_For any_ user state where N global alerts were published after `lastSeenAlertsAt` and M personal notifications have `read == false`, the fixed `getUnreadCount(uid: uid)` SHALL emit exactly `N + M`.

**Validates: Requirements 3.3, 3.4**

---

## Fix Implementation

### Bug 1 — Changes Required

**File**: `lib/services/auth_service.dart`

**Addition**: `watchBanStatus(String uid)` stream method

**Specific Changes:**
1. **Add `watchBanStatus` stream**: Returns `Stream<DateTime?>`. Uses `_db.collection('users').doc(uid).snapshots()` to listen for real-time changes. Parses `bannedUntil` exactly as `getBanStatus` does — returns the `DateTime` if the ban is still active, or `null` if expired/absent.

---

**File**: `lib/screens/home/home_screen.dart`

**Specific Changes:**
1. **Declare `StreamSubscription<DateTime?> _banSubscription`** in `_HomeScreenState`.
2. **In `initState`**: After `_loadProfile()`, start `_banSubscription` on `_authService.watchBanStatus(uid)`. When the stream emits a non-null `bannedUntil`, cancel the subscription and call `Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => BannedScreen(bannedUntil: bannedUntil)))`.
3. **In `dispose`**: Call `_banSubscription.cancel()`.
4. Import `dart:async` and `banned_screen.dart`.

---

**File**: `lib/screens/auth/banned_screen.dart`

**Specific Changes:**
1. **Change expiry redirect from `/login` to `/home`**: In `_BannedScreenState.initState`'s timer callback, replace `Navigator.of(context).pushReplacementNamed('/login')` with `Navigator.of(context).pushReplacementNamed('/home')`. This covers the case where the ban expires (or is lifted by admin) while the app is open and the user is still authenticated.

---

### Bug 2 — Changes Required

**File**: `lib/services/alert_service.dart`

**Specific Changes:**
1. **Add `markAlertsAsSeen(String uid)`**: Writes `{'lastSeenAlertsAt': FieldValue.serverTimestamp()}` to `users/{uid}` via `update()`. Called by the Alerts tab when it becomes visible.
2. **Fix `getUnreadCount` global-alert branch**: Replace the raw `.limit(10)` count with a two-stream `Rx.combineLatest2` that:
   - First reads `users/{uid}.lastSeenAlertsAt` via a snapshot stream.
   - Then queries `alerts` where `createdAt > lastSeenAlertsAt` (or all alerts if `lastSeenAlertsAt` is null).
   - Because Firestore does not allow dynamic query parameters in a stream without re-subscribing, use `switchMap`/`flatMap` from rxdart: outer stream on user doc, inner stream on alerts with the timestamp filter.
3. **Fix null-uid branch**: When `uid == null`, keep existing behavior (return count of last 10, since there is no user context to track seen state).

---

**File**: `lib/screens/alerts/alerts_screen.dart` *(read before modifying)*

**Specific Changes:**
1. **Call `markAlertsAsSeen(uid)` when tab becomes visible**: Override `didChangeDependencies` or use `initState` (if embedded) to call `_alertService.markAlertsAsSeen(uid)` so the badge resets when the user opens the tab.

---

## Testing Strategy

### Validation Approach

Testing follows the two-phase bug-condition methodology: first run tests against unfixed code to confirm the bug and root cause, then run tests against the fixed code to verify both correctness and preservation.

---

### Exploratory Bug Condition Checking

**Goal**: Surface counterexamples that demonstrate each bug BEFORE implementing the fix. Confirm or refute the root cause hypotheses.

**Bug 1 Test Plan**: Mock `AuthService.watchBanStatus` to emit a non-null `DateTime` 500 ms after HomeScreen mounts. Assert that HomeScreen navigates to BannedScreen. On unfixed code this assertion will fail because HomeScreen never subscribes to the stream.

**Test Cases:**
1. **Active ban while on HomeScreen**: Mount HomeScreen with an authenticated user, then fire a Firestore update setting `bannedUntil` to now + 1 hour. Assert navigation to BannedScreen. *(will fail on unfixed code)*
2. **Ban expiry redirects to /home**: Mount BannedScreen with `bannedUntil = DateTime.now() + 2 seconds`. Wait 3 seconds. Assert navigation to `/home`, not `/login`. *(will fail on unfixed code — it goes to `/login`)*
3. **No redirect for non-banned user**: Mount HomeScreen, fire a Firestore update that does NOT set `bannedUntil`. Assert no navigation occurs. *(should pass on unfixed code — used to confirm no false positives)*

**Bug 2 Test Plan**: Call `getUnreadCount(uid: uid)` after calling `markAllRead(uid)` and simulating `lastSeenAlertsAt` covering all existing alerts. Assert the count equals 0. On unfixed code the count will equal the number of global alerts (up to 10).

**Test Cases:**
1. **Badge never reaches zero**: Create 5 global alerts, call `markAllRead(uid)`. Assert `getUnreadCount` emits 0. *(will fail on unfixed code — emits 5)*
2. **Badge counts only new alerts**: Set `lastSeenAlertsAt` to now, then create 2 new global alerts. Assert `getUnreadCount` emits 2. *(will fail on unfixed code — emits up to 10)*
3. **Badge with no global alerts**: Ensure `alerts` collection is empty. Assert `getUnreadCount` emits 0. *(passes on both unfixed and fixed — confirms baseline)*

**Expected Counterexamples:**
- HomeScreen does not navigate to BannedScreen even after `bannedUntil` is set in Firestore.
- `getUnreadCount` returns non-zero even when all alerts predate `lastSeenAlertsAt`.

---

### Fix Checking

**Goal**: Verify that for all inputs where the bug condition holds, the fixed code produces the expected behavior.

**Pseudocode (Bug 1):**
```
FOR ALL appState WHERE isBugCondition_ban(appState) DO
  result := homeScreen_fixed.onBanUpdate(appState.user.bannedUntil)
  ASSERT result == NavigateToBannedScreen(bannedUntil)
END FOR
```

**Pseudocode (Bug 2):**
```
FOR ALL query WHERE isBugCondition_unread(query) DO
  result := getUnreadCount_fixed(uid: query.uid)
  ASSERT result == 0   // user has seen everything
END FOR
```

---

### Preservation Checking

**Goal**: Verify that for all inputs where the bug condition does NOT hold, the fixed code produces the same result as the original code.

**Pseudocode (Bug 1):**
```
FOR ALL appState WHERE NOT isBugCondition_ban(appState) DO
  ASSERT homeScreen_original.behavior(appState) == homeScreen_fixed.behavior(appState)
END FOR
```

**Pseudocode (Bug 2):**
```
FOR ALL query WHERE NOT isBugCondition_unread(query) DO
  ASSERT getUnreadCount_original(query) == getUnreadCount_fixed(query)
END FOR
```

**Testing Approach**: Property-based testing is recommended for preservation checking because:
- It generates many random app states automatically.
- It catches edge cases (e.g., `lastSeenAlertsAt` is null, uid is null, empty collections).
- It provides strong guarantees that non-buggy inputs are unaffected.

**Test Plan**: Observe behavior on unfixed code for non-banned users and for personal notifications, then write property-based tests capturing that behavior.

**Test Cases:**
1. **Non-banned user stays on HomeScreen**: Verify no spurious navigation occurs for users without a `bannedUntil` field.
2. **Personal notification count unchanged**: Verify that `where('read', isEqualTo: false)` count is unaffected by the global-alerts fix.
3. **markRead / markAllRead still work**: Verify personal notification read-marking is unaffected.
4. **Cold-start SplashScreen flow unchanged**: Verify `SplashScreen._navigate` still uses `getBanStatus` (Future, not stream) and behavior is identical.
5. **Login flow unchanged**: Verify `LoginScreen._signIn` ban check is unchanged.

---

### Unit Tests

- Test `AuthService.watchBanStatus` emits `null` when `bannedUntil` is absent or in the past.
- Test `AuthService.watchBanStatus` emits a `DateTime` when `bannedUntil` is in the future.
- Test `AlertService.markAlertsAsSeen` writes `lastSeenAlertsAt` to the correct Firestore path.
- Test `AlertService.getUnreadCount` returns 0 when `lastSeenAlertsAt` covers all global alerts.
- Test `AlertService.getUnreadCount` returns N when N alerts are newer than `lastSeenAlertsAt`.
- Test `BannedScreen` navigates to `/home` (not `/login`) when countdown expires.

### Property-Based Tests

- Generate random sets of global alert timestamps and random `lastSeenAlertsAt` values; assert that `getUnreadCount` equals the number of alerts strictly newer than `lastSeenAlertsAt`.
- Generate random user documents with and without `bannedUntil`; assert `watchBanStatus` emits null for all cases where `bannedUntil` is absent or in the past, and a non-null `DateTime` only when `bannedUntil` is strictly in the future.
- Generate random navigation sequences for a non-banned user; assert HomeScreen never navigates to BannedScreen.

### Integration Tests

- Full flow: admin sets ban → user on HomeScreen is redirected to BannedScreen without restart.
- Full flow: ban expires → BannedScreen automatically transitions to HomeScreen.
- Full flow: user opens Alerts tab → badge count drops to 0 → new alert published → badge shows 1.
- Full flow: user has mixed personal (unread) + global (all seen) → badge shows only personal count.
- Cold-start with active ban still redirects to BannedScreen (regression test).
- Login with active ban still redirects to BannedScreen (regression test).
