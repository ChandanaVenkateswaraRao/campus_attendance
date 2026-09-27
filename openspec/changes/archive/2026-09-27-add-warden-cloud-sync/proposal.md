# Proposal

## Why

Currently, all hostel attendance data (rooms, students, and face embeddings) is stored exclusively in the local Isar database on a specific warden's device. If a warden is absent, there is no way for a covering warden to take attendance using their own device because they lack the localized face vectors. This change introduces an email-based warden authentication and cloud sync system (Option A), allowing a covering warden to log in with the absent warden's credentials and instantly clone their entire floor configuration.

## What Changes

- Add a Login Screen to the Flutter app for email-based warden authentication, requiring Name, Hostel Name, Block Name, and Floor Number during registration.
- Add a Profile section and update the Home Screen to display the assigned Hostel Name and Floor Number.
- Implement "Backup to Cloud" and "Restore from Cloud" functionality in the app to sync Isar data to the Node.js backend.
- Enhance the Node.js Express backend to support Warden registration, login, and storing rooms/students/embeddings keyed by `warden_email`.

## Capabilities

### New Capabilities
- `warden/cloud-sync`: Covers email-based warden authentication and the explicit syncing (backup/restore) of room, student, and face vector configurations to the Node.js backend.

### Modified Capabilities
- `attendance/offline-face-recognition`: (No requirement changes, purely an extension to allow initial cloning. We will leave this empty as the core offline recognition spec remains untouched).

## Impact

- Flutter App: `main.dart` (new Login/Auth routing), `SyncService` (new backup/restore API calls), new `AuthScreen`.
- Node.js Backend: `backend/index.js` (new SQLite tables for wardens and cloud data, new auth and sync endpoints).
