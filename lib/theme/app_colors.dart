import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // Brand: premium agricultural operations palette.
  static const Color primary = Color(0xFF0F5D45);
  static const Color primaryLight = Color(0xFF2F7D62);
  static const Color primaryVariant = Color(0xFF176B50);
  static const Color primarySurface = Color(0xFFE8F3EE);
  static const Color primaryDark = Color(0xFF063828);

  static const Color secondary = Color(0xFFD9A441);
  static const Color secondaryLight = Color(0xFFF4D58D);
  static const Color secondarySurface = Color(0xFFFFF6DF);

  static const Color accent = Color(0xFFC78322);
  static const Color accentSurface = Color(0xFFFFF1D7);

  static const Color background = Color(0xFFFAF7EF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF6F2EA);
  static const Color surfaceMuted = Color(0xFFF1EDE5);

  static const Color textPrimary = Color(0xFF17211D);
  static const Color textSecondary = Color(0xFF5D6862);
  static const Color textTertiary = Color(0xFF89928D);
  static const Color textHint = Color(0xFF9BA39E);
  static const Color textOnPrimary = Color(0xFFFFFFFF);

  static const Color border = Color(0xFFE4DED3);
  static const Color borderLight = Color(0xFFF0EADF);

  static const Color success = Color(0xFF168A50);
  static const Color successLight = Color(0xFFE3F5EA);
  static const Color warning = Color(0xFFD08A18);
  static const Color warningLight = Color(0xFFFFF2D8);
  static const Color error = Color(0xFFC94444);
  static const Color errorLight = Color(0xFFFFE8E6);
  static const Color info = Color(0xFF526B7A);
  static const Color infoLight = Color(0xFFEAF1F4);

  static const Color draft = Color(0xFF9CA3AF);
  static const Color exported = Color(0xFF336B9B);
  static const Color shared = Color(0xFF25D366);
  static const Color completed = success;

  static const Color cardGreen = Color(0xFFEFF8F2);
  static const Color cardGold = Color(0xFFFFF6DE);
  static const Color cardBlue = Color(0xFFEAF2F6);
  static const Color cardPurple = Color(0xFFF2EEF8);
  static const Color cardOrange = Color(0xFFFFF0E2);
  static const Color cardTeal = Color(0xFFEAF7F5);

  static Color shadow = const Color(0xFF17211D).withValues(alpha: 0.07);
  static Color shadowMedium = const Color(0xFF17211D).withValues(alpha: 0.12);
}
