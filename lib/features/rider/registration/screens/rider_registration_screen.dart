import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'package:shophop/features/auth/data/services/auth_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/shared/registration/steps/address_step.dart';
import 'package:shophop/shared/registration/steps/personal_details_step.dart';
import 'package:shophop/features/auth/presentation/screens/login_screen.dart';
import 'package:shophop/features/auth/presentation/screens/email_verification_screen.dart';
import 'package:shophop/features/auth/domain/registration_role.dart';
import 'package:shophop/features/rider/registration/steps/rider_details_step.dart';
import 'package:shophop/features/rider/registration/steps/rider_security_step.dart';
import 'package:shophop/features/rider/registration/widgets/rider_registration_widgets.dart';
import 'package:shophop/features/rider/registration/widgets/rider_ui.dart';

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
  String? _provinceName;
  String? _municipalityCode;
  String? _municipalityName;
  String? _barangayCode;
  String? _barangayName;

  PlatformFile? _orCr;
  PlatformFile? _idOrLicense;

  final List<Map<String, dynamic>> _logisticsCenters = [];
  int? _logisticsPartnerId;
  bool _loadingLogisticsCenters = true;
  String? _logisticsCentersError;
  bool _termsAccepted = false;
  bool _isSubmitting = false;
  int _step = 1;

  @override
  void initState() {
    super.initState();
    _loadLogisticsCenters();
  }

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

  Future<void> _loadLogisticsCenters() async {
    final result = await AuthService.riderLogisticsCenters();
    if (!mounted) return;

    final rawCenters = result.data['centers'];
    final centers = rawCenters is List
        ? rawCenters
            .whereType<Map>()
            .map((value) => Map<String, dynamic>.from(value))
            .where((value) => int.tryParse(value['id']?.toString() ?? '') != null)
            .toList()
        : <Map<String, dynamic>>[];

    setState(() {
      _loadingLogisticsCenters = false;
      _logisticsCenters
        ..clear()
        ..addAll(centers);
      _logisticsCentersError = result.success
          ? (centers.isEmpty
              ? 'No approved Logistics / Sorting Center is available yet.'
              : null)
          : result.message;
    });
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
    if (_isSubmitting) return;
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

  Future<void> _createAccount() async {
    FocusScope.of(context).unfocus();

    if (_isSubmitting) return;

    final valid = _securityKey.currentState?.validate() ?? false;
    if (!valid) {
      _message('Please complete the security requirements.');
      return;
    }

    if (_logisticsPartnerId == null ||
        _provinceCode == null ||
        _provinceName == null ||
        _municipalityCode == null ||
        _municipalityName == null ||
        _barangayCode == null ||
        _barangayName == null ||
        _sex == null ||
        _orCr == null ||
        _idOrLicense == null) {
      _message('Please review the Rider registration details.');
      return;
    }

    setState(() => _isSubmitting = true);

    final result = await AuthService.registerRider(
      logisticsPartnerId: _logisticsPartnerId!,
      firstName: _firstName.text,
      lastName: _lastName.text,
      middleInitial: _middleInitial.text,
      sex: _sex!,
      email: _email.text,
      contactNo: _contact.text,
      birthday: _birthday.text,
      provinceCode: _provinceCode!,
      provinceName: _provinceName!,
      municipalityCode: _municipalityCode!,
      municipalityName: _municipalityName!,
      barangayCode: _barangayCode!,
      barangayName: _barangayName!,
      streetAddress: _street.text,
      vehicleType: _vehicle.text,
      plateNumber: _plate.text,
      orCr: _orCr!,
      idOrLicense: _idOrLicense!,
      password: _password.text,
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (!result.success) {
      _message(result.message);
      return;
    }

    _message(result.message);
    _openEmailVerification();
  }

  void _openEmailVerification() {
    final email = _email.text.trim();

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmailVerificationScreen(
          email: email,
          role: RegistrationRole.rider,
          onVerifyCode: (code) async {
            final result = await AuthService.verifyRiderEmail(
              email: email,
              code: code,
            );
            return result.success ? null : result.message;
          },
          onResendCode: () async {
            final result = await AuthService.resendRiderVerification(
              email: email,
            );
            return result.success ? null : result.message;
          },
          onVerified: () {
            if (!mounted) return;

            Navigator.of(context).pushAndRemoveUntil(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
              (route) => false,
            );
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
              child: PersonalDetailsStep(
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
              child: AddressStep(
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _logisticsCenterField(),
                  const SizedBox(height: 24),
                  RiderDetailsStep(
                    vehicleController: _vehicle,
                    plateNumberController: _plate,
                    orCrFile: _orCr,
                    idOrLicenseFile: _idOrLicense,
                    onOrCrChanged: (file) => setState(() => _orCr = file),
                    onIdOrLicenseChanged: (file) =>
                        setState(() => _idOrLicense = file),
                  ),
                ],
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

  Widget _logisticsCenterField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
                Icons.warehouse_outlined,
                color: AppColors.tealDark,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Logistics / Sorting Center',
                    style: TextStyle(
                      color: AppColors.navy,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Choose the center that will review your Rider application and manage your assignments.',
                    style: TextStyle(
                      color: AppColors.navy.withValues(alpha: 0.45),
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (_loadingLogisticsCenters)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(12),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_logisticsCentersError != null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF4E5),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Unable to load an approved Logistics / Sorting Center.',
                    style: TextStyle(color: AppColors.navy, fontSize: 11),
                  ),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _loadingLogisticsCenters = true;
                      _logisticsCentersError = null;
                    });
                    _loadLogisticsCenters();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          )
        else
          DropdownButtonFormField<int>(
            initialValue: _logisticsPartnerId,
            isExpanded: true,
            decoration: RiderUi.inputDecoration(
              hint: 'Select Logistics / Sorting Center',
              icon: Icons.warehouse_outlined,
            ),
            items: _logisticsCenters.map((center) {
              final id = int.parse(center['id'].toString());
              return DropdownMenuItem<int>(
                value: id,
                child: Text(
                  center['label']?.toString() ??
                      center['company_name']?.toString() ??
                      'Logistics Center',
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12),
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _logisticsPartnerId = value),
            validator: (value) => value == null
                ? 'Please select your Logistics / Sorting Center.'
                : null,
          ),
      ],
    );
  }

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
              onTap: _isSubmitting ? null : () => Navigator.pop(context),
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
                  onPressed: _isSubmitting ? null : () => _goTo(_step - 1),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.navy,
                    side: const BorderSide(color: AppColors.grayBorder),
                    padding: const EdgeInsets.symmetric(horizontal: 17),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.arrow_back_rounded, size: 18),
                      SizedBox(width: 6),
                      Text('Back'),
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
                          : _next,
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
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Row(
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
