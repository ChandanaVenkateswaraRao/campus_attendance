import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:isar/isar.dart';
import '../services/camera_service.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import '../services/ml_isolate_worker.dart';
import '../models/models.dart';
import 'face_painter.dart';

class RegistrationScreen extends StatefulWidget {
  final Isar isar;
  const RegistrationScreen({super.key, required this.isar});

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
  
  final _nameController = TextEditingController();
  final _regNoController = TextEditingController();
  final _roomController = TextEditingController();

  final List<List<double>> _capturedEmbeddings = [];

  @override
  void initState() {
    super.initState();
    _initCamera();
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
        if (mounted) {
          setState(() {
            _faces = faces;
            _imageSize = Size(image.width.toDouble(), image.height.toDouble());
            _faceDetected = faces.isNotEmpty;
          });
        }
      });
    }
  }

  Future<void> _captureAngle() async {
    if (_nameController.text.isEmpty || _regNoController.text.isEmpty || _roomController.text.isEmpty) {
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
    final roomName = _roomController.text.trim();
    
    await widget.isar.writeTxn(() async {
      // 1. Find or create the room
      var room = await widget.isar.rooms.filter().nameEqualTo(roomName).findFirst();
      if (room == null) {
        room = Room()..name = roomName;
        await widget.isar.rooms.put(room);
      }

      // 2. Create the student
      final student = Student()
        ..name = _nameController.text.trim()
        ..studentId = _regNoController.text.trim();
      
      student.room.value = room;
      await widget.isar.students.put(student);
      await student.room.save();

      // 3. Save their embeddings
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
    _roomController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isInitializing || _cameraService.controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Register Student'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Column(
        children: [
          // Registration Form
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Student Name', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _regNoController,
                        decoration: const InputDecoration(labelText: 'Register Number', border: OutlineInputBorder()),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _roomController,
                        decoration: const InputDecoration(labelText: 'Room Number', border: OutlineInputBorder()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Camera Preview
          Expanded(
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
                        isFrontCamera: true, // front camera by default
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
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Capture multiple angles\n($_capturedAngles/$_requiredAngles completed)',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _captureAngle,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 15),
                          ),
                          child: const Text('Capture Frame', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
