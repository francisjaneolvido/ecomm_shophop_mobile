import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/features/after_sales/data/after_sales_evidence_selection.dart';

void main() {
  PlatformFile file(String name, int bytes) =>
      PlatformFile(name: name, size: bytes);

  test('accepts one photo or MP4 and rejects unsupported files', () {
    expect(
      AfterSalesEvidenceSelection.validate([file('broken.mp4', 1024)]),
      isNull,
    );
    expect(
      AfterSalesEvidenceSelection.validate([file('broken.jpg', 1024)]),
      isNull,
    );
    expect(
      AfterSalesEvidenceSelection.validate([file('notes.txt', 1024)]),
      isNotNull,
    );
  });

  test('rejects too many videos and uploads above local PHP limits', () {
    expect(
      AfterSalesEvidenceSelection.validate([
        file('a.mp4', 1024),
        file('b.mp4', 1024),
      ]),
      contains('one MP4'),
    );
    expect(
      AfterSalesEvidenceSelection.validate([
        file('a.mp4', 5 * 1024 * 1024),
        file('b.jpg', 3 * 1024 * 1024),
      ]),
      contains('7 MB'),
    );
    expect(
      AfterSalesEvidenceSelection.validate([file('big.mp4', 6 * 1024 * 1024)]),
      contains('5 MB'),
    );
  });
}
