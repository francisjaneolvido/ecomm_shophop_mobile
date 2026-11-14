import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/data/services/buyer_order_service.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_item_rating_page.dart';

PlatformFile media(String name) {
  final bytes = name.endsWith('.mp4')
      ? Uint8List.fromList([
          0,
          0,
          0,
          24,
          102,
          116,
          121,
          112,
          105,
          115,
          111,
          109,
          0,
          0,
          2,
          0,
          105,
          115,
          111,
          109,
          105,
          115,
          111,
          50,
        ])
      : base64Decode(
          'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+aX1cAAAAASUVORK5CYII=',
        );
  return PlatformFile(name: name, size: bytes.length, bytes: bytes);
}

void main() {
  test('PHP upload failure is shown as a friendly photo error', () async {
    await http.runWithClient(
      () async {
        await expectLater(
          BuyerOrderService.rateItem(
            token: 'test',
            orderId: 2,
            itemId: 7,
            rating: 4,
            comment: 'Review',
          ),
          throwsA(
            isA<BuyerOrderException>().having(
              (error) => error.message,
              'message',
              allOf(isNot(contains('images.0')), contains('photo')),
            ),
          ),
        );
      },
      () => MockClient(
        (_) async => http.Response(
          jsonEncode({
            'message': 'The images.0 failed to upload.',
            'errors': {
              'images.0': ['The images.0 failed to upload.'],
            },
          }),
          422,
        ),
      ),
    );
  });

  test(
    'review upload sends all selected photos and videos as authenticated multipart',
    () async {
      await http.runWithClient(
        () async {
          await BuyerOrderService.rateItem(
            token: 'test',
            orderId: 2,
            itemId: 7,
            rating: 5,
            comment: 'Good item',
            media: [
              media('first.jpg'),
              media('second.png'),
              media('one.mp4'),
              media('two.mp4'),
            ],
          );
        },
        () => MockClient((request) async {
          expect(request.url.path, '/api/mobile/buyer/orders/2/items/7/review');
          expect(request.headers['authorization'], 'Bearer test');
          expect(
            request.headers['content-type'],
            startsWith('multipart/form-data;'),
          );
          final body = latin1.decode(request.bodyBytes);
          for (final field in [
            'images[0]',
            'images[1]',
            'videos[0]',
            'videos[1]',
          ]) {
            expect(body, contains('name="$field"'));
          }
          for (final name in [
            'first.jpg',
            'second.png',
            'one.mp4',
            'two.mp4',
          ]) {
            expect(body, contains('filename="$name"'));
          }
          expect(body, contains('Good item'));
          expect(body, contains('content-type: image/png'));
          expect(body, contains('content-type: video/mp4'));
          return http.Response(
            '{"success":true,"data":{"review_id":1,"rating":5}}',
            200,
          );
        }),
      );
    },
  );

  test(
    'unreadable, disguised and oversized attachments are rejected locally',
    () {
      for (final file in [
        PlatformFile(name: 'missing.jpg', size: 100, path: '/expired/temp.jpg'),
        PlatformFile(
          name: 'unsafe.jpg',
          size: 3,
          bytes: Uint8List.fromList([1, 2, 3]),
        ),
        PlatformFile(
          name: 'disguised.mp4',
          size: media('photo.png').size,
          bytes: media('photo.png').bytes,
        ),
        PlatformFile(
          name: 'unsafe.php',
          size: media('photo.png').size,
          bytes: media('photo.png').bytes,
        ),
        PlatformFile(
          name: 'large.png',
          size: 1,
          bytes: Uint8List(5 * 1024 * 1024 + 1)
            ..setRange(0, 8, media('photo.png').bytes!),
        ),
        PlatformFile(
          name: 'large.mp4',
          size: 1,
          bytes: Uint8List(30 * 1024 * 1024 + 1)
            ..setRange(0, 24, media('video.mp4').bytes!),
        ),
      ]) {
        expect(
          () => BuyerOrderService.validateReviewMedia([file]),
          throwsA(isA<BuyerOrderException>()),
        );
      }
    },
  );

  test('maximum photo and video counts are accepted', () {
    BuyerOrderService.validateReviewMedia([
      ...List.generate(6, (i) => media('$i.png')),
      media('one.mp4'),
      media('two.mp4'),
    ]);
    expect(
      () => BuyerOrderService.validateReviewMedia(
        List.generate(3, (i) => media('$i.mp4')),
      ),
      throwsA(isA<BuyerOrderException>()),
    );
  });

  test(
    'optional media and text use JSON and require a saved review ID',
    () async {
      for (final comment in ['', 'Good item']) {
        await http.runWithClient(
          () => BuyerOrderService.rateItem(
            token: 'test',
            orderId: 1,
            itemId: 1,
            rating: 4,
            comment: comment,
          ),
          () => MockClient((request) async {
            expect(request.headers['content-type'], 'application/json');
            expect(jsonDecode(request.body), {'rating': 4, 'comment': comment});
            return http.Response(
              '{"success":true,"data":{"review_id":1,"rating":4}}',
              200,
            );
          }),
        );
      }
      await http.runWithClient(
        () async {
          await expectLater(
            BuyerOrderService.rateItem(
              token: 'test',
              orderId: 1,
              itemId: 1,
              rating: 4,
              comment: '',
            ),
            throwsA(
              isA<BuyerOrderException>().having(
                (e) => e.message,
                'message',
                contains('did not confirm'),
              ),
            ),
          );
        },
        () => MockClient(
          (_) async => http.Response('{"success":true,"data":{}}', 200),
        ),
      );
    },
  );

  test(
    'oversized server requests, timeouts and connection failures are friendly',
    () async {
      for (final kind in ['413', 'timeout', 'network']) {
        await http.runWithClient(
          () async {
            await expectLater(
              BuyerOrderService.rateItem(
                token: 'test',
                orderId: 1,
                itemId: 1,
                rating: 4,
                comment: '',
                media: [media('photo.png')],
              ),
              throwsA(
                isA<BuyerOrderException>().having(
                  (e) => e.message,
                  'message',
                  isNot(contains('images.0')),
                ),
              ),
            );
          },
          () => MockClient((_) async {
            if (kind == 'timeout') throw TimeoutException('test');
            if (kind == 'network') throw http.ClientException('offline');
            return http.Response('<html>Too large</html>', 413);
          }),
        );
      }
    },
  );

  testWidgets(
    'upload blocks repeat taps and preserves draft after unexpected failure',
    (tester) async {
      final pending = Completer<void>();
      var submissions = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: BuyerItemRatingPage(
            item: const BuyerOrderItemData(
              name: 'Test',
              variant: 'Standard',
              quantity: 1,
              price: 10,
            ),
            pickMedia: () async => [media('photo.png')],
            onSessionExpired: () async {},
            onSubmit: (rating, comment, files) async {
              submissions++;
              expect(rating, 4);
              expect(comment, 'My draft');
              expect(files.single.name, 'photo.png');
              await pending.future;
            },
          ),
        ),
      );
      await tester.ensureVisible(find.text('Add photos or videos'));
      await tester.tap(find.text('Add photos or videos'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('rate-star-4')));
      await tester.tap(find.byKey(const ValueKey('rate-star-4')));
      await tester.ensureVisible(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'My draft');
      await tester.tap(find.text('Submit rating'));
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final button = find.byType(FilledButton);
      await tester.tap(button);
      await tester.pump();
      expect(submissions, 1);
      pending.completeError(StateError('unexpected'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Your rating, text, and attachments are kept'),
        findsOneWidget,
      );
      expect(find.text('My draft'), findsOneWidget);
      expect(find.byTooltip('Remove photo.png'), findsOneWidget);
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'review media parsing preserves mixed media and legacy single photos',
    () {
      final review = BuyerReviewData.fromJson({
        'image': 'https://example.test/old.jpg',
        'media': [
          {'type': 'image', 'url': 'https://example.test/one.jpg'},
          {'type': 'video', 'url': 'https://example.test/two.mp4'},
        ],
      });
      expect(review.attachments.length, 2);
      expect(review.attachments[1].isVideo, isTrue);
      final legacy = BuyerReviewData.fromJson({
        'image': 'https://example.test/old.jpg',
      });
      expect(legacy.attachments.single.url, 'https://example.test/old.jpg');
      expect(legacy.attachments.single.isVideo, isFalse);
    },
  );

  testWidgets(
    'rating attachments can be selected, removed and submitted together',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      List<PlatformFile>? submitted;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BuyerItemRatingPage(
              item: const BuyerOrderItemData(
                name: 'Test item',
                variant: 'Standard',
                quantity: 1,
                price: 10,
              ),
              pickMedia: () async => [
                media('first.jpg'),
                media('second.png'),
                media('one.mp4'),
                media('two.mp4'),
              ],
              onSessionExpired: () async {},
              onSubmit: (rating, comment, files) async {
                submitted = files;
              },
            ),
          ),
        ),
      );
      await tester.ensureVisible(find.text('Add photos or videos'));
      await tester.tap(find.text('Add photos or videos'));
      await tester.pumpAndSettle();
      expect(find.text('one.mp4'), findsOneWidget);
      expect(find.text('two.mp4'), findsOneWidget);
      await tester.ensureVisible(find.byTooltip('Remove first.jpg'));
      await tester.tap(find.byTooltip('Remove first.jpg'));
      await tester.pumpAndSettle();
      expect(find.text('first.jpg'), findsNothing);
      await tester.ensureVisible(find.byKey(const ValueKey('rate-star-5')));
      await tester.tap(find.byKey(const ValueKey('rate-star-5')));
      await tester.pump();
      await tester.ensureVisible(find.text('Submit rating'));
      await tester.tap(find.text('Submit rating'));
      await tester.pumpAndSettle();
      expect(submitted?.map((f) => f.name), [
        'second.png',
        'one.mp4',
        'two.mp4',
      ]);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('too many photos are rejected before submission', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: BuyerItemRatingPage(
            item: const BuyerOrderItemData(
              name: 'Test item',
              variant: 'Standard',
              quantity: 1,
              price: 10,
            ),
            pickMedia: () async =>
                List.generate(7, (i) => media('photo-$i.jpg')),
            onSessionExpired: () async {},
            onSubmit: (_, _, _) async {},
          ),
        ),
      ),
    );
    await tester.ensureVisible(find.text('Add photos or videos'));
    await tester.tap(find.text('Add photos or videos'));
    await tester.pumpAndSettle();
    expect(
      find.text('You can attach up to 6 photos and 2 videos.'),
      findsOneWidget,
    );
    expect(find.byTooltip('Remove photo-0.jpg'), findsNothing);
  });

  testWidgets(
    'full page keeps submit fixed while the form scrolls with enlarged text',
    (tester) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.6)),
            child: BuyerItemRatingPage(
              item: const BuyerOrderItemData(
                name:
                    'A product name that takes more than one line on a small phone',
                variant: 'Standard',
                quantity: 1,
                price: 10,
              ),
              onSessionExpired: () async {},
              onSubmit: (_, _, _) async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final submit = find.widgetWithText(FilledButton, 'Submit rating');
      final position = tester.getTopLeft(submit);
      await tester.drag(
        find.byKey(const ValueKey('rating-form-scroll')),
        const Offset(0, -700),
      );
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(submit), position);
      expect(find.text('Write your review'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
