import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_variant_sheet.dart';

BuyerProductDetailData detail({bool unavailable = false}) =>
    BuyerProductDetailData.fromJson({
      'id': 1,
      'name': 'Desk lamp',
      'price': 100,
      'stock': 5,
      'has_variants': true,
      'variants': [
        {
          'id': 1,
          'name': 'White',
          'label': 'White',
          'price': 100,
          'stock': unavailable ? 0 : 2,
          'status': 'active',
          'in_stock': !unavailable,
        },
        {
          'id': 2,
          'name': 'Blue',
          'label': 'Blue',
          'price': 120,
          'stock': unavailable ? 0 : 10,
          'status': 'active',
          'in_stock': !unavailable,
        },
        {
          'id': 3,
          'name': 'Black',
          'label': 'Black',
          'price': 120,
          'stock': 0,
          'status': 'active',
          'in_stock': false,
        },
      ],
    });

void main() {
  testWidgets('Variant sheet caps stock and confirms the selected quantity', (
    tester,
  ) async {
    final data = detail();
    BuyerVariantSelection? result;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await showBuyerVariantSheet(
                  context,
                  detail: data,
                  selected: data.variants.first,
                  quantity: 2,
                );
              },
              child: const Text('Options'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Increase quantity',
            ),
          )
          .onPressed,
      isNull,
    );
    expect(
      tester
          .widget<ChoiceChip>(
            find.ancestor(
              of: find.text('Black'),
              matching: find.byType(ChoiceChip),
            ),
          )
          .onSelected,
      isNull,
    );
    await tester.tap(find.text('Blue'));
    await tester.pumpAndSettle();
    expect(find.text('5 available'), findsOneWidget);
    for (var i = 0; i < 3; i++) {
      await tester.tap(
        find.byWidgetPredicate(
          (widget) =>
              widget is IconButton && widget.tooltip == 'Increase quantity',
        ),
      );
      await tester.pump();
    }
    expect(find.text('5'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.byWidgetPredicate(
              (widget) =>
                  widget is IconButton && widget.tooltip == 'Increase quantity',
            ),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.text('Confirm selection'));
    await tester.pumpAndSettle();
    expect(result?.variant?.id, 2);
    expect(result?.quantity, 5);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Cancel discards edits and out-of-stock variants cannot be confirmed',
    (tester) async {
      final data = detail();
      BuyerVariantSelection? result;
      var returned = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  result = await showBuyerVariantSheet(
                    context,
                    detail: data,
                    selected: data.variants.first,
                    quantity: 1,
                  );
                  returned = true;
                },
                child: const Text('Options'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Blue'));
      await tester.tap(find.byTooltip('Cancel selection'));
      await tester.pumpAndSettle();
      expect(returned, isTrue);
      expect(result, isNull);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: BuyerVariantSheet(
              detail: detail(unavailable: true),
              selected: null,
              quantity: 1,
            ),
          ),
        ),
      );
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Currently unavailable'),
            )
            .onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Selection sheet supports a small phone and enlarged text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(2)),
          child: child!,
        ),
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showBuyerVariantSheet(
                context,
                detail: detail(),
                selected: null,
                quantity: 1,
              ),
              child: const Text('Options'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    expect(find.text('Confirm selection'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
