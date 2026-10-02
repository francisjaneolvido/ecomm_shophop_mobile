import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../widgets/rider_ui.dart';

class RiderSecurityStep extends StatefulWidget {
  const RiderSecurityStep({
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
  State<RiderSecurityStep> createState() => _RiderSecurityStepState();
}

class _RiderSecurityStepState extends State<RiderSecurityStep> {
  bool _hidePassword = true;
  bool _hideConfirmation = true;

  String get _password => widget.passwordController.text;
  bool get _length => _password.length >= 8;
  bool get _upper => RegExp(r'[A-Z]').hasMatch(_password);
  bool get _lower => RegExp(r'[a-z]').hasMatch(_password);
  bool get _number => RegExp(r'[0-9]').hasMatch(_password);
  bool get _special => RegExp(r'[!@#$%^&*]').hasMatch(_password);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 24),
        _passwordField(),
        const SizedBox(height: 18),
        _confirmField(),
        const SizedBox(height: 18),
        _requirements(),
        const SizedBox(height: 18),
        _approval(),
        const SizedBox(height: 14),
        _terms(),
      ],
    );
  }

  Widget _header() => Row(
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
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Secure your rider account',
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

  Widget _passwordField() => _field(
        label: 'Password',
        controller: widget.passwordController,
        hidden: _hidePassword,
        hint: 'Create a strong password',
        onToggle: () => setState(() => _hidePassword = !_hidePassword),
        onChanged: (_) => setState(() {}),
        validator: (value) {
          final p = value ?? '';
          if (p.isEmpty) return 'Password is required.';
          if (p.length < 8) return 'Password must be at least 8 characters.';
          if (!RegExp(r'[A-Z]').hasMatch(p)) return 'Add at least 1 uppercase letter.';
          if (!RegExp(r'[a-z]').hasMatch(p)) return 'Add at least 1 lowercase letter.';
          if (!RegExp(r'[0-9]').hasMatch(p)) return 'Add at least 1 number.';
          return null;
        },
      );

  Widget _confirmField() => _field(
        label: 'Confirm password',
        controller: widget.confirmPasswordController,
        hidden: _hideConfirmation,
        hint: 'Re-enter your password',
        onToggle: () =>
            setState(() => _hideConfirmation = !_hideConfirmation),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please confirm your password.';
          }
          return value == widget.passwordController.text
              ? null
              : 'Passwords do not match.';
        },
      );

  Widget _field({
    required String label,
    required TextEditingController controller,
    required bool hidden,
    required String hint,
    required VoidCallback onToggle,
    required String? Function(String?) validator,
    ValueChanged<String>? onChanged,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RiderUi.requiredLabel(label),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            obscureText: hidden,
            keyboardType: TextInputType.visiblePassword,
            autofillHints: const [AutofillHints.newPassword],
            onChanged: onChanged,
            validator: validator,
            style: RiderUi.text(
              color: AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            decoration: _decoration(hint).copyWith(
              suffixIcon: IconButton(
                onPressed: onToggle,
                icon: Icon(
                  hidden
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

  Widget _requirements() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.grayBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.grayBorder),
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
            _rule('Minimum 8 characters', _length),
            _rule('1 uppercase letter (A–Z)', _upper),
            _rule('1 lowercase letter (a–z)', _lower),
            _rule('1 number (0–9)', _number),
            _rule('Special character (! @ # \$ % ^ & *) — recommended',
                _special),
          ],
        ),
      );

  Widget _rule(String text, bool done) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            Container(
              width: 17,
              height: 17,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? AppColors.teal : Colors.white,
                border: Border.all(
                  color: done ? AppColors.teal : AppColors.grayBorder,
                ),
              ),
              child: done
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
                  color: done
                      ? AppColors.tealDark
                      : AppColors.navy.withValues(alpha: 0.46),
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _approval() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.tealLight.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(15),
          border:
              Border.all(color: AppColors.teal.withValues(alpha: 0.15)),
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
                'After email verification, please wait for the Logistics / Sorting Center approval. Your approval status will be sent to your registered email.',
                style: TextStyle(
                  color: AppColors.navy.withValues(alpha: 0.55),
                  fontSize: 10.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _terms() => FormField<bool>(
        initialValue: widget.termsAccepted,
        validator: (value) =>
            value == true ? null : 'You must agree to the Terms and Conditions.',
        builder: (field) {
          final checked = field.value ?? false;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
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
                    Checkbox(
                      value: checked,
                      onChanged: (value) {
                        final next = value ?? false;
                        field.didChange(next);
                        widget.onTermsChanged(next);
                      },
                      activeColor: AppColors.teal,
                    ),
                    Expanded(
                      child: Wrap(
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
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Text(' and '),
                          GestureDetector(
                            onTap: widget.onPrivacyTap,
                            child: const Text(
                              'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.tealDark,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const Text('. *'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (field.hasError) ...[
                const SizedBox(height: 7),
                Text(
                  field.errorText!,
                  style: const TextStyle(
                    color: Color(0xFFDB5757),
                    fontSize: 10,
                  ),
                ),
              ],
            ],
          );
        },
      );

  InputDecoration _decoration(String hint) {
    return RiderUi.inputDecoration(
      hint: hint,
      icon: Icons.lock_outline_rounded,
    );
  }
}
