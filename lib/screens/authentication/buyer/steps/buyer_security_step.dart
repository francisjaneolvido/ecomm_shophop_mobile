import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';

class BuyerSecurityStep extends StatefulWidget {
  const BuyerSecurityStep({
    super.key,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.termsAccepted,
    required this.onTermsChanged,
    required this.onTermsTap,
    required this.onPrivacyTap,
  });

  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool termsAccepted;
  final ValueChanged<bool> onTermsChanged;
  final VoidCallback onTermsTap;
  final VoidCallback onPrivacyTap;

  @override
  State<BuyerSecurityStep> createState() => _BuyerSecurityStepState();
}

class _BuyerSecurityStepState extends State<BuyerSecurityStep> {
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  bool get _hasMinimumLength => widget.passwordController.text.length >= 8;

  bool get _hasUppercase => RegExp(r'[A-Z]').hasMatch(widget.passwordController.text);

  bool get _hasLowercase => RegExp(r'[a-z]').hasMatch(widget.passwordController.text);

  bool get _hasNumber => RegExp(r'[0-9]').hasMatch(widget.passwordController.text);

  bool get _hasSpecial => RegExp(r'[!@#$%^&*]').hasMatch(widget.passwordController.text);

  bool get _requiredPasswordRulesPassed =>
      _hasMinimumLength && _hasUppercase && _hasLowercase && _hasNumber;

  String? _validatePassword(String? value) {
    final password = value ?? '';

    if (password.isEmpty) {
      return 'Password is required.';
    }

    if (password.length < 8) {
      return 'Password must be at least 8 characters long.';
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      return 'Add at least 1 uppercase letter (A–Z).';
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      return 'Add at least 1 lowercase letter (a–z).';
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      return 'Add at least 1 number (0–9).';
    }

    return null;
  }

  String? _validateConfirmation(String? value) {
    final confirmation = value ?? '';

    if (confirmation.isEmpty) {
      return 'Please confirm your password.';
    }

    if (confirmation != widget.passwordController.text) {
      return 'Passwords do not match.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 24),
        _buildPasswordField(),
        const SizedBox(height: 18),
        _buildConfirmPasswordField(),
        const SizedBox(height: 18),
        _buildRequirements(),
        const SizedBox(height: 18),
        _buildApprovalNotice(),
        const SizedBox(height: 14),
        _buildTermsField(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.lock_outline_rounded,
            color: AppColors.tealDark,
            size: 21,
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Secure your account',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Create a strong password and review the final agreement.',
                style: TextStyle(
                  color: AppColors.navy.withValues(alpha: 0.45),
                  fontSize: 12,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RequiredLabel(text: 'Password'),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.passwordController,
          obscureText: _obscurePassword,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.newPassword],
          onChanged: (_) {
            setState(() {});
          },
          validator: _validatePassword,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: _inputDecoration(
            hint: 'Create a strong password',
            icon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              icon: Icon(
                _obscurePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: AppColors.navy.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _RequiredLabel(text: 'Confirm password'),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.confirmPasswordController,
          obscureText: _obscureConfirmation,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.newPassword],
          validator: _validateConfirmation,
          style: const TextStyle(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: _inputDecoration(
            hint: 'Re-enter your password',
            icon: Icons.lock_reset_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              tooltip: _obscureConfirmation ? 'Show password' : 'Hide password',
              onPressed: () {
                setState(() {
                  _obscureConfirmation = !_obscureConfirmation;
                });
              },
              icon: Icon(
                _obscureConfirmation
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
                size: 20,
                color: AppColors.navy.withValues(alpha: 0.38),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRequirements() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _requiredPasswordRulesPassed
            ? AppColors.tealLight.withValues(alpha: 0.42)
            : AppColors.grayBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _requiredPasswordRulesPassed
              ? AppColors.teal.withValues(alpha: 0.18)
              : AppColors.grayBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Password requirements',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 11),
          _requirement('Minimum 8 characters', _hasMinimumLength),
          const SizedBox(height: 8),
          _requirement('1 uppercase letter (A–Z)', _hasUppercase),
          const SizedBox(height: 8),
          _requirement('1 lowercase letter (a–z)', _hasLowercase),
          const SizedBox(height: 8),
          _requirement('1 number (0–9)', _hasNumber),
          const SizedBox(height: 8),
          _requirement(
            'Special character (! @ # \$ % ^ & *) — recommended',
            _hasSpecial,
            optional: true,
          ),
        ],
      ),
    );
  }

  Widget _requirement(
    String text,
    bool satisfied, {
    bool optional = false,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 17,
          height: 17,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: satisfied ? AppColors.teal : Colors.white,
            border: Border.all(
              color: satisfied ? AppColors.teal : AppColors.grayBorder,
              width: 1.2,
            ),
          ),
          child: satisfied
              ? const Icon(
                  Icons.check_rounded,
                  size: 11,
                  color: Colors.white,
                )
              : null,
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: satisfied
                  ? AppColors.tealDark
                  : AppColors.navy.withValues(alpha: optional ? 0.34 : 0.46),
              fontSize: 10.5,
              height: 1.4,
              fontWeight: satisfied ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildApprovalNotice() {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: AppColors.tealLight.withValues(
        alpha: 0.45,
      ),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(
        color: AppColors.teal.withValues(
          alpha: 0.15,
        ),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: AppColors.tealDark,
        ),

        const SizedBox(width: 10),

        Expanded(
          child: Text(
            'After creating your account, we’ll send a '
            '6-digit verification code to your email. '
            'Once your email is verified, your registration '
            'will be submitted for administrator approval.',
            style: TextStyle(
              color: AppColors.navy.withValues(
                alpha: 0.55,
              ),
              fontSize: 10.5,
              height: 1.5,
            ),
          ),
        ),
      ],
    ),
  );
}

  Widget _buildTermsField() {
    return FormField<bool>(
      initialValue: widget.termsAccepted,
      validator: (value) {
        if (value != true) {
          return 'You must agree to the Terms and Conditions.';
        }
        return null;
      },
      builder: (field) {
        final checked = field.value ?? false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () {
                final next = !checked;
                field.didChange(next);
                widget.onTermsChanged(next);
              },
              borderRadius: BorderRadius.circular(15),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: field.hasError
                        ? const Color(0xFFDB5757)
                        : checked
                            ? AppColors.teal.withValues(alpha: 0.60)
                            : AppColors.grayBorder,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: Checkbox(
                        value: checked,
                        onChanged: (value) {
                          final next = value ?? false;
                          field.didChange(next);
                          widget.onTermsChanged(next);
                        },
                        activeColor: AppColors.teal,
                        checkColor: Colors.white,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        side: const BorderSide(
                          color: AppColors.grayBorder,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(5),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Wrap(
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            "I have read and agree to ShopHop's ",
                            style: TextStyle(
                              color: AppColors.navy.withValues(alpha: 0.60),
                              fontSize: 10.5,
                              height: 1.5,
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onTermsTap,
                            child: const Text(
                              'Terms and Conditions',
                              style: TextStyle(
                                color: AppColors.tealDark,
                                fontSize: 10.5,
                                height: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            ' and ',
                            style: TextStyle(
                              color: AppColors.navy.withValues(alpha: 0.60),
                              fontSize: 10.5,
                              height: 1.5,
                            ),
                          ),
                          GestureDetector(
                            onTap: widget.onPrivacyTap,
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.tealDark,
                                fontSize: 10.5,
                                height: 1.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Text(
                            '. *',
                            style: TextStyle(
                              color: Color(0xFFDB5757),
                              fontSize: 10.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (field.hasError) ...[
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  field.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFDB5757),
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(
        color: AppColors.navy.withValues(alpha: 0.27),
        fontSize: 13,
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
      errorStyle: const TextStyle(
        fontSize: 10,
        height: 1.3,
      ),
    );
  }
}

class _RequiredLabel extends StatelessWidget {
  const _RequiredLabel({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: AppColors.navy,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        children: [
          TextSpan(text: text),
          const TextSpan(
            text: ' *',
            style: TextStyle(color: Color(0xFFDB5757)),
          ),
        ],
      ),
    );
  }
}
