import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shophop/core/session/auth_session_service.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/rider/data/services/rider_management_service.dart';
import 'package:shophop/features/rider/presentation/screens/rider_application_status_screen.dart';
import 'package:shophop/features/rider/registration/widgets/rider_work_preferences.dart';

http.Response ok(Map<String, dynamic> data) => http.Response(
  jsonEncode({'success': true, 'data': data}),
  200,
  headers: {'content-type': 'application/json'},
);

Map<String, dynamic> application({String status = 'pending_review'}) => {
  'name': 'Test Rider',
  'application_status': status,
  'operational_status': 'pending_activation',
  'can_operate': false,
  'company': {'id': 1, 'name': 'Chosen Logistics'},
  'branch': {'id': 11, 'name': 'Calamba Branch', 'address': 'Laguna'},
  'preferred_coverage': [
    {'key': 'real', 'label': 'Real, Calamba, Laguna'},
  ],
  'official_coverage': [],
  'schedules': [],
  'history': [],
};

void main() {
  test('work options send only selected logistics and Branch IDs', () async {
    final client = MockClient((request) async {
      expect(request.url.path, endsWith('/rider/work-options'));
      expect(request.url.queryParameters, {
        'company_id': '2',
        'branch_id': '21',
      });
      expect(request.headers.containsKey('Authorization'), isFalse);
      return ok({
        'branches': [
          {'id': 21, 'name': 'Branch B'},
        ],
        'coverage': [],
      });
    });
    final result = await RiderManagementService.options(
      companyId: 2,
      branchId: 21,
      client: client,
    );
    expect(result.success, isTrue);
  });
  test(
    'application-only request retains scoped token and validation errors',
    () async {
      final client = MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.headers['Authorization'], 'Bearer applicant-token');
        expect(jsonDecode(request.body), {
          'branch_id': 11,
          'coverage': ['real'],
        });
        return http.Response(
          jsonEncode({
            'message': 'The assigned Branch changed.',
            'errors': {
              'branch_id': ['Refresh your Branch.'],
            },
          }),
          422,
        );
      });
      final result = await RiderManagementService.request(
        'application/confirm-branch',
        token: 'applicant-token',
        method: 'POST',
        body: {
          'branch_id': 11,
          'coverage': ['real'],
        },
        client: client,
      );
      expect(result.success, isFalse);
      expect(result.statusCode, 422);
      expect(result.errors, contains('branch_id'));
    },
  );
  test(
    'connection failure keeps a retryable result instead of throwing',
    () async {
      final result = await RiderManagementService.options(
        client: MockClient((_) async => throw http.ClientException('offline')),
      );
      expect(result.status, 'network_error');
      expect(result.success, isFalse);
    },
  );

  testWidgets(
    'work-area form requires Branch and barangays from chosen provider',
    (tester) async {
      final form = GlobalKey<FormState>();
      RiderWorkSelection selection = const RiderWorkSelection();
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Form(
                    key: form,
                    child: RiderWorkPreferences(
                      companyId: 1,
                      value: selection,
                      onChanged: (v) => selection = v,
                    ),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(form.currentState!.validate(), isFalse);
          await tester.pump();
          expect(find.text('Choose a preferred Branch.'), findsOneWidget);
          await tester.tap(find.byType(DropdownButtonFormField<int>));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Calamba Branch').last);
          await tester.pumpAndSettle();
          expect(selection.branchId, 11);
          expect(form.currentState!.validate(), isFalse);
          await tester.tap(find.byType(CheckboxListTile));
          await tester.pumpAndSettle();
          expect(selection.coverage, ['real']);
          expect(form.currentState!.validate(), isTrue);
          await tester.pumpWidget(const SizedBox.shrink());
        },
        () => MockClient(
          (request) async => ok({
            'branches': [
              {'id': 11, 'name': 'Calamba Branch'},
            ],
            'coverage': request.url.queryParameters.containsKey('branch_id')
                ? [
                    {
                      'key': 'real',
                      'label': 'Real, Calamba, Laguna',
                      'active_count': 6,
                      'limit': 6,
                    },
                  ]
                : [],
          }),
        ),
      );
    },
  );

  testWidgets(
    'application screen refreshes review state and pauses in background',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await AuthSessionService.clearSession();
      await AuthSessionService.saveSession(
        token: 'applicant',
        email: 'rider@example.test',
        accountType: 'rider',
        rememberMe: false,
      );
      var calls = 0;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: const RiderApplicationStatusScreen(),
            ),
          );
          await tester.pumpAndSettle();
          expect(find.text('Application: pending review'), findsOneWidget);
          expect(find.text('Open rider workspace'), findsNothing);
          await tester.pump(const Duration(seconds: 16));
          await tester.pumpAndSettle();
          expect(find.text('Application: approved'), findsOneWidget);
          expect(
            find.textContaining('Your assigned Branch must'),
            findsOneWidget,
          );
          final before = calls;
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.inactive,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.hidden,
          );
          tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.paused,
          );
          await tester.pump(const Duration(seconds: 16));
          expect(calls, before);
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
          expect(calls, before + 1);
          await tester.pumpWidget(const SizedBox.shrink());
          await AuthSessionService.clearSession();
        },
        () => MockClient((request) async {
          calls++;
          expect(request.headers['Authorization'], 'Bearer applicant');
          return ok(
            application(status: calls == 1 ? 'pending_review' : 'approved'),
          );
        }),
      );
    },
  );

  testWidgets('changed Branch requires explicit rider coverage acceptance', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await AuthSessionService.clearSession();
    await AuthSessionService.saveSession(
      token: 'applicant',
      email: 'rider@example.test',
      accountType: 'rider',
      rememberMe: false,
    );
    var accepted = false;
    await http.runWithClient(
      () async {
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: const RiderApplicationStatusScreen(),
          ),
        );
        await tester.pumpAndSettle();
        final button = find.widgetWithText(
          FilledButton,
          'Accept assigned Branch & coverage',
        );
        await tester.scrollUntilVisible(button, 300);
        expect(tester.widget<FilledButton>(button).onPressed, isNull);
        final coverage = find.byType(CheckboxListTile);
        await tester.ensureVisible(coverage);
        await tester.tap(coverage);
        await tester.pumpAndSettle();
        await tester.ensureVisible(button);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(accepted, isTrue);
        expect(
          find.textContaining('Main Hub confirmed a different Branch'),
          findsNothing,
        );
        await tester.pumpWidget(const SizedBox.shrink());
        await AuthSessionService.clearSession();
      },
      () => MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, endsWith('/application/confirm-branch'));
          expect(jsonDecode(request.body), {
            'branch_id': 11,
            'coverage': ['real'],
          });
          accepted = true;
        }
        return ok({
          ...application(status: 'approved'),
          'assignment_confirmation_required': !accepted,
          'branch_coverage_options': !accepted
              ? [
                  {'key': 'real', 'label': 'Real, Calamba, Laguna'},
                ]
              : [],
        });
      }),
    );
  });

  test('operational token exchange preserves Remember me choice', () async {
    FlutterSecureStorage.setMockInitialValues({});
    await AuthSessionService.clearSession();
    await AuthSessionService.saveSession(
      token: 'application',
      email: 'rider@example.test',
      accountType: 'rider',
      rememberMe: true,
    );
    await AuthSessionService.replaceToken('operational');
    expect(
      (await AuthSessionService.readRememberedSession())?.token,
      'operational',
    );
    await AuthSessionService.saveSession(
      token: 'temporary',
      email: 'rider@example.test',
      accountType: 'rider',
      rememberMe: false,
    );
    await AuthSessionService.replaceToken('temporary-operational');
    expect(
      (await AuthSessionService.readSession())?.token,
      'temporary-operational',
    );
    expect(await AuthSessionService.readRememberedSession(), isNull);
    await AuthSessionService.clearSession();
  });
  testWidgets(
    'suspended collector can record a physical handover without task access',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      await AuthSessionService.clearSession();
      await AuthSessionService.saveSession(
        token: 'application',
        email: 'rider@example.test',
        accountType: 'rider',
        rememberMe: false,
      );
      var remitted = false;
      await http.runWithClient(
        () async {
          await tester.pumpWidget(
            MaterialApp(
              theme: AppTheme.light,
              home: const RiderApplicationStatusScreen(),
            ),
          );
          await tester.pumpAndSettle();
          final button = find.text('Record physical cash handover');
          await tester.scrollUntilVisible(button, 250);
          await Scrollable.ensureVisible(
            tester.element(button),
            alignment: 0.5,
          );
          await tester.pumpAndSettle();
          await tester.tap(button);
          await tester.pumpAndSettle();
          expect(remitted, isFalse);
          await tester.tap(find.text('Cash handed over'));
          await tester.pumpAndSettle();
          expect(remitted, isTrue);
          expect(find.text('Record physical cash handover'), findsNothing);
          expect(find.text('Open rider workspace'), findsNothing);
          await tester.pumpWidget(const SizedBox.shrink());
          await AuthSessionService.clearSession();
        },
        () => MockClient((request) async {
          if (request.method == 'POST') {
            expect(request.url.path, endsWith('/cod/99/remit'));
            remitted = true;
            return ok({});
          }
          return ok({
            ...application(status: 'approved'),
            'operational_status': 'suspended',
            'outstanding_cod': remitted
                ? []
                : [
                    {
                      'delivery_id': 99,
                      'order_id': 9,
                      'amount': '100.00',
                      'can_remit': true,
                    },
                  ],
          });
        }),
      );
    },
  );
}
