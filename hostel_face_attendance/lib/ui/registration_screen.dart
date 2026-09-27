import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:isar/isar.dart';
import '../services/camera_service.dart';
import '../services/ml_isolate_worker.dart';
import '../models/models.dart';
import 'face_painter.dart';

class RegistrationScreen extends StatefulWidget {
  final Isar isar;
  final Room room;
  const RegistrationScreen({super.key, required this.isar, required this.room});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final CameraService _cameraService = CameraService();
  final MlWorker _mlWorker = MlWorker();
  
  bool _isInitializing = true;
  bool _faceDetected = false;
  List<FaceWithEmbedding> _faces = [];
  Size? _imageSize;

  int _capturedAngles = 0;
  final int _requiredAngles = 3;
  double _zoomLevel = 1.0;
  
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();

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
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
      _cameraService.startImageStream(_processFrame);
    }
  }

  Future<void> _captureAngle() async {
    if (_nameController.text.isEmpty || _regNoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all details first!')),
      );
      return;
    }

    if (_faces.isEmpty || _faces.first.embedding == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No face detected properly yet!')),
      );
      return;
    }

    if (_capturedAngles < _requiredAngles) {
      setState(() {
        _capturedAngles++;
      });
      
      _capturedEmbeddings.add(_faces.first.embedding!);

      if (_capturedAngles == _requiredAngles) {
        await _saveStudentToDatabase();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration Complete!')),
          );
          Navigator.pop(context);
        }
      }
    }
  }

  Future<void> _saveStudentToDatabase() async {
    await widget.isar.writeTxn(() async {
      // 1. Create the student
      final student = Student()
        ..name = _nameController.text.trim()
        ..studentId = _regNoController.text.trim();
      
      student.room.value = widget.room;
      await widget.isar.students.put(student);
      await student.room.save();

      // 2. Save their embeddings
      for (var vec in _capturedEmbeddings) {
        final embedding = FaceEmbedding()..vector = vec;
        embedding.student.value = student;
        await widget.isar.faceEmbeddings.put(embedding);
        await embedding.student.save();
      }
    });
  }

  @override
  void dispose() {
    _mlWorker.stop();
    _cameraService.stopImageStream();
    _cameraService.dispose();
    _nameController.dispose();
    _regNoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _cameraService.controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('Register Student', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Modern Registration Form
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.meeting_room, color: Colors.blueAccent),
                        const SizedBox(width: 8),
                        Text('Room: ${widget.room.name}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(
                        labelText: 'Student Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _regNoController,
                      decoration: InputDecoration(
                        labelText: 'Register Number',
                        prefixIcon: const Icon(Icons.badge_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            // Camera Preview
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Stack(
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
                        top: 16,
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
                      
                      // Modern Horizontal Zoom Bar
                      Positioned(
                        bottom: 160, // Just above the capture button overlay
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
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
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
