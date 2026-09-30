import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FacePainter extends CustomPainter {
  final List<Face> faces;
  final Map<Rect, String> recognizedNames;
  final Size imageSize;
  final bool isFrontCamera;

  FacePainter({
    required this.faces,
    this.recognizedNames = const {},
    required this.imageSize,
    this.isFrontCamera = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (final Face face in faces) {
      final rect = face.boundingBox;
      final recognizedName = recognizedNames[rect];
      
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..color = recognizedName != null ? Colors.greenAccent : Colors.amber;

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

      final scaledRect = Rect.fromLTRB(left, top, right, bottom);
      canvas.drawRect(scaledRect, paint);

      if (recognizedName != null) {
        final textStyle = const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.green,
        );
        final textSpan = TextSpan(
          text: ' $recognizedName ',
          style: textStyle,
        );
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        final textX = left + (scaledRect.width - textPainter.width) / 2;
        final textY = top - textPainter.height - 4;
        
        // Draw background container for text
        final bgPaint = Paint()..color = Colors.green;
        final bgRect = Rect.fromLTWH(textX, textY, textPainter.width, textPainter.height);
        canvas.drawRRect(RRect.fromRectAndRadius(bgRect, const Radius.circular(4)), bgPaint);
        
        textPainter.paint(canvas, Offset(textX, textY));
      }
    }
  }

  @override
  bool shouldRepaint(FacePainter oldDelegate) {
    return oldDelegate.faces != faces || oldDelegate.imageSize != imageSize;
  }
}
