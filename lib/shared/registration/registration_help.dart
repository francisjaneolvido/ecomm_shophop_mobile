import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:shophop/core/config/api_config.dart';

Future<void> openRegistrationHelp(BuildContext context) async {
  try {
    if (await launchUrl(
      ApiConfig.serverOrigin.resolve('/help'),
      mode: LaunchMode.externalApplication,
    )) {
      return;
    }
  } catch (_) {
    // Keep the application and any entered form information available.
  }
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Unable to open the Help Center. Please try again.'),
    ),
  );
}
