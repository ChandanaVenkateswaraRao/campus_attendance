# Design

## Context

The backend stores attendance in the `attendance_records` SQLite table, using a `present_students_json` column to store the list of students marked as present. Currently, the Flutter app fetches these records to display in the `AttendanceHistoryScreen` but does not support modifying them.

## Goals / Non-Goals

**Goals:**
- Allow modifying the `present_students_json` of an existing record on the server.
- Expose a UI for wardens to edit this list.
- Prevent conflicting offline edits by restricting this feature to online use only.

**Non-Goals:**
- Offline editing and subsequent syncing of historical records (deferred to avoid complex merge conflicts).
- Editing other fields of the record (like timestamp or room name).

## Decisions

**1. Directly update the backend (No local queuing for edits)**
*Rationale*: Syncing offline edits of historical records introduces complex merge scenarios (e.g., if multiple wardens edit the same record, or if the server was updated by another device). To keep it simple and robust, editing is strictly an online operation. We use a `PUT /api/attendance/:id` endpoint.
*Alternatives Considered*: Allowing offline edits and adding a sync queue for updates. This was rejected due to synchronization complexity and merge conflict resolution.

**2. UI Implementation in `AttendanceHistoryScreen`**
*Rationale*: Instead of building a complex new screen, we can add a trailing "Edit" icon button on each record in the history list. When clicked, it opens a dialog or modal bottom sheet showing the students. The warden toggles checkboxes for each student. If offline, the edit button is either hidden or shows a snackbar explaining that internet is required.
*Alternatives Considered*: Creating a dedicated edit screen. A modal/dialog is sufficient and faster to build for toggling a list.

## Risks / Trade-offs

- **Risk**: Warden loses connection while the modal is open, and the PUT request fails.
  - **Mitigation**: The Flutter app will catch the network exception, notify the warden, and the modal state won't be saved. The local database will only be updated if the server returns a 200 OK.
