import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SeismicPainter extends CustomPainter {
  final double offset;
  /// Dalga yoğunluğu çarpanı (1.0 = normal, 3.0 = deprem)
  final double intensity;

  SeismicPainter({required this.offset, this.intensity = 1.0});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Grid lines
    final gridPaint = Paint()
      ..color = const Color(0xFF5A6480).withOpacity(0.15)
      ..strokeWidth = 0.5;
    for (double y = 0; y < h; y += 15) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // Seismic wave — yoğunluk deprem durumuna göre değişir
    final wavePaint = Paint()
      ..color = intensity > 1.5 ? AppColors.danger : AppColors.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 6);

    final path = Path();
    final random = Random(42);
    for (double x = 0; x < w; x++) {
      final y = h / 2 +
          sin((x + offset) * 0.05) * 8 * intensity +
          sin((x + offset) * 0.12) * 5 * intensity +
          (random.nextDouble() - 0.5) * 3 * intensity;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, wavePaint);

    // Draw again without blur for solid line
    final solidPaint = Paint()
      ..color = intensity > 1.5 ? AppColors.danger : AppColors.primary
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, solidPaint);
  }

  @override
  bool shouldRepaint(covariant SeismicPainter oldDelegate) {
    return oldDelegate.offset != offset || oldDelegate.intensity != intensity;
  }
}
