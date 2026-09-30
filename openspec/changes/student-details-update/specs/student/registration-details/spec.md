# Spec: Student Registration & Editing Details

## 1. Data Model
- The `Student` entity must store:
  - Name (String)
  - Registration Number / Student ID (String)
  - Phone Number (String)
  - Father's Phone Number (String)
  - Mother's Phone Number (String)
  - Email ID (String)
  - Room (Relation)
  - Face Embeddings (Relation)

## 2. Registration Flow
- When a warden registers a student, they must be presented with text fields for all the above details.
- Basic validation should ensure at least the Name and Registration Number are provided (this matches current behavior for `studentId`).

## 3. Edit Flow
- On the `student_list_screen.dart`, each student row must have an "Edit" button (e.g. `IconButton` with `Icons.edit`).
- Tapping Edit opens a modal dialog or screen pre-filled with the student's current details.
- Saving the edit updates the student in Isar and triggers a UI refresh.

## 4. Synchronization
- All new fields must be transmitted during `backupToCloud` (POST `/api/backup`).
- All new fields must be restored during `restoreFromCloud` (GET `/api/restore`).
- The backend SQLite schema must dynamically add these columns if they do not exist.
