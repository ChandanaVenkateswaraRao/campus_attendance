# Proposal

## Why

Currently, when a warden returns to a previously scanned room to manually update attendance from "Present" back to "Absent", the Isar local database append-only bug prevents the update from taking effect. Due to `record.presentStudents` not being explicitly loaded before calling `.clear()`, the database retains the existing students and appends any newly marked present students instead of cleanly overwriting the array. This change fixes the bug so manual attendance overrides correctly overwrite the database.

## What Changes

- Fix `_submitAttendance` in `AttendanceScreen` to explicitly load the previous present students from Isar (`_existingRecord.presentStudents.loadSync()`) before clearing them.
- Alternatively, use `reset()` on the `IsarLinks` to guarantee immediate removal from the local database before `addAll()` and `save()`.

## Capabilities

### New Capabilities
None.

### Modified Capabilities
None. (This is a pure bug fix for data persistence, the expected behavior remains identical to the existing specs).

## Impact

- `lib/ui/attendance_screen.dart` (`_submitAttendance` method).
- Isar database operations for `AttendanceRecord` overwrites.
