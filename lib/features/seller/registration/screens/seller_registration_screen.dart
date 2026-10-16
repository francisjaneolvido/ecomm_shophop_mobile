import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:shophop/features/auth/domain/registration_role.dart';
import 'package:shophop/shared/registration/steps/address_step.dart';
import 'package:shophop/shared/registration/steps/personal_details_step.dart';
import 'package:shophop/features/seller/registration/steps/seller_business_step.dart';
import 'package:shophop/features/seller/registration/steps/seller_security_step.dart';
import 'package:shophop/features/seller/registration/steps/seller_verification_step.dart';
import 'package:shophop/features/seller/registration/widgets/seller_registration_widgets.dart';
import 'package:shophop/features/seller/registration/widgets/seller_ui.dart';

class SellerRegistrationScreen
    extends StatefulWidget {
  const SellerRegistrationScreen({
    super.key,
  });

  @override
  State<SellerRegistrationScreen> createState() =>
      _SellerRegistrationScreenState();
}

class _SellerRegistrationScreenState
    extends State<SellerRegistrationScreen> {
  final _scrollController = ScrollController();

  final _personalFormKey = GlobalKey<FormState>();
  final _addressFormKey = GlobalKey<FormState>();
  final _businessFormKey = GlobalKey<FormState>();
  final _verificationFormKey = GlobalKey<FormState>();
  final _securityFormKey = GlobalKey<FormState>();

  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _middleInitialController = TextEditingController();
  final _emailController = TextEditingController();
  final _contactController = TextEditingController();
  final _birthdayController = TextEditingController();
  final _ageController = TextEditingController();

  final _streetAddressController = TextEditingController();

  final _businessNameController = TextEditingController();
  final _businessCategoryController = TextEditingController();

  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _selectedSex;
  DateTime? _selectedBirthday;

  String? _regionCode;
  String? _regionName;
  String? _provinceCode;
  String? _provinceName;

  String? _municipalityCode;
  String? _municipalityName;

  String? _barangayCode;
  String? _barangayName;

  PlatformFile? _validIdFile;
  PlatformFile? _businessPermitFile;

  bool _termsAccepted = false;
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

    _businessNameController.dispose();
    _businessCategoryController.dispose();

    _passwordController.dispose();
    _confirmPasswordController.dispose();

    super.dispose();
  }

  Future<void> _selectBirthday() async {
    FocusScope.of(context).unfocus();

    final now = DateTime.now();

    final initial = _selectedBirthday ??
        DateTime(
          now.year - 18,
          now.month,
          now.day,
        );

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(
        now.year - 18,
        now.month,
        now.day,
      ),
      helpText: 'Select your birthday',
      cancelText: 'Cancel',
      confirmText: 'Select',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.teal,
              onPrimary: Colors.white,
              onSurface: AppColors.navy,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked == null) {
      return;
    }
    if (picked.isAfter(DateTime(now.year - 18, now.month, now.day))) {
      _showMessage('Sellers must be at least 18 years old.');
      return;
    }

    int age = now.year - picked.year;

    final birthdayNotReached =
        now.month < picked.month ||
            (now.month == picked.month &&
                now.day < picked.day);

    if (birthdayNotReached) {
      age--;
    }

    setState(() {
      _selectedBirthday = picked;

      _birthdayController.text =
          '${picked.year}-'
          '${picked.month.toString().padLeft(2, '0')}-'
          '${picked.day.toString().padLeft(2, '0')}';

      _ageController.text = '$age';
    });
  }

  void _nextStep() {
    FocusScope.of(context).unfocus();

    bool valid = false;

    if (_currentStep == 1) {
      valid =
          _personalFormKey.currentState?.validate() ??
              false;
    } else if (_currentStep == 2) {
      valid =
          _addressFormKey.currentState?.validate() ??
              false;
    } else if (_currentStep == 3) {
      valid =
          _businessFormKey.currentState?.validate() ??
              false;
    } else if (_currentStep == 4) {
      valid =
          _verificationFormKey.currentState?.validate() ??
              false;
    }

    if (!valid) {
      _showMessage(
        _currentStep == 4
            ? 'Please upload the required seller documents.'
            : 'Please check the required fields.',
      );
      return;
    }

    if (_currentStep < 5) {
      _goToStep(_currentStep + 1);
    }
  }

  void _previousStep() {
    FocusScope.of(context).unfocus();

    if (_currentStep > 1) {
      _goToStep(_currentStep - 1);
    }
  }

  void _goToStep(int step) {
    setState(() {
      _currentStep = step;
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }

      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _createAccount() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    if (!(_securityFormKey.currentState?.validate() ?? false)) {
      _showMessage('Please complete the password and seller agreement.');
      return;
    }
    if (_validIdFile == null || _businessPermitFile == null) {
      _goToStep(4);
      _showMessage('Please upload your valid ID and business permit.');
      return;
    }
    if (_businessNameController.text.trim().isEmpty ||
        _businessCategoryController.text.trim().isEmpty) {
      _goToStep(3);
      _showMessage('Please complete your business details.');
      return;
    }
    if (_provinceCode == null || _provinceName == null ||
        _municipalityCode == null || _municipalityName == null ||
        _barangayCode == null || _barangayName == null ||
        _streetAddressController.text.trim().isEmpty) {
      _goToStep(2);
      _showMessage('Please complete the delivery address.');
      return;
    }
    if (_selectedSex == null || _birthdayController.text.isEmpty ||
        _firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _contactController.text.trim().isEmpty) {
      _goToStep(1);
      _showMessage('Please complete your personal details.');
      return;
    }

    setState(() => _isSubmitting = true);
    final result = await AuthService.registerSeller(
      firstName: _firstNameController.text,
      lastName: _lastNameController.text,
      middleInitial: _middleInitialController.text,
      sex: _selectedSex!,
      email: _emailController.text,
      contactNo: _contactController.text,
      birthday: _birthdayController.text,
      regionCode: _regionCode,
      regionName: _regionName,
      provinceCode: _provinceCode!,
      provinceName: _provinceName!,
      municipalityCode: _municipalityCode!,
      municipalityName: _municipalityName!,
      barangayCode: _barangayCode!,
      barangayName: _barangayName!,
      streetAddress: _streetAddressController.text,
      businessName: _businessNameController.text,
      businessCategory: _businessCategoryController.text,
      validId: _validIdFile!,
      businessPermit: _businessPermitFile!,
      password: _passwordController.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);
    if (!result.success) {
      _showMessage(result.message);
      return;
    }

    if (result.data['otp_delivery'] == 'failed') {
      _showMessage(result.message);
    }
    _openEmailVerification();
  }

  void _openEmailVerification() {
    final email = _emailController.text.trim().toLowerCase();
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(
          email: email,
          role: RegistrationRole.seller,
          onVerifyCode: (code) async {
            final result = await AuthService.verifySellerEmail(
              email: email,
              code: code,
            );
            return result.success ? null : result.message;
          },
          onResendCode: () async {
            final result = await AuthService.resendSellerVerification(
              email: email,
            );
            return result.success ? null : result.message;
          },
          onVerified: _showVerificationSuccess,
        ),
      ),
    );
  }

  Future<void> _showVerificationSuccess() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Seller email verified!'),
        content: const Text(
          'Your seller registration has been submitted. '
          'Please wait for administrator approval before signing in. '
          'The Seller mobile dashboard is not available yet.',
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Back to Login'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  message,
                  style: SellerUi.text(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.grayBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            _buildAppBar(),
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SellerRegistrationHeader(),
                    const SizedBox(height: 22),
                    SellerRegistrationProgress(
                      currentStep: _currentStep,
                    ),
                    const SizedBox(height: 20),
                    _buildCurrentStep(),
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

  Widget _buildCurrentStep() {
    if (_currentStep == 1) {
      return _buildPersonalCard();
    }

    if (_currentStep == 2) {
      return _buildAddressCard();
    }

    if (_currentStep == 3) {
      return _buildBusinessCard();
    }

    if (_currentStep == 4) {
      return _buildVerificationCard();
    }

    return _buildSecurityCard();
  }

  Widget _buildPersonalCard() {
    return _stepCard(
      child: Form(
        key: _personalFormKey,
        child: PersonalDetailsStep(
          firstNameController: _firstNameController,
          lastNameController: _lastNameController,
          middleInitialController:
              _middleInitialController,
          emailController: _emailController,
          contactController: _contactController,
          birthdayController: _birthdayController,
          ageController: _ageController,
          selectedSex: _selectedSex,
          onSexChanged: (value) {
            setState(() {
              _selectedSex = value;
            });
          },
          onBirthdayTap: _selectBirthday,
        ),
      ),
    );
  }

  Widget _buildAddressCard() {
    return _stepCard(
      child: Form(
        key: _addressFormKey,
        child: AddressStep(
          streetAddressController:
              _streetAddressController,
          provinceCode: _provinceCode,
          municipalityCode: _municipalityCode,
          barangayCode: _barangayCode,
          onRegionChanged: (code, name) {
            setState(() {
              _regionCode = code;
              _regionName = name.isEmpty ? null : name;
            });
          },
          onProvinceChanged: (code, name) {
            setState(() {
              _provinceCode = code;
              _provinceName =
                  name.isEmpty ? null : name;

              _municipalityCode = null;
              _municipalityName = null;

              _barangayCode = null;
              _barangayName = null;
            });
          },
          onMunicipalityChanged: (code, name) {
            setState(() {
              _municipalityCode = code;
              _municipalityName =
                  name.isEmpty ? null : name;

              _barangayCode = null;
              _barangayName = null;
            });
          },
          onBarangayChanged: (code, name) {
            setState(() {
              _barangayCode = code;
              _barangayName =
                  name.isEmpty ? null : name;
            });
          },
        ),
      ),
    );
  }

  Widget _buildBusinessCard() {
    return _stepCard(
      child: Form(
        key: _businessFormKey,
        child: SellerBusinessStep(
          businessNameController:
              _businessNameController,
          businessCategoryController:
              _businessCategoryController,
        ),
      ),
    );
  }

  Widget _buildVerificationCard() {
    return _stepCard(
      child: Form(
        key: _verificationFormKey,
        child: SellerVerificationStep(
          validIdFile: _validIdFile,
          businessPermitFile: _businessPermitFile,
          onValidIdChanged: (file) {
            setState(() {
              _validIdFile = file;
            });
          },
          onBusinessPermitChanged: (file) {
            setState(() {
              _businessPermitFile = file;
            });
          },
        ),
      ),
    );
  }

  Widget _buildSecurityCard() {
    return _stepCard(
      child: Form(
        key: _securityFormKey,
        child: SellerSecurityStep(
          passwordController: _passwordController,
          confirmPasswordController:
              _confirmPasswordController,
          termsAccepted: _termsAccepted,
          onTermsChanged: (value) {
            setState(() {
              _termsAccepted = value;
            });
          },
          onTermsTap: () {
            _showMessage(
              'Seller Terms and Conditions screen will be connected later.',
            );
          },
          onPrivacyTap: () {
            _showMessage(
              'Privacy Policy screen will be connected later.',
            );
          },
        ),
      ),
    );
  }

  Widget _stepCard({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.grayBorder,
        ),
        boxShadow: [
          BoxShadow(
            color:
                AppColors.navy.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildAppBar() {
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
            fit: BoxFit.contain,
          ),
          const SizedBox(width: 7),
          Text(
            'ShopHop',
            style: SellerUi.text(
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

  Widget _buildBottomNavigation() {
    final showBack = _currentStep > 1;
    final isFinalStep = _currentStep == 5;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(
            color:
                AppColors.grayBorder.withValues(alpha: 0.8),
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
                  onPressed: _isSubmitting ? null : _previousStep,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(
                      color: AppColors.grayBorder,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 17,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.arrow_back_rounded,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Back',
                        style: SellerUi.text(
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
                  onPressed: _isSubmitting
                      ? null
                      : isFinalStep
                          ? _createAccount
                          : _nextStep,
                  style: ElevatedButton.styleFrom(
                    elevation: 0,
                    backgroundColor: AppColors.teal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(15),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: Colors.white,
                          ),
                        )
                      : Row(
                    mainAxisAlignment:
                        MainAxisAlignment.center,
                    children: [
                      Text(
                        isFinalStep
                            ? 'Create Account'
                            : 'Continue',
                        style: SellerUi.text(
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
