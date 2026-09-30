import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:isar/isar.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../services/sync_service.dart';
import '../services/camera_service.dart';
import '../services/ml_isolate_worker.dart';
import '../models/models.dart';
import 'face_painter.dart';
import 'widgets/camera_zoom_control.dart';

class FaceCaptureScreen extends StatefulWidget {
  final Isar isar;
  final Student student;

  const FaceCaptureScreen({super.key, required this.isar, required this.student});

  @override
  State<FaceCaptureScreen> createState() => _FaceCaptureScreenState();
}

class _FaceCaptureScreenState extends State<FaceCaptureScreen> {
  final CameraService _cameraService = CameraService();
  final MlWorker _mlWorker = MlWorker();
  
  bool _isInitializing = true;
  bool _faceDetected = false;
  List<FaceWithEmbedding> _faces = [];
  Size? _imageSize;

  int _capturedAngles = 0;
  final int _requiredAngles = 3;
  double _zoomLevel = 1.0;

  final List<List<double>> _capturedEmbeddings = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  void _processFrame(CameraImage image) async {
    final faces = await _mlWorker.processImage(image, _cameraService.sensorOrientation);
    if (mounted) {
      setState(() {
        _faces = faces;
        _imageSize = Size(image.width.toDouble(), image.height.toDouble());
        _faceDetected = faces.isNotEmpty;
      });
    }
  }

  Future<void> _initCamera() async {
    await _mlWorker.init();
    await _cameraService.initialize();
    _cameraService.startImageStream(_processFrame);
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  void _captureAngle() async {
    if (!_faceDetected || _faces.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No face detected. Please position the student in the frame.')),
      );
      return;
    }
    
    // Check if we already have this embedding (optional duplicate check could go here)
    // For now, just add it.
    if (_faces.first.embedding != null) {
      _capturedEmbeddings.add(_faces.first.embedding!);
    }
    
    setState(() {
      _capturedAngles++;
    });

    if (_capturedAngles >= _requiredAngles) {
      // Done capturing
      _cameraService.stopImageStream();
      
      // Save
      final success = await _saveStudentToDatabase();
      if (mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration Complete! Data synced to server.'), backgroundColor: Colors.green),
          );
          // Pop back to Student List
          Navigator.pop(context); // Pop FaceCaptureScreen
          Navigator.pop(context); // Pop RegistrationScreen
        }
      }
    }
  }

  Future<bool> _saveStudentToDatabase() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No internet connection. Cannot register offline.'), backgroundColor: Colors.red),
        );
      }
      return false;
    }

    if (mounted) {
      showDialog(context: context, barrierDismissible: false, builder: (_) => const Center(child: CircularProgressIndicator()));
    }

    await widget.isar.writeTxn(() async {
      // 1. Create the student
      await widget.isar.students.put(widget.student);
      await widget.student.room.save();

      // 2. Save their embeddings
      for (var vec in _capturedEmbeddings) {
        final embedding = FaceEmbedding()..vector = vec;
        embedding.student.value = widget.student;
        await widget.isar.faceEmbeddings.put(embedding);
        await embedding.student.save();
      }
    });

    try {
      await SyncService(widget.isar).backupToCloud();
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
      }
      return true;
    } catch (e) {
      // Rollback local changes
      await widget.isar.writeTxn(() async {
        await widget.isar.faceEmbeddings.filter().student((q) => q.idEqualTo(widget.student.id)).deleteAll();
        await widget.isar.students.delete(widget.student.id);
      });
      if (mounted) {
        Navigator.pop(context); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error during sync. Registration aborted.'), backgroundColor: Colors.red),
        );
      }
      return false;
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
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text('Capture Face: ${widget.student.name}'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera Preview
          CameraPreview(
            _cameraService.controller!,
            child: _imageSize == null ? null : CustomPaint(
              painter: FacePainter(
                faces: _faces.map((e) => e.face).toList(),
                imageSize: _imageSize!,
                isFrontCamera: _cameraService.isFrontCamera,
              ),
            ),
          ),
          
          // Modern Horizontal Zoom Bar
          Positioned(
            bottom: 160,
            left: 20,
            right: 20,
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
          
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Capture multiple angles\n($_capturedAngles/$_requiredAngles completed)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _captureAngle,
                      icon: const Icon(Icons.camera),
                      label: const Text('Capture Frame'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
