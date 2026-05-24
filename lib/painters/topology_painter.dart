import 'dart:math';
import 'package:flutter/material.dart';
import '../models/mesh_node.dart';
import '../theme/app_theme.dart';

class TopologyPainter extends CustomPainter {
  final double animOffset;
  final List<MeshNode> nodes;
  final List<List<int>> edges;

  TopologyPainter({
    required this.animOffset,
    required this.nodes,
    required this.edges,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final cx = w / 2;
    final cy = h / 2;

    // Calculate positions (circular layout)
    final positions = <Offset>[];
    for (int i = 0; i < nodes.length; i++) {
      final angle = (i / nodes.length) * pi * 2 - pi / 2;
      final r = 90.0 + (i % 3) * 22.0;
      positions.add(Offset(cx + cos(angle) * r, cy + sin(angle) * r));
    }

    // Draw edges
    for (final edge in edges) {
      final a = edge[0] - 1;
      final b = edge[1] - 1;
      if (a >= nodes.length || b >= nodes.length) continue;

      final pa = positions[a];
      final pb = positions[b];
      final na = nodes[a];
      final nb = nodes[b];

      final isWeak = na.status == NodeStatus.warning ||
          nb.status == NodeStatus.warning ||
          na.status == NodeStatus.offline ||
          nb.status == NodeStatus.offline;

      final isOffline =
          na.status == NodeStatus.offline || nb.status == NodeStatus.offline;

      final edgePaint = Paint()
        ..strokeWidth = isWeak ? 1.0 : 1.5
        ..style = PaintingStyle.stroke;

      if (isOffline) {
        edgePaint.color = const Color(0xFF5A6480).withOpacity(0.2);
        // Dashed line for offline
        _drawDashedLine(canvas, pa, pb, edgePaint, 4, 4);
      } else {
        edgePaint.color = isWeak
            ? const Color(0xFFFFB347).withOpacity(0.25)
            : const Color(0xFF00E5A0).withOpacity(0.2);
        canvas.drawLine(pa, pb, edgePaint);
      }

      // Animated packet dot
      if (!isOffline) {
        final t = ((animOffset * 0.01 + a * 0.3) % 1);
        final dx = pa.dx + (pb.dx - pa.dx) * t;
        final dy = pa.dy + (pb.dy - pa.dy) * t;
        final dotPaint = Paint()
          ..color = isWeak
              ? const Color(0xFFFFB347).withOpacity(0.6)
              : const Color(0xFF00E5A0).withOpacity(0.6);
        canvas.drawCircle(Offset(dx, dy), 2, dotPaint);
      }
    }

    // Draw nodes
    for (int i = 0; i < nodes.length; i++) {
      final n = nodes[i];
      final p = positions[i];
      final color = _nodeColor(n.status);

      // Glow
      if (n.status != NodeStatus.offline) {
        final glowPaint = Paint()
          ..shader = RadialGradient(
            colors: [
              color.withOpacity(0.2),
              color.withOpacity(0.0),
            ],
          ).createShader(Rect.fromCircle(center: p, radius: 18));
        canvas.drawCircle(p, 18, glowPaint);
      }

      // Node circle
      final nodeRadius = n.type == NodeType.gateway ? 10.0 : 7.0;
      final bgPaint = Paint()
        ..color = n.status == NodeStatus.offline
            ? AppColors.surface2
            : AppColors.surface;
      canvas.drawCircle(p, nodeRadius, bgPaint);

      final borderPaint = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(p, nodeRadius, borderPaint);

      // Inner dot
      final innerPaint = Paint()..color = color;
      canvas.drawCircle(p, 3, innerPaint);

      // Label
      final textPainter = TextPainter(
        text: TextSpan(
          text: '#${n.id}',
          style: const TextStyle(
            fontSize: 9,
            color: AppColors.text2,
            fontFamily: 'Inter',
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(p.dx - textPainter.width / 2, p.dy + 14),
      );
    }
  }

  Color _nodeColor(NodeStatus status) {
    switch (status) {
      case NodeStatus.active:
        return AppColors.primary;
      case NodeStatus.warning:
        return AppColors.warn;
      case NodeStatus.offline:
        return AppColors.text3;
    }
  }

  void _drawDashedLine(
      Canvas canvas, Offset p1, Offset p2, Paint paint, double dash, double gap) {
    final dx = p2.dx - p1.dx;
    final dy = p2.dy - p1.dy;
    final dist = sqrt(dx * dx + dy * dy);
    final steps = dist / (dash + gap);
    for (int i = 0; i < steps; i++) {
      final startFrac = i * (dash + gap) / dist;
      final endFrac = (i * (dash + gap) + dash) / dist;
      if (endFrac > 1) break;
      canvas.drawLine(
        Offset(p1.dx + dx * startFrac, p1.dy + dy * startFrac),
        Offset(p1.dx + dx * endFrac, p1.dy + dy * endFrac),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant TopologyPainter oldDelegate) {
    return oldDelegate.animOffset != animOffset;
  }
}
