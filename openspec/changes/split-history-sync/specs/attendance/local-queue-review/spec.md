# Spec Delta

## Purpose

Enables wardens to review unsynced, locally queued attendance records within the sync interface before uploading them to the server.

## ADDED Requirements

### Requirement: Local Queue Display
The system SHALL display a list of all locally queued attendance records that have not yet been synced to the remote server, providing a summary of the room and student counts.

#### Scenario: Viewing pending records
- **WHEN** the warden navigates to the sync screen
- **THEN** the system displays a list of all locally stored attendance records that are marked as unsynced.
