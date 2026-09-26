# Design

## Context
See `proposal.md` for the motivation and product context. The core technical constraints are that the app must operate without internet access during attendance rounds and must process face recognition on typical mid-range mobile hardware without lag or overheating.

## Goals / Non-Goals

**Goals:**
- Provide near-instantaneous face matching (sub-second) for a room of up to 5 students.
- Eliminate network dependency for the core attendance workflow.
- Ensure the UI remains responsive and fluid during the camera feed processing.

**Non-Goals:**
- Active liveness detection (anti-spoofing). The physical presence of the warden acts as the security layer.
- Cloud-based face recognition or centralized matching (privacy and connectivity concerns).

## Decisions

### 1. Room-Scoped Matching vs. Global Matching
- **Rationale**: Searching the entire database (e.g., 500 students) for a match on a mobile device is slow and leads to false positives (requiring high confidence thresholds). By constraining the search space to the 4-5 students assigned to the selected room, we turn a 1:N search into a much smaller 1:K search.
- **Alternatives Considered**: Using a cloud API (rejected due to offline requirement).

### 2. Live Face Tracking vs. Continuous Recognition
- **Rationale**: Running the MobileFaceNet model (inference) on every single frame for every detected face would consume excessive CPU/NPU, causing UI stutter and device heating. Instead, we use `google_mlkit_face_detection` to detect and track faces (with assigning IDs) on every frame. We only run the heavy recognition model once or twice when a new face enters the frame, and then assume the identity persists as long as the tracker maintains the bounding box.
- **Alternatives Considered**: Running inference at 10fps instead of 30fps (still too heavy for multiple faces).

### 3. Asynchronous Inference with Dart Isolates
- **Rationale**: The heavy lifting of converting image frames (YUV420 to RGB), cropping, and running TFLite inference must not block the main Flutter UI thread.
- **Alternatives Considered**: Using platform channels for all image processing (abandoned because modern `tflite_flutter` supports direct FFI, but we still need isolates to prevent blocking).

### 4. Hardware Acceleration (NNAPI / CoreML)
- **Rationale**: TensorFlow Lite must be explicitly configured to use the device's Neural Processing Unit (via NNAPI Delegate on Android and CoreML Delegate on iOS) rather than falling back to the CPU.

## Risks / Trade-offs

- **Risk: Lighting Conditions**
  - **Trade-off**: The ML Kit bounding box and alignment depend heavily on lighting.
  - **Mitigation**: Implement UI feedback (e.g., yellow bounding box) to indicate when a face is too dark or blurry, prompting the warden to adjust the angle or lighting.
- **Risk: Heavy Glue Code**
  - **Trade-off**: Managing raw camera streams and transforming bytes for TFLite is historically complex in Flutter.
  - **Mitigation**: Encapsulate the image stream conversion and inference entirely within a dedicated background isolate to keep the widget tree clean.
