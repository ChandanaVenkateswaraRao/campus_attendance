import 'dart:math';
import 'dart:ui';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class TrackedFace {
  final int id;
  Rect boundingBox;
  int missedFrames = 0;

  TrackedFace(this.id, this.boundingBox);
}

class ObjectTracker {
  final List<TrackedFace> _trackedFaces = [];
  int _nextId = 1;
  
  // Max distance a box can move between frames to be considered the same face
  final double maxDistanceThreshold = 100.0;
  final int maxMissedFrames = 5;

  List<TrackedFace> updateFaces(List<Face> detectedFaces) {
    List<TrackedFace> currentFrameFaces = [];

    for (var face in detectedFaces) {
      TrackedFace? matchedTracker;
      double minDistance = double.infinity;

      // Find the closest existing tracked face
      for (var tracker in _trackedFaces) {
        final distance = _calculateCenterDistance(tracker.boundingBox, face.boundingBox);
        if (distance < minDistance && distance < maxDistanceThreshold) {
          minDistance = distance;
          matchedTracker = tracker;
        }
      }

      if (matchedTracker != null) {
        // Update existing tracker
        matchedTracker.boundingBox = face.boundingBox;
        matchedTracker.missedFrames = 0;
        currentFrameFaces.add(matchedTracker);
        _trackedFaces.remove(matchedTracker);
      } else {
        // New face entering the frame
        final newTracker = TrackedFace(
          face.trackingId ?? _nextId++, 
          face.boundingBox
        );
        currentFrameFaces.add(newTracker);
      }
    }

    // Keep around trackers that weren't found in this frame, up to a limit
    for (var tracker in _trackedFaces) {
      tracker.missedFrames++;
      if (tracker.missedFrames < maxMissedFrames) {
        currentFrameFaces.add(tracker);
      }
    }

    _trackedFaces.clear();
    _trackedFaces.addAll(currentFrameFaces);

    return _trackedFaces;
  }

  double _calculateCenterDistance(Rect rect1, Rect rect2) {
    final center1 = rect1.center;
    final center2 = rect2.center;
    return sqrt(pow(center1.dx - center2.dx, 2) + pow(center1.dy - center2.dy, 2));
  }
}
