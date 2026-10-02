import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class BuyerCheckoutException implements Exception {
  const BuyerCheckoutException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class BuyerCheckoutAddressData {
  const BuyerCheckoutAddressData({
    required this.name,
    required this.phone,
    required this.line,
    required this.city,
    required this.isDefault,
    required this.verified,
    required this.complete,
  });

  final String name;
  final String phone;
  final String line;
  final String city;
  final bool isDefault;
  final bool verified;
  final bool complete;

  factory BuyerCheckoutAddressData.fromJson(Map<String, dynamic> json) {
    return BuyerCheckoutAddressData(
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      line: json['line']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      isDefault: json['is_default'] == true,
      verified: json['verified'] == true,
      complete: json['complete'] == true,
    );
  }
}

class BuyerCheckoutItemData {
  const BuyerCheckoutItemData({
    required this.lineKey,
    required this.productId,
    required this.variant,
    required this.name,
    required this.image,
    required this.price,
    required this.originalPrice,
    required this.quantity,
    required this.stock,
    required this.lineTotal,
  });

  final String lineKey;
  final int productId;
  final String variant;
  final String name;
  final String image;
  final double price;
  final double? originalPrice;
  final int quantity;
  final int stock;
  final double lineTotal;

  factory BuyerCheckoutItemData.fromJson(Map<String, dynamic> json) {
    return BuyerCheckoutItemData(
      lineKey: (json['line_key'] ?? json['id'])?.toString() ?? '',
      productId: _asInt(json['product_id']),
      variant: json['variant']?.toString() ?? 'Standard',
      name: json['name']?.toString() ?? 'ShopHop Product',
      image: ApiConfig.resolveMediaUrl(json['image']?.toString()),
      price: _asDouble(json['price']),
      originalPrice: json['original_price'] == null
          ? null
          : _asDouble(json['original_price']),
      quantity: _asInt(json['qty']),
      stock: _asInt(json['stock']),
      lineTotal: _asDouble(json['line_total']),
    );
  }
}

class BuyerCheckoutGroupData {
  const BuyerCheckoutGroupData({
    required this.sellerId,
    required this.shopName,
    required this.municipality,
    required this.shippingFeeStandard,
    required this.shippingFeeExpress,
    required this.selectedShippingMethod,
    required this.items,
    required this.merchandiseSubtotal,
    required this.shippingFee,
    required this.codFee,
    required this.voucherDiscount,
    required this.groupTotal,
  });

  final int sellerId;
  final String shopName;
  final String municipality;
  final double shippingFeeStandard;
  final double shippingFeeExpress;
  final String selectedShippingMethod;
  final List<BuyerCheckoutItemData> items;
  final double merchandiseSubtotal;
  final double shippingFee;
  final double codFee;
  final double voucherDiscount;
  final double groupTotal;

  factory BuyerCheckoutGroupData.fromJson(Map<String, dynamic> json) {
    final shop = json['shop'] is Map
        ? Map<String, dynamic>.from(json['shop'] as Map)
        : <String, dynamic>{};

    return BuyerCheckoutGroupData(
      sellerId: _asInt(shop['id']),
      shopName: shop['name']?.toString() ?? 'ShopHop Seller',
      municipality: shop['municipality']?.toString() ?? '',
      shippingFeeStandard: _asDouble(json['shipping_fee_standard']),
      shippingFeeExpress: _asDouble(json['shipping_fee_express']),
      selectedShippingMethod:
          json['selected_shipping_method']?.toString() ?? 'standard',
      items: _mapList(json['items'], BuyerCheckoutItemData.fromJson),
      merchandiseSubtotal: _asDouble(json['merchandise_subtotal']),
      shippingFee: _asDouble(json['shipping_fee']),
      codFee: _asDouble(json['cod_fee']),
      voucherDiscount: _asDouble(json['voucher_discount']),
      groupTotal: _asDouble(json['group_total']),
    );
  }
}

class BuyerCheckoutVoucherData {
  const BuyerCheckoutVoucherData({
    required this.code,
    required this.title,
    required this.description,
    required this.type,
    required this.value,
    required this.minSpend,
    required this.sellerId,
    required this.productIds,
  });

  final String code;
  final String title;
  final String description;
  final String type;
  final double value;
  final double minSpend;
  final int? sellerId;
  final List<int> productIds;

  factory BuyerCheckoutVoucherData.fromJson(Map<String, dynamic> json) {
    return BuyerCheckoutVoucherData(
      code: json['code']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      value: _asDouble(json['value']),
      minSpend: _asDouble(json['min_spend']),
      sellerId: json['seller_id'] == null ? null : _asInt(json['seller_id']),
      productIds: json['product_ids'] is List
          ? (json['product_ids'] as List)
              .map(_asInt)
              .where((id) => id > 0)
              .toList(growable: false)
          : const <int>[],
    );
  }
}

class BuyerCheckoutSummaryData {
  const BuyerCheckoutSummaryData({
    required this.merchandiseSubtotal,
    required this.shippingFee,
    required this.codFee,
    required this.voucherDiscount,
    required this.grandTotal,
  });

  final double merchandiseSubtotal;
  final double shippingFee;
  final double codFee;
  final double voucherDiscount;
  final double grandTotal;

  factory BuyerCheckoutSummaryData.fromJson(Map<String, dynamic> json) {
    return BuyerCheckoutSummaryData(
      merchandiseSubtotal: _asDouble(json['merchandise_subtotal']),
      shippingFee: _asDouble(json['shipping_fee']),
      codFee: _asDouble(json['cod_fee']),
      voucherDiscount: _asDouble(json['voucher_discount']),
      grandTotal: _asDouble(json['grand_total']),
    );
  }
}

class BuyerCheckoutPreviewData {
  const BuyerCheckoutPreviewData({
    required this.address,
    required this.groups,
    required this.vouchers,
    required this.initialVoucherCode,
    required this.itemCount,
    required this.quantityCount,
    required this.shopCount,
    required this.paymentMethod,
    required this.summary,
  });

  final BuyerCheckoutAddressData address;
  final List<BuyerCheckoutGroupData> groups;
  final List<BuyerCheckoutVoucherData> vouchers;
  final String initialVoucherCode;
  final int itemCount;
  final int quantityCount;
  final int shopCount;
  final String paymentMethod;
  final BuyerCheckoutSummaryData summary;

  factory BuyerCheckoutPreviewData.fromJson(Map<String, dynamic> json) {
    final address = json['address'] is Map
        ? Map<String, dynamic>.from(json['address'] as Map)
        : <String, dynamic>{};
    final summary = json['summary'] is Map
        ? Map<String, dynamic>.from(json['summary'] as Map)
        : <String, dynamic>{};

    return BuyerCheckoutPreviewData(
      address: BuyerCheckoutAddressData.fromJson(address),
      groups: _mapList(json['cart_groups'], BuyerCheckoutGroupData.fromJson),
      vouchers: _mapList(
        json['available_vouchers'],
        BuyerCheckoutVoucherData.fromJson,
      ),
      initialVoucherCode: json['initial_voucher_code']?.toString() ?? '',
      itemCount: _asInt(json['item_count']),
      quantityCount: _asInt(json['quantity_count']),
      shopCount: _asInt(json['shop_count']),
      paymentMethod: json['payment_method']?.toString() ?? 'cod',
      summary: BuyerCheckoutSummaryData.fromJson(summary),
    );
  }
}

class BuyerCheckoutPlaceResult {
  const BuyerCheckoutPlaceResult({
    required this.checkoutGroupId,
    required this.orderIds,
    required this.paymentId,
    required this.paymentMethod,
    required this.grandTotal,
    required this.cartCount,
    required this.message,
  });

  final String checkoutGroupId;
  final List<int> orderIds;
  final int? paymentId;
  final String paymentMethod;
  final double grandTotal;
  final int cartCount;
  final String message;

  factory BuyerCheckoutPlaceResult.fromJson(
    Map<String, dynamic> json,
    String message,
  ) {
    return BuyerCheckoutPlaceResult(
      checkoutGroupId: json['checkout_group_id']?.toString() ?? '',
      orderIds: json['order_ids'] is List
          ? (json['order_ids'] as List)
              .map(_asInt)
              .where((id) => id > 0)
              .toList(growable: false)
          : const <int>[],
      paymentId: json['payment_id'] == null ? null : _asInt(json['payment_id']),
      paymentMethod: json['payment_method']?.toString() ?? 'cod',
      grandTotal: _asDouble(json['grand_total']),
      cartCount: _asInt(json['cart_count']),
      message: message,
    );
  }
}

class BuyerPaymentOrderData {
  const BuyerPaymentOrderData({
    required this.id,
    required this.sellerName,
    required this.totalAmount,
    required this.status,
    required this.statusLabel,
  });

  final int id;
  final String sellerName;
  final double totalAmount;
  final String status;
  final String statusLabel;

  factory BuyerPaymentOrderData.fromJson(Map<String, dynamic> json) {
    return BuyerPaymentOrderData(
      id: _asInt(json['id']),
      sellerName: json['seller_name']?.toString() ?? 'ShopHop Seller',
      totalAmount: _asDouble(json['total_amount']),
      status: json['status']?.toString() ?? '',
      statusLabel: json['status_label']?.toString() ?? '',
    );
  }
}

class BuyerPaymentData {
  const BuyerPaymentData({
    required this.id,
    required this.status,
    required this.reference,
    required this.expectedAmount,
    required this.expiresAt,
    required this.submittedAt,
    required this.reviewedAt,
    required this.rejectionReason,
    required this.closureReason,
    required this.canSubmit,
    required this.canCancel,
    required this.orders,
  });

  final int id;
  final String status;
  final String reference;
  final double expectedAmount;
  final DateTime? expiresAt;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String rejectionReason;
  final String closureReason;
  final bool canSubmit;
  final bool canCancel;
  final List<BuyerPaymentOrderData> orders;

  factory BuyerPaymentData.fromJson(Map<String, dynamic> json) {
    return BuyerPaymentData(
      id: _asInt(json['id']),
      status: json['status']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      expectedAmount: _asDouble(json['expected_amount']),
      expiresAt: _asDateTime(json['expires_at']),
      submittedAt: _asDateTime(json['submitted_at']),
      reviewedAt: _asDateTime(json['reviewed_at']),
      rejectionReason: json['rejection_reason']?.toString() ?? '',
      closureReason: json['closure_reason']?.toString() ?? '',
      canSubmit: json['can_submit'] == true,
      canCancel: json['can_cancel'] == true,
      orders: _mapList(json['orders'], BuyerPaymentOrderData.fromJson),
    );
  }
}

class BuyerCheckoutService {
  BuyerCheckoutService._();

  static Future<BuyerCheckoutPreviewData> preview({
    required String token,
    required Map<String, int> items,
    Map<int, String> shippingMethods = const <int, String>{},
    String paymentMethod = 'cod',
    String voucherCode = '',
  }) async {
    final body = await _request(
      '/buyer/checkout/preview',
      token: token,
      method: 'POST',
      body: _checkoutPayload(
        items: items,
        shippingMethods: shippingMethods,
        paymentMethod: paymentMethod,
        voucherCode: voucherCode,
      ),
    );

    return BuyerCheckoutPreviewData.fromJson(
      _requireDataMap(body, 'checkout preview'),
    );
  }

  static Future<BuyerCheckoutPlaceResult> placeOrder({
    required String token,
    required Map<String, int> items,
    required Map<int, String> shippingMethods,
    required String paymentMethod,
    String voucherCode = '',
    Map<int, String> notes = const <int, String>{},
  }) async {
    final payload = _checkoutPayload(
      items: items,
      shippingMethods: shippingMethods,
      paymentMethod: paymentMethod,
      voucherCode: voucherCode,
    );
    payload['groups'] = {
      for (final entry in notes.entries)
        entry.key.toString(): {'note': entry.value.trim()},
    };

    final body = await _request(
      '/buyer/checkout/place-order',
      token: token,
      method: 'POST',
      body: payload,
    );

    return BuyerCheckoutPlaceResult.fromJson(
      _requireDataMap(body, 'checkout result'),
      body['message']?.toString() ?? 'Order placed successfully.',
    );
  }

  static Future<BuyerPaymentData> getPayment({
    required String token,
    required int paymentId,
  }) async {
    final body = await _request(
      '/buyer/payments/$paymentId',
      token: token,
      method: 'GET',
    );
    return BuyerPaymentData.fromJson(_requireDataMap(body, 'payment'));
  }

  static Future<void> submitPaymentProof({
    required String token,
    required int paymentId,
    required String reference,
    required List<int> receiptBytes,
    required String receiptFileName,
  }) async {
    final uri = Uri.parse('${ApiConfig.baseUrl}/buyer/payments/$paymentId/submit');
    final request = http.MultipartRequest('POST', uri)
      ..headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      })
      ..fields['reference'] = reference.trim()
      ..files.add(
        http.MultipartFile.fromBytes(
          'receipt',
          receiptBytes,
          filename: receiptFileName,
        ),
      );

    try {
      final streamed = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamed);
      final decoded = _decode(response.body);
      final successful = response.statusCode >= 200 && response.statusCode < 300;
      if (!successful || decoded['success'] == false) {
        throw BuyerCheckoutException(
          _messageFromResponse(decoded, response.statusCode),
          statusCode: response.statusCode,
        );
      }
    } on BuyerCheckoutException {
      rethrow;
    } catch (_) {
      throw const BuyerCheckoutException(
        'Unable to submit payment proof right now. Check your connection and Laravel server.',
      );
    }
  }

  static Future<void> cancelPayment({
    required String token,
    required int paymentId,
  }) async {
    await _request(
      '/buyer/payments/$paymentId/cancel',
      token: token,
      method: 'POST',
    );
  }

  static Map<String, dynamic> _checkoutPayload({
    required Map<String, int> items,
    required Map<int, String> shippingMethods,
    required String paymentMethod,
    required String voucherCode,
  }) {
    return <String, dynamic>{
      'items': {
        for (final entry in items.entries)
          entry.key: {'quantity': entry.value},
      },
      'shipping_method': {
        for (final entry in shippingMethods.entries)
          entry.key.toString(): entry.value,
      },
      'payment_method': paymentMethod,
      'voucher_code': voucherCode.trim(),
    };
  }

  static Future<Map<String, dynamic>> _request(
    String path, {
    required String token,
    required String method,
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$path');
      final headers = <String, String>{
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
        if (body != null) 'Content-Type': 'application/json',
      };
      final encodedBody = body == null ? null : jsonEncode(body);

      final http.Response response;
      switch (method) {
        case 'POST':
          response = await http
              .post(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 20));
          break;
        default:
          response = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 20));
      }

      final decoded = _decode(response.body);
      final successful = response.statusCode >= 200 && response.statusCode < 300;
      if (!successful || decoded['success'] == false) {
        throw BuyerCheckoutException(
          _messageFromResponse(decoded, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      return decoded;
    } on BuyerCheckoutException {
      rethrow;
    } catch (_) {
      throw const BuyerCheckoutException(
        'Unable to reach ShopHop checkout right now. Check that the Laravel server is running and reachable.',
      );
    }
  }

  static Map<String, dynamic> _decode(String body) {
    try {
      final raw = jsonDecode(body);
      if (raw is Map) {
        return Map<String, dynamic>.from(raw);
      }
    } catch (_) {
      // Status-based fallback is handled by the caller.
    }
    return <String, dynamic>{};
  }

  static Map<String, dynamic> _requireDataMap(
    Map<String, dynamic> body,
    String label,
  ) {
    final data = body['data'];
    if (data is! Map) {
      throw BuyerCheckoutException('ShopHop returned an invalid $label response.');
    }
    return Map<String, dynamic>.from(data);
  }

  static String _messageFromResponse(
    Map<String, dynamic> body,
    int statusCode,
  ) {
    final errors = body['errors'];
    if (errors is Map) {
      for (final value in errors.values) {
        if (value is List && value.isNotEmpty) {
          return value.first.toString();
        }
        if (value != null) {
          return value.toString();
        }
      }
    }

    final message = body['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;

    if (statusCode == 401) {
      return 'Your ShopHop session has expired. Please sign in again.';
    }
    if (statusCode == 403) {
      return 'This Buyer account cannot use checkout yet.';
    }
    if (statusCode == 404) {
      return 'This checkout or payment record could not be found.';
    }
    if (statusCode == 422) {
      return 'Please review your checkout details and try again.';
    }
    if (statusCode >= 500) {
      return 'ShopHop server encountered an error while processing checkout.';
    }
    return 'Unable to process checkout.';
  }
}

List<T> _mapList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) parser,
) {
  if (value is! List) return <T>[];
  return value
      .whereType<Map>()
      .map((item) => parser(Map<String, dynamic>.from(item)))
      .toList(growable: false);
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime? _asDateTime(dynamic value) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return null;
  return DateTime.tryParse(raw)?.toLocal();
}
