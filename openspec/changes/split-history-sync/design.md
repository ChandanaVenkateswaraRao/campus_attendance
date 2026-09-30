# Design

## Context

The current `AttendanceHistoryScreen` reads records from the local Isar database. When a warden edits a record, the backend updates its own database, but the local database remains outdated, causing a mismatch on refresh. The `SyncScreen` currently only displays a raw count of pending records. We need to shift to a cloud-first history view and an expanded sync interface.

## Goals / Non-Goals

**Goals:**
- Provide a `GET /api/attendance?date=...` endpoint.
- Rewrite `AttendanceHistoryScreen` to use `http` calls exclusively.
- Add a detailed `ListView` to `SyncScreen` showing unsynced records.

**Non-Goals:**
- Caching historical records locally for offline viewing.

## Decisions

**1. Re-use `_HistoryData` style layout in SyncScreen**
*Rationale*: Instead of building a completely new UI for reviewing unsynced records, we can port the familiar card layout previously used in `AttendanceHistoryScreen` into `SyncScreen`. This reduces cognitive load for the warden.

**2. Backend ID Resolution**
*Rationale*: Because the frontend will now fetch records directly from the backend, the backend will return its own primary `id`. We can safely use this `id` in the `PUT /api/attendance/:id` endpoint.
*Alternatives Considered*: Continuing to use `local_record_id` and trying to keep Isar in sync. Rejected because it's error-prone and doesn't handle multiple devices well.

## Risks / Trade-offs

- **Risk**: Loss of offline history viewing.
  - **Mitigation**: Instruct wardens that the history screen is an online feature, while the sync screen handles recent, offline work.
