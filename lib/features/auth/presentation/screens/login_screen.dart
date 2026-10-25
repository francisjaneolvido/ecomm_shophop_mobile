import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/presentation/screens/account_type_screen.dart';
import 'package:shophop/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:shophop/features/auth/domain/registration_role.dart';
import 'package:shophop/features/auth/presentation/widgets/account_status_toast.dart';
import 'package:shophop/features/buyer/presentation/screens/buyer_home_screen.dart';
import 'package:shophop/features/rider/presentation/screens/rider_home_screen.dart';
import 'package:shophop/features/logistics/presentation/screens/logistics_scanner_screen.dart';
import 'package:shophop/features/linehaul/presentation/screens/linehaul_driver_home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isSigningIn = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();

    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();

    super.dispose();
  }

  Future<void> _signIn() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isSigningIn) {
      return;
    }

    setState(() {
      _isSigningIn = true;
    });

    final result =
        await AuthService.login(
      email:
          _emailController.text,
      password:
          _passwordController.text,
      rememberMe:
          _rememberMe,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSigningIn = false;
    });

    if (!result.success) {
      _showMessage(
        result.message,
      );
      return;
    }

    final accountType =
        result.data['account_type']
            ?.toString();

    final reviewRole =
        _reviewRoleFromAccountType(
      accountType,
    );

    switch (result.status) {
      case 'email_unverified':
        if (reviewRole == null) {
          _showMessage(
            result.message,
          );
          return;
        }

        await showAccountStatusToast(
          context: context,
          role: reviewRole,
          status:
              AccountAccessStatus
                  .emailUnverified,
          email:
              _emailController.text
                  .trim(),
          onVerifyEmail: () {
            _openEmailVerification(
              accountType,
            );
          },
        );
        return;

      case 'pending':
        if (reviewRole == null) {
          _showMessage(
            result.message,
          );
          return;
        }

        await showAccountStatusToast(
          context: context,
          role: reviewRole,
          status:
              AccountAccessStatus
                  .pendingApproval,
          email:
              _emailController.text
                  .trim(),
        );
        return;

      case 'rejected':
        if (reviewRole == null) {
          _showMessage(
            result.message,
          );
          return;
        }

        await showAccountStatusToast(
          context: context,
          role: reviewRole,
          status:
              AccountAccessStatus
                  .rejected,
          email:
              _emailController.text
                  .trim(),
          rejectionReason:
              result.data[
                      'rejection_reason']
                  ?.toString(),
        );
        return;

      case 'suspended':
      case 'unavailable':
        _showMessage(
          result.message,
        );
        return;

      case 'approved':
        final token =
            result.data['token']
                ?.toString();

        if (token == null ||
            token.isEmpty) {
          _showMessage(
            'Login succeeded, but no mobile session token was returned.',
          );
          return;
        }

        if (accountType != 'buyer' &&
            accountType != 'rider' &&
            accountType != 'logistics' &&
            accountType != 'logistics_staff' &&
            accountType != 'branch' &&
            accountType != 'linehaul_driver') {
          await AuthService.logout(token: token);
          _showMessage(
            'Approved $accountType mobile dashboard is not connected yet.',
          );
          return;
        }

        await AuthSessionService.saveSession(
          token: token,
          email: _emailController.text.trim(),
          accountType: accountType!,
          rememberMe: _rememberMe,
        );

        if (!mounted) return;

        // Flutter Web can assert if an HTML text-editing element is removed
        // while it is still active. Explicitly hide the platform text input and
        // let the browser finish that frame before replacing the login route.
        FocusManager.instance.primaryFocus?.unfocus();
        try {
          await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
        } catch (_) {
          // Native platforms / browsers may already have closed the input.
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
        if (!mounted) return;

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => accountType == 'rider'
                ? const RiderHomeScreen()
                : accountType == 'linehaul_driver'
                    ? const LinehaulDriverHomeScreen()
                    : (accountType == 'logistics' ||
                            accountType == 'logistics_staff' ||
                            accountType == 'branch')
                        ? const LogisticsScannerScreen()
                        : const BuyerHomeScreen(),
          ),
          (route) => false,
        );
        return;

      default:
        _showMessage(
          result.message,
        );
    }
  }

  AccountReviewRole?
      _reviewRoleFromAccountType(
    String? accountType,
  ) {
    switch (accountType) {
      case 'buyer':
        return AccountReviewRole
            .buyer;
      case 'seller':
        return AccountReviewRole
            .seller;
      case 'rider':
        return AccountReviewRole
            .rider;
      default:
        return null;
    }
  }

  RegistrationRole?
      _verificationRoleFromAccountType(
    String? accountType,
  ) {
    switch (accountType) {
      case 'buyer':
        return RegistrationRole
            .buyer;
      case 'seller':
        return RegistrationRole
            .seller;
      case 'rider':
        return RegistrationRole
            .rider;
      default:
        return null;
    }
  }

  void _openEmailVerification(
    String? accountType,
  ) {
    final role =
        _verificationRoleFromAccountType(
      accountType,
    );

    if (role == null) {
      _showMessage(
        'Email verification is not available for this account type on mobile yet.',
      );
      return;
    }

    final email = _emailController.text.trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(
          email: email,
          role: role,
          onVerifyCode: (code) async {
            final result = role == RegistrationRole.rider
                ? await AuthService.verifyRiderEmail(email: email, code: code)
                : role == RegistrationRole.seller
                    ? await AuthService.verifySellerEmail(email: email, code: code)
                    : await AuthService.verifyBuyerEmail(email: email, code: code);
            return result.success ? null : result.message;
          },
          onResendCode: () async {
            final result = role == RegistrationRole.rider
                ? await AuthService.resendRiderVerification(email: email)
                : role == RegistrationRole.seller
                    ? await AuthService.resendSellerVerification(email: email)
                    : await AuthService.resendBuyerVerification(email: email);
            return result.success ? null : result.message;
          },
          onVerified: () {
            if (!mounted) return;
            Navigator.pop(context);
            _showMessage(
              role == RegistrationRole.rider
                  ? 'Email verified. Your Rider application is now waiting for Logistics / Sorting Center approval.'
                  : 'Email verified. Your account is now waiting for administrator approval.',
            );
          },
        ),
      ),
    );
  }

  void _continueWithGoogle() {
    FocusScope.of(context).unfocus();

    _showMessage(
      'Google sign-in is available on ShopHop Web, but the mobile OAuth callback/token endpoint is not exposed in this mobile project yet.',
    );
  }

  void _forgotPassword() {
    FocusScope.of(context).unfocus();

    _showMessage(
      'Forgot password flow will be added next.',
    );
  }

  void _signUp() {
  FocusScope.of(context).unfocus();

  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) =>
          const AccountTypeScreen(),
    ),
  );
}

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.navy,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Please enter your email address.';
    }

    final emailPattern = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailPattern.hasMatch(email)) {
      return 'Please enter a valid email address.';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 700;

    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(24, compact ? 18 : 26, 24, 28),
                child: AutofillGroup(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: Container(
                            width: compact ? 66 : 72,
                            height: compact ? 66 : 72,
                            padding: const EdgeInsets.all(11),
                            decoration: BoxDecoration(
                              color: AppColors.tealLight.withValues(alpha: .48),
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              'assets/images/logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 20 : 26),
                        const Text(
                          'Welcome to ShopHop',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.navy,
                            fontWeight: FontWeight.w800,
                            fontSize: 28,
                            letterSpacing: -.8,
                          ),
                        ),
                        const SizedBox(height: 7),
                        Text(
                          "Sign in to continue or create an account if you're new.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: AppColors.navy.withValues(alpha: .58),
                            height: 1.55,
                            fontSize: 12.5,
                          ),
                        ),
                        SizedBox(height: compact ? 20 : 24),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 13,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tealLight.withValues(alpha: .38),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: AppColors.teal.withValues(alpha: .18),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Icon(
                                  Icons.info_outline_rounded,
                                  size: 17,
                                  color: AppColors.tealDark,
                                ),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  'Logistics staff can sign in using their approved account.',
                                  style: TextStyle(
                                    color: AppColors.navy.withValues(alpha: .72),
                                    fontSize: 10.8,
                                    height: 1.45,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: compact ? 22 : 27),
                        const Text(
                          'Email address',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocusNode,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.username,
                            AutofillHints.email,
                          ],
                          validator: _validateEmail,
                          decoration: const InputDecoration(
                            hintText: 'you@example.com',
                            prefixIcon: Icon(
                              Icons.mail_outline_rounded,
                              size: 20,
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Password',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          validator: _validatePassword,
                          onFieldSubmitted: (_) => _signIn(),
                          decoration: InputDecoration(
                            hintText: 'Enter your password',
                            prefixIcon: const Icon(
                              Icons.lock_outline_rounded,
                              size: 20,
                            ),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Theme(
                              data: Theme.of(context).copyWith(
                                checkboxTheme: CheckboxThemeData(
                                  fillColor: WidgetStateProperty.resolveWith<Color>(
                                    (states) => states.contains(WidgetState.selected)
                                        ? AppColors.teal
                                        : Colors.transparent,
                                  ),
                                  checkColor: const WidgetStatePropertyAll<Color>(
                                    Colors.white,
                                  ),
                                  side: const BorderSide(
                                    color: AppColors.navy,
                                    width: 1.4,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                ),
                              ),
                              child: Checkbox(
                                value: _rememberMe,
                                visualDensity: VisualDensity.compact,
                                onChanged: (value) => setState(
                                  () => _rememberMe = value ?? false,
                                ),
                              ),
                            ),
                            InkWell(
                              borderRadius: BorderRadius.circular(8),
                              onTap: () => setState(
                                () => _rememberMe = !_rememberMe,
                              ),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 8,
                                ),
                                child: Text(
                                  'Remember me',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.navy,
                                  ),
                                ),
                              ),
                            ),
                            const Spacer(),
                            TextButton(
                              onPressed: _forgotPassword,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.tealDark,
                                padding: const EdgeInsets.symmetric(horizontal: 4),
                              ),
                              child: const Text(
                                'Forgot password?',
                                style: TextStyle(fontSize: 11.5),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          height: 52,
                          child: FilledButton(
                            onPressed: _isSigningIn ? null : _signIn,
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.teal,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor:
                                  AppColors.teal.withValues(alpha: .48),
                              disabledForegroundColor: Colors.white,
                              elevation: 0,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: _isSigningIn
                                ? const SizedBox(
                                    width: 19,
                                    height: 19,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign in',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: compact ? 20 : 24),
                        Row(
                          children: [
                            const Expanded(
                              child: Divider(color: AppColors.grayBorder),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'or continue with',
                                style: TextStyle(
                                  color: AppColors.navy.withValues(alpha: .46),
                                  fontSize: 10.8,
                                ),
                              ),
                            ),
                            const Expanded(
                              child: Divider(color: AppColors.grayBorder),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 52,
                          child: OutlinedButton.icon(
                            onPressed: _isSigningIn ? null : _continueWithGoogle,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.navy,
                              backgroundColor: Colors.white,
                              side: const BorderSide(
                                color: AppColors.grayBorder,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            icon: const _GoogleIcon(),
                            label: const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: compact ? 18 : 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'New to ShopHop?',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.navy.withValues(alpha: .6),
                              ),
                            ),
                            TextButton(
                              onPressed: _signUp,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.tealDark,
                                padding: const EdgeInsets.symmetric(horizontal: 7),
                              ),
                              child: const Text('Create an account'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

}


class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 19,
      height: 19,
      child: CustomPaint(
        painter: _GoogleIconPainter(),
      ),
    );
  }
}

class _GoogleIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.17;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - stroke / 2;

    Paint makePaint(Color color) {
      return Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
    }

    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawArc(
      rect,
      -0.30,
      1.20,
      false,
      makePaint(const Color(0xFF4285F4)),
    );
    canvas.drawArc(
      rect,
      0.95,
      0.80,
      false,
      makePaint(const Color(0xFF34A853)),
    );
    canvas.drawArc(
      rect,
      1.82,
      0.82,
      false,
      makePaint(const Color(0xFFFBBC05)),
    );
    canvas.drawArc(
      rect,
      2.72,
      1.20,
      false,
      makePaint(const Color(0xFFEA4335)),
    );
    canvas.drawLine(
      Offset(size.width * 0.55, size.height * 0.52),
      Offset(size.width * 0.92, size.height * 0.52),
      makePaint(const Color(0xFF4285F4)),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
