import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/core/theme/app_theme.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';
import 'package:shophop/features/buyer/presentation/widgets/buyer_product_gallery.dart';

void main() {
  test(
    'Media fallback preserves video order and always supplies a safe page',
    () {
      BuyerProductDetailData detail(Map<String, dynamic> extra) =>
          BuyerProductDetailData.fromJson({'id': 1, 'stock': 1, ...extra});
      expect(buyerProductMedia(detail({})).single.url, '');
      final media = buyerProductMedia(
        detail({
          'gallery': ['/one.jpg', '/two.jpg'],
          'video_url': '/clip.mp4',
          'media_first': 'video',
        }),
      );
      expect(media.map((item) => item.type), ['video', 'image', 'image']);
      expect(
        buyerProductMedia(
          detail({
            'media': [
              {'type': 'image', 'url': '/primary.jpg'},
            ],
            'video_url': '/unused.mp4',
          }),
        ).length,
        1,
      );
    },
  );

  testWidgets(
    'Fullscreen viewer swipes, zooms, and returns the selected photo',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final pages = PageController();
      addTearDown(pages.dispose);
      var selected = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: StatefulBuilder(
            builder: (context, setState) => Scaffold(
              body: SizedBox(
                height: 320,
                child: BuyerProductGallery(
                  media: const [
                    BuyerMediaItem(type: 'image', url: ''),
                    BuyerMediaItem(type: 'image', url: ''),
                  ],
                  controller: pages,
                  index: selected,
                  onChanged: (index) => setState(() => selected = index),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.bySemanticsLabel('Open photo 1 full screen'));
      await tester.pumpAndSettle();
      expect(find.byType(BuyerMediaViewer), findsOneWidget);
      final photo = find.byType(InteractiveViewer).first;
      await tester.tap(photo);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(photo);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<InteractiveViewer>(photo)
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        greaterThan(1),
      );
      await tester.tap(photo);
      await tester.pump(const Duration(milliseconds: 80));
      await tester.tap(photo);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<InteractiveViewer>(photo)
            .transformationController!
            .value
            .getMaxScaleOnAxis(),
        1,
      );
      await tester.drag(find.byType(PageView).last, const Offset(-320, 0));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(BuyerMediaViewer),
          matching: find.text('2/2'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Close full screen'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(pages.page, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('System back also keeps the photo selected in fullscreen', (
    tester,
  ) async {
    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                selected = await showBuyerMediaViewer(
                  context,
                  media: const [
                    BuyerMediaItem(type: 'image', url: ''),
                    BuyerMediaItem(type: 'image', url: ''),
                  ],
                );
              },
              child: const Text('Open gallery'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open gallery'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-700, 0));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(selected, 1);
    expect(find.byType(BuyerMediaViewer), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
