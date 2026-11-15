import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shophop/core/theme/app_colors.dart';

/// Buyer pages use the same pink header and cream surfaces as the Rider app.
class BuyerScaffold extends StatelessWidget {
  const BuyerScaffold({
    super.key,
    this.appBar,
    this.body,
    this.bottomNavigationBar,
    this.backgroundColor = AppColors.page,
  });

  final PreferredSizeWidget? appBar;
  final Widget? body, bottomNavigationBar;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(6),
    );
    return Theme(
      data: base.copyWith(
        colorScheme: base.colorScheme.copyWith(
          primary: AppColors.pink,
          onPrimary: Colors.white,
          primaryContainer: AppColors.pinkSoft,
          onPrimaryContainer: AppColors.navy,
          onSecondary: Colors.white,
        ),
        primaryColor: AppColors.pink,
        scaffoldBackgroundColor: AppColors.page,
        filledButtonTheme: FilledButtonThemeData(
          style: (base.filledButtonTheme.style ?? const ButtonStyle()).merge(
            FilledButton.styleFrom(
              backgroundColor: AppColors.pink,
              foregroundColor: Colors.white,
              shape: shape,
            ),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: (base.elevatedButtonTheme.style ?? const ButtonStyle()).merge(
            ElevatedButton.styleFrom(
              backgroundColor: AppColors.pink,
              foregroundColor: Colors.white,
              shape: shape,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: (base.textButtonTheme.style ?? const ButtonStyle()).merge(
            TextButton.styleFrom(foregroundColor: AppColors.pink),
          ),
        ),
        inputDecorationTheme: base.inputDecorationTheme.copyWith(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(6),
            borderSide: const BorderSide(color: AppColors.pink, width: 1.7),
          ),
        ),
        progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.pink,
        ),
      ),
      child: Scaffold(
        backgroundColor: backgroundColor,
        appBar: appBar,
        body: body,
        bottomNavigationBar: bottomNavigationBar,
      ),
    );
  }
}

class BuyerAppBar extends AppBar {
  BuyerAppBar({
    super.key,
    super.title,
    Widget? leading,
    super.automaticallyImplyLeading = true,
    super.toolbarHeight = 64,
    super.titleSpacing = 14,
    List<Widget>? actions,
  }) : super(
         leading: leading == null
             ? null
             : IconButtonTheme(
                 data: IconButtonThemeData(
                   style: IconButton.styleFrom(
                     foregroundColor: Colors.white,
                     disabledForegroundColor: Colors.white54,
                   ),
                 ),
                 child: leading,
               ),
         backgroundColor: AppColors.pink,
         foregroundColor: Colors.white,
         surfaceTintColor: Colors.transparent,
         elevation: 0,
         scrolledUnderElevation: 0,
         systemOverlayStyle: SystemUiOverlayStyle.light,
         titleTextStyle: const TextStyle(
           fontFamily: 'Poppins',
           fontSize: 18,
           fontWeight: FontWeight.w600,
           color: Colors.white,
         ),
         iconTheme: const IconThemeData(color: Colors.white, size: 22),
         actionsIconTheme: const IconThemeData(color: Colors.white, size: 22),
         actions: actions
             ?.map(
               (child) => TextButtonTheme(
                 data: TextButtonThemeData(
                   style: TextButton.styleFrom(
                     foregroundColor: Colors.white,
                     disabledForegroundColor: Colors.white54,
                   ),
                 ),
                 child: IconButtonTheme(
                   data: IconButtonThemeData(
                     style: IconButton.styleFrom(
                       foregroundColor: Colors.white,
                       disabledForegroundColor: Colors.white54,
                     ),
                   ),
                   child: child,
                 ),
               ),
             )
             .toList(),
       );
}

class BuyerPageHeading extends StatelessWidget {
  const BuyerPageHeading({super.key, required this.title, required this.icon});
  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: .18),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Icon(icon, size: 21, color: Colors.white),
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (MediaQuery.textScalerOf(context).scale(11) <= 15.4)
              const Text(
                'ShopHop Buyer',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: Colors.white,
                ),
              ),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}
