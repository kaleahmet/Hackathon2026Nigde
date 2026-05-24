import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

enum RiskLevel { high, medium, low }

class FloorCard extends StatelessWidget {
  final int floorNumber;
  final String floorName;
  final RiskLevel risk;
  final int score;
  final String vibration;
  final String temperature;
  final String people;
  final String nodes;

  const FloorCard({
    super.key,
    required this.floorNumber,
    required this.floorName,
    required this.risk,
    required this.score,
    required this.vibration,
    required this.temperature,
    required this.people,
    required this.nodes,
  });

  Color get _riskColor {
    switch (risk) {
      case RiskLevel.high:
        return AppColors.danger;
      case RiskLevel.medium:
        return AppColors.warn;
      case RiskLevel.low:
        return AppColors.safe;
    }
  }

  String get _riskLabel {
    switch (risk) {
      case RiskLevel.high:
        return 'Yüksek Risk';
      case RiskLevel.medium:
        return 'Orta Risk';
      case RiskLevel.low:
        return score <= 15 ? 'Güvenli' : 'Düşük Risk';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border(
          left: BorderSide(color: _riskColor, width: 3),
          top: BorderSide(color: AppColors.surface3),
          right: BorderSide(color: AppColors.surface3),
          bottom: BorderSide(color: AppColors.surface3),
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surface2,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$floorNumber',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.text,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      floorName,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.text,
                      ),
                    ),
                    Text(
                      _riskLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.text2,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _riskColor.withOpacity(0.12),
                ),
                alignment: Alignment.center,
                child: Text(
                  '$score',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _riskColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Details grid
          Wrap(
            spacing: 0,
            runSpacing: 6,
            children: [
              _detailItem(Icons.vibration, vibration),
              _detailItem(Icons.local_fire_department, temperature),
              _detailItem(Icons.people, people),
              _detailItem(Icons.wifi_tethering, nodes),
            ],
          ),
        ],
      ),
    );
  }

  Widget _detailItem(IconData icon, String text) {
    return SizedBox(
      width: 160,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.text3),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: const TextStyle(fontSize: 11, color: AppColors.text2),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
