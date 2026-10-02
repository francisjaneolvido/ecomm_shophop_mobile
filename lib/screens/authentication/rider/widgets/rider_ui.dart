import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../theme/app_colors.dart';

class RiderUi {
  RiderUi._();

  static TextStyle text({
    Color color = AppColors.navy,
    double fontSize = 13,
    FontWeight fontWeight = FontWeight.w400,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.poppins(
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  static Widget requiredLabel(String label) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: label),
          TextSpan(
            text: ' *',
            style: text(
              color: const Color(0xFFDB5757),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      style: text(
        color: AppColors.navy,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  static InputDecoration inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: text(
        color: AppColors.navy.withValues(alpha: 0.28),
        fontSize: 12,
      ),
      prefixIcon: Icon(
        icon,
        size: 19,
        color: AppColors.navy.withValues(alpha: 0.35),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: AppColors.grayBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: AppColors.teal,
          width: 1.5,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFDB5757)),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFFDB5757),
          width: 1.5,
        ),
      ),
      errorStyle: text(
        color: const Color(0xFFDB5757),
        fontSize: 10,
        fontWeight: FontWeight.w500,
        height: 1.3,
      ),
    );
  }
}
