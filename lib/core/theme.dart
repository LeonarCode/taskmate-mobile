import 'package:flutter/material.dart';

// ── Brand Palette ──────────────────────────────────────────────────────────────
class AppColors {
  AppColors._();

  // Core purple/pink brand
  static const purple900 = Color(0xFF3B0764);
  static const purple800 = Color(0xFF5B21B6);
  static const purple700 = Color(0xFF6D28D9);
  static const purple600 = Color(0xFF7C3AED);
  static const purple500 = Color(0xFF8B5CF6);
  static const purple400 = Color(0xFFA78BFA);
  static const purple300 = Color(0xFFC4B5FD);
  static const purple200 = Color(0xFFDDD6FE);
  static const purple100 = Color(0xFFEDE9FE);
  static const purple50 = Color(0xFFF5F3FF);

  static const pink600 = Color(0xFFDB2777);
  static const pink500 = Color(0xFFEC4899);
  static const pink400 = Color(0xFFF472B6);
  static const pink300 = Color(0xFFFBCFE8);

  static const green500 = Color(0xFF22C55E);
  static const green400 = Color(0xFF4ADE80);

  static const amber500 = Color(0xFFF59E0B);
  static const amber400 = Color(0xFFFBBF24);

  static const red500 = Color(0xFFEF4444);
  static const red400 = Color(0xFFF87171);

  // Neutrals (light)
  static const gray50 = Color(0xFFF9FAFB);
  static const gray100 = Color(0xFFF3F4F6);
  static const gray200 = Color(0xFFE5E7EB);
  static const gray300 = Color(0xFFD1D5DB);
  static const gray400 = Color(0xFF9CA3AF);
  static const gray500 = Color(0xFF6B7280);
  static const gray600 = Color(0xFF4B5563);
  static const gray700 = Color(0xFF374151);
  static const gray800 = Color(0xFF1F2937);
  static const gray900 = Color(0xFF111827);

  // Dark mode surface colors
  static const dark900 = Color(0xFF0D0B1A);
  static const dark800 = Color(0xFF13101F);
  static const dark700 = Color(0xFF1A1629);
  static const dark600 = Color(0xFF221D36);
  static const dark500 = Color(0xFF2D2748);
  static const dark400 = Color(0xFF3D3660);

  // Gradients
  static const primaryGradient = LinearGradient(
    colors: [purple600, pink500],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const darkBgGradient = LinearGradient(
    colors: [dark900, dark800, dark700],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

// ── Theme ──────────────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = _base(Brightness.light);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.gray50,
      colorScheme: const ColorScheme.light(
        primary: AppColors.purple600,
        onPrimary: Colors.white,
        secondary: AppColors.pink500,
        onSecondary: Colors.white,
        tertiary: AppColors.green500,
        surface: Colors.white,
        onSurface: AppColors.gray900,
        surfaceContainerHighest: AppColors.gray100,
        error: AppColors.red500,
        outline: AppColors.gray300,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.gray900,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: AppColors.gray900,
        ),
        iconTheme: const IconThemeData(color: AppColors.gray700),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: _inputTheme(Brightness.light),
      elevatedButtonTheme: _elevatedButtonTheme(),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: AppColors.purple600,
        unselectedItemColor: AppColors.gray400,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.purple600,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.purple100,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.purple700,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.gray200,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.gray900,
        contentTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData dark() {
    final base = _base(Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.dark900,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.purple500,
        onPrimary: Colors.white,
        secondary: AppColors.pink400,
        onSecondary: Colors.white,
        tertiary: AppColors.green400,
        surface: AppColors.dark800,
        onSurface: Colors.white,
        surfaceContainerHighest: AppColors.dark700,
        error: AppColors.red400,
        outline: AppColors.dark500,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.dark800,
        foregroundColor: Colors.white,
        elevation: 0,
        titleTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 18,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.dark700,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: _inputTheme(Brightness.dark),
      elevatedButtonTheme: _elevatedButtonTheme(),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.dark800,
        selectedItemColor: AppColors.purple400,
        unselectedItemColor: AppColors.gray500,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.purple600,
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.dark600,
        labelStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.purple300,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.dark600,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.dark500,
        contentTextStyle: const TextStyle(
          fontFamily: 'Poppins',
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  static ThemeData _base(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      fontFamily: 'Poppins',
    );
  }

  static InputDecorationTheme _inputTheme(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    return InputDecorationTheme(
      filled: true,
      fillColor: isDark ? AppColors.dark700 : AppColors.gray50,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppColors.dark500 : AppColors.gray200,
          width: 1.5,
        ),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(
          color: isDark ? AppColors.dark500 : AppColors.gray200,
          width: 1.5,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.purple600, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red500, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.red500, width: 2),
      ),
      hintStyle: TextStyle(
        color: isDark ? AppColors.gray500 : AppColors.gray400,
        fontSize: 14,
        fontWeight: FontWeight.w400,
      ),
      errorStyle: const TextStyle(
        color: AppColors.red500,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static ElevatedButtonThemeData _elevatedButtonTheme() {
    return ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.purple600,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Poppins',
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
