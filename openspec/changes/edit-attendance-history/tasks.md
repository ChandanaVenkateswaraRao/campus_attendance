# Tasks

## 1. Backend Implementation

- [x] 1.1 In `backend/index.js`, add a new `PUT /api/attendance/:id` endpoint that accepts a JSON body containing `present_students`. Verify by sending a curl request with mock data and checking if the record in SQLite is updated.

## 2. Frontend Services Update

- [x] 2.1 In the Flutter app, create or update a service (e.g., `SyncService` or a new `AttendanceApiService`) to include an `updateAttendanceRecord(int recordId, List<dynamic> presentStudents)` method that makes a PUT request to the backend. Verify by printing a success log when a mock call is made.

## 3. Frontend UI Implementation

- [x] 3.1 In `AttendanceHistoryScreen`, add an "Edit" trailing icon button to each record in the list. Ensure it only displays or is enabled when the user is connected to the internet (or show a snackbar if offline when clicked). Verify by running the app and tapping the button to ensure it responds.
- [x] 3.2 Implement a modal or dialog that opens when "Edit" is tapped. It should fetch/display all students for that room, with checkboxes showing their current present/absent status. Verify by opening the modal and confirming the checkboxes match the record's data.
- [x] 3.3 Add a "Save" button in the edit modal that calls the `updateAttendanceRecord` service method. Upon success, refresh the historical records list and close the modal. Verify by editing a student's status, saving, and observing the updated count in the history screen.
