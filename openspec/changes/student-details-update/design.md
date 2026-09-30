# Design

## Local Database Changes
Modify `lib/models/models.dart`:
```dart
@collection
class Student {
  Id id = Isar.autoIncrement;

  late String name;
  late String studentId;
  String? phoneNumber;
  String? fatherPhoneNumber;
  String? motherPhoneNumber;
  String? email;
  // ... rest unchanged
}
```
Run `flutter pub run build_runner build` to regenerate `models.g.dart`.

## Backend Changes (`backend/index.js`)
Use SQLite `ALTER TABLE` to gracefully add columns to `cloud_students`:
```javascript
db.run('ALTER TABLE cloud_students ADD COLUMN phone_number TEXT', () => {});
db.run('ALTER TABLE cloud_students ADD COLUMN father_phone_number TEXT', () => {});
db.run('ALTER TABLE cloud_students ADD COLUMN mother_phone_number TEXT', () => {});
db.run('ALTER TABLE cloud_students ADD COLUMN email TEXT', () => {});
```
Update the `/api/backup` route to read `phoneNumber`, `fatherPhoneNumber`, `motherPhoneNumber`, `email` from the JSON payload and insert/update them.
Update the `/api/restore` route to return these fields.

## Frontend UI
1. **`lib/ui/registration_screen.dart`**:
   - Add `TextEditingController` for phone, father phone, mother phone, and email.
   - Add standard `TextField` widgets for these in the scrollable form.
   - Update the Isar save transaction to store these fields.
2. **`lib/ui/student_list_screen.dart`**:
   - Add an `IconButton(Icons.edit)` to the `ListTile` trailing area.
   - Create a `_showEditDialog(Student student)` method that opens an `AlertDialog` with text fields for all 6 editable properties.
   - On save, update Isar and call `setState` to refresh the list.
3. **`lib/services/sync_service.dart`**:
   - Include the 4 new properties in the payload for `/api/backup`.
   - Read the 4 new properties from the response in `/api/restore`.
