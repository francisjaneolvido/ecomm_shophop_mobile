import 'package:flutter/material.dart';

import '../../../../models/psgc_location.dart';
import '../../../../services/psgc_service.dart';
import '../../../../theme/app_colors.dart';

class BuyerAddressStep
    extends StatefulWidget {
  const BuyerAddressStep({
    super.key,
    required this.streetAddressController,
    required this.provinceCode,
    required this.municipalityCode,
    required this.barangayCode,
    required this.onProvinceChanged,
    required this.onMunicipalityChanged,
    required this.onBarangayChanged,
  });

  final TextEditingController
      streetAddressController;

  final String?
      provinceCode;

  final String?
      municipalityCode;

  final String?
      barangayCode;

  final void Function(
    String? code,
    String name,
  ) onProvinceChanged;

  final void Function(
    String? code,
    String name,
  ) onMunicipalityChanged;

  final void Function(
    String? code,
    String name,
  ) onBarangayChanged;

  @override
  State<BuyerAddressStep>
      createState() =>
          _BuyerAddressStepState();
}

class _BuyerAddressStepState
    extends State<BuyerAddressStep> {
  final PsgcService
      _psgcService =
      PsgcService();

  List<PsgcLocation>
      _provinces = [];

  List<PsgcLocation>
      _municipalities = [];

  List<PsgcLocation>
      _barangays = [];

  String?
      _provinceCode;

  String?
      _municipalityCode;

  String?
      _barangayCode;

  bool _loadingProvinces =
      true;

  bool _loadingMunicipalities =
      false;

  bool _loadingBarangays =
      false;

  String?
      _errorMessage;

  @override
  void initState() {
    super.initState();

    _provinceCode =
        widget.provinceCode;

    _municipalityCode =
        widget.municipalityCode;

    _barangayCode =
        widget.barangayCode;

    _loadInitialData();
  }

  Future<void>
      _loadInitialData() async {
    setState(() {
      _loadingProvinces =
          true;
      _errorMessage =
          null;
    });

    try {
      final provinces =
          await _psgcService
              .getProvinces();

      if (!mounted) {
        return;
      }

      setState(() {
        _provinces =
            provinces;

        _loadingProvinces =
            false;
      });

      if (_provinceCode != null) {
        await _loadMunicipalities(
          _provinceCode!,
          preserveSelection:
              true,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingProvinces =
            false;

        _errorMessage =
            'Unable to load address information. Check your internet connection and try again.';
      });
    }
  }

  Future<void>
      _loadMunicipalities(
    String provinceCode, {
    bool preserveSelection = false,
  }) async {
    setState(() {
      _loadingMunicipalities =
          true;

      _municipalities =
          [];

      _barangays =
          [];

      _errorMessage =
          null;

      if (!preserveSelection) {
        _municipalityCode =
            null;

        _barangayCode =
            null;
      }
    });

    try {
      final municipalities =
          await _psgcService
              .getMunicipalities(
        provinceCode,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _municipalities =
            municipalities;

        _loadingMunicipalities =
            false;
      });

      if (preserveSelection &&
          _municipalityCode !=
              null) {
        await _loadBarangays(
          _municipalityCode!,
          preserveSelection:
              true,
        );
      }
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingMunicipalities =
            false;

        _errorMessage =
            'Unable to load municipalities or cities.';
      });
    }
  }

  Future<void>
      _loadBarangays(
    String municipalityCode, {
    bool preserveSelection = false,
  }) async {
    setState(() {
      _loadingBarangays =
          true;

      _barangays =
          [];

      _errorMessage =
          null;

      if (!preserveSelection) {
        _barangayCode =
            null;
      }
    });

    try {
      final barangays =
          await _psgcService
              .getBarangays(
        municipalityCode,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _barangays =
            barangays;

        _loadingBarangays =
            false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingBarangays =
            false;

        _errorMessage =
            'Unable to load barangays.';
      });
    }
  }

  String _locationName(
    List<PsgcLocation> items,
    String code,
  ) {
    for (final item in items) {
      if (item.code == code) {
        return item.name;
      }
    }

    return '';
  }

  Future<void>
      _handleProvinceChanged(
    String? code,
  ) async {
    setState(() {
      _provinceCode =
          code;

      _municipalityCode =
          null;

      _barangayCode =
          null;

      _municipalities =
          [];

      _barangays =
          [];
    });

    widget.onMunicipalityChanged(
      null,
      '',
    );

    widget.onBarangayChanged(
      null,
      '',
    );

    if (code == null) {
      widget.onProvinceChanged(
        null,
        '',
      );

      return;
    }

    final name =
        _locationName(
      _provinces,
      code,
    );

    widget.onProvinceChanged(
      code,
      name,
    );

    await _loadMunicipalities(
      code,
    );
  }

  Future<void>
      _handleMunicipalityChanged(
    String? code,
  ) async {
    setState(() {
      _municipalityCode =
          code;

      _barangayCode =
          null;

      _barangays =
          [];
    });

    widget.onBarangayChanged(
      null,
      '',
    );

    if (code == null) {
      widget.onMunicipalityChanged(
        null,
        '',
      );

      return;
    }

    final name =
        _locationName(
      _municipalities,
      code,
    );

    widget.onMunicipalityChanged(
      code,
      name,
    );

    await _loadBarangays(
      code,
    );
  }

  void _handleBarangayChanged(
    String? code,
  ) {
    setState(() {
      _barangayCode =
          code;
    });

    if (code == null) {
      widget.onBarangayChanged(
        null,
        '',
      );

      return;
    }

    final name =
        _locationName(
      _barangays,
      code,
    );

    widget.onBarangayChanged(
      code,
      name,
    );
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildHeader(),

        if (_errorMessage !=
            null) ...[
          const SizedBox(
            height: 18,
          ),

          _buildErrorCard(),
        ],

        const SizedBox(
          height: 24,
        ),

        _buildProvinceField(),

        const SizedBox(
          height: 18,
        ),

        _buildMunicipalityField(),

        const SizedBox(
          height: 18,
        ),

        _buildBarangayField(),

        const SizedBox(
          height: 18,
        ),

        _buildStreetField(),

        const SizedBox(
          height: 6,
        ),
      ],
    );
  }

  Widget _buildHeader() {
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
            Icons.location_on_outlined,
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
                'Delivery address',
                style:
                    TextStyle(
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
                'Choose your location, then add your exact street address.',
                style:
                    TextStyle(
                  color: AppColors
                      .navy
                      .withValues(
                    alpha: 0.45,
                  ),
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

  Widget _buildErrorCard() {
    return Container(
      width:
          double.infinity,
      padding:
          const EdgeInsets.all(
        13,
      ),
      decoration:
          BoxDecoration(
        color:
            const Color(
          0xFFFFF4F4,
        ),
        borderRadius:
            BorderRadius.circular(
          14,
        ),
        border:
            Border.all(
          color:
              const Color(
            0xFFF1D0D0,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.center,
        children: [
          const Icon(
            Icons
                .error_outline_rounded,
            size: 18,
            color:
                Color(
              0xFFC85353,
            ),
          ),

          const SizedBox(
            width: 10,
          ),

          Expanded(
            child: Text(
              _errorMessage!,
              style:
                  const TextStyle(
                color:
                    Color(
                  0xFFAD4747,
                ),
                fontSize: 11,
                height: 1.4,
              ),
            ),
          ),

          const SizedBox(
            width: 4,
          ),

          TextButton(
            onPressed:
                _loadInitialData,
            style:
                TextButton.styleFrom(
              foregroundColor:
                  AppColors
                      .tealDark,
            ),
            child:
                const Text(
              'Retry',
              style:
                  TextStyle(
                fontSize: 11,
                fontWeight:
                    FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProvinceField() {
    final valueExists =
        _provinceCode != null &&
            _provinces.any(
              (item) =>
                  item.code ==
                  _provinceCode,
            );

    return _buildDropdown(
      label:
          'Province',
      hint:
          _loadingProvinces
              ? 'Loading provinces...'
              : 'Select province',
      icon:
          Icons
              .map_outlined,
      value:
          valueExists
              ? _provinceCode
              : null,
      items:
          _provinces,
      enabled:
          !_loadingProvinces &&
              _provinces.isNotEmpty,
      onChanged:
          _handleProvinceChanged,
    );
  }

  Widget _buildMunicipalityField() {
    final valueExists =
        _municipalityCode !=
                null &&
            _municipalities.any(
              (item) =>
                  item.code ==
                  _municipalityCode,
            );

    String hint;

    if (_provinceCode == null) {
      hint =
          'Select province first';
    } else if (_loadingMunicipalities) {
      hint =
          'Loading municipalities...';
    } else {
      hint =
          'Select municipality / city';
    }

    return _buildDropdown(
      label:
          'Municipality / City',
      hint:
          hint,
      icon:
          Icons
              .location_city_outlined,
      value:
          valueExists
              ? _municipalityCode
              : null,
      items:
          _municipalities,
      enabled:
          _provinceCode != null &&
              !_loadingMunicipalities &&
              _municipalities
                  .isNotEmpty,
      onChanged:
          _handleMunicipalityChanged,
    );
  }

  Widget _buildBarangayField() {
    final valueExists =
        _barangayCode != null &&
            _barangays.any(
              (item) =>
                  item.code ==
                  _barangayCode,
            );

    String hint;

    if (_municipalityCode ==
        null) {
      hint =
          'Select municipality first';
    } else if (_loadingBarangays) {
      hint =
          'Loading barangays...';
    } else {
      hint =
          'Select barangay';
    }

    return _buildDropdown(
      label:
          'Barangay',
      hint:
          hint,
      icon:
          Icons
              .home_work_outlined,
      value:
          valueExists
              ? _barangayCode
              : null,
      items:
          _barangays,
      enabled:
          _municipalityCode !=
                  null &&
              !_loadingBarangays &&
              _barangays.isNotEmpty,
      onChanged:
          _handleBarangayChanged,
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<PsgcLocation>
        items,
    required bool enabled,
    required ValueChanged<String?>
        onChanged,
  }) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _requiredLabel(
          label,
        ),

        const SizedBox(
          height: 8,
        ),

        DropdownButtonFormField<
            String>(
          initialValue: 
              value,
          isExpanded:
              true,
          onChanged:
              enabled
                  ? onChanged
                  : null,
          icon:
              Icon(
            Icons
                .keyboard_arrow_down_rounded,
            color: AppColors
                .navy
                .withValues(
              alpha:
                  enabled
                      ? 0.55
                      : 0.25,
            ),
          ),
          decoration:
              _inputDecoration(
            hint:
                hint,
            icon:
                icon,
            enabled:
                enabled,
          ),
          items:
              items.map(
            (location) {
              return DropdownMenuItem<
                  String>(
                value:
                    location.code,
                child:
                    Text(
                  location.name,
                  overflow:
                      TextOverflow
                          .ellipsis,
                  style:
                      const TextStyle(
                    color:
                        AppColors.navy,
                    fontSize: 13,
                    fontWeight:
                        FontWeight.w500,
                  ),
                ),
              );
            },
          ).toList(),
          validator:
              (selected) {
            if (selected ==
                    null ||
                selected
                    .isEmpty) {
              return '$label is required.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _buildStreetField() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _requiredLabel(
          'Street / House No. / Subdivision',
        ),

        const SizedBox(
          height: 8,
        ),

        TextFormField(
          controller:
              widget
                  .streetAddressController,
          minLines:
              2,
          maxLines:
              4,
          keyboardType:
              TextInputType
                  .streetAddress,
          textCapitalization:
              TextCapitalization.words,
          style:
              const TextStyle(
            color:
                AppColors.navy,
            fontSize: 13,
            height: 1.45,
            fontWeight:
                FontWeight.w500,
          ),
          decoration:
              _inputDecoration(
            hint:
                'House no., street, subdivision, building, etc.',
            icon:
                Icons.home_outlined,
            enabled:
                true,
          ).copyWith(
            alignLabelWithHint:
                true,
          ),
          validator:
              (value) {
            final street =
                value?.trim() ?? '';

            if (street.isEmpty) {
              return 'Street address is required.';
            }

            if (street.length < 5) {
              return 'Please enter a more complete address.';
            }

            return null;
          },
        ),
      ],
    );
  }

  Widget _requiredLabel(
    String label,
  ) {
    return RichText(
      text:
          TextSpan(
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
    required bool enabled,
  }) {
    return InputDecoration(
      hintText:
          hint,

      hintStyle:
          TextStyle(
        color:
            AppColors.navy
                .withValues(
          alpha:
              enabled
                  ? 0.28
                  : 0.22,
        ),
        fontSize:
            12,
      ),

      prefixIcon:
          Icon(
        icon,
        size:
            19,
        color:
            AppColors.navy
                .withValues(
          alpha:
              enabled
                  ? 0.35
                  : 0.20,
        ),
      ),

      filled:
          true,

      fillColor:
          enabled
              ? Colors.white
              : AppColors.grayBg,

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

      disabledBorder:
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
          width:
              1.5,
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
          width:
              1.5,
        ),
      ),

      errorStyle:
          const TextStyle(
        fontSize:
            10,
        height:
            1.3,
      ),
    );
  }
}