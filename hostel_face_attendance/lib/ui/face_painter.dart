import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Size imageSize;
  final bool isFrontCamera;

  FacePainter({
    required this.faces,
    required this.imageSize,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.yellow;

    for (final Face face in faces) {
      final rect = face.boundingBox;
      
      // Scale coordinates from image size to screen size
      final double scaleX = size.width / imageSize.height; // Note: w/h swapped due to rotation
      final double scaleY = size.height / imageSize.width;

      double left = rect.left * scaleX;
      double top = rect.top * scaleY;
      double right = rect.right * scaleX;
      double bottom = rect.bottom * scaleY;

      // Handle mirroring for front camera
      if (isFrontCamera) {
        final temp = left;
        left = size.width - right;
        right = size.width - temp;
      }

      canvas.drawRect(Rect.fromLTRB(left, top, right, bottom), paint);
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces || oldDelegate.imageSize != imageSize;
  }
}
