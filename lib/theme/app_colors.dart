import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand - Deep Green / Emerald (Rice Field Green)
  static const Color primary = Color(0xFF1B5E20);
  static const Color primaryLight = Color(0xFF388E3C);
  static const Color primaryVariant = Color(0xFF2E7D32);
  static const Color primarySurface = Color(0xFFE8F5E9);
  static const Color primaryDark = Color(0xFF0D3B0F);

  // Secondary - Warm Gold / Paddy Yellow
  static const Color secondary = Color(0xFFF9A825);
  static const Color secondaryLight = Color(0xFFFFD54F);
  static const Color secondarySurface = Color(0xFFFFF8E1);

  // Background
  static const Color background = Color(0xFFF5F5F0);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFFAFAFA);

  // Text
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF6B7280);
  static const Color textHint = Color(0xFF9CA3AF);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  // Borders
  static const Color border = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);

  // Semantic
  static const Color success = Color(0xFF16A34A);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFDC2626);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF64748B);
  static const Color infoLight = Color(0xFFF1F5F9);

  // Status
  static const Color draft = Color(0xFF9CA3AF);
  static const Color exported = Color(0xFF2563EB);
  static const Color shared = Color(0xFF25D366);
  static const Color completed = Color(0xFF16A34A);

  // Card backgrounds
  static const Color cardGreen = Color(0xFFF0FDF4);
  static const Color cardGold = Color(0xFFFFFBEB);
  static const Color cardBlue = Color(0xFFEFF6FF);
  static const Color cardPurple = Color(0xFFFAF5FF);
  static const Color cardOrange = Color(0xFFFFF7ED);
  static const Color cardTeal = Color(0xFFF0FDFA);

  // Shadows
  static Color shadow = Colors.black.withValues(alpha: 0.06);
  static Color shadowMedium = Colors.black.withValues(alpha: 0.1);
}
