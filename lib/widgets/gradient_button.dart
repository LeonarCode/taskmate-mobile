import 'package:flutter/material.dart';
import '../core/theme.dart';

class GradientButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final double height;
  final double borderRadius;

  const GradientButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 56,
    this.borderRadius = 16,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedOpacity(
        opacity: onTap == null ? 0.5 : 1.0,
        duration: const Duration(milliseconds: 200),
        child: Container(
          height: height,
          decoration: BoxDecoration(
            gradient: onTap == null
                ? LinearGradient(colors: [AppColors.gray400, AppColors.gray400])
                : AppColors.primaryGradient,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: onTap == null
                ? null
                : [
                    BoxShadow(
                      color: AppColors.purple600.withAlpha(60),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                    BoxShadow(
                      color: AppColors.pink500.withAlpha(30),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                ),
              ),
              if (icon != null) ...[
                const SizedBox(width: 8),
                Icon(icon, color: Colors.white, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
