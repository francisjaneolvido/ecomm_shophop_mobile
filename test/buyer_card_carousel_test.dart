import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_card_carousel.dart';

void main() {
  testWidgets('product card swipes seller media and opens the selected photo', (
    tester,
  ) async {
    var opened = 0;
    final product = BuyerProductData.fromJson({
      'id': 7,
      'media': [
        {'type': 'image', 'url': '/one.png'},
        {'type': 'image', 'url': '/two.png'},
        {'type': 'video', 'url': '/clip.mp4'},
      ],
    });
    expect(product.copyWith(isLiked: true).media.length, 3);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 250,
            height: 280,
            child: BuyerCardCarousel(product: product, onOpen: () => opened++),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('1/3'), findsOneWidget);
    await tester.drag(find.byType(PageView), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.text('2/3'), findsOneWidget);
    await tester.tap(find.byType(PageView));
    expect(opened, 1);
    await tester.drag(find.byType(PageView), const Offset(-250, 0));
    await tester.pumpAndSettle();
    expect(find.text('3/3'), findsOneWidget);
    expect(find.bySemanticsLabel('Play product video'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
