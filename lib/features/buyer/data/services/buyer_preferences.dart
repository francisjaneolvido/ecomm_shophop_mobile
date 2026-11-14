import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class BuyerPreferences {
  BuyerPreferences._();
  static const storage = FlutterSecureStorage();
  static const orderViews = <String, String>{
    'all': 'All orders',
    'to-ship': 'To ship',
    'to-receive': 'To receive',
    'to-rate': 'To rate',
    'completed': 'Completed',
    'cancelled': 'Cancelled',
  };
  static String _key(String email) =>
      'buyer_order_view_${base64Url.encode(utf8.encode(email.trim().toLowerCase()))}';
  static Future<String> orderView(String email) async {
    final value = await storage.read(key: _key(email));
    return orderViews.containsKey(value) ? value! : 'all';
  }

  static Future<void> saveOrderView(String email, String value) async {
    if (!orderViews.containsKey(value)) throw ArgumentError.value(value);
    await storage.write(key: _key(email), value: value);
  }
}
