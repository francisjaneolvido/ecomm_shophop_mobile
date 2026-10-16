import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shophop/core/theme/app_colors.dart';

/// ShopHop's single source of truth for Buyer, Seller and Rider presentation.
/// This file contains only visual tokens. It never changes domain/API behavior.
class AppTheme {
  AppTheme._();

  static const double screenPadding = 16;
  static const double cardRadius = 18;
  static const double inputRadius = 14;
  static const double controlHeight = 50;
  static const double touchTarget = 48;

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final text = GoogleFonts.poppinsTextTheme(base.textTheme).apply(
      bodyColor: AppColors.navy,
      displayColor: AppColors.navy,
    );
    const selected = Color(0xFF087968);
    const unselected = Color(0xFF526177);
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(inputRadius),
      borderSide: const BorderSide(color: AppColors.grayBorder),
    );

    return base.copyWith(
      primaryColor: AppColors.tealDark,
      scaffoldBackgroundColor: AppColors.grayBg,
      canvasColor: Colors.white,
      splashColor: AppColors.tealLight.withValues(alpha: .56),
      highlightColor: AppColors.tealLight.withValues(alpha: .28),
      colorScheme: const ColorScheme.light(
        primary: AppColors.tealDark,
        onPrimary: Colors.white,
        secondary: AppColors.navy,
        onSecondary: Colors.white,
        surface: Colors.white,
        onSurface: AppColors.navy,
        error: Color(0xFFB42318),
        outline: AppColors.grayBorder,
      ),
      textTheme: text,
      primaryTextTheme: text,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.navy,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
        iconTheme: const IconThemeData(color: AppColors.navy, size: 22),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        isDense: false,
        filled: true,
        fillColor: Colors.white,
        hintStyle: text.bodySmall?.copyWith(color: unselected),
        labelStyle: text.bodySmall?.copyWith(color: unselected),
        helperStyle: text.bodySmall?.copyWith(color: unselected),
        prefixIconColor: unselected,
        suffixIconColor: unselected,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: AppColors.grayBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: selected, width: 1.7),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: Color(0xFFDC6A6A)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(inputRadius),
          borderSide: const BorderSide(color: Color(0xFFB42318), width: 1.6),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor: selected,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: selected,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE6EAED),
          disabledForegroundColor: unselected,
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.navy,
          minimumSize: const Size(0, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
          side: const BorderSide(color: AppColors.grayBorder),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: selected,
          minimumSize: const Size(48, 44),
          textStyle: text.labelMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: const BorderSide(color: AppColors.grayBorder),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.tealDark,
        textColor: AppColors.navy,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.grayBorder, thickness: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.navy,
        contentTextStyle: text.bodySmall?.copyWith(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        titleTextStyle: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: AppColors.navy,
        ),
        contentTextStyle: text.bodyMedium?.copyWith(color: unselected, height: 1.5),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: Colors.white,
        modalBackgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: selected,
        unselectedItemColor: unselected,
        selectedLabelStyle: text.labelSmall?.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: text.labelSmall?.copyWith(fontWeight: FontWeight.w500),
        showUnselectedLabels: true,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent, // deliberately no selected oval
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
          return IconThemeData(
            size: 23,
            color: states.contains(WidgetState.selected) ? selected : unselected,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((states) {
          return (text.labelSmall ?? const TextStyle(fontSize: 11)).copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? selected : unselected,
          );
        }),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: selected),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) =>
            states.contains(WidgetState.selected) ? selected : Colors.transparent),
        checkColor: const WidgetStatePropertyAll<Color>(Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) =>
            states.contains(WidgetState.selected) ? selected : unselected),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: selected,
        selectionColor: AppColors.tealLight,
        selectionHandleColor: selected,
      ),
    );
  }
}
