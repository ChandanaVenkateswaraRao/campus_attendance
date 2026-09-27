import 'package:flutter/material.dart';

class CameraZoomControl extends StatelessWidget {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;
  final ValueChanged<double> onZoomChanged;

  const CameraZoomControl({
    super.key,
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
    required this.onZoomChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '${currentZoom.toStringAsFixed(1)} x',
          style: const TextStyle(
            color: Colors.amber,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onPanUpdate: (details) {
            // Dragging left (negative dx) means moving dial right => higher zoom
            // Dragging right (positive dx) means moving dial left => lower zoom
            // We flip the delta so that dragging the dial left increases zoom.
            final sensitivity = 0.01;
            double newZoom = currentZoom - (details.delta.dx * sensitivity);
            newZoom = newZoom.clamp(minZoom, maxZoom);
            if (newZoom != currentZoom) {
              onZoomChanged(newZoom);
            }
          },
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: CustomPaint(
              painter: ZoomDialPainter(
                currentZoom: currentZoom,
                minZoom: minZoom,
                maxZoom: maxZoom,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class ZoomDialPainter extends CustomPainter {
  final double currentZoom;
  final double minZoom;
  final double maxZoom;

  ZoomDialPainter({
    required this.currentZoom,
    required this.minZoom,
    required this.maxZoom,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // draw background pill
    final bgPaint = Paint()..color = const Color(0xFF2A2A2A); // Dark grey pill
    final rrect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24));
    canvas.drawRRect(rrect, bgPaint);

    final tickPaint = Paint()..color = Colors.white54..strokeWidth = 1.5;
    final activeTickPaint = Paint()..color = Colors.amber..strokeWidth = 2.5;
    final majorTickPaint = Paint()..color = Colors.white..strokeWidth = 2.0;

    // center is at size.width / 2
    final center = size.width / 2;
    // We space out ticks so that e.g. 10 ticks (1.0 zoom range) is 150 pixels wide
    final pixelsPerZoom = 150.0; 

    // Because floating point loops can be finicky, use an integer multiplier
    final intMin = (minZoom * 10).round();
    final intMax = (maxZoom * 10).round();

    for (int iz = intMin; iz <= intMax; iz++) {
      double z = iz / 10.0;
      final x = center + (z - currentZoom) * pixelsPerZoom;
      
      // only draw if within bounds (with some horizontal padding)
      if (x > 20 && x < size.width - 20) {
        final isMajor = iz % 10 == 0;
        final isCurrent = (z - currentZoom).abs() < 0.05;

        final paint = isCurrent ? activeTickPaint : (isMajor ? majorTickPaint : tickPaint);
        final height = isCurrent ? 24.0 : (isMajor ? 18.0 : 12.0);

        canvas.drawLine(
          Offset(x, size.height / 2 - height / 2),
          Offset(x, size.height / 2 + height / 2),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(ZoomDialPainter oldDelegate) {
    return oldDelegate.currentZoom != currentZoom;
  }
}
