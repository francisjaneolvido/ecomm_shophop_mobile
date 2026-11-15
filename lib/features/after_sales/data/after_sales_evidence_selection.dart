import 'package:file_picker/file_picker.dart';

class AfterSalesEvidenceSelection {
  const AfterSalesEvidenceSelection._();

  static const maxFiles = 4;
  static const maxFileBytes = 5 * 1024 * 1024;
  static const maxTotalBytes = 7 * 1024 * 1024;
  static const extensions = ['jpg', 'jpeg', 'png', 'webp', 'mp4'];

  static bool isVideo(PlatformFile file) =>
      file.name.toLowerCase().endsWith('.mp4');

  static String? validate(List<PlatformFile> files) {
    if (files.isEmpty) return 'Add at least one photo or MP4 video.';
    if (files.length > maxFiles) return 'Choose up to 4 evidence files.';
    if (files.any(
      (file) => !extensions.contains(file.extension?.toLowerCase()),
    )) {
      return 'Choose JPG, PNG, WebP photos or an MP4 video.';
    }
    if (files.where(isVideo).length > 1) return 'Choose only one MP4 video.';
    if (files.any((file) => file.size > maxFileBytes)) {
      return 'Each photo or video must be 5 MB or smaller.';
    }
    if (files.fold<int>(0, (sum, file) => sum + file.size) > maxTotalBytes) {
      return 'Evidence must be 7 MB or smaller in total.';
    }
    return null;
  }
}
