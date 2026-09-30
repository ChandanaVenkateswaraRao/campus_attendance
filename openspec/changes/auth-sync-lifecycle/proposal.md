# Proposal

## Why

Currently, syncing data to and from the cloud requires manual action by the warden. Tying data synchronization to the authentication lifecycle ensures that a device never holds onto stale or sensitive student data when a warden isn't logged in, and it guarantees that a warden always has the latest records automatically when they start their shift.

## What Changes

- Implement a mandatory network check on logout to ensure data is backed up before exiting.
- Trigger `syncPendingRecords` and `backupToCloud` automatically during the logout flow.
- Block the logout if the backup fails, showing an error to prevent data loss.
- Clear the local database (`isar.clear()`) after successful logout to ensure no sensitive data remains.
- Integrate `restoreFromCloud` into the login flow (and the splash screen for returning users) with a loading indicator so data is fresh.

## Capabilities

### New Capabilities
None

### Modified Capabilities
- `warden/cloud-sync`: Update the requirements so that backup happens automatically on logout, local data is wiped after logout, and restoration happens automatically on login.

## Impact

- **UI**: The Login/Splash screens will show a sync progress indicator. The logout action will show a loading overlay and possible network error Snackbars.
- **Data Flow**: Local database is no longer persistent across sessions for different users.
- **Dependencies**: Tightly couples `SyncService` with `AuthService` and `main.dart`'s initialization logic.
