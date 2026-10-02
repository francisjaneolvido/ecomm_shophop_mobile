import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../theme/app_colors.dart';
import 'rider_ui.dart';

class RiderDocumentPicker extends StatelessWidget {
  const RiderDocumentPicker({
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

  Future<void> _pick(
    BuildContext context,
    FormFieldState<PlatformFile> field,
  ) async {
    try {
      final result = await FilePicker.pickFiles(
        allowMultiple: false,
        withData: true,
      );

      if (!context.mounted || !field.mounted) return;
      if (result == null || result.files.isEmpty) return;

      final file = result.files.single;
      field.didChange(file);
      onChanged(file);
    } catch (_) {
      if (!context.mounted) return;

      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('Unable to select the file. Please try again.'),
            backgroundColor: AppColors.navy,
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        );
    }
  }

  bool _isImage(PlatformFile file) {
    final ext = (file.extension ?? '').toLowerCase();
    return const ['jpg', 'jpeg', 'png', 'webp'].contains(ext);
  }

  bool _isPdf(PlatformFile file) =>
      (file.extension ?? '').toLowerCase() == 'pdf';

  String _size(PlatformFile file) {
    final kb = file.size / 1024;
    return kb < 1024
        ? '${kb.toStringAsFixed(1)} KB'
        : '${(kb / 1024).toStringAsFixed(2)} MB';
  }

  @override
  Widget build(BuildContext context) {
    return FormField<PlatformFile>(
      initialValue: selectedFile,
      validator: (file) => file == null ? '$label is required.' : null,
      builder: (field) {
        final file = field.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RiderUi.requiredLabel(label),
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
                          border: Border.all(color: AppColors.grayBorder),
                        ),
                        child: Icon(
                          file == null
                              ? Icons.upload_file_outlined
                              : Icons.check_rounded,
                          color: file == null
                              ? AppColors.tealDark
                              : AppColors.teal,
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
                              style: TextStyle(
                                color: AppColors.navy.withValues(
                                  alpha: file == null ? 0.52 : 0.82,
                                ),
                                fontSize: 11,
                                height: 1.4,
                                fontWeight: file == null
                                    ? FontWeight.w500
                                    : FontWeight.w600,
                              ),
                            ),
                            if (file != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                _size(file),
                                style: TextStyle(
                                  color:
                                      AppColors.navy.withValues(alpha: 0.36),
                                  fontSize: 9.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
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
                  style: const TextStyle(
                    color: Color(0xFFDB5757),
                    fontSize: 10,
                  ),
                ),
              ),
            ],
            if (file != null) ...[
              const SizedBox(height: 12),
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
                child: Image.memory(file.bytes!, fit: BoxFit.contain),
              ),
            )
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 26),
              color: AppColors.grayBg,
              child: Column(
                children: [
                  Icon(
                    _isPdf(file) ? Icons.picture_as_pdf_outlined : icon,
                    color: AppColors.tealDark,
                    size: 34,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isPdf(file) ? 'PDF selected' : 'Document selected',
                    style: const TextStyle(
                      color: AppColors.navy,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          const Divider(height: 1, color: AppColors.grayBorder),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(context, field),
                    icon: const Icon(Icons.sync_rounded, size: 16),
                    label: const Text('Change'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.navy,
                      side: const BorderSide(color: AppColors.grayBorder),
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
                      side: const BorderSide(color: Color(0xFFF0D0D0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Icon(Icons.delete_outline_rounded, size: 18),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showFullImage(BuildContext context, PlatformFile file) {
    if (file.bytes == null) return;

    showDialog<void>(
      context: context,
      barrierColor: AppColors.navy.withValues(alpha: 0.90),
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 650, maxHeight: 700),
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
                        style: const TextStyle(
                          color: AppColors.navy,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon:
                          const Icon(Icons.close_rounded, color: AppColors.navy),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.grayBorder),
              Expanded(
                child: Container(
                  color: AppColors.grayBg,
                  padding: const EdgeInsets.all(12),
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.memory(file.bytes!, fit: BoxFit.contain),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}
