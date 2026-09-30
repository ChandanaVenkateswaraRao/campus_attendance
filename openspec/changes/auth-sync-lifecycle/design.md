# Design

## Context

See `proposal.md` for the motivation behind tying the cloud sync process to the authentication lifecycle.
Currently, `SyncService` is completely decoupled from `AuthService` and relies on the user pressing a manual "Backup" or "Restore" button on the UI (in the `HomeScreen` menu or `SyncScreen`). We will now trigger these methods from the UI lifecycle hooks inside `AuthScreen` and `HomeScreen`. 

## Goals / Non-Goals

**Goals:**
- Trigger automatic backup when the user logs out from `HomeScreen`.
- Block the logout if the backup fails (e.g. no internet connection).
- Completely wipe the local Isar database upon successful logout to prevent data leakage.
- Modify the `main.dart` splash screen and the `AuthScreen` login completion path to automatically await `restoreFromCloud()`.

**Non-Goals:**
- Offline logout capability. By definition, logging out requires a backup, which requires the internet. An offline logout would mean data loss.
- Modifying the underlying Isar schema or backend APIs.

## Decisions

### 1. Logout Flow Orchestration
**Decision**: In `HomeScreen`, when the user selects "Logout", we will display a full-screen loading dialog. We will invoke `syncPendingRecords()` and `backupToCloud()`. If an exception occurs, we dismiss the dialog and show a `SnackBar` with an error. If successful, we clear the DB with `globalIsar.clear()`, log out of `AuthService`, and route to `AuthScreen`.
**Alternatives Considered**: Allowing offline logout with local warnings. Rejected because it risks severe attendance data loss.

### 2. Login Flow Orchestration
**Decision**: In `AuthScreen`, after a successful login (before `Navigator.pushReplacement`), we will await `SyncService(globalIsar).restoreFromCloud()` while `_isLoading` is true. This way, the user doesn't arrive at `HomeScreen` with a blank database. 
**Alternatives Considered**: Pushing to `HomeScreen` and showing a sync indicator there. Rejected because `HomeScreen` relies on loaded profile fields and database data to function correctly.

### 3. Splash Screen Startup
**Decision**: `main.dart` currently uses `FutureBuilder<bool>` waiting for `AuthService().isLoggedIn()` and a 2-second delay. We will change this to wait for `AuthService().isLoggedIn()`. If true, it also chains `.then((_) => SyncService(globalIsar).restoreFromCloud())`. The user sees the splash screen acting as a loading state. 

## Risks / Trade-offs

- **Risk: Very long restore times** if the database grows large.
  **Mitigation**: The `restoreFromCloud()` operation streams JSON over HTTP. While it might take a few seconds, it is only paid once at login, which is acceptable for security.
- **Risk: Network failure blocks logout**.
  **Mitigation**: Wardens will be explicitly informed via the UI that they need internet to log out securely.
