import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';

/// Shared presentation for all roles, following the web's light theme.
/// Mobile keeps readable type and 48 logical pixel touch targets.
class AppTheme {
  AppTheme._();

  static const double screenPadding = 16;
  static const double cardRadius = 8;
  static const double inputRadius = 6;
  static const double controlHeight = 48;
  static const double touchTarget = 48;
  static const double dialogRadius = 10;
  static const double sectionRadius = 8;

  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);
    final text = base.textTheme
        .copyWith(
          headlineLarge: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            height: 1.25,
            letterSpacing: -.6,
          ),
          headlineMedium: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w800,
            height: 1.3,
            letterSpacing: -.5,
          ),
          headlineSmall: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            height: 1.3,
            letterSpacing: -.4,
          ),
          titleLarge: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.35,
            letterSpacing: -.35,
          ),
          titleMedium: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            height: 1.4,
            letterSpacing: -.25,
          ),
          titleSmall: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.4,
          ),
          bodyLarge: const TextStyle(fontSize: 16, height: 1.5),
          bodyMedium: const TextStyle(fontSize: 14, height: 1.5),
          bodySmall: const TextStyle(fontSize: 12, height: 1.5),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.4,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        )
        .apply(
          fontFamily: 'Poppins',
          bodyColor: AppColors.text,
          displayColor: AppColors.text,
        );
    const selected = AppColors.tealDark;
    const unselected = AppColors.textMuted;
    const scheme = ColorScheme.light(
      primary: selected,
      onPrimary: Colors.white,
      primaryContainer: AppColors.tealLight,
      onPrimaryContainer: AppColors.navy,
      secondary: selected,
      onSecondary: Colors.white,
      secondaryContainer: AppColors.tealLight,
      onSecondaryContainer: AppColors.navy,
      tertiary: selected,
      onTertiary: Colors.white,
      tertiaryContainer: AppColors.tealLight,
      onTertiaryContainer: AppColors.navy,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      surfaceDim: AppColors.surfaceRaised,
      surfaceBright: AppColors.surface,
      surfaceContainerLowest: AppColors.page,
      surfaceContainerLow: AppColors.surfaceSoft,
      surfaceContainer: AppColors.surfaceRaised,
      surfaceContainerHigh: AppColors.surfaceRaised,
      surfaceContainerHighest: AppColors.input,
      onSurfaceVariant: AppColors.textMuted,
      error: AppColors.error,
      onError: Colors.white,
      errorContainer: AppColors.errorSoft,
      onErrorContainer: AppColors.error,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      inverseSurface: AppColors.navy,
      onInverseSurface: Colors.white,
      inversePrimary: AppColors.tealLight,
      surfaceTint: Colors.transparent,
      shadow: AppColors.navy,
      scrim: AppColors.navy,
    );
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(inputRadius),
      borderSide: const BorderSide(color: AppColors.border),
    );
    final controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(inputRadius),
    );
    final navLabel = text.labelSmall!;

    return base.copyWith(
      primaryColor: selected,
      scaffoldBackgroundColor: AppColors.surfaceRaised,
      canvasColor: scheme.surface,
      colorScheme: scheme,
      textTheme: text,
      primaryTextTheme: text.apply(
        bodyColor: scheme.onPrimary,
        displayColor: scheme.onPrimary,
      ),
      disabledColor: AppColors.textFaint,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      splashColor: AppColors.tealLight.withValues(alpha: .56),
      highlightColor: AppColors.tealLight.withValues(alpha: .28),
      iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: text.titleLarge,
        iconTheme: IconThemeData(color: scheme.onSurface, size: 22),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        isDense: false,
        filled: true,
        fillColor: AppColors.input,
        hintStyle: text.bodyMedium?.copyWith(color: AppColors.textFaint),
        labelStyle: text.bodyMedium?.copyWith(color: unselected),
        helperStyle: text.bodySmall?.copyWith(color: unselected),
        errorStyle: text.bodySmall?.copyWith(color: scheme.error),
        prefixIconColor: unselected,
        suffixIconColor: unselected,
        constraints: const BoxConstraints(minHeight: controlHeight),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        disabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: const BorderSide(color: selected, width: 1.7),
        ),
        errorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 1.7),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          elevation: 0,
          shadowColor: Colors.transparent,
          backgroundColor: selected,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: AppColors.surfaceRaised,
          disabledForegroundColor: AppColors.textFaint,
          minimumSize: const Size(touchTarget, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: text.labelLarge,
          shape: controlShape,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: selected,
          foregroundColor: scheme.onPrimary,
          disabledBackgroundColor: AppColors.surfaceRaised,
          disabledForegroundColor: AppColors.textFaint,
          minimumSize: const Size(touchTarget, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          textStyle: text.labelLarge,
          shape: controlShape,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.onSurface,
          disabledForegroundColor: AppColors.textFaint,
          minimumSize: const Size(touchTarget, controlHeight),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          side: BorderSide(color: scheme.outline),
          textStyle: text.labelLarge,
          shape: controlShape,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: selected,
          disabledForegroundColor: AppColors.textFaint,
          minimumSize: const Size(touchTarget, controlHeight),
          textStyle: text.labelMedium,
          shape: controlShape,
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: scheme.onSurface,
          disabledForegroundColor: AppColors.textFaint,
          minimumSize: const Size.square(touchTarget),
        ),
      ),
      cardTheme: CardThemeData(
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
          side: BorderSide(color: scheme.outline),
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: selected,
        textColor: scheme.onSurface,
        titleTextStyle: text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        subtitleTextStyle: text.bodySmall?.copyWith(color: unselected),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        shape: controlShape,
      ),
      dividerTheme: DividerThemeData(color: scheme.outline, thickness: 1),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceSoft,
        selectedColor: scheme.primaryContainer,
        secondarySelectedColor: scheme.primaryContainer,
        disabledColor: AppColors.surfaceRaised,
        labelStyle: text.labelMedium?.copyWith(color: scheme.onSurface),
        secondaryLabelStyle: text.labelMedium?.copyWith(
          color: scheme.onPrimaryContainer,
        ),
        checkmarkColor: scheme.onPrimaryContainer,
        side: BorderSide(color: scheme.outline),
        shape: controlShape,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: scheme.inverseSurface,
        contentTextStyle: text.bodySmall?.copyWith(
          color: scheme.onInverseSurface,
        ),
        actionTextColor: scheme.inversePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dialogRadius),
        ),
        titleTextStyle: text.titleMedium,
        contentTextStyle: text.bodyMedium?.copyWith(color: unselected),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: scheme.surface,
        modalBackgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(dialogRadius),
          ),
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        type: BottomNavigationBarType.fixed,
        backgroundColor: scheme.surface,
        selectedItemColor: selected,
        unselectedItemColor: unselected,
        selectedLabelStyle: navLabel.copyWith(fontWeight: FontWeight.w700),
        unselectedLabelStyle: navLabel.copyWith(fontWeight: FontWeight.w500),
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 24),
        showUnselectedLabels: true,
        elevation: 0,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 70,
        backgroundColor: scheme.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: Colors.transparent,
        iconTheme: WidgetStateProperty.resolveWith<IconThemeData>(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? selected
                : unselected,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>(
          (states) => navLabel.copyWith(
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? selected
                : unselected,
          ),
        ),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: scheme.error,
        textColor: scheme.onError,
        textStyle: text.labelSmall?.copyWith(
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
        largeSize: 18,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: selected),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.surfaceRaised;
          }
          return states.contains(WidgetState.selected)
              ? selected
              : Colors.transparent;
        }),
        checkColor: WidgetStatePropertyAll<Color>(scheme.onPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.textFaint;
          return states.contains(WidgetState.selected) ? selected : unselected;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.border;
          return states.contains(WidgetState.selected)
              ? scheme.onPrimary
              : unselected;
        }),
        trackColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.surfaceRaised;
          }
          return states.contains(WidgetState.selected)
              ? selected
              : AppColors.border;
        }),
        trackOutlineColor: const WidgetStatePropertyAll<Color>(
          Colors.transparent,
        ),
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(cardRadius),
        ),
      ),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: selected,
        selectionColor: AppColors.tealLight,
        selectionHandleColor: selected,
      ),
    );
  }
}
