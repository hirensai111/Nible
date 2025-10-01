import 'package:flutter/material.dart';

class AppColors {
  static const Color hokieMaroon = Color(0xFF900000);
  static const Color hokieOrange = Color(0xFFF47F24);
  static const Color white = Colors.white;
  static const Color shadowColor = Color(
    0x40000000,
  ); // Semi-transparent black for shadows
  static const Color lightGray = Color(0xFFF5F5F5);
  static const Color darkGray = Color(0xFF757575);
}

// Also update your colors.dart file with these constants:
class AppColors1 {
  // Primary colors
  static const Color primaryGreen = Color(0xFF00FF88);
  static const Color primaryGreen1 = Color.fromARGB(255, 1, 136, 102);
  static const Color primaryblue = Color.fromARGB(255, 10, 230, 238);
  static const Color backgroundColor = Color(0xFF000000);
  static const Color surfaceColor = Color(0xFF0A0A0A);
  static const Color cardColor = Color(0xFF1A1A1A);
  static const Color iconBackgroundColor = Color(0xFF262626);
  static const Color navBarColor = Color(0xFF050505);

  // Gradient colors for the delivery card
  static const List<Color> deliveryCardGradient = [
    Color.fromRGBO(0, 77, 64, 0.8),
    Color.fromRGBO(0, 40, 35, 0.85),
    Color.fromRGBO(0, 0, 0, 0.9),
  ];

  // Progress bar gradient colors
  static const List<Color> progressGradient = [
    Color(0xFF00FF88),
    Color(0xFF00D4AA),
    Color(0xFF00A896),
    Color.fromRGBO(0, 168, 150, 0.3),
    Colors.transparent,
  ];

  // Text colors
  static const Color textPrimary = Colors.white;
  static final Color textSecondary = Colors.white.withOpacity(0.85);
  static final Color textTertiary = Colors.white.withOpacity(0.75);
  static const Color textSubtle = Color(0xFF666666);

  // Border and glow effects
  static final Color borderGreen = primaryGreen.withOpacity(0.2);
  static final Color glowGreen = primaryGreen.withOpacity(0.3);
  static final Color subtleGlow = primaryGreen.withOpacity(0.05);
  static const cancelButtonGradient = [Color(0xFF00FF88), Color(0xFF00D4AA)];
}
