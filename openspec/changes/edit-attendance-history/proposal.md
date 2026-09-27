# Proposal

## Why

Wardens occasionally need to correct mistakes in past attendance records (e.g., a student was marked absent but arrived later). We need an edit option in the Attendance History screen, which interacts directly with the server to update these records, ensuring the central database is always accurate. This requires an active internet connection to prevent synchronization conflicts with historical data.

## What Changes

- Add an "Edit" button to individual records in the Attendance History screen.
- The edit option will only be enabled when the device is connected to the internet.
- Implement an edit interface where wardens can toggle students' present/absent status for a historical record.
- Create a new backend endpoint (e.g., PUT `/api/attendance/:id`) to handle updates to a specific attendance record.
- Update the local display immediately upon a successful response from the server.

## Capabilities

### New Capabilities
- `attendance/online-editing`: Enables wardens to edit historical attendance records directly on the server when connected to the internet.

### Modified Capabilities
- `attendance/offline-face-recognition`: No requirement changes. The local queue mechanism remains the same. (We are adding a new capability instead).

## Impact

- **Backend**: Needs a new update endpoint for attendance records.
- **Frontend App**: Needs a new UI for editing a record, logic to check network connectivity before allowing edits, and logic to fetch/update records on the server.
