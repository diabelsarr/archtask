import 'package:flutter/material.dart';

/// Couleurs extraites du design ArchTask (Google Stitch).
/// Ajuste les codes hex si tes valeurs exactes diffèrent.
class AppColors {
  static const primary = Color(0xFF3730A3); // bleu indigo principal
  static const primaryLight = Color(0xFF4C46C9);

  static const priorityHigh = Color(0xFFE63946);
  static const priorityMedium = Color(0xFFF4A261);
  static const priorityLow = Color(0xFF2A9D8F);

  static const background = Color(0xFFF8F9FA);
  static const inputFill = Color(0xFFF3F4F6);
  static const inputBorder = Color(0xFFE5E7EB);

  static const textPrimary = Color(0xFF111827);
  static const textLabel = Color(0xFF4B5563);
  static const textPlaceholder = Color(0xFF9CA3AF);
}

/// Styles de texte réutilisables (labels en majuscules type "mono"
/// comme sur le design Stitch : FULL NAME, EMAIL ADDRESS, etc.)
class AppTextStyles {
  static const label = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: AppColors.textLabel,
    letterSpacing: 0.5,
  );

  static const title = TextStyle(
    fontSize: 26,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const subtitle = TextStyle(
    fontSize: 14,
    color: AppColors.textLabel,
  );
}
