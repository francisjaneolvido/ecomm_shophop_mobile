import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../theme/app_colors.dart';
import 'registration_role.dart';
import 'widgets/verification_card.dart';
import 'widgets/verification_header.dart';
import 'widgets/verification_ui.dart';

class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.role,
    required this.onVerifyCode,
    required this.onResendCode,
    required this.onVerified,
    this.onBack,
    this.resendCooldownSeconds = 60,
  });

  final String email;
  final RegistrationRole role;

  /// Return null on success, or an error message on failure.
  final Future<String?> Function(String code)
      onVerifyCode;

  /// Return null on success, or an error message on failure.
  final Future<String?> Function()
      onResendCode;

  final VoidCallback onVerified;
  final VoidCallback? onBack;
  final int resendCooldownSeconds;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<EmailVerificationScreen> {
  final _codeController =
      TextEditingController();

  Timer? _resendTimer;
  int _secondsRemaining = 0;

  bool _isVerifying = false;
  bool _isResending = false;

  String? _errorMessage;
  String? _successMessage;

  bool get _codeIsValid =>
      RegExp(r'^\d{6}$').hasMatch(
        _codeController.text,
      );

  bool get _enabled =>
      !_isVerifying && !_isResending;

  bool get _canVerify =>
      _enabled && _codeIsValid;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();

    setState(() {
      _secondsRemaining =
          widget.resendCooldownSeconds;
    });

    _resendTimer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_secondsRemaining <= 1) {
          timer.cancel();
          setState(() {
            _secondsRemaining = 0;
          });
          return;
        }

        setState(() {
          _secondsRemaining--;
        });
      },
    );
  }

  Future<void> _verify() async {
    if (!_canVerify) return;

    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final error =
        await widget.onVerifyCode(
      _codeController.text,
    );

    if (!mounted) return;

    if (error != null) {
      HapticFeedback.mediumImpact();

      setState(() {
        _isVerifying = false;
        _errorMessage = error;
      });
      return;
    }

    HapticFeedback.lightImpact();

    setState(() {
      _isVerifying = false;
      _successMessage =
          'Your email was verified successfully.';
    });

    await Future<void>.delayed(
      const Duration(milliseconds: 450),
    );

    if (mounted) {
      widget.onVerified();
    }
  }

  Future<void> _resend() async {
    if (!_enabled ||
        _secondsRemaining > 0) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isResending = true;
      _errorMessage = null;
      _successMessage = null;
    });

    final error =
        await widget.onResendCode();

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isResending = false;
        _errorMessage = error;
      });
      return;
    }

    _codeController.clear();

    setState(() {
      _isResending = false;
      _successMessage =
          'A new verification code was sent to your email.';
    });

    _startResendTimer();
  }

  void _back() {
    if (!_enabled) return;

    if (widget.onBack != null) {
      widget.onBack!();
      return;
    }

    Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _enabled,
      child: Scaffold(
        backgroundColor: AppColors.grayBg,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding:
                      const EdgeInsets.fromLTRB(20, 12, 20, 32),
                  child: Center(
                    child: ConstrainedBox(
                      constraints:
                          const BoxConstraints(maxWidth: 480),
                      child: Column(
                        children: [
                          const SizedBox(height: 12),
                          VerificationHeader(
                            role: widget.role,
                          ),
                          const SizedBox(height: 24),
                          VerificationCard(
                            email: widget.email,
                            role: widget.role,
                            codeController:
                                _codeController,
                            enabled: _enabled,
                            canVerify:
                                _canVerify,
                            isVerifying:
                                _isVerifying,
                            isResending:
                                _isResending,
                            secondsRemaining:
                                _secondsRemaining,
                            errorMessage:
                                _errorMessage,
                            successMessage:
                                _successMessage,
                            onCodeChanged: (_) {
                              setState(() {
                                _errorMessage = null;
                              });
                            },
                            onVerify: _verify,
                            onResend: _resend,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        8,
      ),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            borderRadius:
                BorderRadius.circular(14),
            child: InkWell(
              onTap: _back,
              borderRadius:
                  BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(14),
                  border: Border.all(
                    color: AppColors.grayBorder,
                  ),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 17,
                  color: AppColors.navy,
                ),
              ),
            ),
          ),
          const Spacer(),
          Image.asset(
            'assets/images/logo.png',
            width: 30,
            height: 30,
          ),
          const SizedBox(width: 7),
          Text(
            'ShopHop',
            style: VerificationUi.text(
              color: AppColors.navy,
              fontSize: 15,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
