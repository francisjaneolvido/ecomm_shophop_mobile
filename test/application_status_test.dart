import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/features/auth/presentation/screens/application_status_screen.dart';

void main() {
  testWidgets(
    'pending account restores saved status, refreshes on resume, and pauses while hidden',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await AuthSessionService.clearSession();
      await AuthSessionService.saveSession(
        token: 'status-token',
        email: 'seller@example.test',
        accountType: 'seller',
        rememberMe: true,
      );
      var calls = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            const MaterialApp(home: ApplicationStatusScreen()),
          );
          await tester.pumpAndSettle();
          expect(find.text('PENDING'), findsOneWidget);
          expect(find.text('SELLER-00000001'), findsOneWidget);
          final initialCalls = calls;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump(const Duration(seconds: 61));
          expect(calls, initialCalls);
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          );
          await tester.pumpAndSettle();
          expect(calls, initialCalls + 1);
          expect(find.text('REJECTED'), findsOneWidget);
          expect(
            find.text('Please provide a readable permit.'),
            findsOneWidget,
          );
          await tester.pumpWidget(const SizedBox());
        },
        () => MockClient((request) async {
          expectSync(request.url.path, endsWith('/application'));
          expectSync(request.headers['Authorization'], 'Bearer status-token');
          calls++;
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {
                'reference': 'SELLER-00000001',
                'account_type': 'seller',
                'status': calls == 1 ? 'pending' : 'rejected',
                'name': 'Test Seller',
                'email': 'seller@example.test',
                'message': 'Your saved application.',
                'can_enter_dashboard': false,
                'timeline': [],
                'rejection_reason': calls == 1
                    ? null
                    : 'Please provide a readable permit.',
              },
            }),
            200,
          );
        }),
      );
      await AuthSessionService.clearSession();
    },
  );
}
