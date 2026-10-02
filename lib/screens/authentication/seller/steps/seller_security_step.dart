import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../widgets/seller_ui.dart';

class SellerSecurityStep extends StatefulWidget {
  const SellerSecurityStep({
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
  State<SellerSecurityStep> createState() =>
      _SellerSecurityStepState();
}

class _SellerSecurityStepState
    extends State<SellerSecurityStep> {
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  String get _password => widget.passwordController.text;

  bool get _hasLength => _password.length >= 8;
  bool get _hasUppercase =>
      RegExp(r'[A-Z]').hasMatch(_password);
  bool get _hasLowercase =>
      RegExp(r'[a-z]').hasMatch(_password);
  bool get _hasNumber =>
      RegExp(r'[0-9]').hasMatch(_password);
  bool get _hasSpecial =>
      RegExp(r'[!@#$%^&*]').hasMatch(_password);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SellerUi.sectionHeader(
          icon: Icons.lock_outline_rounded,
          title: 'Secure your seller account',
          subtitle:
              'Create a strong password and review the final seller agreement.',
        ),
        const SizedBox(height: 24),
        _passwordField(),
        const SizedBox(height: 18),
        _confirmField(),
        const SizedBox(height: 18),
        _requirements(),
        const SizedBox(height: 18),
        _approvalNotice(),
        const SizedBox(height: 14),
        _termsField(),
      ],
    );
  }

  Widget _passwordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SellerUi.requiredLabel('Password'),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.passwordController,
          obscureText: _obscurePassword,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.next,
          autofillHints: const [
            AutofillHints.newPassword,
          ],
          onChanged: (_) => setState(() {}),
          validator: (value) {
            final password = value ?? '';

            if (password.isEmpty) {
              return 'Password is required.';
            }

            if (password.length < 8) {
              return 'Password must be at least 8 characters long.';
            }

            if (!RegExp(r'[A-Z]').hasMatch(password)) {
              return 'Add at least 1 uppercase letter.';
            }

            if (!RegExp(r'[a-z]').hasMatch(password)) {
              return 'Add at least 1 lowercase letter.';
            }

            if (!RegExp(r'[0-9]').hasMatch(password)) {
              return 'Add at least 1 number.';
            }

            return null;
          },
          style: SellerUi.text(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: SellerUi.inputDecoration(
            hint: 'Create a strong password',
            icon: Icons.lock_outline_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              tooltip: _obscurePassword
                  ? 'Show password'
                  : 'Hide password',
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

  Widget _confirmField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SellerUi.requiredLabel('Confirm password'),
        const SizedBox(height: 8),
        TextFormField(
          controller: widget.confirmPasswordController,
          obscureText: _obscureConfirmation,
          keyboardType: TextInputType.visiblePassword,
          textInputAction: TextInputAction.done,
          autofillHints: const [
            AutofillHints.newPassword,
          ],
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please confirm your password.';
            }

            if (value != widget.passwordController.text) {
              return 'Passwords do not match.';
            }

            return null;
          },
          style: SellerUi.text(
            color: AppColors.navy,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
          decoration: SellerUi.inputDecoration(
            hint: 'Re-enter your password',
            icon: Icons.lock_reset_rounded,
          ).copyWith(
            suffixIcon: IconButton(
              tooltip: _obscureConfirmation
                  ? 'Show password'
                  : 'Hide password',
              onPressed: () {
                setState(() {
                  _obscureConfirmation =
                      !_obscureConfirmation;
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

  Widget _requirements() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.grayBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.grayBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password requirements',
            style: SellerUi.text(
              color: AppColors.navy,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 11),
          _requirement('Minimum 8 characters', _hasLength),
          _requirement(
            '1 uppercase letter (A–Z)',
            _hasUppercase,
          ),
          _requirement(
            '1 lowercase letter (a–z)',
            _hasLowercase,
          ),
          _requirement('1 number (0–9)', _hasNumber),
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
    String label,
    bool complete, {
    bool optional = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 17,
            height: 17,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: complete ? AppColors.teal : Colors.white,
              border: Border.all(
                color: complete
                    ? AppColors.teal
                    : AppColors.grayBorder,
              ),
            ),
            child: complete
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
              label,
              style: SellerUi.text(
                color: complete
                    ? AppColors.tealDark
                    : AppColors.navy.withValues(
                        alpha: optional ? 0.34 : 0.46,
                      ),
                fontSize: 10.5,
                fontWeight: complete
                    ? FontWeight.w600
                    : FontWeight.w500,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _approvalNotice() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.tealLight.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.teal.withValues(alpha: 0.15),
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
              'After email verification, your seller registration will wait for administrator approval. Your approval status will be sent to your registered email.',
              style: SellerUi.text(
                color: AppColors.navy.withValues(alpha: 0.55),
                fontSize: 10.5,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _termsField() {
    return FormField<bool>(
      initialValue: widget.termsAccepted,
      validator: (value) {
        if (value != true) {
          return 'You must agree to the Seller Terms and Conditions.';
        }
        return null;
      },
      builder: (field) {
        final checked = field.value ?? false;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
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
                      materialTapTargetSize:
                          MaterialTapTargetSize.shrinkWrap,
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
                          style: SellerUi.text(
                            color:
                                AppColors.navy.withValues(alpha: 0.60),
                            fontSize: 10.5,
                            height: 1.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onTermsTap,
                          child: Text(
                            'Seller Terms and Conditions',
                            style: SellerUi.text(
                              color: AppColors.tealDark,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                        Text(
                          ' and ',
                          style: SellerUi.text(
                            color:
                                AppColors.navy.withValues(alpha: 0.60),
                            fontSize: 10.5,
                            height: 1.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: widget.onPrivacyTap,
                          child: Text(
                            'Privacy Policy',
                            style: SellerUi.text(
                              color: AppColors.tealDark,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              height: 1.5,
                            ),
                          ),
                        ),
                        Text(
                          '. *',
                          style: SellerUi.text(
                            color: const Color(0xFFDB5757),
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
            if (field.hasError) ...[
              const SizedBox(height: 7),
              Padding(
                padding: const EdgeInsets.only(left: 4),
                child: Text(
                  field.errorText!,
                  style: SellerUi.text(
                    color: const Color(0xFFDB5757),
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
}
