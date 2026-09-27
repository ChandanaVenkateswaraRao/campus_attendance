# Spec Delta

## Purpose
Provides hierarchical management of physical hostel rooms and the students assigned to them, allowing wardens to easily navigate the roster before performing actions like registration or attendance.

## ADDED Requirements

### Requirement: Room Listing
The system SHALL present a list of all known rooms, allowing the user to view and select a specific room for further actions (like taking attendance or registering students).

#### Scenario: Navigating to rooms list
- **WHEN** the user selects a feature that requires a room (e.g., "Take Attendance" or "Registration")
- **THEN** the system displays a clear, hierarchical list of all rooms retrieved from the local database

### Requirement: Room Creation
The system SHALL provide an explicit mechanism to create a new room, avoiding implicit creation through typos.

#### Scenario: Creating a new room
- **WHEN** the user taps "Add Room" from the room list and enters a valid name
- **THEN** the system creates a new Room record and adds it to the list

### Requirement: Viewing Students within a Room
The system SHALL display the list of registered students restricted to the selected room.

#### Scenario: Selecting a room to view students
- **WHEN** the user taps a specific room in the Registration flow
- **THEN** the system displays all students registered to that room and provides an option to "Add Student"
