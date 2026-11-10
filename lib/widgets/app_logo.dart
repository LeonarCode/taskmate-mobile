import 'package:flutter/material.dart';
import '../core/theme.dart';

/// TaskMate logo widget — clipboard mascot drawn in Flutter
class AppLogo extends StatelessWidget {
  final double size;

  const AppLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer glow
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(size * 0.26),
              boxShadow: [
                BoxShadow(
                  color: AppColors.purple600.withAlpha(80),
                  blurRadius: size * 0.3,
                  spreadRadius: size * 0.02,
                ),
              ],
            ),
          ),
          // Main body
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.purple500, AppColors.purple700],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(size * 0.26),
              border: Border.all(
                color: AppColors.purple400.withAlpha(60),
                width: 2,
              ),
            ),
          ),
          // Clipboard paper
          Positioned(
            top: size * 0.16,
            child: Container(
              width: size * 0.6,
              height: size * 0.68,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(size * 0.1),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 8,
                    offset: Offset(0, size * 0.03),
                  ),
                ],
              ),
            ),
          ),
          // Clip top (pink bar)
          Positioned(
            top: size * 0.1,
            child: Container(
              width: size * 0.22,
              height: size * 0.12,
              decoration: BoxDecoration(
                color: AppColors.pink500,
                borderRadius: BorderRadius.circular(size * 0.06),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.pink500.withAlpha(80),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          // Eyes
          Positioned(
            top: size * 0.29,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _eye(size),
                SizedBox(width: size * 0.13),
                _eye(size),
              ],
            ),
          ),
          // Smile
          Positioned(
            top: size * 0.42,
            child: SizedBox(
              width: size * 0.18,
              height: size * 0.08,
              child: CustomPaint(painter: _SmilePainter()),
            ),
          ),
          // Green checkmark
          Positioned(
            bottom: size * 0.1,
            child: Icon(
              Icons.check_rounded,
              color: AppColors.green500,
              size: size * 0.44,
              shadows: [
                Shadow(
                  color: AppColors.green500.withAlpha(100),
                  blurRadius: 10,
                  offset: Offset(0, size * 0.03),
                ),
              ],
            ),
          ),
          // Sparkle
          Positioned(
            top: size * 0.05,
            right: size * 0.06,
            child: Icon(
              Icons.auto_awesome_rounded,
              color: AppColors.amber400,
              size: size * 0.14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _eye(double size) {
    return Container(
      width: size * 0.07,
      height: size * 0.07,
      decoration: BoxDecoration(
        color: const Color(0xFF2D1B5E),
        shape: BoxShape.circle,
      ),
    );
  }
}

class _SmilePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.pink500
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.35
      ..strokeCap = StrokeCap.round;

    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size.width / 2, size.height * 1.2, size.width, 0);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}
