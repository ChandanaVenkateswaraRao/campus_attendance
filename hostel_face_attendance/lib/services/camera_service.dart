import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  
  CameraController? get controller => _controller;

  List<CameraDescription> _cameras = [];
  int _cameraIndex = 0;

  Future<void> initialize() async {
    _cameras = await availableCameras();
    _cameraIndex = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
    if (_cameraIndex == -1 && _cameras.isNotEmpty) _cameraIndex = 0;
    
    await _initCamera(_cameras[_cameraIndex]);
  }

  Future<void> _initCamera(CameraDescription camera) async {
    _controller = CameraController(
      camera,
      ResolutionPreset.high,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );
    await _controller!.initialize();
  }

  bool get isFrontCamera => _cameras.isNotEmpty && _cameras[_cameraIndex].lensDirection == CameraLensDirection.front;
  int get sensorOrientation => _cameras.isNotEmpty ? _cameras[_cameraIndex].sensorOrientation : 90;

  Future<void> switchCamera(Function(CameraImage) onImage) async {
    if (_cameras.length < 2) return;
    
    final wasStreaming = _controller?.value.isStreamingImages ?? false;
    await _controller?.dispose();
    
    _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    await _initCamera(_cameras[_cameraIndex]);
    
    if (wasStreaming) {
      startImageStream(onImage);
    }
  }

  Future<void> setZoom(double zoom) async {
    if (_controller != null) {
      try {
        final maxZoom = await _controller!.getMaxZoomLevel();
        final minZoom = await _controller!.getMinZoomLevel();
        final clamped = zoom.clamp(minZoom, maxZoom);
        await _controller!.setZoomLevel(clamped);
      } catch (e) {
        debugPrint('Error setting zoom: $e');
      }
    }
  }

  void startImageStream(Function(CameraImage) onImage) {
    if (_controller != null && _controller!.value.isInitialized) {
      if (!_controller!.value.isStreamingImages) {
        _controller!.startImageStream((CameraImage image) {
          // Log frame metadata to verify the stream is active without rendering
          debugPrint('Received frame: ${image.width}x${image.height} Format: ${image.format.group}');
          onImage(image);
        });
      }
    }
  }

  void stopImageStream() {
    if (_controller != null && _controller!.value.isStreamingImages) {
      _controller!.stopImageStream();
    }
  }

  void dispose() {
    _controller?.dispose();
  }
}
