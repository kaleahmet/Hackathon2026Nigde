import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../painters/seismic_painter.dart';

enum SensorType { earthquake, fire, temperature }

class SensorCard extends StatefulWidget {
  final SensorType type;
  /// ESP32'den gelen gerçek veriler
  final bool isActive;
  final String metaLeft;
  final String metaRight;
  // Deprem verileri
  final double accelX;
  final double accelY;
  final double accelZ;
  // Yangın verileri
  final double flameIntensity; // 0.0 - 1.0
  // Sıcaklık verileri
  final double temperature;
  final double humidity;

  const SensorCard({
    super.key,
    required this.type,
    this.isActive = false,
    this.metaLeft = '',
    this.metaRight = '',
    this.accelX = 0,
    this.accelY = 0,
    this.accelZ = 0,
    this.flameIntensity = 0,
    this.temperature = 0,
    this.humidity = 0,
  });

  @override
  State<SensorCard> createState() => _SensorCardState();
}

class _SensorCardState extends State<SensorCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 100),
    )..repeat();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.surface3),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      ),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 10),
          _buildContent(),
          const SizedBox(height: 8),
          _buildMeta(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    IconData icon;
    Color iconColor;
    String name;
    String statusText;

    switch (widget.type) {
      case SensorType.earthquake:
        icon = Icons.vibration;
        iconColor = AppColors.warn;
        name = 'Sismik Algılayıcı';
        statusText = widget.isActive ? 'DEPREM!' : 'NORMAL';
        break;
      case SensorType.fire:
        icon = Icons.local_fire_department;
        iconColor = AppColors.danger;
        name = 'Alev Dedektörü';
        statusText = widget.isActive ? 'ALEV VAR!' : 'NORMAL';
        break;
      case SensorType.temperature:
        icon = Icons.thermostat;
        iconColor = AppColors.accent;
        name = 'Sıcaklık & Nem';
        statusText = widget.isActive ? 'YÜKSEK!' : 'NORMAL';
        break;
    }

    return Row(
      children: [
        Icon(icon, size: 20, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            name,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.text,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: widget.isActive
                ? AppColors.danger.withOpacity(0.12)
                : AppColors.safe.withOpacity(0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            statusText,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: widget.isActive ? AppColors.danger : AppColors.safe,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContent() {
    switch (widget.type) {
      case SensorType.earthquake:
        return ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            height: 60,
            width: double.infinity,
            child: AnimatedBuilder(
              animation: _animController,
              builder: (context, _) {
                return CustomPaint(
                  painter: SeismicPainter(
                    offset: _animController.value * 2000,
                    // Gerçek ivme verileri ile dalga yoğunluğunu kontrol et
                    intensity: widget.isActive ? 3.0 : 1.0,
                  ),
                );
              },
            ),
          ),
        );
      case SensorType.fire:
        return Container(
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.surface2,
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: widget.flameIntensity.clamp(0.02, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isActive
                      ? [AppColors.warn, AppColors.danger]
                      : [AppColors.safe, AppColors.warn],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        );
      case SensorType.temperature:
        return Row(
          children: [
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: widget.temperature > 40
                    ? [AppColors.warn, AppColors.danger]
                    : [AppColors.accent, AppColors.primary],
              ).createShader(bounds),
              child: Text(
                '${widget.temperature.toStringAsFixed(1)}°',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 20),
            Row(
              children: [
                const Icon(Icons.water_drop, size: 18, color: AppColors.accent),
                const SizedBox(width: 4),
                Text(
                  '${widget.humidity.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ],
            ),
          ],
        );
    }
  }

  Widget _buildMeta() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(widget.metaLeft, style: const TextStyle(fontSize: 11, color: AppColors.text3)),
        Text(
          widget.metaRight,
          style: TextStyle(
            fontSize: 11,
            color: AppColors.text2,
            fontFamily: AppTheme.mono.fontFamily,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
