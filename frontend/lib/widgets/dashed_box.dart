import 'package:flutter/material.dart';
import 'dart:ui' as ui;

class DashedBox extends StatelessWidget {
  final Widget child;
  final Color color;
  final double strokeWidth;
  final double gap;

  const DashedBox({
    super.key, 
    required this.child, 
    this.color = Colors.grey, 
    this.strokeWidth = 1.0, 
    this.gap = 5.0
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRectPainter(color: color, strokeWidth: strokeWidth, gap: gap),
      child: child,
    );
  }
}

class _DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;

  _DashedRectPainter({required this.color, required this.strokeWidth, required this.gap});

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    final ui.Paint paint = ui.Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = ui.PaintingStyle.stroke;

    _drawDashedPath(canvas, ui.Path()..addRRect(ui.RRect.fromRectAndRadius(ui.Offset.zero & size, const Radius.circular(12))), paint);
  }

  void _drawDashedPath(Canvas canvas, ui.Path path, ui.Paint paint) {
    ui.PathMetrics pathMetrics = path.computeMetrics();
    for (ui.PathMetric pathMetric in pathMetrics) {
      double distance = 0.0;
      while (distance < pathMetric.length) {
        // Draw a segment
        double nextDistance = distance + 10; // Dash length
        canvas.drawPath(
          pathMetric.extractPath(distance, nextDistance),
          paint,
        );
        distance = nextDistance + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRectPainter oldDelegate) {
    return color != oldDelegate.color || strokeWidth != oldDelegate.strokeWidth || gap != oldDelegate.gap;
  }
}
