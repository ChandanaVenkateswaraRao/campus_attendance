# Proposal

## Why

Currently, the Attendance History screen reads records from the local database, leading to complex sync issues where edits aren't reflected and server IDs get mismatched. To fix this while preserving offline utility, we need to split the data viewing experience: the History screen will act as an online-only window into the live backend, while the Sync screen will allow wardens to review their pending, unsynced local records before uploading them.

## What Changes

- Modify `AttendanceHistoryScreen` to fetch data entirely from a new backend endpoint via HTTP GET, rather than from the local Isar database.
- Modify `SyncScreen` to display a detailed list of all locally queued (unsynced) records, allowing the warden to review them before tapping the sync button.
- Create a new `GET /api/attendance` endpoint on the backend that returns a warden's attendance history for a given date.

## Capabilities

### New Capabilities
- `attendance/local-queue-review`: Enables wardens to review unsynced attendance records directly within the sync screen.
- `attendance/cloud-history`: Mandates that the historical attendance view fetches data exclusively from the remote server, removing reliance on local storage.

### Modified Capabilities
<!-- No modified capabilities since online-editing isn't archived yet -->

## Impact

- **Frontend (`attendance_history_screen.dart`)**: Rewritten to use `http` instead of `isar`.
- **Frontend (`sync_screen.dart`)**: Expanded to include a `ListView` similar to the old history screen layout.
- **Backend (`index.js`)**: Needs a new, authenticated `GET` endpoint for fetching records.
