# Tasks

## 1. Project Navigation Foundation

- [x] 1.1 Add `cupertino_icons` and related styling dependencies to `pubspec.yaml` (if not already present) and verify `flutter pub get` completes successfully.
- [x] 1.2 Redesign `HomeScreen` (`lib/ui/home_screen.dart`) to feature large, modern Material 3 cards for "Registration" and "Take Attendance", removing direct navigation to camera screens. Verify by launching the app and ensuring the UI displays the two cards.

## 2. Room Management UI (Registration Flow)

- [x] 2.1 Create `RoomListScreen` (`lib/ui/room_list_screen.dart`) that fetches all `Room` entities from Isar and displays them in a modern list (e.g. `ListView.builder` with `ListTile`). Verify by successfully rendering the list.
- [x] 2.2 Add an "Add Room" FAB or action button in `RoomListScreen` that opens a dialog to create a new Room in Isar. Verify by creating a new room and seeing it instantly appear in the list.
- [x] 2.3 Create `StudentListScreen` (`lib/ui/student_list_screen.dart`) that accepts a `Room` argument, fetches students belonging to that room from Isar, and displays them. Verify by tapping a room in `RoomListScreen` and navigating successfully to the empty `StudentListScreen`.

## 3. Adapting the Camera Registration Flow

- [x] 3.1 Refactor `RegistrationScreen` (`lib/ui/registration_screen.dart`) to accept a `Room` object as a required constructor argument, removing the manual Room Name text field. Verify by ensuring the code compiles without errors.
- [x] 3.2 Add an "Add Student" button to `StudentListScreen` that navigates to the refactored `RegistrationScreen`. Verify by successfully registering a student to the selected room and confirming they appear in the `StudentListScreen` upon return.
- [x] 3.3 Apply the new modern UI theme (rounded borders, elevated cards, updated colors) to `RegistrationScreen`. Verify visually.

## 4. Adapting the Attendance Flow

- [x] 4.1 Update `HomeScreen`'s "Take Attendance" card to navigate to `RoomListScreen` (passing a flag to indicate it's the attendance flow). Verify navigation works.
- [x] 4.2 From `RoomListScreen` (in attendance mode), tapping a room should navigate directly to `AttendanceScreen` (passing the `Room` object or name). Verify navigation works.
- [x] 4.3 Refactor `AttendanceScreen` (`lib/ui/attendance_screen.dart`) to accept the `Room` object directly instead of fetching it via string lookup. Apply modern UI styling to the student list overlay (rounded top edges, frosted glass background, etc.). Verify by performing a successful face match and observing the modern UI updates.

## 5. Final Integration

- [x] 5.1 Perform a complete end-to-end run: launch app, create a new room, register a face into that room, go back home, select take attendance, pick the room, and successfully be recognized. Verify all transitions are smooth and bug-free.
