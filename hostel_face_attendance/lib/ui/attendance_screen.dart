import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:isar/isar.dart';
import 'dart:ui';
import '../services/camera_service.dart';
import '../services/object_tracker.dart';
import '../models/models.dart';
import '../services/ml_isolate_worker.dart';
import '../services/sync_service.dart';
import 'face_painter.dart';
import 'widgets/camera_zoom_control.dart';
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
  Map<Rect, String> _recognizedNames = {};
  Size? _imageSize;
  List<Student> _expectedStudents = [];
  final Map<int, bool> _attendanceStatus =
      {}; // maps student.id to present boolean
  final Map<int, List<FaceEmbedding>> _studentEmbeddings = {};
  final Map<int, double> _studentMaxSimilarity = {};
  double _zoomLevel = 1.0;
  double _sheetExtent = 0.35;

  AttendanceRecord? _existingRecord;

  @override
  void initState() {
    super.initState();
    _loadRoomData();
  }

  Future<void> _loadRoomData() async {
    // Fetch students for this room
    _expectedStudents = await widget.isar.students
        .filter()
        .room((q) => q.idEqualTo(widget.room.id))
        .findAll();

    // Check if there's already an attendance record for this room today
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = DateTime(
      today.year,
      today.month,
      today.day,
      23,
      59,
      59,
      999,
    );

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
      final embeddings = await widget.isar.faceEmbeddings
          .filter()
          .student((q) => q.idEqualTo(student.id))
          .findAll();
      _studentEmbeddings[student.id] = embeddings;
    }

    await _initCamera();
  }

  void _processFrame(CameraImage image) async {
    final faces = await _mlWorker.processImage(
      image,
      _cameraService.sensorOrientation,
    );

    Map<Rect, String> newRecognizedNames = {};

    if (faces.isNotEmpty && _expectedStudents.isNotEmpty) {
      for (var face in faces) {
        if (face.embedding != null && face.embedding!.isNotEmpty) {
          // Find matching student
          for (var student in _expectedStudents) {
            final savedEmbeddings = _studentEmbeddings[student.id] ?? [];
            for (var saved in savedEmbeddings) {
              if (saved.vector.length != face.embedding!.length) continue;

              double similarity = _cosineSimilarity(
                face.embedding!,
                saved.vector,
              );

              if (similarity > 0.80) {
                // Threshold
                newRecognizedNames[face.face.boundingBox] = student.name;
              }

              // Update UI max similarity
              if (mounted) {
                setState(() {
                  final currentMax = _studentMaxSimilarity[student.id] ?? 0.0;
                  if (similarity > currentMax) {
                    _studentMaxSimilarity[student.id] = similarity;
                  }
                  if (similarity > 0.80) {
                    // Threshold
                    if (_attendanceStatus[student.id] != true) {
                      _attendanceStatus[student.id] = true;
                    }
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
          _recognizedNames = newRecognizedNames;
          _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _faces = [];
          _recognizedNames = {};
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

    final presentStudents = _expectedStudents
        .where((s) => presentStudentIds.contains(s.id))
        .toList();
    final absentStudents = _expectedStudents
        .where((s) => !presentStudentIds.contains(s.id))
        .toList();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    List<dynamic> allLeaves = [];
    try {
      allLeaves = await SyncService(widget.isar).fetchLeaves();
    } catch (_) {}

    if (mounted) {
      Navigator.pop(context);
    }

    final now = DateTime.now();
    final todayStr =
        '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final yesterday = now.subtract(const Duration(days: 1));
    final yesterdayStr =
        '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';

    List<Map<String, dynamic>> absentDetails = [];
    for (var student in absentStudents) {
      final studentLeaves = allLeaves
          .where(
            (l) =>
                l['status'] == 'APPROVED' &&
                l['register_number'] == student.studentId,
          )
          .toList();

      String status = 'Unauthorized leave';
      Color color = Colors.red;

      for (var l in studentLeaves) {
        final fromDate = l['from_date']?.toString().split('T').first;
        final toDate = l['to_date']?.toString().split('T').first;
        if (fromDate != null && toDate != null) {
          if (todayStr.compareTo(fromDate) >= 0 &&
              todayStr.compareTo(toDate) <= 0) {
            status = 'Absent, on leave';
            color = Colors.orange;
            break;
          } else if (yesterdayStr.compareTo(fromDate) >= 0 &&
              yesterdayStr.compareTo(toDate) <= 0) {
            status = 'Absent, leave expired yesterday';
            color = Colors.redAccent;
          }
        }
      }
      absentDetails.add({'student': student, 'status': status, 'color': color});
    }

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Confirm Attendance'),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Present: ${presentStudents.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                Text(
                  'Absent: ${absentStudents.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(height: 16),
                if (absentStudents.isNotEmpty) ...[
                  const Text(
                    'Absent Students:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Divider(),
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: absentDetails.length,
                      itemBuilder: (context, index) {
                        final detail = absentDetails[index];
                        final Student s = detail['student'];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${s.name} (${s.studentId})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                detail['status'],
                                style: TextStyle(
                                  color: detail['color'],
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                const Text('Submit this attendance record?'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
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
        await record.presentStudents
            .reset(); // explicitly drops existing links in the DB
      } else {
        record.presentStudents.clear();
      }

      record.presentStudents.addAll(presentStudents);
      await record.presentStudents.save();
    });

    bool syncSuccess = false;
    try {
      await SyncService(widget.isar).syncPendingRecords();
      syncSuccess = true;
    } catch (_) {}

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            syncSuccess
                ? 'Attendance Saved & Synced for Room ${widget.room.name}'
                : 'Attendance Saved offline for Room ${widget.room.name}',
          ),
        ),
      );
      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    _cameraService.stopImageStream();
    _mlWorker.stop();
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
        title: Text(
          'Room ${widget.room.name}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
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
                width:
                    _cameraService.controller!.value.previewSize?.height ??
                    1080,
                height:
                    _cameraService.controller!.value.previewSize?.width ?? 1920,
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
                            recognizedNames: _recognizedNames,
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

          // Camera Switch and Flashlight Buttons
          Positioned(
            top:
                AppBar().preferredSize.height +
                MediaQuery.of(context).padding.top +
                10,
            right: 16,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.cameraswitch,
                      color: Colors.white,
                      size: 28,
                    ),
                    onPressed: () async {
                      await _cameraService.switchCamera(_processFrame);
                      setState(() {});
                    },
                  ),
                ),
              ],
            ),
          ),

          // Zoom Bar above the bottom sheet
          Positioned(
            bottom: MediaQuery.of(context).size.height * _sheetExtent + 16,
            left: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: CameraZoomControl(
                currentZoom: _zoomLevel,
                minZoom: 1.0,
                maxZoom: 5.0,
                onZoomChanged: (newZoom) {
                  setState(() => _zoomLevel = newZoom);
                  _cameraService.setZoom(newZoom);
                },
              ),
            ),
          ),

          // Draggable Bottom Sheet Overlay
          NotificationListener<DraggableScrollableNotification>(
            onNotification: (notification) {
              setState(() {
                _sheetExtent = notification.extent;
              });
              return true;
            },
            child: DraggableScrollableSheet(
              initialChildSize: 0.35,
              minChildSize: 0.15,
              maxChildSize: 0.8,
              builder: (context, scrollController) {
                return ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(32),
                  ),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.70),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(32),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: Colors.white.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                      ),
                      child: CustomScrollView(
                        controller: scrollController,
                        slivers: [
                          SliverToBoxAdapter(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Drag handle
                                Center(
                                  child: Container(
                                    margin: const EdgeInsets.only(
                                      top: 12,
                                      bottom: 8,
                                    ),
                                    height: 5,
                                    width: 40,
                                    decoration: BoxDecoration(
                                      color: Colors.grey.withOpacity(0.5),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 8,
                                  ),
                                  child: Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Expected Students',
                                        style: TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        '${_attendanceStatus.values.where((v) => v).length} / ${_expectedStudents.length}',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.grey.shade700,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Divider(),
                              ],
                            ),
                          ),
                          if (_expectedStudents.isEmpty)
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20.0,
                                ),
                                child: Center(
                                  child: Text(
                                    'No students registered in this room.',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                              ),
                            )
                          else
                            SliverPadding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildBuilderDelegate((
                                  context,
                                  index,
                                ) {
                                  final student = _expectedStudents[index];
                                  final isPresent =
                                      _attendanceStatus[student.id] ?? false;
                                  final maxSim =
                                      _studentMaxSimilarity[student.id] ?? 0.0;
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 10,
                                          offset: const Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: ListTile(
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 8,
                                          ),
                                      leading: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isPresent
                                              ? Colors.green.withOpacity(0.1)
                                              : Colors.grey.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          isPresent
                                              ? Icons.check_circle_rounded
                                              : Icons.pending_rounded,
                                          color: isPresent
                                              ? Colors.green
                                              : Colors.grey,
                                        ),
                                      ),
                                      title: Text(
                                        student.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      subtitle: Text(
                                        '${student.studentId} | Score: ${(maxSim * 100).toStringAsFixed(1)}%',
                                      ),
                                      trailing: Switch(
                                        value: isPresent,
                                        activeColor: Colors.green,
                                        onChanged: (val) {
                                          setState(() {
                                            _attendanceStatus[student.id] = val;
                                          });
                                        },
                                      ),
                                    ),
                                  );
                                }, childCount: _expectedStudents.length),
                              ),
                            ),
                          SliverToBoxAdapter(
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                              child: ElevatedButton.icon(
                                onPressed: _submitAttendance,
                                icon: const Icon(Icons.check),
                                label: const Text(
                                  'Complete Room',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
