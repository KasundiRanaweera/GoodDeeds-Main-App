import 'package:flutter/material.dart';

/// Centralized app colors
class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF0DF233);
  static const Color backgroundLight = Color(0xFFF8F6F6);
  static const Color backgroundDark = Color(0xFF221610);

  // Status colors
  static const Color successDark = Color(0xFF50B27C);
  static const Color successLight = Color(0xFF1C8D55);
  static const Color infoDark = Color(0xFF6FA8FF);
  static const Color infoLight = Color(0xFF2B73D6);

  // Text colors
  static const Color textPrimary = Colors.black87;
  static const Color textSecondary = Colors.grey;
  static const Color textLight = Colors.white;

  /// Get status color based on theme
  static Color getStatusColorForTheme(bool isDark) {
    return isDark ? successDark : successLight;
  }

  /// Get info color based on theme
  static Color getInfoColorForTheme(bool isDark) {
    return isDark ? infoDark : infoLight;
  }

  /// Get background based on theme
  static Color getBackgroundForTheme(bool isDark) {
    return isDark ? backgroundDark : backgroundLight;
  }
}
