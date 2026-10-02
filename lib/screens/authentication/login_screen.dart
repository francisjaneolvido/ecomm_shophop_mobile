import 'package:flutter/material.dart';

import '../../services/auth_service.dart';
import '../../services/auth_session_service.dart';
import '../../theme/app_colors.dart';
import 'account_type_screen.dart';
import 'verification/email_verification_screen.dart';
import 'verification/registration_role.dart';
import 'widgets/account_status_toast.dart';
import '../buyer/buyer_home_screen.dart';

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

        if (accountType != 'buyer') {
          await AuthService.logout(
            token: token,
          );

          _showMessage(
            'Approved $accountType mobile dashboard will be connected after the Buyer flow.',
          );
          return;
        }

        await AuthSessionService
            .saveSession(
          token: token,
          email:
              _emailController.text
                  .trim(),
          accountType:
              accountType!,
        );

        if (!mounted) {
          return;
        }

        // Flutter Web can assert if a focused HTML text input is removed
        // during navigation. Clear focus first, then navigate on the next tick.
        FocusManager.instance.primaryFocus?.unfocus();
        await Future<void>.delayed(const Duration(milliseconds: 50));

        if (!mounted) {
          return;
        }

        Navigator.of(context)
            .pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) =>
                const BuyerHomeScreen(),
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

    if (role !=
        RegistrationRole.buyer) {
      _showMessage(
        'This mobile verification endpoint will be connected after the Buyer flow is confirmed.',
      );
      return;
    }

    final email =
        _emailController.text
            .trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EmailVerificationScreen(
          email: email,
          role: role,
          onVerifyCode:
              (code) async {
            final result =
                await AuthService
                    .verifyBuyerEmail(
              email: email,
              code: code,
            );

            return result.success
                ? null
                : result.message;
          },
          onResendCode:
              () async {
            final result =
                await AuthService
                    .resendBuyerVerification(
              email: email,
            );

            return result.success
                ? null
                : result.message;
          },
          onVerified: () {
            if (!mounted) {
              return;
            }

            Navigator.pop(context);

            _showMessage(
              'Email verified. Your account is now waiting for administrator approval.',
            );
          },
        ),
      ),
    );
  }

  void _continueWithGoogle() {
    FocusScope.of(context).unfocus();

    _showMessage(
      'Google Sign-In will be connected to the backend next.',
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
    return Scaffold(
      backgroundColor: Colors.white,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                  ),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      // ===============================
                      // TOP BRAND / DECORATION
                      // ===============================

                      _buildHeaderDecoration(),

                      // ===============================
                      // LOGIN CONTENT
                      // ===============================

                      Padding(
                        padding:
                            const EdgeInsets.fromLTRB(
                          24,
                          0,
                          24,
                          28,
                        ),
                        child: AutofillGroup(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                _buildTitle(),

                                const SizedBox(height: 26),

                                _buildGoogleButton(),

                                const SizedBox(height: 22),

                                _buildDivider(),

                                const SizedBox(height: 24),

                                _buildEmailField(),

                                const SizedBox(height: 22),

                                _buildPasswordField(),

                                const SizedBox(height: 15),

                                _buildRememberAndForgot(),

                                const SizedBox(height: 30),

                                _buildSignInButton(),

                                const SizedBox(height: 18),

                                _buildApprovalNote(),

                                const SizedBox(height: 28),

                                _buildSignUp(),

                                const SizedBox(height: 12),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeaderDecoration() {
    return SizedBox(
      height: 220,
      width: double.infinity,
      child: ClipPath(
        clipper: _LoginHeaderClipper(),
        child: Container(
          color: AppColors.tealLight,
          child: Stack(
            children: [
              // Contour pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: _ContourPainter(),
                ),
              ),

              // Subtle decorative circles
              Positioned(
                top: -35,
                left: -30,
                child: _decorativeCircle(120),
              ),

              Positioned(
                right: -48,
                bottom: 12,
                child: _decorativeCircle(135),
              ),

              // Brand
              Positioned(
                top: 32,
                left: 24,
                right: 24,
                child: Row(
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius:
                            BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.navy
                                .withValues(
                              alpha: 0.06,
                            ),
                            blurRadius: 20,
                            offset: const Offset(
                              0,
                              7,
                            ),
                          ),
                        ],
                      ),
                      child: Image.asset(
                        'assets/images/logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'ShopHop',
                            style: TextStyle(
                              color: AppColors.navy,
                              fontSize: 18,
                              height: 1,
                              fontWeight:
                                  FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),

                          const SizedBox(height: 5),

                          Text(
                            'HOP IN. SHOP MORE.',
                            style: TextStyle(
                              color: AppColors.navy
                                  .withValues(
                                alpha: 0.48,
                              ),
                              fontSize: 8,
                              fontWeight:
                                  FontWeight.w700,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _decorativeCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(
            alpha: 0.38,
          ),
          width: 1.2,
        ),
      ),
    );
  }

  // ============================================================
  // TITLE
  // ============================================================

  Widget _buildTitle() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Sign in',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 32,
            height: 1.05,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),

        const SizedBox(height: 9),

        Container(
          width: 46,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.teal,
            borderRadius:
                BorderRadius.circular(100),
          ),
        ),

        const SizedBox(height: 14),

        Text(
          'Welcome back. Sign in to continue your ShopHop experience.',
          style: TextStyle(
            color: AppColors.navy.withValues(
              alpha: 0.53,
            ),
            fontSize: 13,
            height: 1.55,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // GOOGLE
  // ============================================================

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: OutlinedButton(
        onPressed: _continueWithGoogle,
        style: OutlinedButton.styleFrom(
          elevation: 0,
          backgroundColor: Colors.white,
          foregroundColor: AppColors.navy,
          side: const BorderSide(
            color: AppColors.grayBorder,
            width: 1,
          ),
          padding:
              const EdgeInsets.symmetric(
            horizontal: 18,
          ),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15),
          ),
        ),
        child: const Row(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            _GoogleIcon(),

            SizedBox(width: 12),

            Text(
              'Continue with Google',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // DIVIDER
  // ============================================================

  Widget _buildDivider() {
    return Row(
      children: [
        const Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.grayBorder,
          ),
        ),

        Padding(
          padding:
              const EdgeInsets.symmetric(
            horizontal: 13,
          ),
          child: Text(
            'or sign in with email',
            style: TextStyle(
              color: AppColors.navy
                  .withValues(
                alpha: 0.34,
              ),
              fontSize: 10,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: AppColors.grayBorder,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // EMAIL
  // ============================================================

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Email',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),

        TextFormField(
          controller: _emailController,
          focusNode: _emailFocusNode,
          keyboardType:
              TextInputType.emailAddress,
          textInputAction:
              TextInputAction.next,
          validator: _validateEmail,
          autofillHints: const [
            AutofillHints.email,
            AutofillHints.username,
          ],
          onFieldSubmitted: (_) {
            _passwordFocusNode
                .requestFocus();
          },
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration:
              _inputDecoration(
            hintText: 'you@example.com',
            icon: Icons.mail_outline_rounded,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PASSWORD
  // ============================================================

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Password',
          style: TextStyle(
            color: AppColors.navy,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),

        TextFormField(
          controller:
              _passwordController,
          focusNode:
              _passwordFocusNode,
          obscureText:
              _obscurePassword,
          textInputAction:
              TextInputAction.done,
          validator:
              _validatePassword,
          autofillHints: const [
            AutofillHints.password,
          ],
          onFieldSubmitted: (_) {
            _signIn();
          },
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
          decoration:
              _inputDecoration(
            hintText:
                'Enter your password',
            icon:
                Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              tooltip: _obscurePassword
                  ? 'Show password'
                  : 'Hide password',
              onPressed: () {
                setState(() {
                  _obscurePassword =
                      !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons
                        .visibility_outlined
                    : Icons
                        .visibility_off_outlined,
                size: 20,
                color: AppColors.navy
                    .withValues(
                  alpha: 0.34,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // INPUT DECORATION
  // ============================================================

  InputDecoration _inputDecoration({
    required String hintText,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hintText,

      hintStyle: TextStyle(
        color: AppColors.navy.withValues(
          alpha: 0.28,
        ),
        fontSize: 13,
      ),

      prefixIcon: Icon(
        icon,
        size: 18,
        color: AppColors.navy.withValues(
          alpha: 0.35,
        ),
      ),

      prefixIconConstraints:
          const BoxConstraints(
        minWidth: 32,
        minHeight: 40,
      ),

      contentPadding:
          const EdgeInsets.symmetric(
        vertical: 14,
      ),

      enabledBorder:
          UnderlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.navy
              .withValues(
            alpha: 0.13,
          ),
          width: 1,
        ),
      ),

      focusedBorder:
          const UnderlineInputBorder(
        borderSide: BorderSide(
          color: AppColors.teal,
          width: 1.7,
        ),
      ),

      errorBorder:
          const UnderlineInputBorder(
        borderSide: BorderSide(
          color: Color(0xFFDE5B5B),
          width: 1.2,
        ),
      ),

      focusedErrorBorder:
          const UnderlineInputBorder(
        borderSide: BorderSide(
          color: Color(0xFFDE5B5B),
          width: 1.7,
        ),
      ),

      errorStyle: const TextStyle(
        fontSize: 10,
        height: 1.2,
      ),
    );
  }

  // ============================================================
  // REMEMBER + FORGOT
  // ============================================================

  Widget _buildRememberAndForgot() {
    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              setState(() {
                _rememberMe =
                    !_rememberMe;
              });
            },
            borderRadius:
                BorderRadius.circular(8),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(
                vertical: 5,
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: Checkbox(
                      value:
                          _rememberMe,
                      onChanged: (value) {
                        setState(() {
                          _rememberMe =
                              value ??
                                  false;
                        });
                      },
                      activeColor:
                          AppColors.teal,
                      checkColor:
                          Colors.white,
                      materialTapTargetSize:
                          MaterialTapTargetSize
                              .shrinkWrap,
                      side: BorderSide(
                        color: AppColors
                            .navy
                            .withValues(
                          alpha: 0.18,
                        ),
                        width: 1.4,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius
                                .circular(4),
                      ),
                    ),
                  ),

                  const SizedBox(
                    width: 8,
                  ),

                  Text(
                    'Remember me',
                    style: TextStyle(
                      color:
                          AppColors.navy
                              .withValues(
                        alpha: 0.53,
                      ),
                      fontSize: 11,
                      fontWeight:
                          FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        TextButton(
          onPressed:
              _forgotPassword,
          style:
              TextButton.styleFrom(
            foregroundColor:
                AppColors.tealDark,
            padding:
                const EdgeInsets.symmetric(
              horizontal: 0,
              vertical: 6,
            ),
            minimumSize:
                Size.zero,
            tapTargetSize:
                MaterialTapTargetSize
                    .shrinkWrap,
          ),
          child: const Text(
            'Forgot Password?',
            style: TextStyle(
              fontSize: 11,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SIGN IN BUTTON
  // ============================================================

  Widget _buildSignInButton() {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed:
            _isSigningIn
                ? null
                : _signIn,
        style:
            ElevatedButton.styleFrom(
          elevation: 0,
          backgroundColor:
              AppColors.teal,
          foregroundColor:
              Colors.white,
          disabledBackgroundColor:
              AppColors.teal
                  .withValues(
            alpha: 0.55,
          ),
          disabledForegroundColor:
              Colors.white,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(15),
          ),
        ),
        child: _isSigningIn
            ? const SizedBox(
                width: 21,
                height: 21,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2.2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Sign in',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
      ),
    );
  }

  // ============================================================
  // APPROVAL NOTICE
  // ============================================================

  Widget _buildApprovalNote() {
    return Row(
      mainAxisAlignment:
          MainAxisAlignment.center,
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 14,
          color: AppColors.navy
              .withValues(
            alpha: 0.35,
          ),
        ),

        const SizedBox(width: 6),

        Flexible(
          child: Text(
            'New accounts require approval before sign in becomes available.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy
                  .withValues(
                alpha: 0.38,
              ),
              fontSize: 10,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SIGN UP
  // ============================================================

  Widget _buildSignUp() {
    return Center(
      child: Wrap(
        crossAxisAlignment:
            WrapCrossAlignment.center,
        children: [
          Text(
            "Don't have an account? ",
            style: TextStyle(
              color: AppColors.navy
                  .withValues(
                alpha: 0.52,
              ),
              fontSize: 12,
              fontWeight:
                  FontWeight.w500,
            ),
          ),

          GestureDetector(
            behavior:
                HitTestBehavior.opaque,
            onTap: _signUp,
            child: const Padding(
              padding:
                  EdgeInsets.symmetric(
                vertical: 5,
              ),
              child: Text(
                'Sign up',
                style: TextStyle(
                  color:
                      AppColors.tealDark,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// HEADER WAVE
// ============================================================

class _LoginHeaderClipper
    extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();

    path.lineTo(
      0,
      size.height * 0.76,
    );

    path.cubicTo(
      size.width * 0.15,
      size.height * 0.66,
      size.width * 0.28,
      size.height * 0.68,
      size.width * 0.43,
      size.height * 0.79,
    );

    path.cubicTo(
      size.width * 0.66,
      size.height * 0.97,
      size.width * 0.83,
      size.height * 0.97,
      size.width,
      size.height * 0.82,
    );

    path.lineTo(
      size.width,
      0,
    );

    path.close();

    return path;
  }

  @override
  bool shouldReclip(
    covariant CustomClipper<Path>
        oldClipper,
  ) {
    return false;
  }
}

// ============================================================
// CONTOUR DECORATION
// ============================================================

class _ContourPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final paint = Paint()
      ..color =
          AppColors.teal.withValues(
        alpha: 0.17,
      )
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    _drawContour(
      canvas,
      paint,
      Offset(
        size.width * 0.19,
        size.height * 0.26,
      ),
      115,
      72,
    );

    _drawContour(
      canvas,
      paint,
      Offset(
        size.width * 0.67,
        size.height * 0.19,
      ),
      150,
      92,
    );

    _drawContour(
      canvas,
      paint,
      Offset(
        size.width * 0.48,
        size.height * 0.58,
      ),
      175,
      94,
    );

    _drawContour(
      canvas,
      paint,
      Offset(
        size.width * 0.90,
        size.height * 0.60,
      ),
      112,
      75,
    );
  }

  void _drawContour(
    Canvas canvas,
    Paint paint,
    Offset center,
    double width,
    double height,
  ) {
    for (int i = 0; i < 4; i++) {
      final inset = i * 9.0;

      final rect = Rect.fromCenter(
        center: center,
        width: width - inset * 2,
        height: height - inset * 2,
      );

      if (rect.width <= 0 ||
          rect.height <= 0) {
        continue;
      }

      canvas.drawOval(
        rect,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter
        oldDelegate,
  ) {
    return false;
  }
}

// ============================================================
// SIMPLE GOOGLE MARK
// ============================================================

class _GoogleIcon
    extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(
    BuildContext context,
  ) {
    return SizedBox(
      width: 19,
      height: 19,
      child: CustomPaint(
        painter:
            _GoogleIconPainter(),
      ),
    );
  }
}

class _GoogleIconPainter
    extends CustomPainter {
  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final stroke =
        size.width * 0.17;

    final center = Offset(
      size.width / 2,
      size.height / 2,
    );

    final radius =
        size.width / 2 -
            stroke / 2;

    Paint makePaint(Color color) {
      return Paint()
        ..color = color
        ..style =
            PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap =
            StrokeCap.round;
    }

    final rect =
        Rect.fromCircle(
      center: center,
      radius: radius,
    );

    canvas.drawArc(
      rect,
      -0.30,
      1.20,
      false,
      makePaint(
        const Color(0xFF4285F4),
      ),
    );

    canvas.drawArc(
      rect,
      0.95,
      0.80,
      false,
      makePaint(
        const Color(0xFF34A853),
      ),
    );

    canvas.drawArc(
      rect,
      1.82,
      0.82,
      false,
      makePaint(
        const Color(0xFFFBBC05),
      ),
    );

    canvas.drawArc(
      rect,
      2.72,
      1.20,
      false,
      makePaint(
        const Color(0xFFEA4335),
      ),
    );

    canvas.drawLine(
      Offset(
        size.width * 0.55,
        size.height * 0.52,
      ),
      Offset(
        size.width * 0.92,
        size.height * 0.52,
      ),
      makePaint(
        const Color(0xFF4285F4),
      ),
    );
  }

  @override
  bool shouldRepaint(
    covariant CustomPainter
        oldDelegate,
  ) {
    return false;
  }
}