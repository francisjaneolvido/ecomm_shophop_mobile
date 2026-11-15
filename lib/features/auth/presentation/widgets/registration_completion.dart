import 'package:flutter/material.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/auth/presentation/widgets/registration_success_dialog.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/features/auth/presentation/screens/application_status_screen.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/rider/presentation/screens/rider_application_status_screen.dart';

/// Called only by the successful OTP transition, never by login or app startup.
Future<void> completeRegistration(
  BuildContext context,
  AuthApiResult result,
) async {
  final role = result.data['account_type']?.toString() ?? 'buyer';
  final token = result.data['token']?.toString();
  final buyerReady =
      role == 'buyer' && result.data['application_status'] == 'approved';
  if (!result.success) return;
  // An already-verified public response proves no new verification transition.
  if (token == null || token.isEmpty) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
    return;
  }
  await AuthSessionService.saveSession(
    token: token,
    email: '${result.data['email']}',
    accountType: role,
    rememberMe: false,
  );
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => RegistrationSuccessDialog(
      title: buyerReady
          ? 'Account Verified!'
          : role == 'buyer'
          ? 'Email Verified!'
          : 'Application Submitted!',
      description: buyerReady
          ? 'Your ShopHop account is ready. Start exploring products and enjoy shopping.'
          : role == 'rider'
          ? 'Your Rider application has been forwarded to your selected Logistics Main Hub for review.'
          : role == 'seller'
          ? 'Your Seller application has been submitted successfully. You can track its review and approval status.'
          : 'Your email is verified. Your account is waiting for the required ShopHop administrator approval.',
      action: buyerReady
          ? 'Start Shopping'
          : role == 'rider'
          ? 'Track Application'
          : 'View Application Status',
      reference: result.data['reference']?.toString(),
      status: result.data['application_status']?.toString(),
    ),
  );
  if (!context.mounted) return;
  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(
      builder: (_) => role == 'rider'
          ? const RiderApplicationStatusScreen()
          : const ApplicationStatusScreen(),
    ),
    (_) => false,
  );
}
