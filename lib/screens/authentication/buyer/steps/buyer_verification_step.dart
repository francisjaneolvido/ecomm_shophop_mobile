import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:open_filex/open_filex.dart';

import '../../../../theme/app_colors.dart';

class BuyerVerificationStep extends StatelessWidget {
  const BuyerVerificationStep({
    super.key,
    required this.selectedFile,
    required this.onFileChanged,
  });

  final PlatformFile? selectedFile;

  final ValueChanged<PlatformFile?> onFileChanged;

  static const int _maxFileSize =
      5 * 1024 * 1024;

  static const List<String> _allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'pdf',
  ];


  Future<void> _pickFile(
    BuildContext context,
    FormFieldState<PlatformFile> field,
  ) async {
    FocusScope.of(context).unfocus();

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowMultiple: false,
        allowedExtensions: _allowedExtensions,
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

      if (file.size > _maxFileSize) {
        _showMessage(
          context,
          'File is too large. Maximum size is 5MB.',
        );
        return;
      }

      if (file.bytes == null &&
          (file.path == null || file.path!.isEmpty)) {
        _showMessage(
          context,
          'Unable to read the selected file.',
        );
        return;
      }

      field.didChange(file);
      onFileChanged(file);
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

  void _removeFile(
    FormFieldState<PlatformFile> field,
  ) {
    field.didChange(null);

    onFileChanged(null);
  }

  bool _isImage(
    PlatformFile file,
  ) {
    final extension =
        (file.extension ?? '')
            .toLowerCase();

    return extension == 'jpg' ||
        extension == 'jpeg' ||
        extension == 'png';
  }

  bool _isPdf(
    PlatformFile file,
  ) {
    return (file.extension ?? '')
            .toLowerCase() ==
        'pdf';
  }

  String _formatFileSize(
  PlatformFile file,
) {
  final bytes =
      file.size;

  final kb =
      bytes / 1024;

  if (kb < 1024) {
    return '${kb.toStringAsFixed(1)} KB';
  }

  final mb =
      kb / 1024;

  return '${mb.toStringAsFixed(2)} MB';
}

  void _showMessage(
    BuildContext context,
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: AppColors.navy,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      );
  }


  Future<void> _openPdf(
    BuildContext context,
    PlatformFile file,
  ) async {
    if (kIsWeb) {
      _showMessage(
        context,
        'PDF selected successfully. PDF opening is available on the mobile app.',
      );
      return;
    }

    final path = file.path;

    if (path == null || path.isEmpty) {
      _showMessage(
        context,
        'Unable to open this PDF.',
      );
      return;
    }

    try {
      await OpenFilex.open(path);
    } catch (_) {
      if (!context.mounted) {
        return;
      }

      _showMessage(
        context,
        'No PDF viewer is available on this device.',
      );
    }
  }

  void _showImagePreview(
    BuildContext context,
    PlatformFile file,
  ) {
    final bytes = file.bytes;

    if (bytes == null) {
      _showMessage(
        context,
        'Unable to preview this image.',
      );
      return;
    }

    showDialog<void>(
      context: context,
      barrierColor: AppColors.navy.withValues(
        alpha: 0.88,
      ),
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(16),
          backgroundColor: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(
              maxWidth: 650,
              maxHeight: 720,
            ),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    13,
                    10,
                    13,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.verified_user_outlined,
                        size: 19,
                        color: AppColors.tealDark,
                      ),
                      const SizedBox(width: 9),
                      const Expanded(
                        child: Text(
                          'Valid ID preview',
                          style: TextStyle(
                            color: AppColors.navy,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: () {
                          Navigator.pop(dialogContext);
                        },
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
                    width: double.infinity,
                    color: AppColors.grayBg,
                    padding: const EdgeInsets.all(14),
                    child: InteractiveViewer(
                      minScale: 1,
                      maxScale: 4,
                      child: Center(
                        child: Image.memory(
                          bytes,
                          fit: BoxFit.contain,
                          errorBuilder: (
                            context,
                            error,
                            stackTrace,
                          ) {
                            return const Center(
                              child: Text(
                                'Unable to preview image.',
                                style: TextStyle(
                                  color: AppColors.navy,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(14),
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
                      const SizedBox(width: 12),
                      Text(
                        _formatFileSize(file),
                        style: TextStyle(
                          color: AppColors.navy.withValues(
                            alpha: 0.45,
                          ),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
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

        const SizedBox(height: 24),

        const _RequiredLabel(
          text: 'Upload Valid ID',
        ),

        const SizedBox(height: 8),

        FormField<PlatformFile>(
          initialValue: selectedFile,
          validator: (file) {
            if (file == null) {
              return 'Please upload a valid ID.';
            }

            return null;
          },
          builder: (field) {
            final file = field.value;

            return Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                _buildUploadArea(
                  context,
                  field,
                  file,
                ),

                if (field.hasError) ...[
                  const SizedBox(height: 7),

                  Padding(
                    padding:
                        const EdgeInsets.only(
                      left: 4,
                    ),
                    child: Text(
                      field.errorText!,
                      style:
                          const TextStyle(
                        color:
                            Color(
                          0xFFDB5757,
                        ),
                        fontSize: 10,
                        fontWeight:
                            FontWeight.w500,
                      ),
                    ),
                  ),
                ],

                if (file != null) ...[
                  const SizedBox(height: 16),

                  _buildPreviewCard(
                    context,
                    field,
                    file,
                  ),
                ],
              ],
            );
          },
        ),

        const SizedBox(height: 18),

        _buildSecurityNotice(),
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
          decoration: BoxDecoration(
            color: AppColors.tealLight,
            borderRadius:
                BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons
                .verified_user_outlined,
            color:
                AppColors.tealDark,
            size: 21,
          ),
        ),

        const SizedBox(width: 13),

        Expanded(
          child: Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Verify your identity',
                style: TextStyle(
                  color: AppColors.navy,
                  fontSize: 16,
                  fontWeight:
                      FontWeight.w700,
                ),
              ),

              const SizedBox(height: 4),

              Text(
                'Upload one clear valid ID to help keep ShopHop secure.',
                style: TextStyle(
                  color: AppColors.navy
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

  Widget _buildUploadArea(
    BuildContext context,
    FormFieldState<PlatformFile> field,
    PlatformFile? file,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _pickFile(
            context,
            field,
          );
        },
        borderRadius:
            BorderRadius.circular(17),
        child: Container(
          width: double.infinity,
          padding:
              const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 18,
          ),
          decoration: BoxDecoration(
            color: AppColors.grayBg,
            borderRadius:
                BorderRadius.circular(17),
            border: Border.all(
              color: field.hasError
                  ? const Color(
                      0xFFDB5757,
                    )
                  : file != null
                      ? AppColors.teal
                          .withValues(
                          alpha: 0.65,
                        )
                      : AppColors.grayBorder,
              width: file != null
                  ? 1.4
                  : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  border: Border.all(
                    color:
                        AppColors.grayBorder,
                  ),
                ),
                child: Icon(
                  file == null
                      ? Icons
                          .upload_file_outlined
                      : Icons.check_rounded,
                  color: file == null
                      ? AppColors.tealDark
                      : AppColors.teal,
                  size: 23,
                ),
              ),

              const SizedBox(width: 13),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      file == null
                          ? 'Choose a valid ID'
                          : 'ID selected',
                      style:
                          const TextStyle(
                        color:
                            AppColors.navy,
                        fontSize: 13,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      file == null
                          ? 'JPG, JPEG, PNG or PDF · Max 5MB'
                          : 'Tap here to choose another file',
                      style: TextStyle(
                        color: AppColors
                            .navy
                            .withValues(
                          alpha: 0.42,
                        ),
                        fontSize: 10,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),

              Icon(
                Icons
                    .chevron_right_rounded,
                color: AppColors.navy
                    .withValues(
                  alpha: 0.30,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPreviewCard(
    BuildContext context,
    FormFieldState<PlatformFile> field,
    PlatformFile file,
  ) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.grayBorder,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy
                .withValues(
              alpha: 0.04,
            ),
            blurRadius: 18,
            offset:
                const Offset(0, 7),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          if (_isImage(file))
            _buildImagePreview(
              context,
              file,
            ),

          if (_isPdf(file))
            _buildPdfPreview(
              context,
              file,
            ),

          const Divider(
            height: 1,
            color:
                AppColors.grayBorder,
          ),

          Padding(
            padding:
                const EdgeInsets.all(14),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration:
                          BoxDecoration(
                        color:
                            AppColors.tealLight,
                        borderRadius:
                            BorderRadius.circular(
                          10,
                        ),
                      ),
                      child: Icon(
                        _isPdf(file)
                            ? Icons
                                .picture_as_pdf_outlined
                            : Icons
                                .image_outlined,
                        size: 17,
                        color:
                            AppColors.tealDark,
                      ),
                    ),

                    const SizedBox(
                      width: 10,
                    ),

                    Expanded(
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            file.name,
                            maxLines: 1,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                const TextStyle(
                              color:
                                  AppColors.navy,
                              fontSize: 11,
                              fontWeight:
                                  FontWeight.w600,
                            ),
                          ),

                          const SizedBox(
                            height: 2,
                          ),

                          Text(
                            _formatFileSize(
                              file,
                            ),
                            style: TextStyle(
                              color: AppColors
                                  .navy
                                  .withValues(
                                alpha:
                                    0.40,
                              ),
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 13),

                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          _pickFile(
                            context,
                            field,
                          );
                        },
                        icon: const Icon(
                          Icons
                              .sync_rounded,
                          size: 17,
                        ),
                        label: const Text(
                          'Change ID',
                        ),
                        style:
                            OutlinedButton
                                .styleFrom(
                          foregroundColor:
                              AppColors.navy,
                          side:
                              const BorderSide(
                            color:
                                AppColors
                                    .grayBorder,
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              13,
                            ),
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    SizedBox(
                      width: 48,
                      height: 48,
                      child: OutlinedButton(
                        onPressed: () {
                          _removeFile(
                            field,
                          );
                        },
                        style:
                            OutlinedButton
                                .styleFrom(
                          padding:
                              EdgeInsets.zero,
                          foregroundColor:
                              const Color(
                            0xFFC45252,
                          ),
                          side:
                              const BorderSide(
                            color:
                                Color(
                              0xFFF0D0D0,
                            ),
                          ),
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              13,
                            ),
                          ),
                        ),
                        child: const Icon(
                          Icons
                              .delete_outline_rounded,
                          size: 19,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildImagePreview(
    BuildContext context,
    PlatformFile file,
  ) {
    final bytes = file.bytes;

    if (bytes == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(
          vertical: 28,
          horizontal: 20,
        ),
        color: AppColors.grayBg,
        child: Column(
          children: [
            const Icon(
              Icons.image_not_supported_outlined,
              color: AppColors.tealDark,
              size: 30,
            ),
            const SizedBox(height: 10),
            const Text(
              'Image selected',
              style: TextStyle(
                color: AppColors.navy,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'The image was selected successfully, but a preview is unavailable.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.navy.withValues(alpha: 0.44),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      height: 220,
      color: AppColors.grayBg,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: Image.memory(
                bytes,
                fit: BoxFit.contain,
                errorBuilder: (
                  context,
                  error,
                  stackTrace,
                ) {
                  return Center(
                    child: Text(
                      'Unable to preview image.',
                      style: TextStyle(
                        color: AppColors.navy.withValues(alpha: 0.45),
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: FilledButton.icon(
              onPressed: () {
                _showImagePreview(
                  context,
                  file,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy.withValues(alpha: 0.90),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 8,
                ),
                minimumSize: Size.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              icon: const Icon(
                Icons.fullscreen_rounded,
                size: 15,
              ),
              label: const Text(
                'View',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPdfPreview(
    BuildContext context,
    PlatformFile file,
  ) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: 28,
        horizontal: 20,
      ),
      color: AppColors.grayBg,
      child: Column(
        children: [
          Container(
            width: 62,
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: AppColors.grayBorder,
              ),
            ),
            child: const Icon(
              Icons.picture_as_pdf_outlined,
              color: AppColors.tealDark,
              size: 29,
            ),
          ),
          const SizedBox(height: 13),
          const Text(
            'PDF selected',
            style: TextStyle(
              color: AppColors.navy,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            kIsWeb
                ? 'Your PDF is ready for submission.'
                : 'Open the file to review your uploaded ID.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.navy.withValues(alpha: 0.44),
              fontSize: 10,
              height: 1.4,
            ),
          ),
          if (!kIsWeb) ...[
            const SizedBox(height: 15),
            OutlinedButton.icon(
              onPressed: () {
                _openPdf(
                  context,
                  file,
                );
              },
              icon: const Icon(
                Icons.open_in_new_rounded,
                size: 16,
              ),
              label: const Text('Open PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.tealDark,
                side: const BorderSide(
                  color: AppColors.grayBorder,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSecurityNotice() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.tealLight
            .withValues(
          alpha: 0.50,
        ),
        borderRadius:
            BorderRadius.circular(15),
        border: Border.all(
          color: AppColors.teal
              .withValues(
            alpha: 0.14,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.lock_outline_rounded,
            color:
                AppColors.tealDark,
            size: 18,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              'Make sure all details on your ID are clear and readable before continuing.',
              style: TextStyle(
                color: AppColors.navy
                    .withValues(
                  alpha: 0.58,
                ),
                fontSize: 10,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredLabel
    extends StatelessWidget {
  const _RequiredLabel({
    required this.text,
  });

  final String text;

  @override
  Widget build(
    BuildContext context,
  ) {
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: text,
          ),
          const TextSpan(
            text: ' *',
            style: TextStyle(
              color: Color(0xFFDB5757),
            ),
          ),
        ],
      ),
      style: const TextStyle(
        color: AppColors.navy,
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
