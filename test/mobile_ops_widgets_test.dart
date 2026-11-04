import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/shared/widgets/shop_hop_ops.dart';
import 'package:shophop/shared/widgets/shop_hop_product_media.dart';

void main() {
  testWidgets('Logistics action remains tappable with a compact label',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ShopHopOpsAction(
      icon: Icons.qr_code_scanner_rounded,
      title: 'Receive inbound manifest',
      subtitle: 'Verify the physical parcel count',
      onTap: () => taps++,
    ))));
    expect(find.text('Receive inbound manifest'), findsOneWidget);
    await tester.tap(find.text('Receive inbound manifest'));
    expect(taps, 1);
  });

  testWidgets('Disabled action does not trigger a scanner operation',
      (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ShopHopOpsAction(
      icon: Icons.inventory_2_outlined,
      title: 'Load outbound manifest',
      subtitle: 'Needs an assigned facility',
      enabled: false,
      onTap: () => taps++,
    ))));
    await tester.tap(find.text('Load outbound manifest'));
    expect(taps, 0);
  });

  testWidgets('Product without media shows a safe placeholder',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(home: Scaffold(body:
      ShopHopProductThumbnail(width: 72, height: 72))));
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
  });
}
