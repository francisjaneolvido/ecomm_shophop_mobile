import 'package:flutter/material.dart';

/// ShopHop's single light palette: navy, pink and warm cream.
class AppColors {
  AppColors._();
  static const navy = Color(0xFF10193C);
  static const navyHover = Color(0xFF26305A);
  static const pink = Color(0xFFEDA3AE);
  static const pinkHover = Color(0xFFE1909E);
  static const pinkSoft = Color(0xFFFCECEF);
  static const cream = Color(0xFFFBF6EE);
  static const page = cream;
  static const surface = Color(0xFFFFFFFF);
  static const surfaceRaised = cream;
  static const surfaceSoft = Color(0xFFFFFAF6);
  static const text = navy;
  static const textMuted = Color(0xFF6B6B7B);
  static const textFaint = textMuted;
  static const border = Color(0x2610193C);
  static const input = surface;
  static const success = Color(0xFF1F9D55);
  static const successStrong = Color(0xFF166534);
  static const successSoft = Color(0xFFEAF7EE);
  static const error = Color(0xFFD93F4C);
  static const errorStrong = Color(0xFFA92F3A);
  static const errorSoft = Color(0xFFFFF0F2);
  static const warning = Color(0xFFF59E0B);

  // Compatibility aliases keep existing role screens on the shared palette.
  static const teal = navy;
  static const tealDark = navy;
  static const tealLight = pinkSoft;
  static const grayBg = page;
  static const grayBorder = border;
}
