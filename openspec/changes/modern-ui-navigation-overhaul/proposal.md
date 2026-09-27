# Proposal

## Why

The current user interface requires wardens to manually type room numbers to register students or take attendance. This flat, manual input approach can lead to data fragmentation (e.g., typos like "Room 101" vs "room101"). A modern, hierarchical UI with an iOS-like design language will eliminate these errors, make the app visually appealing, and vastly improve the user experience by guiding users through a structured flow (Home -> Room -> Students).

## What Changes

- Complete overhaul of the Flutter UI using a modern iOS-like design system (e.g., `Cupertino` widgets or heavily rounded Material 3 cards, frosted glass effects, clean typography).
- **Home Screen Refactor**: Introduction of large action cards for "Registration" and "Take Attendance".
- **Hierarchical Registration Flow**:
  - Tap "Registration" -> Opens a list of all existing Rooms.
  - Option to create a new Room explicitly.
  - Tap a Room -> Opens a list of students currently registered in that room.
  - Option to register a new student to that specific room, opening the camera.
- **Hierarchical Attendance Flow**:
  - Tap "Take Attendance" -> Opens a list of all existing Rooms.
  - Tap a Room -> Opens the live ML Camera for that room.
- Removal of manual text input fields for "Room Number".

## Capabilities

### New Capabilities
- `attendance/room-management`: Managing physical hostel rooms (creation, listing) and the hierarchical grouping of students within those rooms before applying face recognition.

### Modified Capabilities
- (None)

## Impact

- `lib/ui/`: Existing UI screens (`registration_screen.dart`, `attendance_screen.dart`, `home_screen.dart`) will be completely rewritten or heavily refactored.
- Navigation routing logic will become deeper (stack-based navigation).
- `Student` and `Room` Isar models remain unchanged, but the way they are queried and presented in the UI will change.
