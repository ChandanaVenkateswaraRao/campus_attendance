# Tasks

## 1. Sync & Auth Service Wiring

- [x] 1.1 In `SyncService`, ensure `backupToCloud()` strictly throws exceptions on failure so that callers can catch network errors, and verify by throwing a mock error.
- [x] 1.2 In `AuthService`, ensure `logout()` functions correctly independently, and verify it clears SharedPreferences.

## 2. Login Flow Updates (Restore)

- [x] 2.1 Update `AuthScreen`'s `_submit` method to await `SyncService(globalIsar).restoreFromCloud()` after successful login before routing to `HomeScreen`, and verify by observing the loading spinner delay on successful login.
- [x] 2.2 Update `main.dart`'s `FutureBuilder` to chain `SyncService(globalIsar).restoreFromCloud()` if `isLoggedIn()` returns true, replacing the hardcoded 2-second delay, and verify by restarting the app while logged in and seeing data load.
- [x] 2.3 Add a small "Syncing data from server..." text below the university title in the splash screen of `main.dart`, and verify visually.

## 3. Logout Flow Updates (Backup & Wipe)

- [x] 3.1 Update `HomeScreen`'s `onSelected` logout handler to show a non-dismissible loading dialog, and verify it blocks UI interaction.
- [x] 3.2 In the logout handler, invoke `syncPendingRecords()` and `backupToCloud()`, then verify a `SnackBar` error is shown if they throw exceptions.
- [x] 3.3 After successful backup, call `globalIsar.clear()`, then `_authService.logout()`, and navigate to `AuthScreen`. Verify by confirming the database is completely empty on the next login attempt (before restore).
- [x] 3.4 Clean up any removed UI: remove the "Backup to Cloud" and "Restore from Cloud" popup menu items from `HomeScreen` since they are now automatic, and verify the menu only shows "Profile" and "Logout".
