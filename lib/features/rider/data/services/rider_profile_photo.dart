import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';

class RiderProfilePhotoPreparation {
  static const maxInputBytes = 20 * 1024 * 1024;
  static const maxEdge = 800;

  static Future<PlatformFile> prepare(PlatformFile file) async {
    if (file.size > maxInputBytes) {
      throw const FormatException('Choose a photo up to 20 MB.');
    }
    final Uint8List bytes = file.bytes ?? await file.xFile.readAsBytes();
    if (bytes.length > maxInputBytes) {
      throw const FormatException('Choose a photo up to 20 MB.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
    ui.ImageDescriptor? descriptor;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      final ratio = math.min(
        1.0,
        maxEdge / math.max(descriptor.width, descriptor.height),
      );
      final codec = await descriptor.instantiateCodec(
        targetWidth: math.max(1, (descriptor.width * ratio).round()),
        targetHeight: math.max(1, (descriptor.height * ratio).round()),
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final encoded = await frame.image.toByteData(
            format: ui.ImageByteFormat.png,
          );
          if (encoded == null) {
            throw const FormatException(
              'Cannot read this photo. Choose another JPG, PNG or WebP.',
            );
          }
          final output = encoded.buffer.asUint8List(
            encoded.offsetInBytes,
            encoded.lengthInBytes,
          );
          return PlatformFile(
            name: 'profile.png',
            size: output.length,
            bytes: output,
          );
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } finally {
      descriptor?.dispose();
      buffer.dispose();
    }
  }
}
