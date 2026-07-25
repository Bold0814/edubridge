import 'package:flutter/material.dart';

/// Shared EduBridge color tokens — bright school-friendly light palette.
abstract final class AppColors {
  static const Color primary = Color(0xFF1565C0);
  static const Color success = Color(0xFF2E7D32);
  static const Color warning = Color(0xFFEF6C00);
  static const Color error = Color(0xFFC62828);
  static const Color grade = Color(0xFF7B1FA2);
  static const Color background = Color(0xFFF8FAFC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color onSurface = Color(0xFF1B1B1F);
  static const Color onSurfaceVariant = Color(0xFF44474E);
  static const Color outline = Color(0xFFD0D5DD);
  static const Color outlineSubtle = Color(0xFFE4E7EC);

  /// Semantic aliases used across modules.
  static const Color present = success;
  static const Color late = warning;
  static const Color absent = error;
  static const Color announcement = primary;
  static const Color homework = warning;
}
