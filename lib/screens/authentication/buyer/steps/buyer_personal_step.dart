import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_colors.dart';

class BuyerPersonalStep extends StatelessWidget {
  const BuyerPersonalStep({
    super.key,
    required this.firstNameController,
    required this.lastNameController,
    required this.middleInitialController,
    required this.emailController,
    required this.contactController,
    required this.birthdayController,
    required this.ageController,
    required this.selectedSex,
    required this.onSexChanged,
    required this.onBirthdayTap,
  });

  final TextEditingController
      firstNameController;

  final TextEditingController
      lastNameController;

  final TextEditingController
      middleInitialController;

  final TextEditingController
      emailController;

  final TextEditingController
      contactController;

  final TextEditingController
      birthdayController;

  final TextEditingController
      ageController;

  final String? selectedSex;

  final ValueChanged<String?>
      onSexChanged;

  final VoidCallback
      onBirthdayTap;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(),

        const SizedBox(
          height: 24,
        ),

        _buildTextField(
          controller:
              firstNameController,
          label:
              'First name',
          hint:
              'Enter your first name',
          icon:
              Icons.person_outline_rounded,
          textInputAction:
              TextInputAction.next,
          textCapitalization:
              TextCapitalization.words,
          autofillHints: const [
            AutofillHints.givenName,
          ],
          validator: (value) {
            final firstName =
                value?.trim() ?? '';

            if (firstName.isEmpty) {
              return 'First name is required.';
            }

            if (firstName.length < 2) {
              return 'Enter a valid first name.';
            }

            return null;
          },
        ),

        const SizedBox(
          height: 18,
        ),

        _buildTextField(
          controller:
              lastNameController,
          label:
              'Last name',
          hint:
              'Enter your last name',
          icon:
              Icons.badge_outlined,
          textInputAction:
              TextInputAction.next,
          textCapitalization:
              TextCapitalization.words,
          autofillHints: const [
            AutofillHints.familyName,
          ],
          validator: (value) {
            final lastName =
                value?.trim() ?? '';

            if (lastName.isEmpty) {
              return 'Last name is required.';
            }

            if (lastName.length < 2) {
              return 'Enter a valid last name.';
            }

            return null;
          },
        ),

        const SizedBox(
          height: 18,
        ),

        _buildTextField(
          controller:
              middleInitialController,
          label:
              'Middle initial',
          hint:
              'e.g. M.',
          icon:
              Icons.short_text_rounded,
          textInputAction:
              TextInputAction.next,
          textCapitalization:
              TextCapitalization.characters,
          requiredField:
              false,
          inputFormatters: [
            FilteringTextInputFormatter.allow(
              RegExp(
                r'[a-zA-Z.]',
              ),
            ),
            LengthLimitingTextInputFormatter(
              2,
            ),
          ],
          validator: (value) {
            final middle =
                value?.trim() ?? '';

            if (middle.isEmpty) {
              return null;
            }

            final valid =
                RegExp(
              r'^[A-Za-z]\.?$',
            ).hasMatch(
              middle,
            );

            if (!valid) {
              return 'Use an initial like M or M.';
            }

            return null;
          },
        ),

        const SizedBox(
          height: 18,
        ),

        _buildSexField(),

        const SizedBox(
          height: 18,
        ),

        _buildTextField(
          controller:
              emailController,
          label:
              'Email address',
          hint:
              'you@example.com',
          icon:
              Icons.mail_outline_rounded,
          keyboardType:
              TextInputType.emailAddress,
          textInputAction:
              TextInputAction.next,
          autofillHints: const [
            AutofillHints.email,
          ],
          validator: (value) {
            final email =
                value?.trim() ?? '';

            if (email.isEmpty) {
              return 'Email address is required.';
            }

            final emailPattern =
                RegExp(
              r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
            );

            if (!emailPattern
                .hasMatch(email)) {
              return 'Enter a valid email address.';
            }

            return null;
          },
        ),

        const SizedBox(
          height: 18,
        ),

        _buildTextField(
          controller:
              contactController,
          label:
              'Contact number',
          hint:
              '09XXXXXXXXX',
          icon:
              Icons.phone_outlined,
          keyboardType:
              TextInputType.phone,
          textInputAction:
              TextInputAction.next,
          autofillHints: const [
            AutofillHints.telephoneNumber,
          ],
          inputFormatters: [
            FilteringTextInputFormatter
                .digitsOnly,
            LengthLimitingTextInputFormatter(
              11,
            ),
          ],
          validator: (value) {
            final contact =
                value?.trim() ?? '';

            if (contact.isEmpty) {
              return 'Contact number is required.';
            }

            if (!RegExp(
              r'^09\d{9}$',
            ).hasMatch(contact)) {
              return 'Use an 11-digit number starting with 09.';
            }

            return null;
          },
        ),

        const SizedBox(
          height: 18,
        ),

        _buildBirthdayAndAge(),

        const SizedBox(
          height: 6,
        ),
      ],
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration:
              BoxDecoration(
            color:
                AppColors.tealLight,
            borderRadius:
                BorderRadius.circular(
              14,
            ),
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color:
                AppColors.tealDark,
            size: 21,
          ),
        ),

        const SizedBox(
          width: 13,
        ),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Personal information',
                style: TextStyle(
                  color:
                      AppColors.navy,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(
                height: 4,
              ),

              Text(
                'Tell us a little about yourself.',
                style: TextStyle(
                  color: AppColors
                      .navy
                      .withValues(
                    alpha: 0.45,
                  ),
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSexField() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _label(
          'Sex',
          required: true,
        ),

        const SizedBox(
          height: 8,
        ),

        DropdownButtonFormField<
            String>(
          initialValue:
              selectedSex,
          isExpanded:
              true,
          icon:
              const Icon(
            Icons
                .keyboard_arrow_down_rounded,
            color:
                AppColors.navy,
          ),
          decoration:
              _inputDecoration(
            hint:
                'Select sex',
            icon:
                Icons.groups_2_outlined,
          ),
          items:
              const [
            DropdownMenuItem(
              value:
                  'Male',
              child:
                  Text('Male'),
            ),
            DropdownMenuItem(
              value:
                  'Female',
              child:
                  Text('Female'),
            ),
            DropdownMenuItem(
              value:
                  'Prefer not to say',
              child:
                  Text(
                'Prefer not to say',
              ),
            ),
          ],
          onChanged:
              onSexChanged,
          validator:
              (value) {
            if (value == null ||
                value.isEmpty) {
              return 'Please select your sex.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildBirthdayAndAge() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _label(
                'Birthday',
                required: true,
              ),

              const SizedBox(
                height: 8,
              ),

              TextFormField(
                controller:
                    birthdayController,
                readOnly: true,
                onTap:
                    onBirthdayTap,
                style:
                    const TextStyle(
                  color:
                      AppColors.navy,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w500,
                ),
                decoration:
                    _inputDecoration(
                  hint:
                      'Select date',
                  icon:
                      Icons
                          .calendar_month_outlined,
                ).copyWith(
                  suffixIcon:
                      const Icon(
                    Icons
                        .keyboard_arrow_down_rounded,
                    color:
                        AppColors.navy,
                  ),
                ),
                validator:
                    (value) {
                  if (value == null ||
                      value
                          .trim()
                          .isEmpty) {
                    return 'Birthday is required.';
                  }

                  return null;
                },
              ),
            ],
          ),
        ),

        const SizedBox(
          width: 12,
        ),

        Expanded(
          flex: 2,
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              _label(
                'Age',
              ),

              const SizedBox(
                height: 8,
              ),

              TextFormField(
                controller:
                    ageController,
                readOnly:
                    true,
                style:
                    const TextStyle(
                  color:
                      AppColors.navy,
                  fontSize: 13,
                  fontWeight:
                      FontWeight.w600,
                ),
                textAlign:
                    TextAlign.center,
                decoration:
                    _inputDecoration(
                  hint:
                      '--',
                  icon:
                      Icons
                          .cake_outlined,
                ).copyWith(
                  fillColor:
                      AppColors.grayBg,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController
        controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(
      String?,
    ) validator,
    TextInputType? keyboardType,
    TextInputAction? textInputAction,
    TextCapitalization
        textCapitalization =
        TextCapitalization.none,
    List<TextInputFormatter>?
        inputFormatters,
    List<String>?
        autofillHints,
    bool requiredField = true,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _label(
          label,
          required:
              requiredField,
        ),

        const SizedBox(
          height: 8,
        ),

        TextFormField(
          controller:
              controller,
          keyboardType:
              keyboardType,
          textInputAction:
              textInputAction,
          textCapitalization:
              textCapitalization,
          inputFormatters:
              inputFormatters,
          autofillHints:
              autofillHints,
          validator:
              validator,
          style:
              const TextStyle(
            color:
                AppColors.navy,
            fontSize: 13,
            fontWeight:
                FontWeight.w500,
          ),
          decoration:
              _inputDecoration(
            hint:
                hint,
            icon:
                icon,
          ),
        ),
      ],
    );
  }

  Widget _label(
    String label, {
    bool required = false,
  }) {
    return RichText(
      text: TextSpan(
        style:
            const TextStyle(
          color:
              AppColors.navy,
          fontSize: 12,
          fontWeight:
              FontWeight.w600,
        ),
        children: [
          TextSpan(
            text:
                label,
          ),

          if (required)
            const TextSpan(
              text:
                  ' *',
              style:
                  TextStyle(
                color:
                    Color(
                  0xFFDB5757,
                ),
              ),
            ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText:
          hint,

      hintStyle:
          TextStyle(
        color:
            AppColors.navy
                .withValues(
          alpha: 0.27,
        ),
        fontSize: 13,
      ),

      prefixIcon:
          Icon(
        icon,
        size: 19,
        color:
            AppColors.navy
                .withValues(
          alpha: 0.35,
        ),
      ),

      filled:
          true,

      fillColor:
          Colors.white,

      contentPadding:
          const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 15,
      ),

      enabledBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        borderSide:
            const BorderSide(
          color:
              AppColors.grayBorder,
        ),
      ),

      focusedBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        borderSide:
            const BorderSide(
          color:
              AppColors.teal,
          width: 1.5,
        ),
      ),

      errorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        borderSide:
            const BorderSide(
          color:
              Color(
            0xFFDB5757,
          ),
        ),
      ),

      focusedErrorBorder:
          OutlineInputBorder(
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        borderSide:
            const BorderSide(
          color:
              Color(
            0xFFDB5757,
          ),
          width: 1.5,
        ),
      ),

      errorStyle:
          const TextStyle(
        fontSize: 10,
        height: 1.3,
      ),
    );
  }
}