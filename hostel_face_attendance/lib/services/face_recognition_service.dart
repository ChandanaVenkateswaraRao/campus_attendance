import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;

  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();
      if (Platform.isAndroid) {
        // XNNPACK is usually default or recommended
      } else if (Platform.isIOS) {
        options.addDelegate(GpuDelegate());
      }
      
      _interpreter = await Interpreter.fromAsset('assets/mobilefacenet.tflite', options: options);
      debugPrint('TFLite model loaded successfully.');
    } catch (e) {
      debugPrint('Failed to load TFLite model: $e');
    }
  }

  /// Converts an NV21 byte array to a cropped, resized 112x112 RGB matrix
  List<List<List<double>>>? preprocessImage(
      Uint8List nv21Bytes, int width, int height, Face face, int sensorOrientation) {
    if (_interpreter == null) {
      debugPrint('Interpreter is null!');
      return null;
    }

    try {
      // 1. Convert NV21 to RGB Image
      final rgbImage = _nv21ToRgb(nv21Bytes, width, height);
      
      // Rotate the raw image based on the sensor orientation
      final rotatedImage = img.copyRotate(rgbImage, angle: sensorOrientation);

      // 2. Crop to bounding box
      final box = face.boundingBox;
      int cropX = max(0, box.left.toInt());
      int cropY = max(0, box.top.toInt());
      int cropW = min(rotatedImage.width - cropX, box.width.toInt());
      int cropH = min(rotatedImage.height - cropY, box.height.toInt());

      final croppedImage = img.copyCrop(
        rotatedImage,
        x: cropX,
        y: cropY,
        width: cropW,
        height: cropH,
      );

      // 3. Resize to 112x112
      final resizedImage = img.copyResize(croppedImage, width: 112, height: 112);

      // 4. Normalize and convert to [1, 112, 112, 3] float array
      // MobileFaceNet requires inputs to be (pixel - 127.5) / 128.0
      List<List<List<double>>> inputMatrix = List.generate(
        112,
        (y) => List.generate(
          112,
          (x) {
            final pixel = resizedImage.getPixel(x, y);
            return [
              (pixel.r - 127.5) / 128.0,
              (pixel.g - 127.5) / 128.0,
              (pixel.b - 127.5) / 128.0,
            ];
          },
        ),
      );

      return inputMatrix;
    } catch (e) {
      debugPrint('Error preprocessing image: $e');
      return null;
    }
  }

  /// Returns a 192 dimensional embedding
  List<double> getEmbedding(List<List<List<double>>> rgbImageArray) {
    if (_interpreter == null) return [];

    var input = [rgbImageArray];
    var output = List.generate(1, (i) => List.filled(192, 0.0));

    _interpreter!.run(input, output);

    return output[0];
  }

  void close() {
    _interpreter?.close();
  }

  // Fast NV21 to RGB using integer approximation
  img.Image _nv21ToRgb(Uint8List yuv420sp, int width, int height) {
    final int frameSize = width * height;
    final rgbImage = img.Image(width: width, height: height);

    for (int j = 0, yp = 0; j < height; j++) {
      int uvp = frameSize + (j >> 1) * width, u = 0, v = 0;
      for (int i = 0; i < width; i++, yp++) {
        int y = (0xff & yuv420sp[yp]) - 16;
        if (y < 0) y = 0;
        if ((i & 1) == 0) {
          v = (0xff & yuv420sp[uvp++]) - 128;
          u = (0xff & yuv420sp[uvp++]) - 128;
        }

        int y1192 = 1192 * y;
        int r = (y1192 + 1634 * v);
        int g = (y1192 - 833 * v - 400 * u);
        int b = (y1192 + 2066 * u);

        if (r < 0) r = 0; else if (r > 262143) r = 262143;
        if (g < 0) g = 0; else if (g > 262143) g = 262143;
        if (b < 0) b = 0; else if (b > 262143) b = 262143;

        rgbImage.setPixelRgba(i, j, (r >> 10) & 0xff, (g >> 10) & 0xff, (b >> 10) & 0xff, 255);
      }
    }
    return rgbImage;
  }
}
