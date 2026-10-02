import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../theme/app_colors.dart';
import '../../../services/auth_service.dart';
import '../login_screen.dart';
import '../verification/email_verification_screen.dart';
import '../verification/registration_role.dart';
import 'steps/buyer_address_step.dart';
import 'steps/buyer_personal_step.dart';
import 'steps/buyer_security_step.dart';
import 'steps/buyer_verification_step.dart';

class BuyerRegistrationScreen
    extends StatefulWidget {
  const BuyerRegistrationScreen({
    super.key,
  });

  @override
  State<BuyerRegistrationScreen>
      createState() =>
          _BuyerRegistrationScreenState();
}

class _BuyerRegistrationScreenState
    extends State<BuyerRegistrationScreen> {
  final _scrollController =
      ScrollController();

  final _personalFormKey =
      GlobalKey<FormState>();

  final _addressFormKey =
      GlobalKey<FormState>();

  final _verificationFormKey =
      GlobalKey<FormState>();

  final _securityFormKey =
      GlobalKey<FormState>();

  // ============================================================
  // STEP 1 — PERSONAL
  // ============================================================

  final _firstNameController =
      TextEditingController();

  final _lastNameController =
      TextEditingController();

  final _middleInitialController =
      TextEditingController();

  final _emailController =
      TextEditingController();

  final _contactController =
      TextEditingController();

  final _birthdayController =
      TextEditingController();

  final _ageController =
      TextEditingController();

  String? _selectedSex;

  DateTime? _selectedBirthday;

  // ============================================================
  // STEP 2 — ADDRESS
  // ============================================================

  final _streetAddressController =
      TextEditingController();

  String? _provinceCode;
  String? _provinceName;

  String? _municipalityCode;
  String? _municipalityName;

  String? _barangayCode;
  String? _barangayName;

  // ============================================================
  // STEP 3 — VERIFICATION
  // ============================================================

  PlatformFile? _validIdFile;

  // ============================================================
  // STEP 4 — SECURITY
  // ============================================================

  final _passwordController =
      TextEditingController();

  final _confirmPasswordController =
      TextEditingController();

  bool _termsAccepted = false;

  // ============================================================
  // STEP STATE
  // ============================================================

  int _currentStep = 1;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _scrollController.dispose();

    _firstNameController.dispose();
    _lastNameController.dispose();
    _middleInitialController.dispose();

    _emailController.dispose();
    _contactController.dispose();

    _birthdayController.dispose();
    _ageController.dispose();

    _streetAddressController.dispose();

    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  // ============================================================
  // BIRTHDAY
  // ============================================================

  Future<void> _selectBirthday() async {
    FocusScope.of(context).unfocus();

    final now =
        DateTime.now();

    final initial =
        _selectedBirthday ??
            DateTime(
              now.year - 18,
              now.month,
              now.day,
            );

    final picked =
        await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate:
          DateTime(
        1900,
        1,
        1,
      ),
      lastDate:
          DateTime(
        now.year,
        now.month,
        now.day,
      ),
      helpText:
          'Select your birthday',
      cancelText:
          'Cancel',
      confirmText:
          'Select',
      builder: (
        context,
        child,
      ) {
        return Theme(
          data:
              Theme.of(context).copyWith(
            colorScheme:
                const ColorScheme.light(
              primary:
                  AppColors.teal,
              onPrimary:
                  Colors.white,
              onSurface:
                  AppColors.navy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _selectedBirthday =
          picked;

      _birthdayController.text =
          _formatDate(
        picked,
      );

      _ageController.text =
          _calculateAge(
        picked,
      ).toString();
    });
  }

  int _calculateAge(
    DateTime birthday,
  ) {
    final today =
        DateTime.now();

    int age =
        today.year -
            birthday.year;

    final birthdayNotReached =
        today.month <
                birthday.month ||
            (today.month ==
                    birthday.month &&
                today.day <
                    birthday.day);

    if (birthdayNotReached) {
      age--;
    }

    return age;
  }

  String _formatDate(
    DateTime date,
  ) {
    final month =
        date.month
            .toString()
            .padLeft(
              2,
              '0',
            );

    final day =
        date.day
            .toString()
            .padLeft(
              2,
              '0',
            );

    return '${date.year}-$month-$day';
  }

  // ============================================================
  // NAVIGATION
  // ============================================================

  void _nextStep() {
    FocusScope.of(context).unfocus();

    if (_currentStep == 1) {
      final valid =
          _personalFormKey
                  .currentState
                  ?.validate() ??
              false;

      if (!valid) {
        _showValidationMessage();

        return;
      }

      _goToStep(2);

      return;
    }

    if (_currentStep == 2) {
      final valid =
          _addressFormKey
                  .currentState
                  ?.validate() ??
              false;

      if (!valid) {
        _showValidationMessage();

        return;
      }

      _goToStep(3);

      return;
    }

    if (_currentStep == 3) {
      final valid =
          _verificationFormKey
                  .currentState
                  ?.validate() ??
              false;

      if (!valid) {
        _showValidationMessage(
          message:
              'Please upload a valid ID before continuing.',
        );

        return;
      }

      _goToStep(4);

      return;
    }
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();

    if (_currentStep <= 1) {
      return;
    }

    _goToStep(
      _currentStep - 1,
    );
  }

  void _goToStep(
    int step,
  ) {
    setState(() {
      _currentStep = step;
    });

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!_scrollController
            .hasClients) {
          return;
        }

        _scrollController.animateTo(
          0,
          duration:
              const Duration(
            milliseconds: 250,
          ),
          curve:
              Curves.easeOut,
        );
      },
    );
  }

  void _showValidationMessage({
    String message =
        'Please check the required fields.',
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons
                    .error_outline_rounded,
                color:
                    Colors.white,
                size: 20,
              ),

              const SizedBox(
                width: 10,
              ),

              Expanded(
                child: Text(
                  message,
                ),
              ),
            ],
          ),
          backgroundColor:
              AppColors.navy,
          behavior:
              SnackBarBehavior.floating,
          margin:
              const EdgeInsets.all(
            16,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
        ),
      );
  }

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    final securityValid =
        _securityFormKey.currentState?.validate() ?? false;

    if (!securityValid) {
      _showValidationMessage(
        message:
            'Please complete the password and agreement requirements.',
      );
      return;
    }

    if (_validIdFile == null) {
      _goToStep(3);
      _showValidationMessage(
        message:
            'Please upload a valid ID before creating your account.',
      );
      return;
    }

    final addressNamesComplete =
        (_provinceName?.isNotEmpty ?? false) &&
        (_municipalityName?.isNotEmpty ?? false) &&
        (_barangayName?.isNotEmpty ?? false);

    if (!addressNamesComplete) {
      _goToStep(2);
      _showValidationMessage(
        message:
            'Please complete your delivery address.',
      );
      return;
    }

    final provinceCode =
        _provinceCode;
    final provinceName =
        _provinceName;
    final municipalityCode =
        _municipalityCode;
    final municipalityName =
        _municipalityName;
    final barangayCode =
        _barangayCode;
    final barangayName =
        _barangayName;
    final sex =
        _selectedSex;
    final validId =
        _validIdFile;

    if (provinceCode == null ||
        provinceName == null ||
        municipalityCode == null ||
        municipalityName == null ||
        barangayCode == null ||
        barangayName == null ||
        sex == null ||
        validId == null) {
      _showValidationMessage();
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    final result =
        await AuthService.registerBuyer(
      firstName:
          _firstNameController.text,
      lastName:
          _lastNameController.text,
      middleInitial:
          _middleInitialController.text,
      sex: sex,
      email:
          _emailController.text,
      contactNo:
          _contactController.text,
      birthday:
          _birthdayController.text,
      provinceCode:
          provinceCode,
      provinceName:
          provinceName,
      municipalityCode:
          municipalityCode,
      municipalityName:
          municipalityName,
      barangayCode:
          barangayCode,
      barangayName:
          barangayName,
      streetAddress:
          _streetAddressController.text,
      validId: validId,
      password:
          _passwordController.text,
    );

    if (!mounted) {
      return;
    }

    setState(() {
      _isSubmitting = false;
    });

    if (!result.success) {
      _showValidationMessage(
        message: result.message,
      );
      return;
    }

    _openEmailVerification();
  }

  void _openEmailVerification() {
    final email =
        _emailController.text
            .trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EmailVerificationScreen(
          email: email,
          role:
              RegistrationRole.buyer,
          onVerifyCode:
              (code) async {
            final result =
                await AuthService
                    .verifyBuyerEmail(
              email: email,
              code: code,
            );

            if (result.success) {
              return null;
            }

            return result.message;
          },
          onResendCode:
              () async {
            final result =
                await AuthService
                    .resendBuyerVerification(
              email: email,
            );

            if (result.success) {
              return null;
            }

            return result.message;
          },
          onVerified: () {
            _showVerificationSuccess();
          },
        ),
      ),
    );
  }

  Future<void>
      _showVerificationSuccess() async {
    if (!mounted) {
      return;
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
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
            width: 58,
            height: 58,
            decoration:
                BoxDecoration(
              color:
                  AppColors.tealLight,
              borderRadius:
                  BorderRadius.circular(
                18,
              ),
            ),
            child: const Icon(
              Icons
                  .check_circle_outline_rounded,
              color:
                  AppColors.tealDark,
              size: 30,
            ),
          ),
          title: const Text(
            'Email verified!',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  AppColors.navy,
              fontSize: 19,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
          content: Text(
            'Your registration has been submitted successfully. '
            'You can sign in once your account has been approved.',
            textAlign:
                TextAlign.center,
            style: TextStyle(
              color:
                  AppColors.navy
                      .withValues(
                alpha: 0.54,
              ),
              fontSize: 11.5,
              height: 1.5,
            ),
          ),
          actionsAlignment:
              MainAxisAlignment.center,
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  dialogContext,
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
              child: const Text(
                'Back to Login',
                style: TextStyle(
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (!mounted) {
      return;
    }

    Navigator.of(context)
        .pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) =>
            const LoginScreen(),
      ),
      (route) => false,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          AppColors.grayBg,
      resizeToAvoidBottomInset:
          true,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),

            Expanded(
              child:
                  SingleChildScrollView(
                controller:
                    _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior
                        .onDrag,
                padding:
                    const EdgeInsets.fromLTRB(
                  20,
                  10,
                  20,
                  30,
                ),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment
                          .start,
                  children: [
                    _buildHeader(),

                    const SizedBox(
                      height: 22,
                    ),

                    _buildProgress(),

                    const SizedBox(
                      height: 20,
                    ),

                    if (_currentStep ==
                        1)
                      _buildPersonalCard(),

                    if (_currentStep ==
                        2)
                      _buildAddressCard(),

                    if (_currentStep ==
                        3)
                      _buildVerificationCard(),

                    if (_currentStep ==
                        4)
                      _buildSecurityCard(),
                  ],
                ),
              ),
            ),

            _buildBottomNavigation(),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // TOP BAR
  // ============================================================

  Widget _buildAppBar() {
    return Padding(
      padding:
          const EdgeInsets.fromLTRB(
        18,
        12,
        18,
        8,
      ),
      child: Row(
        children: [
          Material(
            color:
                Colors.white,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
            child: InkWell(
              onTap: () {
                Navigator.pop(
                  context,
                );
              },
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              child: Container(
                width: 44,
                height: 44,
                decoration:
                    BoxDecoration(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color:
                        AppColors
                            .grayBorder,
                  ),
                ),
                child:
                    const Icon(
                  Icons
                      .arrow_back_ios_new_rounded,
                  size: 17,
                  color:
                      AppColors.navy,
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

          const SizedBox(
            width: 7,
          ),

          const Text(
            'ShopHop',
            style: TextStyle(
              color:
                  AppColors.navy,
              fontSize: 15,
              fontWeight:
                  FontWeight.w800,
              letterSpacing:
                  -0.2,
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // HEADER
  // ============================================================

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'BUYER REGISTRATION',
          style: TextStyle(
            color:
                AppColors.tealDark,
            fontSize: 10,
            fontWeight:
                FontWeight.w800,
            letterSpacing: 1.3,
          ),
        ),

        const SizedBox(
          height: 7,
        ),

        const Text(
          'Create your account',
          style: TextStyle(
            color:
                AppColors.navy,
            fontSize: 28,
            height: 1.1,
            fontWeight:
                FontWeight.w800,
            letterSpacing:
                -0.6,
          ),
        ),

        const SizedBox(
          height: 9,
        ),

        Text(
          'Four quick steps and you’ll be ready to shop.',
          style: TextStyle(
            color: AppColors.navy
                .withValues(
              alpha: 0.48,
            ),
            fontSize: 12,
            height: 1.5,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // PROGRESS
  // ============================================================

  Widget _buildProgress() {
    const labels = [
      'Personal',
      'Address',
      'Verify',
      'Security',
    ];

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.fromLTRB(
        14,
        15,
        14,
        13,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(
          18,
        ),
        border: Border.all(
          color:
              AppColors.grayBorder,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'REGISTRATION PROGRESS',
                style: TextStyle(
                  color: AppColors.navy
                      .withValues(
                    alpha: 0.40,
                  ),
                  fontSize: 9,
                  fontWeight:
                      FontWeight.w700,
                  letterSpacing: 0.7,
                ),
              ),

              const Spacer(),

              Text(
                '$_currentStep of 4',
                style:
                    const TextStyle(
                  color:
                      AppColors.tealDark,
                  fontSize: 10,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 15,
          ),

          Row(
            children:
                List.generate(
              7,
              (index) {
                if (index.isOdd) {
                  final lineStep =
                      ((index + 1) /
                              2)
                          .floor();

                  return Expanded(
                    child:
                        AnimatedContainer(
                      duration:
                          const Duration(
                        milliseconds: 180,
                      ),
                      height: 2,
                      color:
                          lineStep <
                                  _currentStep
                              ? AppColors.teal
                              : AppColors.grayBorder,
                    ),
                  );
                }

                final step =
                    (index ~/ 2) +
                        1;

                return _stepCircle(
                  step,
                );
              },
            ),
          ),

          const SizedBox(
            height: 9,
          ),

          Row(
            mainAxisAlignment:
                MainAxisAlignment
                    .spaceBetween,
            children:
                List.generate(
              labels.length,
              (index) {
                final step =
                    index + 1;

                final reached =
                    step <=
                        _currentStep;

                return SizedBox(
                  width: 58,
                  child: Text(
                    labels[index],
                    textAlign:
                        TextAlign.center,
                    style: TextStyle(
                      color: reached
                          ? AppColors.navy
                          : AppColors.navy
                              .withValues(
                              alpha: 0.27,
                            ),
                      fontSize: 9,
                      fontWeight:
                          reached
                              ? FontWeight.w600
                              : FontWeight.w500,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _stepCircle(
    int step,
  ) {
    final completed =
        step <
            _currentStep;

    final active =
        step ==
            _currentStep;

    final highlighted =
        completed ||
            active;

    return AnimatedContainer(
      duration:
          const Duration(
        milliseconds: 180,
      ),
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape:
            BoxShape.circle,
        color: highlighted
            ? AppColors.teal
            : Colors.white,
        border: Border.all(
          color: highlighted
              ? AppColors.teal
              : AppColors.grayBorder,
          width: 1.5,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color:
                      AppColors.teal
                          .withValues(
                    alpha: 0.18,
                  ),
                  blurRadius: 0,
                  spreadRadius: 4,
                ),
              ]
            : null,
      ),
      alignment:
          Alignment.center,
      child: completed
          ? const Icon(
              Icons.check_rounded,
              size: 16,
              color:
                  Colors.white,
            )
          : Text(
              '$step',
              style: TextStyle(
                color: active
                    ? Colors.white
                    : AppColors.navy
                        .withValues(
                      alpha: 0.30,
                    ),
                fontSize: 10,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
    );
  }

  // ============================================================
  // STEP 1
  // ============================================================

  Widget _buildPersonalCard() {
    return _stepCard(
      child: Form(
        key:
            _personalFormKey,
        child:
            BuyerPersonalStep(
          firstNameController:
              _firstNameController,
          lastNameController:
              _lastNameController,
          middleInitialController:
              _middleInitialController,
          emailController:
              _emailController,
          contactController:
              _contactController,
          birthdayController:
              _birthdayController,
          ageController:
              _ageController,
          selectedSex:
              _selectedSex,
          onSexChanged:
              (value) {
            setState(() {
              _selectedSex =
                  value;
            });
          },
          onBirthdayTap:
              _selectBirthday,
        ),
      ),
    );
  }

  // ============================================================
  // STEP 2
  // ============================================================

  Widget _buildAddressCard() {
    return _stepCard(
      child: Form(
        key:
            _addressFormKey,
        child:
            BuyerAddressStep(
          streetAddressController:
              _streetAddressController,

          provinceCode:
              _provinceCode,

          municipalityCode:
              _municipalityCode,

          barangayCode:
              _barangayCode,

          onProvinceChanged: (
            code,
            name,
          ) {
            setState(() {
              _provinceCode =
                  code;

              _provinceName =
                  name.isEmpty
                      ? null
                      : name;

              _municipalityCode =
                  null;

              _municipalityName =
                  null;

              _barangayCode =
                  null;

              _barangayName =
                  null;
            });
          },

          onMunicipalityChanged: (
            code,
            name,
          ) {
            setState(() {
              _municipalityCode =
                  code;

              _municipalityName =
                  name.isEmpty
                      ? null
                      : name;

              _barangayCode =
                  null;

              _barangayName =
                  null;
            });
          },

          onBarangayChanged: (
            code,
            name,
          ) {
            setState(() {
              _barangayCode =
                  code;

              _barangayName =
                  name.isEmpty
                      ? null
                      : name;
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // STEP 3
  // ============================================================

  Widget _buildVerificationCard() {
    return _stepCard(
      child: Form(
        key:
            _verificationFormKey,
        child:
            BuyerVerificationStep(
          selectedFile:
              _validIdFile,
          onFileChanged:
              (file) {
            setState(() {
              _validIdFile =
                  file;
            });
          },
        ),
      ),
    );
  }

  // ============================================================
  // STEP 4
  // ============================================================

  Widget _buildSecurityCard() {
    return _stepCard(
      child: Form(
        key: _securityFormKey,
        child: BuyerSecurityStep(
          passwordController: _passwordController,
          confirmPasswordController: _confirmPasswordController,
          termsAccepted: _termsAccepted,
          onTermsChanged: (value) {
            setState(() {
              _termsAccepted = value;
            });
          },
          onTermsTap: () {
            _showMessage(
              'Terms and Conditions page will be connected next.',
            );
          },
          onPrivacyTap: () {
            _showMessage(
              'Privacy Policy page will be connected next.',
            );
          },
        ),
      ),
    );
  }

  // ============================================================
  // STEP CARD
  // ============================================================

  Widget _stepCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              AppColors.grayBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy
                .withValues(
              alpha: 0.035,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  // ============================================================
  // BOTTOM NAVIGATION
  // ============================================================

  Widget _buildBottomNavigation() {
    final showBack = _currentStep > 1;
    final isLastStep = _currentStep == 4;

    return Container(
      padding: const EdgeInsets.fromLTRB(
        20,
        12,
        20,
        18,
      ),
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
                  onPressed: _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(
                      color: AppColors.grayBorder,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Back',
                        style: TextStyle(
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
                  onPressed: _isSubmitting
                      ? null
                      : isLastStep
                          ? _createAccount
                          : _nextStep,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 21,
                          height: 21,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        isLastStep ? 'Create Account' : 'Continue',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        isLastStep
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