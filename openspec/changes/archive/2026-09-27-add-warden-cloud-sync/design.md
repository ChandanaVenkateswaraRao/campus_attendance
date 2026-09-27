# Design

## Context

See proposal.md - Why. Currently, all data is siloed on a single device, meaning if a warden is absent, their floor configuration is inaccessible to covering staff.

## Goals / Non-Goals

**Goals:**
- Implement Warden login via email/password in the app and backend.
- Allow Wardens to push their entire Isar configuration to the Node.js backend.
- Allow Wardens to pull and overwrite their local Isar database with their cloud configuration.

**Non-Goals:**
- Real-time multiplayer synchronization (e.g., two wardens taking attendance for the same floor simultaneously). Sync is strictly manual "push/pull".
- Forgot password/email verification flows (out of scope for MVP).

## Decisions

**1. Authentication Method & Profile**
- **Decision:** Simple JWT or token-based authentication from Node.js Express. The login/register endpoints will also return the warden's profile fields (name, hostel, block, floor).
- **Rationale:** Easy to implement. Returning the profile in the auth response allows the Flutter app to cache it via `shared_preferences`, ensuring the Home Screen can display the personalized greeting instantly without subsequent network requests.

**2. Data Sync Strategy**
- **Decision:** "Snapshot Sync" (Nuke and Pave). When restoring from the cloud, the local Isar database will drop all existing rooms, students, and face embeddings, replacing them entirely with the cloud payload.
- **Rationale:** Given this is intended for a warden switching devices, they need the exact state of their floor. Trying to merge data piecewise is complex and unnecessary for this specific "device handoff" use case.

## Risks / Trade-offs

- **[Risk] Data Loss on Restore** → **Mitigation:** Display a strong warning confirmation dialog before a warden restores from the cloud, explaining it will overwrite any local unregistered changes.
- **[Risk] Large Payload Size** → **Mitigation:** Face embeddings are arrays of 192 floats. For a floor of 100 students with 5 embeddings each, this is ~100x5x192 floats (~400KB), which is perfectly manageable for a single JSON HTTP request.
