import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/rider/presentation/screens/rider_home_screen.dart';
import 'package:shophop/shared/widgets/shop_hop_navigation.dart';

http.Response result(Map<String, dynamic> data, {int status = 200}) =>
    http.Response(
      jsonEncode(data),
      status,
      headers: {'content-type': 'application/json'},
    );
Finder option(String state) =>
    find.byKey(ValueKey('rider-availability-$state'));
Future<void> mount(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  FlutterSecureStorage.setMockInitialValues({});
  await AuthSessionService.saveSession(
    token: 'home-test',
    email: 'rider@example.test',
    accountType: 'rider',
    rememberMe: false,
  );
  await tester.pumpWidget(
    MaterialApp(theme: AppTheme.light, home: const RiderHomeScreen()),
  );
  await tester.pumpAndSettle();
}

http.Response me(String state) => result({
  'success': true,
  'status': 'approved',
  'data': {
    'name': 'August C Camunias',
    'sorting_center_name': 'Hidden Home Branch',
    'operational_service_areas': [
      {'label': 'Hidden Barangay, Calamba, Laguna'},
    ],
    'availability': state,
    'availability_status': state == 'online'
        ? 'available'
        : state == 'busy'
        ? 'busy'
        : 'offline',
  },
});

void main() {
  testWidgets(
    'Home shows only the name in a pink greeting and saves real availability without changing state after an error',
    (tester) async {
      var state = 'online';
      var fail = false;
      final writes = <String>[];
      await http.runWithClient(
        () async {
          await mount(tester);
          expect(find.text('August C Camunias'), findsOneWidget);
          expect(find.textContaining('Hidden Home Branch'), findsNothing);
          expect(find.textContaining('Hidden Barangay'), findsNothing);
          expect(
            (tester
                        .widget<Container>(
                          find.byKey(const ValueKey('rider-greeting')),
                        )
                        .decoration
                    as BoxDecoration)
                .color,
            AppColors.pink,
          );
          expect(
            tester.widget<OutlinedButton>(option('online')).onPressed,
            isNull,
          );
          await tester.tap(option('on_break'));
          await tester.pumpAndSettle();
          expect(writes, ['on_break']);
          expect(state, 'on_break');
          expect(
            tester.widget<OutlinedButton>(option('on_break')).onPressed,
            isNull,
          );
          fail = true;
          await tester.tap(option('offline'));
          await tester.pumpAndSettle();
          expect(find.text('Resolve assigned parcels first.'), findsOneWidget);
          expect(state, 'on_break');
          expect(
            tester.widget<OutlinedButton>(option('on_break')).onPressed,
            isNull,
          );
          fail = false;
          await tester.tap(option('offline'));
          await tester.pumpAndSettle();
          expect(state, 'offline');
          expect(
            tester.widget<OutlinedButton>(option('offline')).onPressed,
            isNull,
          );
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await AuthSessionService.clearSession();
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/me')) return me(state);
          if (request.method == 'PATCH') {
            expect(request.headers['authorization'], 'Bearer home-test');
            writes.add(jsonDecode(request.body)['state'] as String);
            if (fail) {
              return result({
                'message': 'Resolve assigned parcels first.',
              }, status: 422);
            }
            state = writes.last;
            return result({
              'success': true,
              'data': {'availability': state},
            });
          }
          return result({'success': true, 'data': {}});
        }),
      );
    },
  );

  testWidgets(
    'Busy routes lock availability and Tasks use pink selected filters',
    (tester) async {
      var writes = 0;
      await http.runWithClient(
        () async {
          await mount(tester);
          expect(find.text('Busy'), findsOneWidget);
          for (final state in ['online', 'on_break', 'offline']) {
            expect(
              tester.widget<OutlinedButton>(option(state)).onPressed,
              isNull,
            );
          }
          await tester.tap(
            find.descendant(
              of: find.byType(ShopHopNavigation),
              matching: find.text('Tasks'),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'All 0'))
                .selectedColor,
            AppColors.pink,
          );
          await tester.tap(find.widgetWithText(ChoiceChip, 'Pickup 0'));
          await tester.pumpAndSettle();
          expect(
            tester
                .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Pickup 0'))
                .selected,
            isTrue,
          );
          expect(writes, 0);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox());
          await AuthSessionService.clearSession();
        },
        () => MockClient((request) async {
          if (request.url.path.endsWith('/me')) return me('busy');
          if (request.method == 'PATCH') writes++;
          return result({'success': true, 'data': {}});
        }),
      );
    },
  );
}
