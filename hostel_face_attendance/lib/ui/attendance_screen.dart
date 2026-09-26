import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:isar/isar.dart';
import '../services/camera_service.dart';
import '../services/object_tracker.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../models/models.dart';
import '../services/ml_isolate_worker.dart';
import 'face_painter.dart';
import 'dart:math' as math;

class AttendanceScreen extends StatefulWidget {
  final Isar isar;
  final String roomName;

  const AttendanceScreen({super.key, required this.isar, required this.roomName});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  final CameraService _cameraService = CameraService();
  final ObjectTracker _tracker = ObjectTracker();
  final MlWorker _mlWorker = MlWorker();
  
  bool _isInitializing = true;
  List<FaceWithEmbedding> _faces = [];
  Size? _imageSize;
  Room? _room;
  List<Student> _expectedStudents = [];
  final Map<int, bool> _attendanceStatus = {}; // maps student.id to present boolean
  final Map<int, List<FaceEmbedding>> _studentEmbeddings = {};
  final Map<int, double> _studentMaxSimilarity = {};

  @override
  void initState() {
    super.initState();
    _loadRoomData();
  }

  Future<void> _loadRoomData() async {
    // Fetch room
    _room = await widget.isar.rooms.filter().nameEqualTo(widget.roomName).findFirst();
    
    if (_room != null) {
      // Fetch students for this room
      _expectedStudents = await widget.isar.students.filter().room((q) => q.idEqualTo(_room!.id)).findAll();
      
      for (var student in _expectedStudents) {
        _attendanceStatus[student.id] = false;
        // Fetch embeddings for student
        final embeddings = await widget.isar.faceEmbeddings.filter().student((q) => q.idEqualTo(student.id)).findAll();
        _studentEmbeddings[student.id] = embeddings;
      }
    }

    await _initCamera();
  }

  Future<void> _initCamera() async {
    await _mlWorker.init();
    await _cameraService.initialize();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
      _cameraService.startImageStream((image) async {
        final faces = await _mlWorker.processImage(image);
        
        if (faces.isNotEmpty && _expectedStudents.isNotEmpty) {
           for (var face in faces) {
             if (face.embedding != null && face.embedding!.isNotEmpty) {
                // Find matching student
                for (var student in _expectedStudents) {
                  final savedEmbeddings = _studentEmbeddings[student.id] ?? [];
                  for (var saved in savedEmbeddings) {
                    if (saved.vector.length != face.embedding!.length) continue;
                    
                    double similarity = _cosineSimilarity(face.embedding!, saved.vector);
                    
                    // Update UI max similarity
                    if (mounted) {
                      setState(() {
                         final currentMax = _studentMaxSimilarity[student.id] ?? 0.0;
                         if (similarity > currentMax) {
                            _studentMaxSimilarity[student.id] = similarity;
                         }
                         if (similarity > 0.80) { // Threshold
                            _attendanceStatus[student.id] = true;
                         }
                      });
                    }
                  }
                }
             }
           }
           
           if (mounted) {
             setState(() {
                _faces = faces;
                _imageSize = Size(image.width.toDouble(), image.height.toDouble());
             });
           }
        } else {
           if (mounted) {
             setState(() {
                _faces = [];
             });
           }
        }
      });
    }
  }

  double _cosineSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length) return 0.0;
    double dotProduct = 0.0, normA = 0.0, normB = 0.0;
    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      normA += v1[i] * v1[i];
      normB += v2[i] * v2[i];
    }
    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
  }

  Future<void> _submitAttendance() async {
    if (_room == null) return;
    
    final presentStudentIds = _attendanceStatus.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final presentStudents = _expectedStudents.where((s) => presentStudentIds.contains(s.id)).toList();

    await widget.isar.writeTxn(() async {
      final record = AttendanceRecord()
        ..timestamp = DateTime.now()
        ..isSynced = false;
      
      record.room.value = _room;
      await widget.isar.attendanceRecords.put(record);
      await record.room.save();

      record.presentStudents.addAll(presentStudents);
      await record.presentStudents.save();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Attendance Saved for Room ${widget.roomName}')),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _mlWorker.stop();
    _cameraService.stopImageStream();
    _cameraService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _cameraService.controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_room == null) {
      return Scaffold(
        appBar: AppBar(title: Text('Room ${widget.roomName}')),
        body: Center(child: Text('Room ${widget.roomName} not found. Please register students first.')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Room ${widget.roomName} Attendance'),
        backgroundColor: Colors.green,
      ),
      body: Stack(
        children: [
          // The camera feed
          SizedBox.expand(
            child: CameraPreview(_cameraService.controller!),
          ),
          if (_faces.isNotEmpty && _imageSize != null)
            SizedBox.expand(
              child: CustomPaint(
                painter: FacePainter(
                  faces: _faces.map((e) => e.face).toList(),
                  imageSize: _imageSize!,
                  isFrontCamera: true, // front camera by default
                ),
              ),
            ),
          
          // UI Overlay for Expected Students
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Expected Students', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  if (_expectedStudents.isEmpty) 
                    const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Text('No students registered in this room.'),
                    ),
                  ..._expectedStudents.map((student) {
                    final isPresent = _attendanceStatus[student.id] ?? false;
                    final maxSim = _studentMaxSimilarity[student.id] ?? 0.0;
                    return ListTile(
                      leading: Icon(
                        isPresent ? Icons.check_circle : Icons.pending,
                        color: isPresent ? Colors.green : Colors.grey,
                      ),
                      title: Text(student.name),
                      subtitle: Text('${student.studentId} | Score: ${(maxSim * 100).toStringAsFixed(1)}%'),
                      trailing: IconButton(
                        icon: Icon(isPresent ? Icons.toggle_on : Icons.toggle_off),
                        color: isPresent ? Colors.green : Colors.grey,
                        onPressed: () {
                          // Manual override for testing
                          setState(() {
                            _attendanceStatus[student.id] = !isPresent;
                          });
                        },
                      ),
                    );
                  }),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitAttendance,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                      child: const Text('Complete Room', style: TextStyle(color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
