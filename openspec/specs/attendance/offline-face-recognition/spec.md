# offline-face-recognition

## Purpose

Provides hostel wardens with an offline-capable, high-speed face recognition tool for automating daily room attendance directly from a mobile device.

## Requirements

### Requirement: Multi-Angle Face Registration
The system SHALL allow wardens to capture and locally store multiple baseline face embeddings for a given student to improve recognition accuracy.

#### Scenario: Registering a new student in a room
- **WHEN** the warden initiates registration for a student in a specific room and captures multiple facial angles
- **THEN** the system generates the corresponding face embeddings and securely stores them locally against the student's profile for that room

### Requirement: Room-Scoped Offline Attendance
The system SHALL restrict face matching exclusively to the students registered to the currently selected room, and it MUST perform this matching entirely on the device without requiring an internet connection.

#### Scenario: Scanning a populated room
- **WHEN** the warden selects a room and scans it using the live camera feed
- **THEN** the system detects faces, extracts their embeddings, compares them only to the embeddings of students assigned to that room, and immediately indicates successful matches

### Requirement: Live Frame Tracking for Recognition
The system SHALL utilize object tracking across consecutive frames to maintain identity context without running the full neural network on every frame, and it MUST require a consistent match across multiple frames to confirm a student's presence.

#### Scenario: Sustained recognition
- **WHEN** a recognized student moves slightly within the camera's view
- **THEN** the system tracks the bounding box, averages the recognition confidence over recent frames, and maintains the "Present" status without UI stutter or false identification

### Requirement: Auto-Capture and Haptic Feedback
The system SHALL automatically mark a room's attendance as complete once all expected students are confidently recognized for a sustained duration, providing immediate tactile and audio feedback.

#### Scenario: Completing a room
- **WHEN** the system confirms the presence of all registered students in a room for 1 consecutive second
- **THEN** the device vibrates, plays a success tone, automatically saves the room's attendance record, and returns the warden to the room selection screen

### Requirement: Batch Syncing
The system SHALL queue all attendance records locally and upload them to the backend server only upon an explicit sync command from the user.

#### Scenario: Syncing at the end of rounds
- **WHEN** the warden taps the "Sync" button while connected to the internet
- **THEN** the system uploads all locally queued attendance records and updates the central database
