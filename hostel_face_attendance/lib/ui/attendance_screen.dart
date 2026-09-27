import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:isar/isar.dart';
import 'dart:ui';
import '../services/camera_service.dart';
import '../services/object_tracker.dart';
import '../models/models.dart';
import '../services/ml_isolate_worker.dart';
import 'face_painter.dart';
import 'dart:math' as math;

class AttendanceScreen extends StatefulWidget {
  final Isar isar;
  final Room room;

  const AttendanceScreen({super.key, required this.isar, required this.room});

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
  List<Student> _expectedStudents = [];
  final Map<int, bool> _attendanceStatus = {}; // maps student.id to present boolean
  final Map<int, List<FaceEmbedding>> _studentEmbeddings = {};
  final Map<int, double> _studentMaxSimilarity = {};
  double _zoomLevel = 1.0;

  AttendanceRecord? _existingRecord;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
  }

  Future<void> _loadRoomData() async {
    // Fetch students for this room
    _expectedStudents = await widget.isar.students.filter().room((q) => q.idEqualTo(widget.room.id)).findAll();
    
    // Check if there's already an attendance record for this room today
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59, 999);
    
    _existingRecord = await widget.isar.attendanceRecords
        .filter()
        .room((q) => q.idEqualTo(widget.room.id))
        .timestampBetween(startOfDay, endOfDay)
        .findFirst();
        
    Set<int> presentIds = {};
    if (_existingRecord != null) {
      await _existingRecord!.presentStudents.load();
      presentIds = _existingRecord!.presentStudents.map((s) => s.id).toSet();
    }
    
    for (var student in _expectedStudents) {
      _attendanceStatus[student.id] = presentIds.contains(student.id);
      // Fetch embeddings for student
      final embeddings = await widget.isar.faceEmbeddings.filter().student((q) => q.idEqualTo(student.id)).findAll();
      _studentEmbeddings[student.id] = embeddings;
    }

    await _initCamera();
  }

  void _processFrame(CameraImage image) async {
    final faces = await _mlWorker.processImage(image, _cameraService.sensorOrientation);
    
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
  }

  Future<void> _initCamera() async {
    await _mlWorker.init();
    await _cameraService.initialize();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
      _cameraService.startImageStream(_processFrame);
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
    final presentStudentIds = _attendanceStatus.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();

    final presentStudents = _expectedStudents.where((s) => presentStudentIds.contains(s.id)).toList();
    final absentCount = _expectedStudents.length - presentStudents.length;

    // Show confirmation dialog before saving
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Attendance'),
          content: Text(
            'Present: ${presentStudents.length}\n'
            'Absent: $absentCount\n\n'
            'Are you sure you want to submit this attendance record?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Submit'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    await widget.isar.writeTxn(() async {
      final record = _existingRecord ?? AttendanceRecord();
      record.timestamp = DateTime.now();
      record.isSynced = false;
      
      record.room.value = widget.room;
      await widget.isar.attendanceRecords.put(record);
      await record.room.save();

      if (_existingRecord != null) {
        await record.presentStudents.reset(); // explicitly drops existing links in the DB
      } else {
        record.presentStudents.clear();
      }
      
      record.presentStudents.addAll(presentStudents);
      await record.presentStudents.save();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_existingRecord == null ? 'Attendance Saved for Room ${widget.room.name}' : 'Attendance Updated for Room ${widget.room.name}')),
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Room ${widget.room.name}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.black.withOpacity(0.3),
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        children: [
          // The camera feed and bounding boxes
          SizedBox.expand(
            child: FittedBox(
              fit: BoxFit.cover,
              child: SizedBox(
                width: _cameraService.controller!.value.previewSize?.height ?? 1080,
                height: _cameraService.controller!.value.previewSize?.width ?? 1920,
                child: Stack(
                  children: [
                    SizedBox.expand(
                      child: CameraPreview(_cameraService.controller!),
                    ),
                    if (_faces.isNotEmpty && _imageSize != null)
                      SizedBox.expand(
                        child: CustomPaint(
                          painter: FacePainter(
                            faces: _faces.map((e) => e.face).toList(),
                            imageSize: _imageSize!,
                            isFrontCamera: _cameraService.isFrontCamera,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),

          // Camera Switch Button
          Positioned(
            top: AppBar().preferredSize.height + MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                icon: const Icon(Icons.cameraswitch, color: Colors.white, size: 28),
                onPressed: () async {
                  await _cameraService.switchCamera(_processFrame);
                  setState(() {});
                },
              ),
            ),
          ),
          
          // Modern UI Overlay for Expected Students and Zoom Bar
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Modern Horizontal Zoom Bar
                Container(
                  width: 240,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.zoom_out, color: Colors.white, size: 20),
                        onPressed: () {
                          double newZoom = (_zoomLevel - 0.5).clamp(1.0, 5.0);
                          setState(() => _zoomLevel = newZoom);
                          _cameraService.setZoom(newZoom);
                        },
                      ),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white30,
                            thumbColor: Colors.white,
                          ),
                          child: Slider(
                            value: _zoomLevel,
                            min: 1.0,
                            max: 5.0,
                            onChanged: (val) {
                              setState(() => _zoomLevel = val);
                              _cameraService.setZoom(val);
                            },
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.zoom_in, color: Colors.white, size: 20),
                        onPressed: () {
                          double newZoom = (_zoomLevel + 0.5).clamp(1.0, 5.0);
                          setState(() => _zoomLevel = newZoom);
                          _cameraService.setZoom(newZoom);
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                
                // Bottom Sheet Overlay
                ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.70),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Expected Students', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text(
                            '${_attendanceStatus.values.where((v) => v).length} / ${_expectedStudents.length}',
                            style: TextStyle(fontSize: 16, color: Colors.grey.shade700, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxHeight: MediaQuery.of(context).size.height * 0.20,
                        ),
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_expectedStudents.isEmpty) 
                                Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 20.0),
                                  child: Text('No students registered in this room.', style: TextStyle(color: Colors.grey.shade600)),
                                ),
                              ..._expectedStudents.map((student) {
                                final isPresent = _attendanceStatus[student.id] ?? false;
                                final maxSim = _studentMaxSimilarity[student.id] ?? 0.0;
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4)),
                                    ],
                                  ),
                                  child: ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    leading: Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isPresent ? Colors.green.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        isPresent ? Icons.check_circle_rounded : Icons.pending_rounded,
                                        color: isPresent ? Colors.green : Colors.grey,
                                      ),
                                    ),
                                    title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                    subtitle: Text('${student.studentId} | Score: ${(maxSim * 100).toStringAsFixed(1)}%'),
                                    trailing: Switch(
                                      value: isPresent,
                                      activeColor: Colors.green,
                                      onChanged: (val) {
                                        // Manual override for testing
                                        setState(() {
                                          _attendanceStatus[student.id] = val;
                                        });
                                      },
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: _submitAttendance,
                        icon: const Icon(Icons.check),
                        label: const Text('Complete Room', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                      )
                    ],
                  ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}
}
