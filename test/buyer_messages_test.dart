import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_messages_page.dart';

http.Response reply(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

void main() {
  testWidgets(
    'Chats searches shops and filters unread conversations on a small phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: const BuyerMessagesPage(token: 'test'),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Chats'), findsOneWidget);
          await tester.tap(find.text('Unread'));
          await tester.pumpAndSettle();
          expect(find.text('Unread Shop'), findsOneWidget);
          expect(find.text('Other Shop'), findsNothing);
          await tester.enterText(find.byType(TextField), 'missing');
          await tester.pumpAndSettle();
          expect(find.text('No matching chats'), findsOneWidget);
          await tester.enterText(find.byType(TextField), '');
          await tester.tap(find.text('All'));
          await tester.pumpAndSettle();
          expect(find.text('Other Shop'), findsOneWidget);
          await tester.pumpWidget(const SizedBox());
          expect(tester.takeException(), isNull);
        },
        () => MockClient(
          (_) async => reply({
            'ok': true,
            'conversations': [
              {
                'id': 1,
                'name': 'Unread Shop',
                'last': 'Hello',
                'time': 'just now',
                'unread': 2,
              },
              {
                'id': 2,
                'name': 'Other Shop',
                'last': 'Thanks',
                'time': 'a day ago',
                'unread': 0,
              },
            ],
          }),
        ),
      );
    },
  );

  testWidgets('Thread emoji picker inserts into the current draft', (
    tester,
  ) async {
    await http.runWithClient(() async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const BuyerChatPage(token: 'test', chatId: 4, name: 'Shop'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Hello ');
      await tester.pump();
      await tester.tap(find.byTooltip('Choose emoji'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('😊'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Hello 😊',
      );
      await tester.pumpWidget(const SizedBox());
      expect(tester.takeException(), isNull);
    }, () => MockClient((_) async => reply({'ok': true, 'messages': []})));
  });

  testWidgets(
    'Inbox opens shared history and sends once without duplicating poll results',
    (tester) async {
      var sent = false;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: const BuyerMessagesPage(token: 'test'),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(find.text('Test Shop'));
          await tester.pumpAndSettle();
          expect(find.text('Reply from web'), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'Hello seller');
          await tester.pump();
          await tester.tap(find.byTooltip('Send message'));
          await tester.pumpAndSettle();
          expect(sent, isTrue);
          expect(find.text('Hello seller'), findsOneWidget);
          await tester.pump(const Duration(seconds: 3));
          await tester.pumpAndSettle();
          expect(find.text('Hello seller'), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            isEmpty,
          );
          await tester.pumpWidget(const SizedBox());
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test');
          if (request.url.path.endsWith('/conversations'))
            return reply({
              'ok': true,
              'conversations': [
                {
                  'id': 4,
                  'name': 'Test Shop',
                  'last': 'Reply from web',
                  'time': 'just now',
                  'unread': 1,
                },
              ],
            });
          if (request.method == 'POST') {
            expect(jsonDecode(request.body)['body'], 'Hello seller');
            sent = true;
            return reply({
              'ok': true,
              'message': {
                'id': 2,
                'body': 'Hello seller',
                'mine': true,
                'time': '1:00 PM',
              },
            });
          }
          return reply({
            'ok': true,
            'messages': [
              {
                'id': 1,
                'body': 'Reply from web',
                'mine': false,
                'time': '12:59 PM',
              },
              if (sent)
                {
                  'id': 2,
                  'body': 'Hello seller',
                  'mine': true,
                  'time': '1:00 PM',
                },
            ],
          });
        }),
      );
    },
  );

  testWidgets('Failed send preserves the draft and permits retry', (
    tester,
  ) async {
    var attempts = 0;
    String? clientId;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const BuyerChatPage(token: 'test', chatId: 4, name: 'Shop'),
          ),
        );
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), 'Keep this draft');
        await tester.pump();
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          'Keep this draft',
        );
        expect(find.textContaining('Unable to send'), findsOneWidget);
        await tester.pump(const Duration(seconds: 3));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Send message'));
        await tester.pumpAndSettle();
        expect(attempts, 2);
        expect(find.text('Keep this draft'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        expect(tester.takeException(), isNull);
      },
      () => MockClient((request) async {
        if (request.method != 'POST') {
          return reply({
            'ok': true,
            'messages': [
              if (attempts > 0)
                {
                  'id': 1,
                  'body': 'Keep this draft',
                  'mine': true,
                  'time': '1:00 PM',
                },
            ],
          });
        }
        final id = jsonDecode(request.body)['client_message_id'] as String;
        clientId ??= id;
        expect(id, clientId);
        if (++attempts == 1) throw http.ClientException('offline');
        return reply({
          'ok': true,
          'message': {
            'id': 1,
            'body': 'Keep this draft',
            'mine': true,
            'time': '1:00 PM',
          },
        });
      }),
    );
  });
}
