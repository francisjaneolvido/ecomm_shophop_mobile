import 'package:flutter/material.dart';
import 'package:shophop/core/theme/app_colors.dart';

/// Brand accents for entry and registration screens, independent of workspace themes.
class ShopHopAuthTheme extends StatelessWidget {
  const ShopHopAuthTheme({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final focused = OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: AppColors.pink, width: 1.5),
    );
    return Theme(
      data: base.copyWith(
        primaryColor: AppColors.pink,
        colorScheme: base.colorScheme.copyWith(
          primary: AppColors.pink,
          onPrimary: Colors.white,
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          focusedBorder: focused,
          floatingLabelStyle: const TextStyle(color: AppColors.pink),
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: AppColors.pink,
          selectionColor: AppColors.pinkSoft,
          selectionHandleColor: AppColors.pink,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.pink,
            foregroundColor: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.pink,
            foregroundColor: Colors.white,
          ),
        ),
      ),
      child: child,
    );
  }
}
