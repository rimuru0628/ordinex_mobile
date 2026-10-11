# Design: BEE-Alert Ban Enforcement & Notification Unread Count Bugfix

## Overview

This document details the fix design for two bugs using the bug condition methodology.

---

## Bug 1: Real-Time Ban Enforcement

### Bug Condition (C(X))

```
isBugCondition(user) =
  user is authenticated
  AND user is on HomeScreen (past SplashScreen navigation)
  AND Firestore users/{uid}.bannedUntil exists
  AND bannedUntil.toDate().isAfter(DateTime.now())
```

The bug fires when the admin sets `bannedUntil` on a user who is *already* inside HomeScreen. No active listener detects the change.

### Expected Behavior (P(result))

```
expectedBehavior(result) =
  result == BannedScreen(bannedUntil: <value>) is displayed
  AND HomeScreen is no longer accessible
  AND when bannedUntil passes, BannedScreen auto-navigates to '/home'
```

### Root Cause

`HomeScreen.initState()` calls `_loadProfile()` once. There is no Firestore `snapshots()` listener on the user document inside HomeScreen. The ban is only re-checked on the next cold start or login.

### Fix Design

#### 1. Add `watchBanStatus(String uid)` to `AuthService`

```dart
/// Real-time stream of the user's ban status.
/// Emits a DateTime (bannedUntil) when banned, null when not banned.
Stream<DateTime?> watchBanStatus(String uid) {
  return _db.collection('users').doc(uid).snapshots().map((doc) {
    final data = doc.data() ?? {};
    final bannedField = data['bannedUntil'];
    if (bannedField == null) return null;
    DateTime? bannedUntil;
    if (bannedField is Timestamp) {
      bannedUntil = bannedField.toDate();
    } else {
      bannedUntil = DateTime.tryParse(bannedField.toString());
    }
    if (bannedUntil != null && bannedUntil.isAfter(DateTime.now())) {
      return bannedUntil;
    }
    return null;
  });
}
```

#### 2. Add ban watcher to `HomeScreen`

In `_HomeScreenState`:

```dart
StreamSubscription<DateTime?>? _banSubscription;

@override
void initState() {
  super.initState();
  _loadProfile();
  _loadContacts();
  _startBanWatch();
}

void _startBanWatch() {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return;
  _banSubscription = _authService.watchBanStatus(uid).listen((bannedUntil) {
    if (!mounted) return;
    if (bannedUntil != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => BannedScreen(bannedUntil: bannedUntil),
        ),
      );
    }
  });
}

@override
void dispose() {
  _banSubscription?.cancel();
  super.dispose();
}
```

- The `_onReportConcernTap` ban dialog becomes redundant but can remain as a secondary guard (no code removal required for correctness).

#### 3. Fix `BannedScreen` expiry redirect

Current: redirects to `/login` on expiry.
Fix: redirect to `/home` on expiry when the ban expires naturally (user is still authenticated).

```dart
// In _BannedScreenState._timer callback, when remaining.isNegative:
_timer.cancel();
Navigator.of(context).pushReplacementNamed('/home');
```

### Preservation Requirements

- Users with no active ban: `watchBanStatus` emits `null` — no navigation occurs.
- `getBanStatus` (used by SplashScreen and LoginScreen) is unchanged.
- Sign-out button on BannedScreen continues to navigate to `/login`.
- `_loadProfile()`, `_loadContacts()`, and all HomeScreen tab logic are unchanged.

---

## Bug 2: Notification Unread Count for Global Alerts

### Bug Condition (C(X))

```
isBugCondition(state) =
  uid is not null (user is authenticated)
  AND alerts collection has >= 1 document
  AND getUnreadCount(uid: uid) is being observed
```

The defective branch:
```dart
_db.collection('alerts')
    .orderBy('createdAt', descending: true)
    .limit(10)
    .snapshots()
    .map((snap) => snap.docs.length);  // always 1..10, never 0 while alerts exist
```

### Expected Behavior (P(result))

```
expectedBehavior(count) =
  count == (unreadPersonalNotifications + globalAlertsCreatedAfterLastSeenAlertsAt)
  AND count == 0 when user has seen all alerts and no new ones arrived
```

### Root Cause

There is no per-user timestamp tracking when the user last viewed the Alerts tab. Without a `lastSeenAlertsAt` field, all global alerts always count as unread. The query counts documents rather than unread items.

### Fix Design

#### 1. Add `lastSeenAlertsAt` field to `UserModel`

```dart
// UserModel — add optional field
final DateTime? lastSeenAlertsAt;

// In constructor:
this.lastSeenAlertsAt,

// In fromMap:
lastSeenAlertsAt: map['lastSeenAlertsAt'] is Timestamp
    ? (map['lastSeenAlertsAt'] as Timestamp).toDate()
    : null,

// In toMap — omit from toMap (not written by the app at profile creation)
// In copyWith — add optional parameter
```

#### 2. Add `markAlertsAsSeen(String uid)` to `AlertService`

```dart
/// Records that the user has seen all global alerts up to now.
/// Call this when the user opens the Alerts tab.
Future<void> markAlertsAsSeen(String uid) async {
  await _db.collection('users').doc(uid).update({
    'lastSeenAlertsAt': FieldValue.serverTimestamp(),
  });
}
```

#### 3. Fix `getUnreadCount` in `AlertService`

Replace the global alerts branch with a query that compares `createdAt` against `lastSeenAlertsAt`:

```dart
Stream<int> getUnreadCount({String? uid}) {
  if (uid == null) {
    // No authenticated user — count is irrelevant; return 0
    return Stream.value(0);
  }

  // Stream lastSeenAlertsAt from user document
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
        if (lastSeen == null) return true; // never seen — count all
        return alertTime.isAfter(lastSeen);
      }).length;
      return personalCount + globalCount;
    },
  );
}
```

#### 4. Call `markAlertsAsSeen` when the Alerts tab is opened

In `HomeScreen._onNavTap` (or wherever `_currentIndex` is set to 2):

```dart
void _onNavTap(int index) {
  setState(() => _currentIndex = index);
  if (index == 2) {
    // Mark global alerts as seen when user opens the Alerts tab
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _alertService.markAlertsAsSeen(uid);
    }
  }
}
```

Also call when `_currentIndex` is set to 2 via `setState(() => _currentIndex = 2)` in the "View Alerts" button.

### Preservation Requirements

- Personal notification tracking (`where('read', isEqualTo: false)`) is unchanged.
- `markRead` and `markAllRead` are unchanged.
- `getAlerts()`, `getUserNotifications()`, `getAllNotifications()` streams are unchanged.
- Bell icon badge display in HomeScreen uses the same `getUnreadCount` stream — no widget changes needed.
- `UserModel.toMap()` does not write `lastSeenAlertsAt` — it is only written by `markAlertsAsSeen` via a targeted `update()` call.

---

## Files Changed

| File | Change |
|------|--------|
| `lib/services/auth_service.dart` | Add `watchBanStatus(String uid)` stream method |
| `lib/screens/home/home_screen.dart` | Add `_banSubscription`, `_startBanWatch()`, cancel in `dispose()`; fix `_onNavTap` to call `markAlertsAsSeen`; add `'View Alerts'` button markAlertsAsSeen call |
| `lib/screens/auth/banned_screen.dart` | Change expiry redirect from `/login` to `/home` |
| `lib/services/alert_service.dart` | Add `markAlertsAsSeen(String uid)`; fix `getUnreadCount` global branch |
| `lib/models/user_model.dart` | Add optional `lastSeenAlertsAt` field with `fromMap` parsing and `copyWith` support |
