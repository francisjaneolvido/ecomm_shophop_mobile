import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/buyer/data/services/buyer_preferences.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_device_settings_page.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_account_page.dart';
import 'package:shophop/features/buyer/presentation/pages/buyer_account_settings_page.dart';

final profile = <String, dynamic>{
  'first_name': 'Juan',
  'last_name': 'Dela Cruz',
  'middle_initial': 'A',
  'email': 'buyer@example.com',
  'contact_no': '09123456789',
  'birthday': '1998-04-15',
  'sex': 'Male',
  'sex_options': ['Male', 'Female'],
};

http.Response reply(Map<String, dynamic> body, [int status = 200]) =>
    http.Response(
      jsonEncode(body),
      status,
      headers: {'content-type': 'application/json'},
    );

Finder field(String label) => find.ancestor(
  of: find.byWidgetPredicate(
    (widget) => widget is TextField && widget.decoration?.labelText == label,
  ),
  matching: find.byType(TextFormField),
);

Future<void> enter(WidgetTester tester, String label, String value) async {
  await tester.ensureVisible(field(label));
  await tester.pumpAndSettle();
  await tester.enterText(field(label), value);
}

Future<void> tapVisible(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text));
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Help Centre opens readable in-app answers', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light,
      home: const BuyerAccountSettingsPage(token: 'test')));
    await tester.scrollUntilVisible(find.text('Help Centre'), 250);
    await tapVisible(tester, 'Help Centre');
    await tapVisible(tester, 'Where can I check my orders?');
    expect(find.textContaining('Tap an order to see delivery progress'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Order preference is isolated between accounts', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await BuyerPreferences.saveOrderView('buyer@example.com', 'to-ship');
    expect(await BuyerPreferences.orderView('buyer@example.com'), 'to-ship');
    expect(await BuyerPreferences.orderView('another@example.com'), 'all');
  });

  testWidgets(
    'Privacy removes remembered login while keeping the active session',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await AuthSessionService.clearSession();
      await AuthSessionService.saveSession(
        token: 'active-test-token',
        email: 'buyer@example.com',
        accountType: 'buyer',
        rememberMe: true,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const BuyerPrivacySettingsPage(),
        ),
      );
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Remove remembered sign-in');
      expect(
        find.text('Sign-in is not remembered on this device.'),
        findsOneWidget,
      );
      expect(await AuthSessionService.readToken(), 'active-test-token');
      expect(await AuthSessionService.isRemembered(), isFalse);
      expect(
        (await const FlutterSecureStorage().readAll()).values,
        isNot(contains('active-test-token')),
      );
      await AuthSessionService.clearSession();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Notification settings opens the phone permission screen', (
    tester,
  ) async {
    var opened = false;
    const channel = MethodChannel('shophop/device_settings');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      expect(call.method, 'notifications');
      opened = true;
      return null;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const BuyerNotificationSettingsPage(),
      ),
    );
    await tapVisible(tester, 'Open phone notification settings');
    expect(opened, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Settings removes bank accounts and persists the default order view',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: const BuyerAccountSettingsPage(token: 'test'),
        ),
      );
      expect(find.text('Bank Accounts / Cards'), findsNothing);
      await tapVisible(tester, 'Order Settings');
      await tapVisible(tester, 'To receive');
      expect(find.text('Default order view saved.'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tapVisible(tester, 'Order Settings');
      expect(
        tester
            .widget<RadioListTile<String>>(
              find.widgetWithText(RadioListTile<String>, 'To receive'),
            )
            .value,
        'to-receive',
      );
      final storage = await const FlutterSecureStorage().readAll();
      expect(storage.values, contains('to-receive'));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Account settings opens, saves profile and updates the account name',
    (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      Map<String, dynamic>? saved;
      String? name;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: BuyerAccountPage(
                  displayName: 'Juan Dela Cruz',
                  token: 'test',
                  email: 'buyer@example.com',
                  loggingOut: false,
                  onLogout: () {},
                  onOpenOrders: (_) {},
                  onOpenLikes: () {},
                  onOpenCart: () {},
                  onDisplayNameChanged: (value) => name = value,
                ),
              ),
            ),
          );
          await tapVisible(tester, 'Account settings');
          expect(find.text('My Account'), findsOneWidget);
          await tapVisible(tester, 'Account & Security');
          expect(
            tester.widget<TextFormField>(field('First name')).controller!.text,
            'Juan',
          );
          await enter(tester, 'First name', 'María');
          await tapVisible(tester, 'Save changes');
          expect(saved?['first_name'], 'María');
          expect(saved?['birthday'], '1998-04-15');
          expect(saved!.containsKey('email'), isFalse);
          expect(name, 'María Dela Cruz');
          expect(find.text('Profile changes saved.'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          expect(request.headers['Authorization'], 'Bearer test');
          expect(request.url.path.endsWith('/buyer/profile'), isTrue);
          if (request.method == 'PATCH') {
            saved = jsonDecode(request.body) as Map<String, dynamic>;
          }
          return reply({
            'success': true,
            'data': {...profile, ...?saved},
          });
        }),
      );
    },
  );

  testWidgets('Failed save keeps edits and displays server validation errors', (
    tester,
  ) async {
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const BuyerAccountSecurityPage(token: 'test'),
          ),
        );
        await tester.pumpAndSettle();
        await enter(tester, 'First name', 'Edited');
        await tapVisible(tester, 'Save changes');
        expect(
          tester.widget<TextFormField>(field('First name')).controller!.text,
          'Edited',
        );
        expect(find.text('Profile changes saved.'), findsNothing);
        expect(find.text('This name is invalid.'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
      () => MockClient(
        (request) async => request.method == 'GET'
            ? reply({'success': true, 'data': profile})
            : reply({
                'message': 'Validation failed.',
                'errors': {
                  'first_name': ['This name is invalid.'],
                },
              }, 422),
      ),
    );
  });

  testWidgets(
    'Password validates confirmation, handles rejection, then clears secrets after saving',
    (tester) async {
      var requests = 0;
      Map<String, dynamic>? sent;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: const BuyerPasswordPage(token: 'test'),
            ),
          );
          await enter(tester, 'Current password', 'OldPassword1!');
          await enter(tester, 'New password', 'NewPassword2!');
          await enter(tester, 'Confirm new password', 'Mismatch2!');
          await tapVisible(tester, 'Update password');
          expect(requests, 0);
          expect(find.text('Passwords do not match.'), findsOneWidget);
          await enter(tester, 'Confirm new password', 'NewPassword2!');
          await tapVisible(tester, 'Update password');
          expect(requests, 1);
          expect(find.text('The current password is incorrect.'), findsWidgets);
          await enter(tester, 'Current password', 'CorrectPassword1!');
          await tapVisible(tester, 'Update password');
          expect(requests, 2);
          expect(sent?['current_password'], 'CorrectPassword1!');
          expect(sent?['password_confirmation'], 'NewPassword2!');
          expect(find.text('Password changed.'), findsOneWidget);
          for (final label in [
            'Current password',
            'New password',
            'Confirm new password',
          ]) {
            expect(
              tester.widget<TextFormField>(field(label)).controller!.text,
              isEmpty,
            );
          }
          expect(tester.takeException(), isNull);
        },
        () => MockClient((request) async {
          requests++;
          expect(request.url.path.endsWith('/buyer/password'), isTrue);
          expect(request.method, 'PATCH');
          sent = jsonDecode(request.body) as Map<String, dynamic>;
          return requests == 1
              ? reply({
                  'errors': {
                    'current_password': ['The current password is incorrect.'],
                  },
                }, 422)
              : reply({'success': true});
        }),
      );
    },
  );

  testWidgets(
    'Load can retry after a connection error and expires an invalid session',
    (tester) async {
      var requests = 0, expired = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: BuyerAccountSecurityPage(
                token: 'test',
                onSessionExpired: () async => expired++,
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Try again'), findsOneWidget);
          await tester.tap(find.text('Try again'));
          await tester.pumpAndSettle();
          expect(expired, 1);
          expect(tester.takeException(), isNull);
        },
        () => MockClient((_) async {
          if (++requests == 1) throw http.ClientException('offline');
          return reply({'message': 'Unauthenticated.'}, 401);
        }),
      );
    },
  );
}
