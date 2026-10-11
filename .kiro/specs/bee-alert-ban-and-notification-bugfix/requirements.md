# Requirements: BEE-Alert Ban Enforcement & Notification Unread Count Bugfix

## Overview

Two bugs exist in the BEE-Alert Flutter app:

1. **Bug 1 — Ban not enforced while app is running**: A user who is already on HomeScreen when an admin applies a ban remains fully functional. Ban checks only happen at cold start, login, and on the "Report Concern" tap. The app must detect bans in real-time and immediately redirect to BannedScreen. When the ban expires, the user must be automatically released back to HomeScreen without a logout/login cycle.

2. **Bug 2 — Notification unread count never reaches zero**: `AlertService.getUnreadCount()` calculates the global alerts badge count by returning the number of the last 10 documents (always 1–10), rather than counting truly unread items. For personal notifications it correctly uses `where('read', isEqualTo: false)`, but global alerts have no per-user read tracking, so the badge never clears.

---

## Bug 1: Real-Time Ban Enforcement

### 1.1 Bug Condition

- **Trigger**: A user is on HomeScreen (already authenticated and approved) when an admin sets `bannedUntil` to a future timestamp in their Firestore `users/{uid}` document.
- **Defective behavior**: The app continues to show HomeScreen normally. The user can browse all tabs (Home, My Reports, Alerts, Profile), view data, and interact freely. No ban check is active after the initial navigation.
- **C(X)**: `isBanned(user)` where `user.bannedUntil` is a Timestamp in Firestore and `bannedUntil.toDate().isAfter(DateTime.now())`.

### 1.2 Expected Behavior

- **Requirement**: While the user is on HomeScreen, the app MUST subscribe to a real-time Firestore stream on `users/{uid}`. When the ban condition becomes true, the app MUST immediately navigate to BannedScreen, replacing the HomeScreen route.
- **P(result)**: `result == BannedScreen shown` when `isBanned(user)` becomes true.
- **Ban expiry release**: When the ban expires (`bannedUntil` passes current time), BannedScreen MUST automatically navigate the user to `/home` (not `/login`). The user should NOT be required to log out and log back in.

### 1.3 Preservation Requirements

- **¬C(X)**: Users who are NOT banned (`bannedUntil` is null, already expired, or not set) MUST continue to see HomeScreen normally with no disruption.
- **Login-time ban check** in `LoginScreen._signIn()` MUST continue to work as-is.
- **Cold-start ban check** in `SplashScreen._navigate()` MUST continue to work as-is.
- **Report Concern ban dialog** (`HomeScreen._onReportConcernTap`) can be removed or left — it is superseded by the real-time redirect, but its removal must not break compilation.
- The `BannedScreen` sign-out button MUST continue to work.
- `AuthService.getBanStatus()` MUST continue to work as-is (used by SplashScreen and LoginScreen).

---

## Bug 2: Notification Unread Count for Global Alerts

### 2.1 Bug Condition

- **Trigger**: Any logged-in user navigates to HomeScreen. The bell icon badge is driven by `AlertService.getUnreadCount(uid: uid)`.
- **Defective behavior**: The global alerts component of the count uses `.limit(10).snapshots().map((snap) => snap.docs.length)`, which returns up to 10 regardless of whether the user has read them. If there are ≥1 global alerts, the badge never clears.
- **C(X)**: `globalAlertsExist` where the `alerts` Firestore collection has at least 1 document.

### 2.2 Expected Behavior

- **Requirement**: `getUnreadCount(uid: uid)` MUST return the count of truly unread items only — the sum of unread personal notifications and unread global alerts for that user.
- **Per-user seen tracking**: A `lastSeenAlertsAt` Timestamp field MUST be stored on the user's document (`users/{uid}`) to record when the user last viewed the Alerts tab.
- **Global unread count**: Calculated as the number of global alerts in `alerts` with `createdAt > lastSeenAlertsAt`. If `lastSeenAlertsAt` is null, all global alerts count as unread.
- **Mark as seen**: A `markAlertsAsSeen(String uid)` method MUST be added to `AlertService`. It writes `lastSeenAlertsAt = FieldValue.serverTimestamp()` to `users/{uid}`. This MUST be called when the user opens the Alerts tab.
- **P(result)**: `result == 0` when the user has opened the Alerts tab and no new global alerts or personal notifications have arrived since.

### 2.3 Preservation Requirements

- **¬C(X)**: Personal notification read tracking via `where('read', isEqualTo: false)` MUST continue to work unchanged.
- `markRead(uid, notificationId)` and `markAllRead(uid)` MUST continue to work as-is.
- `getAlerts()`, `getUserNotifications(uid)`, `getAllNotifications(uid)` streams MUST remain unchanged.
- The bell icon badge display logic in `HomeScreen` MUST continue to use the `getUnreadCount` stream — only the stream's internal counting logic changes.
- If `uid` is null (unauthenticated path in `getUnreadCount`), behavior is undefined/irrelevant — the app always passes a uid for authenticated users, but the null branch can be removed or left unchanged.
