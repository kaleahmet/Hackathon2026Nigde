/// ESP32 /api/sensors endpoint'inden dönen sensör verisi modeli
class SensorData {
  final double temperature;
  final double humidity;
  final bool flameDetected;
  final int flameRaw;
  final bool earthquakeDetected;
  final double accelX;
  final double accelY;
  final double accelZ;
  final int floorId;
  final int nodeCount;

  const SensorData({
    required this.temperature,
    required this.humidity,
    required this.flameDetected,
    required this.flameRaw,
    required this.earthquakeDetected,
    required this.accelX,
    required this.accelY,
    required this.accelZ,
    required this.floorId,
    required this.nodeCount,
  });

  factory SensorData.fromJson(Map<String, dynamic> json) {
    return SensorData(
      temperature: (json['temp'] as num?)?.toDouble() ?? 0.0,
      humidity: (json['hum'] as num?)?.toDouble() ?? 0.0,
      flameDetected: json['flame'] as bool? ?? false,
      flameRaw: json['flameRaw'] as int? ?? 4095,
      earthquakeDetected: json['quake'] as bool? ?? false,
      accelX: (json['ax'] as num?)?.toDouble() ?? 0.0,
      accelY: (json['ay'] as num?)?.toDouble() ?? 0.0,
      accelZ: (json['az'] as num?)?.toDouble() ?? 0.0,
      floorId: json['floor'] as int? ?? 0,
      nodeCount: json['nodes'] as int? ?? 0,
    );
  }

  /// Toplam ivme büyüklüğü (g cinsinden)
  double get totalAccel {
    return _sqrt(accelX * accelX + accelY * accelY + accelZ * accelZ);
  }

  /// Alev yoğunluğu yüzdesi (0=alev yok, 100=maksimum alev)
  double get flameIntensityPercent {
    // ESP32'de flameRaw 0-4095 arasında, düşük değer = yüksek alev
    return ((4095 - flameRaw) / 4095 * 100).clamp(0, 100);
  }

  /// Varsayılan boş veri
  static const SensorData empty = SensorData(
    temperature: 0,
    humidity: 0,
    flameDetected: false,
    flameRaw: 4095,
    earthquakeDetected: false,
    accelX: 0,
    accelY: 0,
    accelZ: 0,
    floorId: 0,
    nodeCount: 0,
  );

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    double x = v;
    for (int i = 0; i < 20; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }
}
