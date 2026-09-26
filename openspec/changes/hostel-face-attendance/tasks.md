# Tasks

## 1. Project Scaffolding & Database Setup

- [x] 1.1 Initialize the new Flutter project (`flutter create hostel_face_attendance`) and verify the default app runs on a connected device/emulator.
- [x] 1.2 Add core dependencies (`isar`, `isar_flutter_libs`, `camera`, `tflite_flutter`, `google_mlkit_face_detection`) to `pubspec.yaml` and verify `flutter pub get` succeeds.
- [x] 1.3 Design and implement the Isar schema for `Student` (including the float array for face embeddings), `Room`, and `AttendanceRecord`, and verify code generation succeeds (`flutter pub run build_runner build`).
- [x] 1.4 Write unit tests for basic Isar CRUD operations and verify they pass.

## 2. ML & Camera Core (The Isolate Worker)

- [x] 2.1 Set up the Camera controller to output YUV420 image streams without rendering them directly to the UI yet. Verify the stream is active via logging.
- [x] 2.2 Implement a Dart Isolate that receives YUV420 frames and runs `google_mlkit_face_detection` to extract bounding boxes. Verify by logging bounding box coordinates.
- [x] 2.3 Implement the TFLite wrapper using the NNAPI/CoreML delegate and load the MobileFaceNet model. Verify the model loads successfully in the isolate.
- [x] 2.4 Implement the image cropping, alignment, and format conversion (YUV420 to RGB 112x112 bytes) inside the isolate. Verify by successfully passing a cropped face byte array to TFLite and receiving a 1D float array (embedding) back.

## 3. Registration Mode & Object Tracking

- [x] 3.1 Build the Registration UI allowing a warden to select a room and a student, displaying the live camera feed. Verify UI layout matches wireframes.
- [x] 3.2 Implement the multi-angle capture logic: instruct the user to turn their head, capture 3-5 embeddings, and save them to Isar. Verify by retrieving the student record and confirming the embeddings list length.
- [x] 3.3 Implement the fast Object Tracking logic (assigning IDs to bounding boxes across consecutive frames). Verify by logging persistent tracker IDs while moving the camera slightly.

## 4. Attendance Mode & Matching Logic

- [x] 4.1 Build the Attendance UI, displaying the live camera feed and a list of expected students for the selected room. Verify UI layout.
- [x] 4.2 Implement the cosine similarity / euclidean distance calculation in Dart to compare live embeddings against the Isar records for that room. Verify correctness with hardcoded test vectors.
- [x] 4.3 Combine the Tracker and the Matching logic: only run inference on new tracker IDs, and calculate the rolling average of match confidence across 5 frames. Verify by confirming UI indicates a recognized student.

## 5. UX Polish & Offline Syncing

- [x] 5.1 Add color-coded bounding boxes (Yellow = scanning, Green = recognized, Red = unknown) overlaying the camera feed. Verify visual feedback aligns with face locations.
- [x] 5.2 Implement the auto-capture logic (trigger haptic feedback and save attendance when all expected students in the room are green for 1 second). Verify the vibration occurs and the Isar `AttendanceRecord` is created.
- [x] 5.3 Implement the Batch Sync UI and API service to upload pending `AttendanceRecord`s to a mock backend. Verify the network request succeeds and records are marked as synced locally.

## 6. Real Face Recognition

- [x] **Task 18**: Fetch a pre-trained `mobile_face_net.tflite` model (or similar) into the `assets/` directory and configure `pubspec.yaml` to include it.
- [x] **Task 19**: Implement NV21 to RGB image cropping and resizing (112x112) in `FaceRecognitionService`.
- [x] **Task 20**: Wire `tflite_flutter` inference to extract real 192-d embeddings.
- [x] **Task 21**: Update Registration and Attendance to use the real embeddings and match using Cosine Similarity against Isar.
