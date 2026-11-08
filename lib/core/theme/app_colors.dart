import 'package:flutter/material.dart';

/// Shared light palette from the web's partials/theme-head.blade.php.
/// Keep the existing brand names available for screens migrating to tokens.
class AppColors {
  AppColors._();

  static const navy = Color(0xFF0F1B3D);
  static const teal = Color(0xFF21C3A6);
  static const tealDark = Color(0xFF18A98E);
  static const tealLight = Color(0xFFD4F5EE);

  static const page = Color(0xFFFFFFFF);
  static const surface = Color(0xFFFFFFFF);
  static const surfaceRaised = Color(0xFFF3F5F7);
  static const surfaceSoft = Color(0xFFF8FAFB);
  static const text = navy;
  static const textMuted = Color(0xFF59667A);
  static const textFaint = Color(0xFF748095);
  static const border = Color(0xFFE2E6EA);
  static const input = surfaceRaised;
  static const error = Color(0xFFB42318);
  static const errorSoft = Color(0xFFFEE4E2);

  // Compatibility aliases used by existing Buyer, Seller and Rider screens.
  static const grayBg = surfaceRaised;
  static const grayBorder = border;
}
