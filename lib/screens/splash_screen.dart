import 'dart:math';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _loadCtrl;
  late AnimationController _pulseCtrl;
  late AnimationController _meshCtrl;

  @override
  void initState() {
    super.initState();
    _loadCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500))..forward();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _meshCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 20))..repeat();

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).pushReplacementNamed('/home');
    });
  }

  @override
  void dispose() {
    _loadCtrl.dispose();
    _pulseCtrl.dispose();
    _meshCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Stack(children: [
        // Mesh rotating background
        AnimatedBuilder(animation: _meshCtrl, builder: (_, child) {
          return Transform.rotate(
            angle: _meshCtrl.value * 2 * pi,
            child: CustomPaint(size: MediaQuery.of(context).size, painter: _MeshBgPainter()),
          );
        }),
        // Content
        Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Logo ring
          AnimatedBuilder(animation: _pulseCtrl, builder: (_, child) {
            return Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.primary, width: 2),
                boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.2 + _pulseCtrl.value * 0.2), blurRadius: 30 + _pulseCtrl.value * 20)],
              ),
              child: Center(
                child: Container(
                  width: 80, height: 80,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [AppColors.primary, AppColors.accent]),
                  ),
                  child: const Icon(Icons.shield, size: 40, color: AppColors.bg),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
          // Title
          RichText(text: const TextSpan(children: [
            TextSpan(text: 'Van', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1, color: AppColors.text)),
            TextSpan(text: 'guard', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: -1, color: AppColors.primary)),
          ])),
          const SizedBox(height: 6),
          const Text('Merkeziyetsiz Afet Yönetim Ağı', style: TextStyle(fontSize: 14, color: AppColors.text2)),
          const SizedBox(height: 32),
          // Loading bar
          SizedBox(
            width: 200, height: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: AnimatedBuilder(animation: _loadCtrl, builder: (_, child) {
                return LinearProgressIndicator(
                  value: _loadCtrl.value,
                  backgroundColor: AppColors.surface2,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                );
              }),
            ),
          ),
          const SizedBox(height: 16),
          Text('v2.1.0 · ESP32 Mesh Protocol', style: TextStyle(fontSize: 11, color: AppColors.text3, fontFamily: AppTheme.mono.fontFamily)),
        ])),
      ]),
    );
  }
}

class _MeshBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint1 = Paint()..color = AppColors.primary.withOpacity(0.03)..strokeWidth = 1;
    final paint2 = Paint()..color = AppColors.accent.withOpacity(0.03)..strokeWidth = 1;
    for (double i = -size.height; i < size.height * 2; i += 41) {
      canvas.drawLine(Offset(0, i), Offset(size.width, i + size.width * tan(pi / 3)), paint1);
      canvas.drawLine(Offset(0, i), Offset(size.width, i - size.width * tan(pi / 3)), paint2);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
