# Tasks

## 1. Database & Models
- [x] 1.1 In `lib/models/models.dart`, add `phoneNumber`, `fatherPhoneNumber`, `motherPhoneNumber`, and `email` to the `Student` class as nullable Strings.
- [x] 1.2 Run `flutter pub run build_runner build` in the `hostel_face_attendance` directory to regenerate `models.g.dart`.
- [x] 1.3 In `backend/index.js`, add `ALTER TABLE` statements for `cloud_students` to add `phone_number`, `father_phone_number`, `mother_phone_number`, and `email`.
- [x] 1.4 In `backend/index.js`, update the `/api/backup` route to accept these new fields and insert/update them in `cloud_students`.
- [x] 1.5 In `backend/index.js`, update the `/api/restore` route to return these fields in the `students` array.

## 2. Synchronization Service
- [x] 2.1 In `lib/services/sync_service.dart`, update `backupToCloud` to include `phoneNumber`, `fatherPhoneNumber`, `motherPhoneNumber`, and `email` in the student JSON map.
- [x] 2.2 In `lib/services/sync_service.dart`, update `restoreFromCloud` to read these fields from the JSON map and assign them to the local `Student` object.

## 3. Registration UI
- [x] 3.1 In `lib/ui/registration_screen.dart`, add `TextEditingController`s for the new fields.
- [x] 3.2 Add `TextField` widgets for the new fields to the form layout.
- [x] 3.3 Update the save logic in `registration_screen.dart` to assign the controller values to the new `Student` model fields before putting to Isar.

## 4. Edit UI
- [x] 4.1 In `lib/ui/student_list_screen.dart`, add an edit `IconButton` to the trailing widget of each student's `ListTile` (you may need to wrap the delete button in a Row).
- [x] 4.2 In `lib/ui/student_list_screen.dart`, implement `_showEditDialog(Student student)` to display an `AlertDialog` with text fields pre-filled with the student's data.
- [x] 4.3 Implement the save logic in the edit dialog to update the `Student` object in an Isar write transaction and call `setState` to refresh the UI.
