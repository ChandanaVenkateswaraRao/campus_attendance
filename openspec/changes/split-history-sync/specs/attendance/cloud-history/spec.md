# Spec Delta

## Purpose

Mandates that the historical attendance view fetches data exclusively from the remote server, providing a definitive source of truth and resolving edit synchronization conflicts.

## ADDED Requirements

### Requirement: Cloud-Only History Fetching
The system SHALL retrieve historical attendance records exclusively via an API request to the backend, rather than reading them from local storage.

#### Scenario: Viewing history while online
- **WHEN** the warden opens the attendance history screen and has internet connectivity
- **THEN** the system fetches the records from the remote server and displays them.

### Requirement: Offline History Prevention
The system SHALL NOT display cached or local historical records in the history view when offline.

#### Scenario: Viewing history while offline
- **WHEN** the warden opens the attendance history screen without internet connectivity
- **THEN** the system displays a clear message that an active connection is required to view historical data.
