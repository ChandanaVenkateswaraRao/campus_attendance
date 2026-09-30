# Spec Delta

## Purpose

Provides a professional, collapsed, room-based grouping for historical attendance records to avoid excessively long student lists on screen.

## ADDED Requirements

### Requirement: Room-level Summary Cards
The system SHALL display historical attendance grouped by room, showing a collapsed card that displays only the room name, timestamp, and a summary count of present and absent students.

#### Scenario: Warden views history list
- **WHEN** the warden navigates to the attendance history screen
- **THEN** they see a list of cards, each representing one room's attendance session
- **AND** the student names are not immediately visible, keeping the list compact

### Requirement: Expandable Student Details
The system SHALL allow wardens to expand a room-level summary card to view the detailed list of present and absent students for that specific room.

#### Scenario: Warden drills down into a room
- **WHEN** the warden taps on a room summary card
- **THEN** the card expands smoothly
- **AND** the system displays the full list of students categorized by present and absent status for that room
