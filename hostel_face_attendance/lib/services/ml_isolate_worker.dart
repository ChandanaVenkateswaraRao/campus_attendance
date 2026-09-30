import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'dart:ui';
import 'face_recognition_service.dart';

class FaceWithEmbedding {
  final Face face;
  final List<double>? embedding;
  FaceWithEmbedding(this.face, this.embedding);
}

class MlWorker {
  late final FaceDetector _faceDetector;
  final FaceRecognitionService _recognitionService = FaceRecognitionService();
  bool _isProcessing = false;
  bool _isDisposed = false;

  MlWorker() {
    _faceDetector = FaceDetector(
      options: FaceDetectorOptions(
        enableContours: false,
        enableLandmarks: true, 
        enableTracking: true,  
        performanceMode: FaceDetectorMode.fast,
      ),
    );
  }

  Future<void> init() async {
    await _recognitionService.loadModel();
  }

  Future<List<FaceWithEmbedding>> processImage(CameraImage image, int sensorOrientation) async {
    if (_isProcessing || _isDisposed) return [];
    _isProcessing = true;

    try {
      final width = image.width;
      final height = image.height;

      Uint8List bytes;
      InputImageFormat inputImageFormat;

      if (image.format.group == ImageFormatGroup.yuv420) {
        final int nv21Size = (width * height * 1.5).toInt();
        bytes = Uint8List(nv21Size);
        
        final yBuffer = image.planes[0].bytes;
        final uBuffer = image.planes[1].bytes;
        final vBuffer = image.planes[2].bytes;

        int yIndex = 0;
        final int yRowStride = image.planes[0].bytesPerRow;
        for (int y = 0; y < height; y++) {
          int rowStart = y * yRowStride;
          bytes.setRange(yIndex, yIndex + width, yBuffer.sublist(rowStart, rowStart + width));
          yIndex += width;
        }

        int uvIndex = width * height;
        final int uvRowStride = image.planes[1].bytesPerRow;
        final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

        for (int y = 0; y < height ~/ 2; y++) {
          for (int x = 0; x < width ~/ 2; x++) {
            int uvOffset = y * uvRowStride + x * uvPixelStride;
            bytes[uvIndex++] = vBuffer[uvOffset];
            bytes[uvIndex++] = uBuffer[uvOffset];
          }
        }
        inputImageFormat = InputImageFormat.nv21;
      } else {
        final WriteBuffer allBytes = WriteBuffer();
        for (final Plane plane in image.planes) {
          allBytes.putUint8List(plane.bytes);
        }
        bytes = allBytes.done().buffer.asUint8List();
        inputImageFormat = InputImageFormat.bgra8888;
      }
      
      final imageSize = Size(width.toDouble(), height.toDouble());
      final imageRotation = InputImageRotationValue.fromRawValue(sensorOrientation) ?? InputImageRotation.rotation90deg;

      final metadata = InputImageMetadata(
        size: imageSize,
        rotation: imageRotation,
        format: inputImageFormat,
        bytesPerRow: width,
      );

      final inputImage = InputImage.fromBytes(bytes: bytes, metadata: metadata);

      final faces = await _faceDetector.processImage(inputImage);
      
      List<FaceWithEmbedding> results = [];
      for (var face in faces) {
        if (_isDisposed) break;
        // Crop and run TFLite
        final rgbMatrix = _recognitionService.preprocessImage(bytes, width, height, face, sensorOrientation);
        List<double>? embedding;
        if (rgbMatrix != null) {
          embedding = _recognitionService.getEmbedding(rgbMatrix);
        }
        results.add(FaceWithEmbedding(face, embedding));
      }

      _isProcessing = false;
      return results;
    } catch (e) {
      debugPrint('Face detection failed: $e');
      _isProcessing = false;
      return [];
    }
  }

  void stop() {
    _isDisposed = true;
    _faceDetector.close();
    _recognitionService.close();
  }
}
