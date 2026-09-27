# Design

## Context

The app currently uses a flat navigation structure (`HomeScreen` -> `RegistrationScreen` or `AttendanceScreen`) where the user must type the "Room Number" manually on the target screen. This design proposes a hierarchical navigation stack that groups actions by physical Room.

## Goals / Non-Goals

**Goals:**
- Replace flat navigation with a structured, stack-based navigation flow (`Navigator.push`).
- Separate Room selection/creation from the Camera-based screens.
- Implement a modern iOS-like UI using standard Flutter Material 3 with rounded corners (`BorderRadius.circular`), elevated cards, and clean typography, or `Cupertino` equivalents.

**Non-Goals:**
- Modifying the underlying Isar database schema (no changes to `Room` or `Student` models).
- Modifying the offline face recognition ML pipeline (which is already working).

## Decisions

### 1. Navigation Flow Structure
- **Decision:** Introduce intermediate screens: `RoomListScreen` and `StudentListScreen`.
- **Rationale:** Separates concerns. `RoomListScreen` handles querying and displaying all rooms. `StudentListScreen` shows all students in a selected room. 
- **Alternative:** Keep everything on one screen with expandable panels. Rejected because it becomes too cluttered when adding the camera feed.

### 2. UI Styling System
- **Decision:** Use Material 3 with heavy customizations (rounded corners, subtle shadows, vibrant colors) rather than strict `Cupertino` widgets.
- **Rationale:** Flutter's Material 3 is cross-platform and highly customizable to look "modern iOS-like" without the strict constraints of `Cupertino` widgets, reducing the need to maintain parallel widget trees.
- **Alternative:** Use `flutter/cupertino.dart` exclusively. Rejected as it can be overly restrictive and sometimes looks out of place on Android devices, whereas a "clean modern UI" using Material 3 looks great everywhere.

## Risks / Trade-offs

- **Risk:** Deeper navigation stack means state management between screens (passing the `Isar` instance and `Room` object). 
  - **Mitigation:** Simply pass the `Isar` instance and the selected `Room` object as constructor arguments to the subsequent screens.

- **Risk:** Existing code in `RegistrationScreen` creates the Room inline if it doesn't exist.
  - **Mitigation:** Refactor `RegistrationScreen` to expect a pre-existing `Room` object passed to it. Move room creation logic to `RoomListScreen`.
