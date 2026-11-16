import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/features/buyer/data/services/buyer_account_service.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_account_settings_page.dart';

final png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aWQAAAABJRU5ErkJggg==',
);
const photoUrl = '/api/mobile/buyer/profile/avatar?v=new';
const profile = {
  'first_name': 'Juan',
  'last_name': 'Buyer',
  'email': 'buyer@test.com',
  'contact_no': '09123456789',
  'sex': 'Male',
  'birthday': '1998-04-15',
  'sex_options': ['Male', 'Female'],
};

class PhotoPicker extends FilePickerPlatform {
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = true,
    int compressionQuality = 30,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
    bool cancelUploadOnWindowBlur = true,
  }) async => FilePickerResult([
    PlatformFile(name: 'avatar.png', size: png.length, bytes: png),
  ]);
}

void main() {
  test(
    'uploads authenticated multipart photo and reads saved avatar URL',
    () async {
      await http.runWithClient(
        () async {
          final saved = await BuyerAccountService.uploadAvatar(
            'secret',
            PlatformFile(name: 'avatar.png', size: png.length, bytes: png),
          );
          expect(saved.avatarUrl, photoUrl);
        },
        () => MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/mobile/buyer/profile/avatar');
          expect(request.headers['Authorization'], 'Bearer secret');
          expect(
            request.headers['content-type'],
            contains('multipart/form-data'),
          );
          expect(
            utf8.decode(request.bodyBytes, allowMalformed: true),
            contains('name="avatar"'),
          );
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {...profile, 'avatar_url': photoUrl},
            }),
            200,
          );
        }),
      );
    },
  );

  test('rejects oversized files before upload', () async {
    final bytes = Uint8List(2 * 1024 * 1024 + 1)..setRange(0, png.length, png);
    await expectLater(
      BuyerAccountService.uploadAvatar(
        'secret',
        PlatformFile(name: 'large.png', size: bytes.length, bytes: bytes),
      ),
      throwsA(
        isA<BuyerAccountException>().having(
          (e) => e.message,
          'message',
          contains('2 MB'),
        ),
      ),
    );
  });

  testWidgets(
    'photo upload updates saved profile callback without clearing unsaved edits',
    (tester) async {
      final oldPicker = FilePickerPlatform.instance;
      FilePickerPlatform.instance = PhotoPicker();
      addTearDown(() => FilePickerPlatform.instance = oldPicker);
      BuyerAccountProfile? saved;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              home: BuyerAccountSecurityPage(
                token: 'secret',
                onProfileSaved: (p) => saved = p,
              ),
            ),
          );
          await tester.pumpAndSettle();
          final first = find.widgetWithText(TextFormField, 'First name');
          await tester.enterText(first, 'Unsaved');
          final controller = tester.widget<TextFormField>(first).controller!;
          await tester.ensureVisible(find.text('Upload profile photo'));
          await tester.tap(find.text('Upload profile photo'));
          await tester.pumpAndSettle();
          expect(saved?.avatarUrl, photoUrl);
          expect(controller.text, 'Unsaved');
          expect(find.text('Profile photo updated.'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (request) async => http.Response(
            jsonEncode({
              'success': true,
              'data': {
                ...profile,
                if (request.method == 'POST') 'avatar_url': photoUrl,
              },
            }),
            200,
          ),
        ),
      );
    },
  );
}
