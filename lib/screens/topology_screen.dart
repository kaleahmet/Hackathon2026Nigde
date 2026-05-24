import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/mesh_node.dart';
import '../painters/topology_painter.dart';
import '../services/esp32_service.dart';
import '../theme/app_theme.dart';
import '../widgets/node_item.dart';

class TopologyScreen extends StatefulWidget {
  final Function(int)? onNavigate;
  const TopologyScreen({super.key, this.onNavigate});
  @override
  State<TopologyScreen> createState() => _TopologyScreenState();
}

class _TopologyScreenState extends State<TopologyScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 100))..repeat();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<Esp32Service>(
      builder: (context, esp, child) {
        final data = esp.sensorData;
        final nodes = MeshNode.sampleNodes;

        return Column(children: [
          // Header
          Container(
            padding: const EdgeInsets.fromLTRB(16, 50, 16, 12),
            color: AppColors.bg,
            child: Row(children: [
              IconButton(icon: const Icon(Icons.arrow_back, color: AppColors.text), onPressed: () => widget.onNavigate?.call(0)),
              const SizedBox(width: 4),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Ağ Topolojisi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.text)),
                Text(
                  esp.isConnected
                      ? '${data.nodeCount} düğüm aktif · Canlı'
                      : 'Self-Healing Mesh Haritası',
                  style: const TextStyle(fontSize: 11, color: AppColors.text2),
                ),
              ])),
              GestureDetector(
                onTap: () => esp.fetchSensors(),
                child: const Icon(Icons.refresh, color: AppColors.text2, size: 22),
              ),
            ]),
          ),
          Expanded(
            child: ListView(padding: const EdgeInsets.symmetric(horizontal: 16), children: [
              // Bağlantı durumu göstergesi
              if (esp.isConnected)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.08),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(children: [
                    const Icon(Icons.wifi_tethering, size: 18, color: AppColors.primary),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                      'ESP32 Mesh: ${data.nodeCount} düğüm · Kat ${data.floorId}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary),
                    )),
                  ]),
                ),
              // Legend
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _legendItem(AppColors.primary, 'Aktif'),
                const SizedBox(width: 16),
                _legendItem(AppColors.warn, 'Zayıf'),
                const SizedBox(width: 16),
                _legendItem(AppColors.text3, 'Çevrimdışı'),
              ]),
              const SizedBox(height: 12),
              // Topology canvas
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  border: Border.all(color: AppColors.surface3),
                  borderRadius: BorderRadius.circular(AppTheme.cardRadius),
                ),
                child: AnimatedBuilder(
                  animation: _animCtrl,
                  builder: (_, child) => CustomPaint(
                    size: const Size(double.infinity, 300),
                    painter: TopologyPainter(
                      animOffset: _animCtrl.value * 1000,
                      nodes: nodes,
                      edges: MeshNode.edges,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              _sectionLabel('DÜĞÜM LİSTESİ'),
              ...nodes.map((n) => NodeItem(node: n)),
              const SizedBox(height: 80),
            ]),
          ),
        ]);
      },
    );
  }

  Widget _legendItem(Color color, String text) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
      const SizedBox(width: 5),
      Text(text, style: const TextStyle(fontSize: 11, color: AppColors.text2)),
    ]);
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.text3, letterSpacing: 1.5)),
    );
  }
}
