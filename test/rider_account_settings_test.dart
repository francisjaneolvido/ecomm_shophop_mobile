import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/rider/presentation/screens/rider_account_page.dart';
import 'package:shophop/features/rider/presentation/widgets/rider_coverage_list.dart';
import 'package:shophop/features/rider/data/services/rider_management_service.dart';
import 'package:shophop/features/rider/data/services/rider_profile_photo.dart';
import 'package:shophop/shared/widgets/shop_hop_scan_feedback.dart';

const profile = {
  'id': 8,
  'name': 'Juan Rider',
  'email': 'juan@example.test',
  'contact_no': '09123456789',
  'status': 'active',
};
http.Response response(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json'},
    );

Future<void> mount(
  WidgetTester tester, {
  VoidCallback? logout,
  double textScale = 1,
}) async {
  tester.view.physicalSize = textScale > 1
      ? const Size(320, 800)
      : const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: RiderAccountPage(
          token: 'test',
          name: 'Juan Rider',
          company: 'Test Logistics',
          workDetails: const Text('Calamba Branch'),
          onOpenWorkSettings: () async {},
          onSessionExpired: () async {},
          onLogout: () async {
            logout?.call();
          },
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> tap(WidgetTester tester, String text) async {
  final target = find.text(text);
  await tester.scrollUntilVisible(
    target,
    180,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

Future<Uint8List> photoBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xFFFA3E68), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  try {
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    return bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('shophop/device_settings'),
          (_) async => {'version': '1.0.0', 'build_number': '1'},
        );
  });

  test('Profile photo is sent as an authenticated image upload', () async {
    final bytes = await photoBytes(1, 1);
    await http.runWithClient(
      () async {
        final result = await RiderManagementService.uploadPhoto(
          'photo-token',
          PlatformFile(name: 'profile.png', size: bytes.length, bytes: bytes),
        );
        expect(result.success, isTrue);
        expect(
          result.data['photo_url'],
          '/api/mobile/rider/profile/photo?v=new',
        );
      },
      () => MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, endsWith('/rider/profile/photo'));
        expect(request.headers['authorization'], 'Bearer photo-token');
        expect(
          request.headers['content-type'],
          contains('multipart/form-data'),
        );
        expect(
          latin1.decode(request.bodyBytes),
          contains('name="photo"; filename="profile.png"'),
        );
        expect(
          latin1.decode(request.bodyBytes),
          contains('content-type: image/png'),
        );
        return response({
          'success': true,
          'data': {
            ...profile,
            'photo_url': '/api/mobile/rider/profile/photo?v=new',
          },
        });
      }),
    );
  });

  test(
    'Camera-size photos are resized without stretching and invalid photos do not upload',
    () async {
      for (final size in [
        const ui.Size(6000, 1200),
        const ui.Size(1200, 6000),
      ]) {
        final bytes = await photoBytes(size.width.toInt(), size.height.toInt());
        final result = await RiderProfilePhotoPreparation.prepare(
          PlatformFile(name: 'camera.png', size: 4 * 1024 * 1024, bytes: bytes),
        );
        final codec = await ui.instantiateImageCodec(result.bytes!);
        final image = (await codec.getNextFrame()).image;
        expect(image.width, size.width > size.height ? 800 : 160);
        expect(image.height, size.width > size.height ? 160 : 800);
        expect(result.size, lessThan(3 * 1024 * 1024));
        image.dispose();
        codec.dispose();
      }
      var requests = 0;
      await http.runWithClient(
        () async {
          final result = await RiderManagementService.uploadPhoto(
            'photo-token',
            PlatformFile(
              name: 'invalid.jpg',
              size: 3,
              bytes: Uint8List.fromList([1, 2, 3]),
            ),
          );
          expect(result.success, isFalse);
          expect(result.status, 'invalid_photo');
          expect(requests, 0);
        },
        () => MockClient((_) async {
          requests++;
          return response({'success': true});
        }),
      );
    },
  );

  testWidgets(
    'Coverage groups locations, expands and searches at larger text sizes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: SingleChildScrollView(
              child: MediaQuery(
                data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
                child: RiderCoverageList(
                  areas: List.generate(
                    18,
                    (i) => 'Barangay ${i + 1}, Calamba, Laguna',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Calamba, Laguna'), findsOneWidget);
      expect(find.text('View all 18 areas'), findsOneWidget);
      expect(find.text('Barangay 9'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Barangay 9');
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Barangay 9'),
        findsOneWidget,
      );
      expect(find.text('Barangay 1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Email keeps the current address until verification and permits correcting a wrong code',
    (tester) async {
      var verifies = 0;
      await http.runWithClient(
        () async {
          await mount(tester);
          await tap(tester, 'Personal information');
          await tap(tester, 'Change email');
          await tester.enterText(field('New email'), 'new@example.test');
          await tester.enterText(
            field('Current password'),
            'OriginalPassword123!',
          );
          await tap(tester, 'Send verification code');
          expect(find.text('Current email: juan@example.test'), findsOneWidget);
          await tester.enterText(field('Verification code'), '111111');
          await tap(tester, 'Verify new email');
          expect(find.text('Incorrect verification code.'), findsWidgets);
          await tester.enterText(field('Verification code'), '123456');
          await tap(tester, 'Verify new email');
          expect(verifies, 2);
          expect(find.text('new@example.test'), findsOneWidget);
          expect(find.text('Personal information'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          final body = request.method == 'POST'
              ? jsonDecode(request.body) as Map<String, dynamic>
              : <String, dynamic>{};
          if (request.url.path.endsWith('/email/verify')) {
            verifies++;
            if (body['code'] != '123456') {
              return response({
                'success': false,
                'errors': {
                  'code': ['Incorrect verification code.'],
                },
              }, status: 422);
            }
            return response({
              'success': true,
              'data': {...profile, 'email': 'new@example.test'},
            });
          }
          if (request.url.path.endsWith('/email')) {
            expect(body, {
              'email': 'new@example.test',
              'current_password': 'OriginalPassword123!',
            });
            return response({
              'success': true,
              'data': {...profile, 'pending_email': 'new@example.test'},
            });
          }
          return response({'success': true, 'data': profile});
        }),
      );
    },
  );

  testWidgets(
    'Personal information validates, saves structured names and keeps server errors retryable',
    (tester) async {
      var writes = 0;
      Map<String, dynamic>? sent;
      await http.runWithClient(
        () async {
          await mount(tester);
          await tap(tester, 'Personal information');
          expect(find.text('juan@example.test'), findsOneWidget);
          await tester.enterText(field('Contact number'), '123');
          await tap(tester, 'Save changes');
          expect(writes, 0);
          await tester.enterText(field('Contact number'), '09201234567');
          await tester.enterText(field('First name'), 'Maria');
          await tester.enterText(field('Last name'), 'Santos');
          await tap(tester, 'Save changes');
          expect(find.text('Please check this contact number.'), findsWidgets);
          expect(find.text('Personal information'), findsOneWidget);
          await tap(tester, 'Save changes');
          expect(writes, 2);
          expect(sent, {
            'contact_no': '09201234567',
            'first_name': 'Maria',
            'last_name': 'Santos',
            'middle_initial': '',
          });
          expect(find.text('Personal information updated.'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (request.method == 'PATCH') {
            writes++;
            sent = jsonDecode(request.body) as Map<String, dynamic>;
            if (writes == 1) {
              return response({
                'success': false,
                'errors': {
                  'contact_no': ['Please check this contact number.'],
                },
              }, status: 422);
            }
            return response({
              'success': true,
              'data': {...profile, 'contact_no': sent!['contact_no']},
            });
          }
          return response({'success': true, 'data': profile});
        }),
      );
    },
  );

  testWidgets(
    'Password form checks confirmation and handles an incorrect current password before retry',
    (tester) async {
      var writes = 0;
      await http.runWithClient(
        () async {
          await mount(tester);
          await tap(tester, 'Change password');
          await tester.enterText(field('Current password'), 'Incorrect123!');
          await tester.enterText(field('New password'), 'UpdatedPassword456!');
          await tester.enterText(field('Confirm new password'), 'Mismatch123!');
          await tap(tester, 'Save changes');
          expect(find.text('Passwords do not match.'), findsOneWidget);
          expect(writes, 0);
          await tester.enterText(
            field('Confirm new password'),
            'UpdatedPassword456!',
          );
          await tap(tester, 'Save changes');
          expect(find.text('The current password is incorrect.'), findsWidgets);
          await tester.enterText(
            field('Current password'),
            'OriginalPassword123!',
          );
          await tap(tester, 'Save changes');
          expect(writes, 2);
          expect(find.textContaining('Password changed.'), findsOneWidget);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          if (request.method == 'PATCH') {
            expect(request.url.path.endsWith('/rider/password'), isTrue);
            writes++;
            final body = jsonDecode(request.body) as Map<String, dynamic>;
            if (body['current_password'] != 'OriginalPassword123!') {
              return response({
                'success': false,
                'errors': {
                  'current_password': ['The current password is incorrect.'],
                },
              }, status: 422);
            }
            expect(body['password'], body['password_confirmation']);
            return response({'success': true});
          }
          return response({'success': true, 'data': profile});
        }),
      );
    },
  );

  testWidgets(
    'Scanner preferences survive reload and Rider sign out requires confirmation',
    (tester) async {
      var logouts = 0;
      await ShopHopScanFeedback.loadPreferences();
      await http.runWithClient(
        () async {
          await mount(tester, logout: () => logouts++, textScale: 1.8);
          await tap(tester, 'Scan sound');
          expect(ShopHopScanFeedback.soundEnabled.value, isFalse);
          expect(
            await const FlutterSecureStorage().read(key: 'shophop_scan_sound'),
            'false',
          );
          ShopHopScanFeedback.soundEnabled.value = true;
          await ShopHopScanFeedback.loadPreferences();
          expect(ShopHopScanFeedback.soundEnabled.value, isFalse);
          await tap(tester, 'Scan vibration');
          expect(ShopHopScanFeedback.vibrationEnabled.value, isFalse);
          await tap(tester, 'About ShopHop');
          expect(find.text('1.0.0 (1)'), findsOneWidget);
          await tester.tap(find.text('Close'));
          await tester.pumpAndSettle();
          await tap(tester, 'Sign out');
          await tap(tester, 'Cancel');
          expect(logouts, 0);
          await tap(tester, 'Sign out');
          await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
          await tester.pumpAndSettle();
          expect(logouts, 1);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient(
          (_) async => response({'success': true, 'data': profile}),
        ),
      );
    },
  );
}
