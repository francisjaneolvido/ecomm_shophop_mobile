import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shophop/shared/realtime/foreground_refresh.dart';
import 'package:shophop/features/buyer/data/services/buyer_catalog_service.dart';

void main() {
  testWidgets(
    'polls only when visible and foregrounded, and stops after disposal',
    (tester) async {
      var calls = 0;
      var visible = true;
      final refresh = ForegroundRefresh(
        refresh: () async {
          calls++;
        },
        canRefresh: () => visible,
        interval: const Duration(seconds: 1),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(calls, 1);
      visible = false;
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 1);
      visible = true;
      refresh.didChangeAppLifecycleState(AppLifecycleState.paused);
      await tester.pump(const Duration(seconds: 2));
      expect(calls, 1);
      refresh.didChangeAppLifecycleState(AppLifecycleState.resumed);
      await tester.pump();
      expect(calls, 2);
      refresh.dispose();
      await tester.pump(const Duration(seconds: 3));
      expect(calls, 2);
    },
  );

  testWidgets('does not overlap pending network refreshes', (tester) async {
    var calls = 0;
    final pending = Completer<void>();
    final refresh = ForegroundRefresh(
      refresh: () {
        calls++;
        return pending.future;
      },
      canRefresh: () => true,
      interval: const Duration(seconds: 1),
    );
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 5));
    expect(calls, 1);
    pending.complete();
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 2);
    refresh.dispose();
  });

  test('buyer review parses persisted seller replies and older payloads', () {
    expect(
      BuyerReviewData.fromJson({'seller_reply': 'Thank you'}).sellerReply,
      'Thank you',
    );
    expect(BuyerReviewData.fromJson({}).sellerReply, '');
  });
}
