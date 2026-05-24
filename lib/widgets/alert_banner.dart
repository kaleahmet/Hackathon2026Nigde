import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class AlertBanner extends StatefulWidget {
  final String title;
  final String subtitle;
  final Color alertColor;
  final IconData icon;
  final VoidCallback? onDismiss;

  const AlertBanner({
    super.key,
    this.title = 'Sismik Aktivite Algılandı',
    this.subtitle = 'Kat 3 · 2.4 magnitude · 3s önce',
    this.alertColor = AppColors.danger,
    this.icon = Icons.warning_rounded,
    this.onDismiss,
  });

  @override
  State<AlertBanner> createState() => _AlertBannerState();
}

class _AlertBannerState extends State<AlertBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _dismiss() {
    setState(() => _visible = false);
    widget.onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return const SizedBox.shrink();

    return AnimatedOpacity(
      opacity: _visible ? 1.0 : 0.0,
      duration: const Duration(milliseconds: 400),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              widget.alertColor.withOpacity(0.15),
              widget.alertColor.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: widget.alertColor.withOpacity(0.25)),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Stack(
          children: [
            // Pulse bar on left
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: widget.alertColor
                          .withOpacity(0.3 + _pulseController.value * 0.7),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
              child: Row(
                children: [
                  Icon(widget.icon,
                      color: widget.alertColor, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: widget.alertColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.subtitle,
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.text2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: _dismiss,
                    child: const Icon(Icons.close,
                        color: AppColors.text3, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
