import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import 'seller_ui.dart';

class SellerDocumentPicker extends StatelessWidget {
  const SellerDocumentPicker({
    super.key,
    required this.label,
    required this.description,
    required this.icon,
    required this.selectedFile,
    required this.onChanged,
  });

  final String label;
  final String description;
  final IconData icon;
  final PlatformFile? selectedFile;
  final ValueChanged<PlatformFile?> onChanged;

  static const _allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'pdf',
  ];

  static const _maxBytes = 5 * 1024 * 1024;

  Future<void> _pick(
    BuildContext context,
    FormFieldState<PlatformFile> field,
  ) async {
    FocusScope.of(context).unfocus();

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        allowMultiple: false,
        withData: true,
      );

      if (!context.mounted || !field.mounted) {
        return;
      }

      if (result == null || result.files.isEmpty) {
        return;
      }

      final file = result.files.single;
      final extension = (file.extension ?? '').toLowerCase();

      if (!_allowedExtensions.contains(extension)) {
        _showMessage(
          context,
          'Only JPG, JPEG, PNG or PDF files are allowed.',
        );
        return;
      }

      if (file.size > _maxBytes) {
        _showMessage(
          context,
          'File is too large. Maximum size is 5MB.',
        );
        return;
      }

      field.didChange(file);
      onChanged(file);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      _showMessage(
        context,
        'Unable to select the file. Please try again.',
      );
    }
  }

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
            style: SellerUi.text(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
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

  String _size(PlatformFile file) {
    final kb = file.size / 1024;

    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }

    return '${(kb / 1024).toStringAsFixed(2)} MB';
  }

  bool _isImage(PlatformFile file) {
    final extension = (file.extension ?? '').toLowerCase();

    return extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png';
  }

  bool _isPdf(PlatformFile file) {
    return (file.extension ?? '').toLowerCase() == 'pdf';
  }

  @override
  Widget build(BuildContext context) {
    return FormField<PlatformFile>(
      initialValue: selectedFile,
      validator: (file) {
        if (file == null) {
          return '$label is required.';
        }
        return null;
      },
      builder: (field) {
        final file = field.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SellerUi.requiredLabel(label),
            const SizedBox(height: 8),
            Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _pick(context, field),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: AppColors.grayBg,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: field.hasError
                          ? const Color(0xFFDB5757)
                          : file != null
                              ? AppColors.teal.withValues(alpha: 0.55)
                              : AppColors.grayBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: AppColors.grayBorder,
                          ),
                        ),
                        child: Icon(
                          file == null
                              ? Icons.upload_file_outlined
                              : Icons.check_rounded,
                          color: file == null
                              ? AppColors.tealDark
                              : AppColors.teal,
                          size: 21,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              file?.name ?? description,
                              maxLines: file == null ? 2 : 1,
                              overflow: TextOverflow.ellipsis,
                              style: SellerUi.text(
                                color: AppColors.navy.withValues(
                                  alpha: file == null ? 0.52 : 0.82,
                                ),
                                fontSize: 11,
                                fontWeight: file == null
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              file == null
                                  ? 'JPG, JPEG, PNG or PDF · Max 5MB'
                                  : _size(file),
                              style: SellerUi.text(
                                color: AppColors.navy.withValues(alpha: 0.34),
                                fontSize: 9.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.navy.withValues(alpha: 0.28),
                      ),
                    ],
                  ),
                ),
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
            if (file != null) ...[
              const SizedBox(height: 14),
              _preview(context, field, file),
            ],
          ],
        );
      },
    );
  }

  Widget _preview(
    BuildContext context,
    FormFieldState<PlatformFile> field,
    PlatformFile file,
  ) {
    final imagePreview = _isImage(file) && file.bytes != null;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.grayBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (imagePreview)
            GestureDetector(
              onTap: () => _showFullImage(context, file),
              child: Container(
                width: double.infinity,
                height: 190,
                padding: const EdgeInsets.all(10),
                color: AppColors.grayBg,
                child: Image.memory(
                  file.bytes!,
                  fit: BoxFit.contain,
                ),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                vertical: 28,
                horizontal: 18,
              ),
              color: AppColors.grayBg,
              child: Column(
                children: [
                  Icon(
                    _isPdf(file)
                        ? Icons.picture_as_pdf_outlined
                        : icon,
                    color: AppColors.tealDark,
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isPdf(file)
                        ? 'PDF selected'
                        : 'Document selected',
                    style: SellerUi.text(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(
            height: 1,
            color: AppColors.grayBorder,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(context, field),
                    icon: const Icon(
                      Icons.sync_rounded,
                      size: 16,
                    ),
                    label: Text(
                      'Change',
                      style: SellerUi.text(
                        color: AppColors.navy,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(
                        color: AppColors.grayBorder,
                      ),
                      minimumSize: const Size.fromHeight(46),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 46,
                  height: 46,
                  child: OutlinedButton(
                    onPressed: () {
                      field.didChange(null);
                      onChanged(null);
                    },
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      foregroundColor: const Color(0xFFC45252),
                      side: const BorderSide(
                        color: Color(0xFFF0D0D0),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(
                      Icons.delete_outline_rounded,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(
    BuildContext context,
    PlatformFile file,
  ) {
    if (file.bytes == null) {
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: AppColors.navy.withValues(alpha: 0.90),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 650,
              maxHeight: 700,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: SellerUi.text(
                            color: AppColors.navy,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: AppColors.navy,
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(
                  height: 1,
                  color: AppColors.grayBorder,
                ),
                Expanded(
                  child: Container(
                    color: AppColors.grayBg,
                    padding: const EdgeInsets.all(12),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: Image.memory(
                          file.bytes!,
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
