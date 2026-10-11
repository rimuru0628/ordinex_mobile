# Bugfix Requirements Document

## Introduction

Two bugs exist in the BEE-Alert Flutter app (ordinex_mobile) that together undermine both security enforcement and notification accuracy for residents.

**Bug 1 — Ban not enforced while app is running:** An admin can ban a user in Firestore at any time, but the mobile app only checks for bans at cold-start (`SplashScreen._navigate`) and at login (`LoginScreen._signIn`). A user who is already on `HomeScreen` when a ban is applied remains fully functional — they can browse all tabs, view reports, see alerts, and manage their profile until they restart the app or log out. The `BannedScreen` exists and works correctly, but there is no live Firestore listener that pushes the user there during an active session. When a ban expires, the user must also log out and back in to recover access, rather than being released automatically.

**Bug 2 — Notification unread count never reaches zero for global alerts:** `AlertService.getUnreadCount()` counts global alerts by taking the last 10 documents from the `alerts` collection and returning `snap.docs.length`. Because up to 10 alerts almost always exist in the collection, this value is always 1–10, even when the user has already read every global alert. There is no per-user read-state tracking for global alerts, so the bell-icon badge on `HomeScreen` never clears for that portion of the count.

---

## Bug Analysis

### Current Behavior (Defect)

**Bug 1 — Real-time ban enforcement**

1.1 WHEN a user is already on `HomeScreen` (or any nested tab) AND an admin sets `bannedUntil` to a future timestamp in Firestore THEN the app does NOT detect the change and the user continues to browse all tabs, view reports, see alerts, and access their profile without interruption.

1.2 WHEN a user is already on `HomeScreen` AND their active ban expires (the `bannedUntil` timestamp passes) THEN the app does NOT detect the expiry and the user must manually log out and log back in to regain full access.

1.3 WHEN a banned user taps "Report Concern" THEN the app shows a temporary dialog but does NOT navigate to `BannedScreen`, allowing the user to dismiss the dialog and continue using all other app features.

**Bug 2 — Notification unread count**

1.4 WHEN `AlertService.getUnreadCount(uid: uid)` is called with a valid `uid` THEN the global-alerts portion of the count is computed as `snap.docs.length` after a `.limit(10)` query, which always returns up to 10 regardless of whether the user has already seen those alerts.

1.5 WHEN `AlertService.getUnreadCount(uid: null)` is called (no uid path) THEN the count is computed identically — `snap.docs.length` after `.limit(10)` — and also always returns up to 10.

1.6 WHEN a user opens the `AlertsScreen` and views all global alerts THEN the bell-icon badge count on `HomeScreen` never drops to 0 for the global-alerts component, because there is no per-user read-state tracking for global alerts.

---

### Expected Behavior (Correct)

**Bug 1 — Real-time ban enforcement**

2.1 WHEN a user is on `HomeScreen` AND Firestore updates `bannedUntil` to a future timestamp on their user document THEN the app SHALL detect the change in real-time via a Firestore document stream and immediately navigate the user to `BannedScreen`, blocking all further app use.

2.2 WHEN a user is on `BannedScreen` AND their `bannedUntil` timestamp passes THEN the app SHALL detect the expiry in real-time (via either the existing countdown timer or the Firestore stream) and automatically navigate the user back to `HomeScreen` without requiring a logout/login cycle.

2.3 WHEN a user is on `HomeScreen` AND the Firestore stream confirms they are NOT banned THEN the app SHALL allow normal navigation to all tabs without interruption.

2.4 WHEN a user taps "Report Concern" AND their account is banned THEN the app SHALL navigate to `BannedScreen` (not show a dismissible dialog), ensuring full access is blocked consistently.

**Bug 2 — Notification unread count**

2.5 WHEN `AlertService.getUnreadCount(uid: uid)` is called THEN the global-alerts portion of the count SHALL only include alerts that the user has not yet seen, tracked via a per-user read-receipts sub-collection or a field on the user document (e.g., `users/{uid}/seenAlerts/{alertId}` or a `lastSeenAlertsAt` timestamp on the user document).

2.6 WHEN a user opens `AlertsScreen` and all global alerts are recorded as seen THEN `getUnreadCount` SHALL return 0 for the global-alerts portion, causing the bell-icon badge to disappear.

2.7 WHEN new global alerts are published after the user's last-seen marker THEN `getUnreadCount` SHALL count only those newer alerts as unread, accurately reflecting the number of unseen items.

2.8 WHEN the `AlertsScreen` is opened (or global alerts are scrolled into view) THEN the app SHALL update the per-user seen-state so subsequent calls to `getUnreadCount` reflect the newly seen alerts.

---

### Unchanged Behavior (Regression Prevention)

3.1 WHEN a user is not banned (no `bannedUntil` field, or `bannedUntil` is in the past) THEN the app SHALL CONTINUE TO allow full access to all tabs and features on `HomeScreen` without any interruption or redirect.

3.2 WHEN the Firestore stream for the user document emits an update that does not set or change the ban status THEN the app SHALL CONTINUE TO remain on the current screen without any navigation side-effect.

3.3 WHEN the ban check fails due to a network error or Firestore exception THEN the app SHALL CONTINUE TO allow the user to use the app (fail-open for ban detection, consistent with existing `_onReportConcernTap` behaviour).

3.4 WHEN `AlertService.getUnreadCount(uid: uid)` is called THEN the personal-notifications portion SHALL CONTINUE TO be counted using the existing `where('read', isEqualTo: false)` query, unchanged.

3.5 WHEN a personal notification (report update, account approval/rejection) is marked as read via `AlertService.markRead` or `AlertService.markAllRead` THEN those notifications SHALL CONTINUE TO be excluded from the unread count immediately.

3.6 WHEN `BannedScreen` is navigated to at cold-start (via `SplashScreen._navigate`) or at login (via `LoginScreen._signIn`) THEN the existing `BannedScreen` behavior — countdown timer, sign-out button, `/login` redirect on expiry — SHALL CONTINUE TO work as before.

3.7 WHEN a user registers, logs in, or is on the pending/rejected screens THEN none of the ban-stream or unread-count changes SHALL affect those flows.
