import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../verification/email_verification_screen.dart';
import '../verification/registration_role.dart';
import '../buyer/steps/buyer_address_step.dart';
import '../buyer/steps/buyer_personal_step.dart';
import 'steps/rider_details_step.dart';
import 'steps/rider_security_step.dart';
import 'widgets/rider_registration_widgets.dart';
import 'widgets/rider_ui.dart';

class RiderRegistrationScreen extends StatefulWidget {
  const RiderRegistrationScreen({super.key});

  @override
  State<RiderRegistrationScreen> createState() =>
      _RiderRegistrationScreenState();
}

class _RiderRegistrationScreenState extends State<RiderRegistrationScreen> {
  final _scroll = ScrollController();

  final _personalKey = GlobalKey<FormState>();
  final _addressKey = GlobalKey<FormState>();
  final _riderKey = GlobalKey<FormState>();
  final _securityKey = GlobalKey<FormState>();

  final _firstName = TextEditingController();
  final _lastName = TextEditingController();
  final _middleInitial = TextEditingController();
  final _email = TextEditingController();
  final _contact = TextEditingController();
  final _birthday = TextEditingController();
  final _age = TextEditingController();

  final _street = TextEditingController();
  final _vehicle = TextEditingController();
  final _plate = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();

  String? _sex;
  DateTime? _birthdayDate;

  String? _provinceCode;
  // ignore: unused_field
  String? _provinceName;
  String? _municipalityCode;
  // ignore: unused_field
  String? _municipalityName;
  String? _barangayCode;
  // ignore: unused_field
  String? _barangayName;

  PlatformFile? _orCr;
  PlatformFile? _idOrLicense;

  bool _termsAccepted = false;
  int _step = 1;

  @override
  void dispose() {
    _scroll.dispose();
    for (final controller in [
      _firstName,
      _lastName,
      _middleInitial,
      _email,
      _contact,
      _birthday,
      _age,
      _street,
      _vehicle,
      _plate,
      _password,
      _confirmPassword,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _selectBirthday() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _birthdayDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (picked == null) return;

    setState(() {
      _birthdayDate = picked;
      _birthday.text =
          '${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}';

      var age = now.year - picked.year;
      if (now.month < picked.month ||
          (now.month == picked.month && now.day < picked.day)) {
        age--;
      }
      _age.text = '$age';
    });
  }

  void _goTo(int value) {
    setState(() => _step = value);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _next() {
    FocusScope.of(context).unfocus();

    final valid = switch (_step) {
      1 => _personalKey.currentState?.validate() ?? false,
      2 => _addressKey.currentState?.validate() ?? false,
      3 => _riderKey.currentState?.validate() ?? false,
      _ => false,
    };

    if (!valid) {
      _message('Please check the required fields.');
      return;
    }

    if (_step < 4) _goTo(_step + 1);
  }

  void _createAccount() {
    FocusScope.of(context).unfocus();

    final valid =
        _securityKey.currentState?.validate() ??
            false;

    if (!valid) {
      _message(
        'Please complete the security requirements.',
      );
      return;
    }

    _showVerificationPreviewDialog();
  }

  Future<void> _showVerificationPreviewDialog() async {
    final shouldPreview =
        await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor:
              Colors.white,
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              22,
            ),
          ),
          icon: Container(
            width: 54,
            height: 54,
            decoration:
                BoxDecoration(
              color:
                  AppColors.tealLight,
              borderRadius:
                  BorderRadius.circular(
                17,
              ),
            ),
            child: const Icon(
              Icons
                  .mark_email_unread_outlined,
              color:
                  AppColors.tealDark,
              size: 27,
            ),
          ),
          title: Text(
            'Rider registration UI complete',
            textAlign:
                TextAlign.center,
            style: RiderUi.text(
              color:
                  AppColors.navy,
              fontSize: 18,
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          content: Text(
            'The Laravel registration API is not connected yet, so no real '
            'verification code will be sent. You can still preview the '
            'rider email verification screen.',
            textAlign:
                TextAlign.center,
            style: RiderUi.text(
              color:
                  AppColors.navy
                      .withValues(
                alpha: 0.52,
              ),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          actionsAlignment:
              MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  false,
                );
              },
              child: Text(
                'Not now',
                style: RiderUi.text(
                  color:
                      AppColors.navy,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
                  true,
                );
              },
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    AppColors.teal,
                foregroundColor:
                    Colors.white,
                shape:
                    RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
              ),
              child: Text(
                'Preview',
                style: RiderUi.text(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted ||
        shouldPreview != true) {
      return;
    }

    _openEmailVerificationPreview();
  }

  void _openEmailVerificationPreview() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EmailVerificationScreen(
          email:
              _email.text.trim(),
          role:
              RegistrationRole.rider,
          onVerifyCode:
              (code) async {
            await Future<void>.delayed(
              const Duration(
                milliseconds: 550,
              ),
            );

            return 'UI preview only — no verification code was sent because '
                'the Laravel API is not connected yet.';
          },
          onResendCode:
              () async {
            await Future<void>.delayed(
              const Duration(
                milliseconds: 550,
              ),
            );

            return 'UI preview only — resend will work after the Laravel '
                'verification API is connected.';
          },
          onVerified: () {
            // Connect this after the real backend confirms the OTP.
          },
        ),
      ),
    );
  }

  void _message(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            text,
            style: RiderUi.text(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppColors.grayBg,
        body: SafeArea(
          child: Column(
            children: [
              _topBar(),
              Expanded(
                child: SingleChildScrollView(
                  controller: _scroll,
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const RiderRegistrationHeader(),
                      const SizedBox(height: 22),
                      RiderRegistrationProgress(currentStep: _step),
                      const SizedBox(height: 20),
                      _content(),
                    ],
                  ),
                ),
              ),
              _bottomBar(),
            ],
          ),
        ),
      );

  Widget _content() => switch (_step) {
        1 => _card(
            Form(
              key: _personalKey,
              child: BuyerPersonalStep(
                firstNameController: _firstName,
                lastNameController: _lastName,
                middleInitialController: _middleInitial,
                emailController: _email,
                contactController: _contact,
                birthdayController: _birthday,
                ageController: _age,
                selectedSex: _sex,
                onSexChanged: (value) => setState(() => _sex = value),
                onBirthdayTap: _selectBirthday,
              ),
            ),
          ),
        2 => _card(
            Form(
              key: _addressKey,
              child: BuyerAddressStep(
                streetAddressController: _street,
                provinceCode: _provinceCode,
                municipalityCode: _municipalityCode,
                barangayCode: _barangayCode,
                onProvinceChanged: (code, name) => setState(() {
                  _provinceCode = code;
                  _provinceName = name.isEmpty ? null : name;
                  _municipalityCode = null;
                  _municipalityName = null;
                  _barangayCode = null;
                  _barangayName = null;
                }),
                onMunicipalityChanged: (code, name) => setState(() {
                  _municipalityCode = code;
                  _municipalityName = name.isEmpty ? null : name;
                  _barangayCode = null;
                  _barangayName = null;
                }),
                onBarangayChanged: (code, name) => setState(() {
                  _barangayCode = code;
                  _barangayName = name.isEmpty ? null : name;
                }),
              ),
            ),
          ),
        3 => _card(
            Form(
              key: _riderKey,
              child: RiderDetailsStep(
                vehicleController: _vehicle,
                plateNumberController: _plate,
                orCrFile: _orCr,
                idOrLicenseFile: _idOrLicense,
                onOrCrChanged: (file) => setState(() => _orCr = file),
                onIdOrLicenseChanged: (file) =>
                    setState(() => _idOrLicense = file),
              ),
            ),
          ),
        _ => _card(
            Form(
              key: _securityKey,
              child: RiderSecurityStep(
                passwordController: _password,
                confirmPasswordController: _confirmPassword,
                termsAccepted: _termsAccepted,
                onTermsChanged: (value) =>
                    setState(() => _termsAccepted = value),
                onTermsTap: () => _message(
                  'Terms and Conditions screen will be connected later.',
                ),
                onPrivacyTap: () => _message(
                  'Privacy Policy screen will be connected later.',
                ),
              ),
            ),
          ),
      };

  Widget _card(Widget child) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.grayBorder),
          boxShadow: [
            BoxShadow(
              color: AppColors.navy.withValues(alpha: 0.035),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      );

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 8),
      child: Row(
        children: [
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.grayBorder),
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
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 7),
          Text(
            'ShopHop',
            style: RiderUi.text(
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

  Widget _bottomBar() {
    final showBack = _step > 1;
    final isFinalStep = _step == 4;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color: AppColors.grayBorder.withValues(alpha: 0.8),
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (showBack) ...[
              SizedBox(
                height: 54,
                child: OutlinedButton(
                  onPressed: () => _goTo(_step - 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.grayBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.arrow_back_rounded, size: 18),
                      const SizedBox(width: 6),
                      Text(
                        'Back',
                        style: RiderUi.text(
                          color: AppColors.navy,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: isFinalStep ? _createAccount : _next,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isFinalStep ? 'Create Account' : 'Continue',
                        style: RiderUi.text(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isFinalStep
                            ? Icons.person_add_alt_1_rounded
                            : Icons.arrow_forward_rounded,
                        size: 19,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
