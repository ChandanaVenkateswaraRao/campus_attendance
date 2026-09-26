import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';

class CameraService {
  CameraController? _controller;
  
  CameraController? get controller => _controller;

  Future<void> initialize() async {
    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    _controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    await _controller!.initialize();
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
