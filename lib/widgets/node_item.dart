import 'package:flutter/material.dart';
import '../models/mesh_node.dart';
import '../theme/app_theme.dart';

class NodeItem extends StatelessWidget {
  final MeshNode node;
  const NodeItem({super.key, required this.node});

  @override
  Widget build(BuildContext context) {
    Color dotColor;
    Color? dotGlow;
    switch (node.status) {
      case NodeStatus.active:
        dotColor = AppColors.primary;
        dotGlow = AppColors.primary.withOpacity(0.4);
        break;
      case NodeStatus.warning:
        dotColor = AppColors.warn;
        dotGlow = AppColors.warn.withOpacity(0.4);
        break;
      case NodeStatus.offline:
        dotColor = AppColors.text3;
        dotGlow = null;
        break;
    }

    Color sigColor;
    if (node.status == NodeStatus.offline) {
      sigColor = AppColors.text3;
    } else if (node.signal > -50) {
      sigColor = AppColors.primary;
    } else {
      sigColor = AppColors.warn;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.surface3),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(children: [
        Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: dotColor,
            boxShadow: dotGlow != null ? [BoxShadow(color: dotGlow, blurRadius: 8)] : null,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${node.name} · ${node.typeLabel}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.text)),
          Text('${node.floor} · ESP32-WROOM', style: const TextStyle(fontSize: 10, color: AppColors.text2)),
        ])),
        Text(node.signalText, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: sigColor, fontFamily: AppTheme.mono.fontFamily)),
      ]),
    );
  }
}
