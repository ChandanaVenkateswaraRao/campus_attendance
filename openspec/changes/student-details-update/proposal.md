# Proposal: Comprehensive Student Details & Edit Functionality

## Goal
Enhance the student registration process by capturing a comprehensive set of details and providing the ability to edit these details later.

## Scope
1. **Database Schema:** 
   - Expand the Isar `Student` model to include `phoneNumber`, `fatherPhoneNumber`, `motherPhoneNumber`, and `email`.
   - Update the backend SQLite `cloud_students` table to store these new fields.
2. **Registration Flow:**
   - Add input fields for these new details to `registration_screen.dart`.
3. **Edit Functionality:**
   - Add an edit button to the student cards in `student_list_screen.dart`.
   - Create an edit modal/screen to allow wardens to update these details.
4. **Syncing:**
   - Update `sync_service.dart` and the backend `POST /api/backup` and `GET /api/restore` endpoints to serialize and deserialize the new fields.

## Constraints
- The UI must remain professional and consistent with the new theme (Indigo).
- `models.dart` must run build_runner after updates.
- SQLite schema updates should use `ALTER TABLE` if columns do not exist.
