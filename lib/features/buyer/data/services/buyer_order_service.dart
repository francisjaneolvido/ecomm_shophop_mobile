import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';

class BuyerOrderException implements Exception {
  const BuyerOrderException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
  @override
  String toString() => message;
}

class BuyerOrderItemData {
  const BuyerOrderItemData({required this.name, required this.variant, required this.quantity, required this.price});
  final String name;
  final String variant;
  final int quantity;
  final double price;

  factory BuyerOrderItemData.fromJson(Map<String, dynamic> json) => BuyerOrderItemData(
        name: json['name']?.toString() ?? 'Product',
        variant: json['variant']?.toString() ?? 'Standard',
        quantity: (num.tryParse(json['quantity'].toString()) ?? 0).toInt(),
        price: double.tryParse(json['price'].toString()) ?? 0,
      );
}

class BuyerOrderMilestone {
  const BuyerOrderMilestone({required this.label, required this.at});
  final String label;
  final String at;
  factory BuyerOrderMilestone.fromJson(Map<String, dynamic> json) => BuyerOrderMilestone(
        label: json['label']?.toString() ?? '',
        at: json['at']?.toString() ?? '',
      );
}

class BuyerOrderData {
  const BuyerOrderData({
    required this.id,
    required this.displayId,
    required this.sellerName,
    required this.statusLabel,
    required this.statusNote,
    required this.totalAmount,
    required this.paymentMethod,
    required this.paymentId,
    required this.deliveryAddress,
    required this.trackingCode,
    required this.failureReason,
    required this.canConfirmReceipt,
    required this.items,
    required this.timeline,
  });

  final int id;
  final String displayId;
  final String sellerName;
  final String statusLabel;
  final String statusNote;
  final double totalAmount;
  final String paymentMethod;
  final int? paymentId;
  final String deliveryAddress;
  final String? trackingCode;
  final String? failureReason;
  final bool canConfirmReceipt;
  final List<BuyerOrderItemData> items;
  final List<BuyerOrderMilestone> timeline;

  factory BuyerOrderData.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final rawTimeline = json['timeline'];
    return BuyerOrderData(
      id: (num.tryParse(json['id'].toString()) ?? 0).toInt(),
      displayId: json['display_id']?.toString() ?? '',
      sellerName: json['seller_name']?.toString() ?? 'ShopHop Seller',
      statusLabel: json['status_label']?.toString() ?? 'Placed',
      statusNote: json['status_note']?.toString() ?? '',
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
      paymentMethod: json['payment_method']?.toString() ?? 'cod',
      paymentId: json['payment_id'] == null ? null : int.tryParse(json['payment_id'].toString()),
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      trackingCode: json['tracking_code']?.toString(),
      failureReason: json['failure_reason']?.toString(),
      canConfirmReceipt: json['can_confirm_receipt'] == true,
      items: rawItems is List
          ? rawItems.whereType<Map>().map((item) => BuyerOrderItemData.fromJson(Map<String, dynamic>.from(item))).toList()
          : const [],
      timeline: rawTimeline is List
          ? rawTimeline.whereType<Map>().map((item) => BuyerOrderMilestone.fromJson(Map<String, dynamic>.from(item))).toList()
          : const [],
    );
  }
}

class BuyerOrderPageData {
  const BuyerOrderPageData({required this.orders, required this.hasMore});
  final List<BuyerOrderData> orders;
  final bool hasMore;
}

class BuyerOrderService {
  BuyerOrderService._();

  static Future<BuyerOrderPageData> list({required String token, int page = 1}) async {
    final data = await _request('/buyer/orders?page=$page', token: token);
    final orders = data['orders'];
    return BuyerOrderPageData(
      orders: orders is List
          ? orders.whereType<Map>().map((item) => BuyerOrderData.fromJson(Map<String, dynamic>.from(item))).toList()
          : const [],
      hasMore: data['has_more'] == true,
    );
  }

  static Future<void> confirmReceipt({required String token, required int orderId}) async {
    await _request('/buyer/orders/$orderId/confirm-receipt', token: token, post: true);
  }

  static Future<Map<String, dynamic>> _request(String path, {required String token, bool post = false}) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
      final response = post
          ? await http.post(url, headers: headers).timeout(const Duration(seconds: 15))
          : await http.get(url, headers: headers).timeout(const Duration(seconds: 15));
      Map<String, dynamic> result = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) result = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // A non-JSON error is reported with its HTTP status below.
      }
      if (response.statusCode < 200 || response.statusCode >= 300 || result['success'] != true) {
        final errors = result['errors'];
        final firstError = errors is Map && errors.isNotEmpty ? errors.values.first : null;
        final firstMessage = firstError is List && firstError.isNotEmpty ? firstError.first.toString() : null;
        throw BuyerOrderException(
          firstMessage ?? result['message']?.toString() ?? 'Could not load ShopHop orders.',
          statusCode: response.statusCode,
        );
      }
      final data = result['data'];
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } on BuyerOrderException {
      rethrow;
    } catch (_) {
      throw const BuyerOrderException('Connection unavailable. Please try again.');
    }
  }
}
