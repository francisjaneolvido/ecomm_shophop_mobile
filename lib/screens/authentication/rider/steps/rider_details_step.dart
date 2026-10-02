import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../theme/app_colors.dart';
import '../widgets/rider_document_picker.dart';
import '../widgets/rider_ui.dart';

class RiderDetailsStep extends StatelessWidget {
  const RiderDetailsStep({
    super.key,
    required this.vehicleController,
    required this.plateNumberController,
    required this.orCrFile,
    required this.idOrLicenseFile,
    required this.onOrCrChanged,
    required this.onIdOrLicenseChanged,
  });

  final TextEditingController vehicleController;
  final TextEditingController plateNumberController;
  final PlatformFile? orCrFile;
  final PlatformFile? idOrLicenseFile;
  final ValueChanged<PlatformFile?> onOrCrChanged;
  final ValueChanged<PlatformFile?> onIdOrLicenseChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _header(),
        const SizedBox(height: 24),
        _field(
          controller: vehicleController,
          label: 'Vehicle',
          hint: 'Enter your vehicle type',
          icon: Icons.two_wheeler_rounded,
          validator: (value) =>
              value == null || value.trim().isEmpty ? 'Vehicle is required.' : null,
        ),
        const SizedBox(height: 18),
        _field(
          controller: plateNumberController,
          label: 'Plate number',
          hint: 'Enter plate number',
          icon: Icons.pin_outlined,
          capitalization: TextCapitalization.characters,
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z0-9 -]')),
            LengthLimitingTextInputFormatter(20),
          ],
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Plate number is required.'
              : null,
        ),
        const SizedBox(height: 22),
        RiderDocumentPicker(
          label: 'Upload OR/CR',
          description: 'Upload a clear copy of your vehicle OR/CR.',
          icon: Icons.description_outlined,
          selectedFile: orCrFile,
          onChanged: onOrCrChanged,
        ),
        const SizedBox(height: 18),
        RiderDocumentPicker(
          label: 'Upload ID / Driver’s License',
          description: 'Upload a clear valid ID or driver’s license.',
          icon: Icons.badge_outlined,
          selectedFile: idOrLicenseFile,
          onChanged: onIdOrLicenseChanged,
        ),
        const SizedBox(height: 10),
        _notice(),
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
              Icons.delivery_dining_outlined,
              color: AppColors.tealDark,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Rider details',
                  style: TextStyle(
                    color: AppColors.navy,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tell us about your vehicle and upload the required rider documents.',
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

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required String? Function(String?) validator,
    TextCapitalization capitalization = TextCapitalization.words,
    List<TextInputFormatter>? inputFormatters,
  }) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RiderUi.requiredLabel(label),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            textCapitalization: capitalization,
            inputFormatters: inputFormatters,
            validator: validator,
            style: RiderUi.text(
              color: AppColors.navy,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
            decoration: RiderUi.inputDecoration(
              hint: hint,
              icon: icon,
            ),
          ),
        ],
      );

  Widget _notice() => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: AppColors.tealLight.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(15),
          border:
              Border.all(color: AppColors.teal.withValues(alpha: 0.14)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.info_outline_rounded,
              color: AppColors.tealDark,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Make sure your vehicle details and uploaded documents are clear and correct before continuing.',
                style: TextStyle(
                  color: AppColors.navy.withValues(alpha: 0.55),
                  fontSize: 10.5,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      );
}
