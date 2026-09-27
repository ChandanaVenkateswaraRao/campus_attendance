# Proposal

## Why

Hostel wardens currently spend a significant amount of time manually taking attendance room by room. This process is tedious and prone to errors. We need an automated, fast, and highly accurate solution. Since hostel corridors often lack reliable internet connectivity, this solution must function entirely offline during the attendance rounds, syncing data only when a reliable connection is available.

## What Changes

- A new Flutter mobile application for hostel wardens.
- Implementation of a local, on-device database (Isar/SQLite) to store student profiles, room mappings, face embeddings, and pending attendance records.
- Integration of Google ML Kit for on-device real-time face detection (bounding boxes and face alignment).
- Integration of TensorFlow Lite (with NNAPI/CoreML hardware acceleration) and a lightweight model (e.g., MobileFaceNet) to extract and compare face embeddings.
- Development of a "Registration Mode" for day-one baseline face capture (multi-angle registration).
- Development of an "Attendance Mode" featuring room-scoped strict matching, live frame tracking (to avoid running heavy recognition on every frame), and auto-capture with haptic feedback when a room is complete.
- A batch sync mechanism to upload locally queued attendance data to the backend.

## Capabilities

### New Capabilities
- `attendance/offline-face-recognition`: Face registration and room-scoped attendance scanning using on-device ML models, with offline caching and batch syncing.

### Modified Capabilities
None

## Impact

- **Mobile App:** Brand new Flutter application for iOS and Android.
- **Backend API:** Requires API endpoints to receive batch-synced attendance records and distribute initial student/room mapping data.
- **Dependencies:** `google_mlkit_face_detection`, `tflite_flutter`, `camera`, `isar` (or `sqflite`).
