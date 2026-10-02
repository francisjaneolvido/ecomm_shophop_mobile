import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import '../widgets/seller_document_picker.dart';
import '../widgets/seller_ui.dart';

class SellerVerificationStep extends StatelessWidget {
  const SellerVerificationStep({
    super.key,
    required this.validIdFile,
    required this.businessPermitFile,
    required this.onValidIdChanged,
    required this.onBusinessPermitChanged,
  });

  final PlatformFile? validIdFile;
  final PlatformFile? businessPermitFile;

  final ValueChanged<PlatformFile?> onValidIdChanged;
  final ValueChanged<PlatformFile?> onBusinessPermitChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SellerUi.sectionHeader(
          icon: Icons.verified_user_outlined,
          title: 'Verify your seller identity',
          subtitle:
              'Upload the documents required for seller account review.',
        ),
        const SizedBox(height: 24),
        SellerDocumentPicker(
          label: 'Upload Valid ID',
          description: 'Choose a clear valid ID.',
          icon: Icons.badge_outlined,
          selectedFile: validIdFile,
          onChanged: onValidIdChanged,
        ),
        const SizedBox(height: 18),
        SellerDocumentPicker(
          label: 'Upload Business Permit',
          description: 'Choose your business permit.',
          icon: Icons.description_outlined,
          selectedFile: businessPermitFile,
          onChanged: onBusinessPermitChanged,
        ),
        const SizedBox(height: 18),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: AppColors.tealLight.withValues(alpha: 0.45),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: AppColors.teal.withValues(alpha: 0.14),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                color: AppColors.tealDark,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Use clear and readable documents. These files are for seller verification and approval.',
                  style: SellerUi.text(
                    color: AppColors.navy.withValues(alpha: 0.55),
                    fontSize: 10.5,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
