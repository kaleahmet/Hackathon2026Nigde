enum NodeStatus { active, warning, offline }

enum NodeType { gateway, sensor, relay }

class MeshNode {
  final int id;
  final String name;
  final String floor;
  final NodeType type;
  final NodeStatus status;
  final int signal;

  const MeshNode({
    required this.id,
    required this.name,
    required this.floor,
    required this.type,
    required this.status,
    required this.signal,
  });

  String get typeLabel {
    switch (type) {
      case NodeType.gateway:
        return 'Gateway';
      case NodeType.sensor:
        return 'Sensör';
      case NodeType.relay:
        return 'Relay';
    }
  }

  String get signalText {
    if (status == NodeStatus.offline) return 'Çevrimdışı';
    return '$signal dBm';
  }

  static List<MeshNode> get sampleNodes => const [
        MeshNode(id: 1, name: 'Düğüm #1', floor: 'Kat 1', type: NodeType.gateway, status: NodeStatus.active, signal: -32),
        MeshNode(id: 2, name: 'Düğüm #2', floor: 'Kat 1', type: NodeType.sensor, status: NodeStatus.active, signal: -40),
        MeshNode(id: 3, name: 'Düğüm #3', floor: 'Kat 2', type: NodeType.sensor, status: NodeStatus.active, signal: -45),
        MeshNode(id: 4, name: 'Düğüm #4', floor: 'Kat 2', type: NodeType.relay, status: NodeStatus.active, signal: -38),
        MeshNode(id: 5, name: 'Düğüm #5', floor: 'Kat 3', type: NodeType.sensor, status: NodeStatus.active, signal: -52),
        MeshNode(id: 6, name: 'Düğüm #6', floor: 'Kat 3', type: NodeType.sensor, status: NodeStatus.warning, signal: -68),
        MeshNode(id: 7, name: 'Düğüm #7', floor: 'Kat 4', type: NodeType.relay, status: NodeStatus.active, signal: -47),
        MeshNode(id: 8, name: 'Düğüm #8', floor: 'Kat 4', type: NodeType.sensor, status: NodeStatus.active, signal: -55),
        MeshNode(id: 9, name: 'Düğüm #9', floor: 'Kat 5', type: NodeType.sensor, status: NodeStatus.warning, signal: -72),
        MeshNode(id: 10, name: 'Düğüm #10', floor: 'Kat 5', type: NodeType.sensor, status: NodeStatus.active, signal: -60),
        MeshNode(id: 11, name: 'Düğüm #11', floor: 'Kat 3', type: NodeType.gateway, status: NodeStatus.active, signal: -35),
        MeshNode(id: 12, name: 'Düğüm #12', floor: 'Kat 1', type: NodeType.sensor, status: NodeStatus.offline, signal: 0),
      ];

  static const List<List<int>> edges = [
    [1, 2], [1, 3], [2, 4], [3, 4], [3, 5], [4, 7],
    [5, 6], [5, 11], [6, 9], [7, 8], [7, 10], [8, 9],
    [9, 10], [11, 1], [11, 7], [4, 12],
  ];
}
