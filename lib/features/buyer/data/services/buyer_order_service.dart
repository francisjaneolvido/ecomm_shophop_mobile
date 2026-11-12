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
  const BuyerOrderItemData({
    required this.name,
    required this.variant,
    required this.quantity,
    required this.price,
    this.image,
    this.id = 0,
    this.canRate = false,
    this.rating,
  });
  final String name;
  final String variant;
  final int quantity;
  final double price;
  final String? image;
  final int id;
  final bool canRate;
  final int? rating;

  factory BuyerOrderItemData.fromJson(Map<String, dynamic> json) =>
      BuyerOrderItemData(
        name: json['name']?.toString() ?? 'Product',
        variant: json['variant']?.toString() ?? 'Standard',
        quantity: (num.tryParse(json['quantity'].toString()) ?? 0).toInt(),
        price: double.tryParse(json['price'].toString()) ?? 0,
        image: json['image']?.toString(),
        id: int.tryParse(json['id'].toString()) ?? 0,
        canRate: json['can_rate'] == true,
        rating: int.tryParse(json['rating'].toString()),
      );
}

class BuyerOrderMilestone {
  const BuyerOrderMilestone({required this.label, required this.at});
  final String label;
  final String at;
  factory BuyerOrderMilestone.fromJson(Map<String, dynamic> json) =>
      BuyerOrderMilestone(
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
    required this.deliveryAddress,
    required this.trackingCode,
    required this.failureReason,
    required this.canConfirmReceipt,
    required this.items,
    required this.timeline,
    this.status = '',
  });

  final int id;
  final String displayId;
  final String sellerName;
  final String statusLabel;
  final String status;
  final String statusNote;
  final double totalAmount;
  final String paymentMethod;
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
      status: json['status']?.toString() ?? '',
      statusNote: json['status_note']?.toString() ?? '',
      totalAmount: double.tryParse(json['total_amount'].toString()) ?? 0,
      paymentMethod: json['payment_method']?.toString() ?? 'cod',
      deliveryAddress: json['delivery_address']?.toString() ?? '',
      trackingCode: json['tracking_code']?.toString(),
      failureReason: json['failure_reason']?.toString(),
      canConfirmReceipt: json['can_confirm_receipt'] == true,
      items: rawItems is List
          ? rawItems
                .whereType<Map>()
                .map(
                  (item) => BuyerOrderItemData.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      timeline: rawTimeline is List
          ? rawTimeline
                .whereType<Map>()
                .map(
                  (item) => BuyerOrderMilestone.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class BuyerOrderPageData {
  const BuyerOrderPageData({
    required this.orders,
    required this.hasMore,
    this.statusCounts = const {},
  });
  final List<BuyerOrderData> orders;
  final bool hasMore;
  final Map<String, int> statusCounts;
}

class BuyerOrderService {
  BuyerOrderService._();

  static Future<BuyerOrderPageData> list({
    required String token,
    int page = 1,
    String? statusGroup,
  }) async {
    final query = Uri(
      queryParameters: {
        'page': '$page',
        if (statusGroup != null) 'status_group': statusGroup,
      },
    ).query;
    final data = await _request('/buyer/orders?$query', token: token);
    final orders = data['orders'];
    return BuyerOrderPageData(
      orders: orders is List
          ? orders
                .whereType<Map>()
                .map(
                  (item) =>
                      BuyerOrderData.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      hasMore: data['has_more'] == true,
      statusCounts: data['status_counts'] is Map
          ? (data['status_counts'] as Map).map(
              (key, value) =>
                  MapEntry(key.toString(), int.tryParse(value.toString()) ?? 0),
            )
          : const {},
    );
  }

  static Future<void> confirmReceipt({
    required String token,
    required int orderId,
  }) async {
    await _request(
      '/buyer/orders/$orderId/confirm-receipt',
      token: token,
      post: true,
    );
  }

  static Future<void> rateItem({
    required String token,
    required int orderId,
    required int itemId,
    required int rating,
    required String comment,
  }) async {
    await _request(
      '/buyer/orders/$orderId/items/$itemId/review',
      token: token,
      post: true,
      body: {'rating': rating, 'comment': comment.trim()},
    );
  }

  static Future<Map<String, dynamic>> _request(
    String path, {
    required String token,
    bool post = false,
    Map<String, dynamic>? body,
  }) async {
    try {
      final url = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      };
      final response = post
          ? await http
                .post(
                  url,
                  headers: headers,
                  body: body == null ? null : jsonEncode(body),
                )
                .timeout(const Duration(seconds: 15))
          : await http
                .get(url, headers: headers)
                .timeout(const Duration(seconds: 15));
      Map<String, dynamic> result = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) result = Map<String, dynamic>.from(decoded);
      } catch (_) {
        // A non-JSON error is reported with its HTTP status below.
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          result['success'] != true) {
        final errors = result['errors'];
        final firstError = errors is Map && errors.isNotEmpty
            ? errors.values.first
            : null;
        final firstMessage = firstError is List && firstError.isNotEmpty
            ? firstError.first.toString()
            : null;
        throw BuyerOrderException(
          firstMessage ??
              result['message']?.toString() ??
              'Could not load ShopHop orders.',
          statusCode: response.statusCode,
        );
      }
      final data = result['data'];
      return data is Map ? Map<String, dynamic>.from(data) : {};
    } on BuyerOrderException {
      rethrow;
    } catch (_) {
      throw const BuyerOrderException(
        'Connection unavailable. Please try again.',
      );
    }
  }
}
