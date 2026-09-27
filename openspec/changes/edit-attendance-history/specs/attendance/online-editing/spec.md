# Spec Delta

## Purpose

Enables wardens to securely edit historical attendance records directly on the remote server when connected to the internet, ensuring the central database maintains accurate and up-to-date attendance data.

## ADDED Requirements

### Requirement: Online Record Editing
The system SHALL provide an interface for wardens to edit the list of present students for a previously submitted attendance record.

#### Scenario: Editing an attendance record
- **WHEN** the warden views a past attendance record and selects the edit option
- **THEN** the system displays the students in that room, allowing the warden to toggle their present/absent status, and saves the updated list to the remote server.

### Requirement: Connectivity Enforcement
The system SHALL restrict the edit functionality to only be available when the device has an active internet connection.

#### Scenario: Attempting to edit while offline
- **WHEN** the warden attempts to edit a historical attendance record without an internet connection
- **THEN** the system disables the edit option and displays a message indicating that an internet connection is required to modify historical records.

### Requirement: Remote Syncing of Edits
The system SHALL save edits directly to the remote server, rather than queueing them locally, to immediately resolve any potential historical conflicts.

#### Scenario: Saving a modified record
- **WHEN** the warden submits an edited attendance record
- **THEN** the system sends a request to the backend to update the record and refreshes the local display to confirm the changes have been successfully saved to the server.
