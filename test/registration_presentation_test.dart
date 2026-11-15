import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/core/theme/app_colors.dart';
import 'package:shophop/features/auth/presentation/widgets/registration_success_dialog.dart';
import 'package:shophop/features/buyer/registration/steps/buyer_security_step.dart';
import 'package:shophop/features/seller/registration/steps/seller_security_step.dart';
import 'package:shophop/features/seller/registration/steps/seller_business_step.dart';
import 'package:shophop/shared/registration/registration_policy_screen.dart';

void main() {
  testWidgets(
    'compact category menu still scrolls to and saves the last choice',
    (tester) async {
      final name = TextEditingController(text: 'Test Shop');
      final category = TextEditingController();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SellerBusinessStep(
              businessNameController: name,
              businessCategoryController: category,
            ),
          ),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      final list = find.byType(Scrollable).last;
      expect(tester.getSize(list).height, lessThanOrEqualTo(224));
      await tester.scrollUntilVisible(
        find.text('Office and School Supplies'),
        100,
        scrollable: list,
      );
      await tester.tap(find.text('Office and School Supplies').last);
      await tester.pumpAndSettle();
      expect(category.text, 'Office and School Supplies');
      await tester.pumpWidget(const SizedBox());
      name.dispose();
      category.dispose();
    },
  );
  testWidgets(
    'success dialog stays centered on a small screen with a navy action',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (_) => const RegistrationSuccessDialog(
                      title: 'Application Submitted!',
                      description:
                          'Your Seller application has been submitted successfully. You can track its review and approval status.',
                      action: 'View Application Status',
                      reference: 'SELLER-00000001',
                      status: 'pending',
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final panel = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(panel.center.dx, closeTo(160, 1));
      expect(panel.center.dy, closeTo(320, 1));
      expect(panel.width, lessThanOrEqualTo(280));
      final action = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'View Application Status'),
      );
      expect(action.style!.backgroundColor!.resolve({}), AppColors.navy);
      await tester.tap(find.text('View Application Status'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
    },
  );

  for (final seller in [false, true]) {
    testWidgets(
      '${seller ? 'Seller' : 'Buyer'} password checks update and policy reading never preselects agreement',
      (tester) async {
        final password = TextEditingController();
        final confirmation = TextEditingController();
        final form = GlobalKey<FormState>();
        var accepted = false;
        final role = seller ? 'seller' : 'buyer';
        await tester.runAsync(
          () => rootBundle.loadString('assets/data/registration-policies.json'),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: StatefulBuilder(
                  builder: (context, setState) {
                    void changed(bool value) =>
                        setState(() => accepted = value);
                    void terms() {
                      RegistrationPolicyScreen.open(context, role);
                    }

                    void privacy() {
                      RegistrationPolicyScreen.open(context, 'privacy');
                    }

                    return Form(
                      key: form,
                      child: seller
                          ? SellerSecurityStep(
                              passwordController: password,
                              confirmPasswordController: confirmation,
                              termsAccepted: accepted,
                              onTermsChanged: changed,
                              onTermsTap: terms,
                              onPrivacyTap: privacy,
                            )
                          : BuyerSecurityStep(
                              passwordController: password,
                              confirmPasswordController: confirmation,
                              termsAccepted: accepted,
                              onTermsChanged: changed,
                              onTermsTap: terms,
                              onPrivacyTap: privacy,
                            ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
        expect(find.byIcon(Icons.check_rounded), findsNothing);
        await tester.enterText(
          find.byType(TextFormField).first,
          'StrongPass1!',
        );
        await tester.pump();
        expect(find.byIcon(Icons.check_rounded), findsNWidgets(5));
        await tester.enterText(find.byType(TextFormField).last, 'StrongPass1!');
        await tester.pump();
        expect(form.currentState!.validate(), false);
        await tester.pump();
        final link = find.text(
          seller ? 'Seller Terms and Conditions' : 'Terms and Conditions',
        );
        await tester.ensureVisible(link);
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pumpAndSettle();
        await tester.tap(link);
        await tester.pump();
        await tester.runAsync(
          () => rootBundle.loadString('assets/data/registration-policies.json'),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(
            seller
                ? 'Seller Terms and Conditions'
                : 'Buyer Terms and Conditions',
          ),
          findsOneWidget,
        );
        expect(accepted, false);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, false);
        await tester.ensureVisible(find.byType(Checkbox));
        await tester.tap(find.byType(Checkbox));
        await tester.pump();
        expect(accepted, true);
        expect(form.currentState!.validate(), true);
        await tester.pumpWidget(const SizedBox());
        password.dispose();
        confirmation.dispose();
      },
    );
  }
}
