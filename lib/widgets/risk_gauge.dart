import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RiskGauge extends StatelessWidget {
  final int riskValue;
  const RiskGauge({super.key, required this.riskValue});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 90, height: 90,
      child: CustomPaint(
        painter: _GaugePainter(riskValue: riskValue),
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text('$riskValue', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.text)),
            const Text('Risk', style: TextStyle(fontSize: 11, color: AppColors.text3)),
          ]),
        ),
      ),
    );
  }
}

class _GaugePainter extends CustomPainter {
  final int riskValue;
  _GaugePainter({required this.riskValue});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final bgPaint = Paint()..color = AppColors.surface3..strokeWidth = 8..style = PaintingStyle.stroke;
    canvas.drawCircle(center, radius, bgPaint);
    final fillPaint = Paint()..color = AppColors.warn..strokeWidth = 8..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final sweep = (riskValue / 100) * 2 * pi;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), -pi / 2, sweep, false, fillPaint);
  }

  @override
  bool shouldRepaint(covariant _GaugePainter old) => old.riskValue != riskValue;
}
