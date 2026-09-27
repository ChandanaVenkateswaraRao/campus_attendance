# Tasks

## 1. Node.js Backend Auth & Sync

- [x] 1.1 Update Node.js SQLite schema: create `wardens` table, and add `warden_email` to `rooms`, `students`, and `face_embeddings` tables. Verify by starting the server without SQL syntax errors.
- [x] 1.2 Implement POST `/api/register` and POST `/api/login` endpoints returning a JWT or simple token. Verify by curling the endpoints.
- [x] 1.3 Implement POST `/api/backup` endpoint to receive a JSON payload of rooms, students, and embeddings and store them keyed to the authenticated warden's email. Verify by curling a mock payload.
- [x] 1.4 Implement GET `/api/restore` endpoint to return all rooms, students, and embeddings belonging to the authenticated warden's email. Verify by curling the endpoint and checking the returned JSON structure.

## 2. Flutter App Authentication

- [x] 2.1 Create `AuthService` in Flutter to handle login/register HTTP requests and store the authenticated email/token locally (e.g., using `shared_preferences`). Verify by running the app and logging a token.
- [x] 2.2 Create an `AuthScreen` UI with email and password fields, Login, and Register buttons. Verify by rendering the screen in the emulator.
- [x] 2.3 Update `main.dart` routing to show `AuthScreen` on startup if not logged in, or `HomeScreen` if logged in. Verify by restarting the app and landing on the correct screen.

## 3. Flutter App Cloud Sync

- [x] 3.1 In `SyncService`, implement `backupToCloud()` that queries all Isar `Room`, `Student`, and `FaceEmbedding` records, formats them to JSON, and POSTs to `/api/backup`. Verify by calling the function and checking the Node.js server logs for successful insertion.
- [x] 3.2 In `SyncService`, implement `restoreFromCloud()` that GETs `/api/restore`, drops existing Isar collections (`clear()` or `writeTxn`), and inserts the parsed JSON data into Isar. Verify by running the function and observing the UI update with the downloaded rooms.
- [x] 3.3 Add "Backup to Cloud" and "Restore from Cloud" buttons (or menu options) to the `HomeScreen` UI that trigger the respective `SyncService` methods with loading indicators. Verify by tapping them in the app.

## 4. Warden Profile Update

- [x] 4.1 Update Node.js SQLite `wardens` table to include `name`, `hostel_name`, `block_name`, `floor_number`. Update `/api/register` to accept these fields and `/api/login` to return them.
- [x] 4.2 Update `AuthScreen` UI to include text fields for Name, Hostel, Block, and Floor. Make them visible only when "Register" is being performed (or always require them on register).
- [x] 4.3 Update `AuthService` in Flutter to send the new fields during registration and cache them in `shared_preferences` on login/register.
- [x] 4.4 Update `HomeScreen` UI to read the cached profile data. Replace the "Welcome back, Warden" greeting entirely with just the Hostel Name and Floor Number. Add a "Profile" popup menu option that opens a dialog showing all details (Name, Hostel, Block, Floor).
- [x] 4.5 Update `main.dart` to set `debugShowCheckedModeBanner: false` in `MaterialApp` to remove the Debug strip from the top right corner.
