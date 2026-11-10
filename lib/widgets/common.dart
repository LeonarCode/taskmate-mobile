import 'package:flutter/material.dart';
import '../core/theme.dart';

/// The small grab bar at the top of bottom sheets.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key, this.bottomMargin = 20});

  final double bottomMargin;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: EdgeInsets.only(bottom: bottomMargin),
        decoration: BoxDecoration(
          color: isDark ? AppColors.dark500 : AppColors.gray200,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

/// The rounded container every bottom sheet uses; pads for the keyboard.
class SheetContainer extends StatelessWidget {
  const SheetContainer({super.key, required this.child, this.height});

  final Widget child;
  final double? height;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      padding: EdgeInsets.fromLTRB(
        24,
        20,
        24,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.dark800 : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: child,
    );
  }
}

/// A red box with an error message, as shown above forms.
class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.red500.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.red500.withAlpha(80)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: AppColors.red500,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: AppColors.red500,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Spinner in the brand color.
class BrandSpinner extends StatelessWidget {
  const BrandSpinner({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(
        valueColor: AlwaysStoppedAnimation<Color>(AppColors.purple600),
      ),
    );
  }
}

/// Icon, title and hint shown when a list is empty.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.title,
    this.onTap,
  });

  final IconData icon;
  final String message;
  final String? title;

  /// Makes the whole state tappable, e.g. "tap to try again".
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.purple600.withAlpha(15),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(
                  icon,
                  size: 40,
                  color: AppColors.purple600.withAlpha(150),
                ),
              ),
              const SizedBox(height: 16),
              if (title != null) ...[
                Text(
                  title!,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppColors.gray800,
                  ),
                ),
                const SizedBox(height: 6),
              ],
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? AppColors.gray400 : AppColors.gray500,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
