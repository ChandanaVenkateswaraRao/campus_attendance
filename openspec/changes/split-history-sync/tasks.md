# Tasks

## 1. Backend API Updates

- [x] 1.1 In `backend/index.js`, add a new `GET /api/attendance` endpoint (with `authenticateToken`) that queries `attendance_records`. It should optionally accept a `date` query parameter to filter records. Verify by sending a curl request and receiving a filtered JSON response.
- [x] 1.2 In `backend/index.js`, modify the `PUT /api/attendance/:id` endpoint to update the row where `id = ?` (using the server's primary key) instead of relying on `local_record_id`. Verify by updating a record via curl and confirming the change in the database.

## 2. Frontend Services Update

- [x] 2.1 In `lib/services/sync_service.dart`, add a `fetchAttendanceHistory(DateTime date)` method that makes an HTTP GET request to `/api/attendance?date=...` and returns a list of parsed JSON records. Verify by calling this method and logging the returned data length.

## 3. Sync Screen Update

- [x] 3.1 In `lib/ui/sync_screen.dart`, add logic to load the detailed list of pending records from Isar (similar to the old history load). Display these records below the pending count using a `ListView`. Verify by taking attendance offline and seeing the new cards appear in the sync screen.

## 4. Attendance History Screen Rewrite

- [x] 4.1 In `lib/ui/attendance_history_screen.dart`, rewrite `_loadRecords()` to call `syncService.fetchAttendanceHistory(_selectedDate)` instead of querying the local Isar database. Add network connectivity error handling (e.g., showing a friendly message if offline). Verify by running the app online and seeing records load from the server, then going offline and seeing the error message.
- [x] 4.2 In `lib/ui/attendance_history_screen.dart`, update the `_openEditModal` save button logic to just call `_loadRecords()` upon a successful edit, which will now automatically pull the fresh data from the backend. Verify by making an edit and observing the history screen visually update.
