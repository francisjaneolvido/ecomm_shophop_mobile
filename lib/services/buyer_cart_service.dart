import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class BuyerCartException implements Exception {
  const BuyerCartException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class BuyerCartData {
  const BuyerCartData({
    required this.groups,
    required this.vouchers,
    required this.cartCount,
    required this.quantityCount,
    required this.subtotal,
    required this.unavailableCount,
  });

  final List<BuyerCartGroupData> groups;
  final List<BuyerCartVoucherData> vouchers;
  final int cartCount;
  final int quantityCount;
  final double subtotal;
  final int unavailableCount;

  List<BuyerCartItemData> get items => groups
      .expand((group) => group.items)
      .toList(growable: false);

  factory BuyerCartData.fromJson(Map<String, dynamic> json) {
    return BuyerCartData(
      groups: _mapList(json['groups'], BuyerCartGroupData.fromJson),
      vouchers: _mapList(json['vouchers'], BuyerCartVoucherData.fromJson),
      cartCount: _asInt(json['cart_count']),
      quantityCount: _asInt(json['quantity_count']),
      subtotal: _asDouble(json['subtotal']),
      unavailableCount: _asInt(json['unavailable_count']),
    );
  }
}

class BuyerCartGroupData {
  const BuyerCartGroupData({
    required this.shop,
    required this.items,
  });

  final BuyerCartShopData shop;
  final List<BuyerCartItemData> items;

  factory BuyerCartGroupData.fromJson(Map<String, dynamic> json) {
    final shopJson = json['shop'] is Map
        ? Map<String, dynamic>.from(json['shop'] as Map)
        : <String, dynamic>{};

    return BuyerCartGroupData(
      shop: BuyerCartShopData.fromJson(shopJson),
      items: _mapList(json['items'], BuyerCartItemData.fromJson),
    );
  }
}

class BuyerCartShopData {
  const BuyerCartShopData({
    required this.id,
    required this.name,
    required this.municipality,
  });

  final int id;
  final String name;
  final String municipality;

  factory BuyerCartShopData.fromJson(Map<String, dynamic> json) {
    return BuyerCartShopData(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? 'ShopHop Seller',
      municipality: json['municipality']?.toString() ?? '',
    );
  }
}

class BuyerCartItemData {
  const BuyerCartItemData({
    required this.lineKey,
    required this.productId,
    required this.variantId,
    required this.variant,
    required this.name,
    required this.image,
    required this.price,
    required this.originalPrice,
    required this.quantity,
    required this.stock,
    required this.isAvailable,
    required this.lineTotal,
  });

  final String lineKey;
  final int productId;
  final int? variantId;
  final String variant;
  final String name;
  final String image;
  final double price;
  final double? originalPrice;
  final int quantity;
  final int stock;
  final bool isAvailable;
  final double lineTotal;

  factory BuyerCartItemData.fromJson(Map<String, dynamic> json) {
    return BuyerCartItemData(
      lineKey: json['line_key']?.toString() ?? '',
      productId: _asInt(json['product_id']),
      variantId: json['variant_id'] == null
          ? null
          : _asInt(json['variant_id']),
      variant: json['variant']?.toString() ?? 'Standard',
      name: json['name']?.toString() ?? 'ShopHop Product',
      image: ApiConfig.resolveMediaUrl(json['image']?.toString()),
      price: _asDouble(json['price']),
      originalPrice: json['original_price'] == null
          ? null
          : _asDouble(json['original_price']),
      quantity: _asInt(json['qty']),
      stock: _asInt(json['stock']),
      isAvailable: json['is_available'] == true,
      lineTotal: _asDouble(json['line_total']),
    );
  }
}

class BuyerCartVoucherData {
  const BuyerCartVoucherData({
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

  factory BuyerCartVoucherData.fromJson(Map<String, dynamic> json) {
    return BuyerCartVoucherData(
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

class BuyerCartMutationData {
  const BuyerCartMutationData({
    required this.cartCount,
    this.lineKey,
  });

  final int cartCount;
  final String? lineKey;

  factory BuyerCartMutationData.fromJson(Map<String, dynamic> json) {
    return BuyerCartMutationData(
      cartCount: _asInt(json['cart_count']),
      lineKey: json['line_key']?.toString(),
    );
  }
}

class BuyerCartService {
  BuyerCartService._();

  static Future<BuyerCartData> getCart({required String token}) async {
    final body = await _request(
      '/buyer/cart',
      token: token,
      method: 'GET',
    );
    return BuyerCartData.fromJson(_requireDataMap(body, 'cart'));
  }

  static Future<BuyerCartMutationData> addToCart({
    required String token,
    required int productId,
    int? variantId,
    int quantity = 1,
  }) async {
    final body = await _request(
      '/buyer/cart/add',
      token: token,
      method: 'POST',
      body: {
        'product_id': productId,
        if (variantId != null) 'variant_id': variantId,
        'qty': quantity,
      },
    );
    return BuyerCartMutationData.fromJson(_requireDataMap(body, 'cart update'));
  }

  static Future<BuyerCartMutationData> updateQuantity({
    required String token,
    required String lineKey,
    required int quantity,
  }) async {
    final body = await _request(
      '/buyer/cart/$lineKey',
      token: token,
      method: 'PATCH',
      body: {'qty': quantity},
    );
    return BuyerCartMutationData.fromJson(_requireDataMap(body, 'cart update'));
  }

  static Future<BuyerCartMutationData> remove({
    required String token,
    required String lineKey,
  }) async {
    final body = await _request(
      '/buyer/cart/$lineKey',
      token: token,
      method: 'DELETE',
    );
    return BuyerCartMutationData.fromJson(_requireDataMap(body, 'cart update'));
  }

  static Future<BuyerCartMutationData> removeMany({
    required String token,
    required List<String> lineKeys,
  }) async {
    final body = await _request(
      '/buyer/cart/remove-many',
      token: token,
      method: 'POST',
      body: {
        'keys': lineKeys.map((key) => int.tryParse(key) ?? 0).where((id) => id > 0).toList(),
      },
    );
    return BuyerCartMutationData.fromJson(_requireDataMap(body, 'cart update'));
  }

  static Future<int> getCount({required String token}) async {
    final body = await _request(
      '/buyer/cart/count',
      token: token,
      method: 'GET',
    );
    return _asInt(_requireDataMap(body, 'cart count')['cart_count']);
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
              .timeout(const Duration(seconds: 15));
          break;
        case 'PATCH':
          response = await http
              .patch(uri, headers: headers, body: encodedBody)
              .timeout(const Duration(seconds: 15));
          break;
        case 'DELETE':
          response = await http
              .delete(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
          break;
        default:
          response = await http
              .get(uri, headers: headers)
              .timeout(const Duration(seconds: 15));
      }

      Map<String, dynamic> decoded = <String, dynamic>{};
      try {
        final raw = jsonDecode(response.body);
        if (raw is Map) {
          decoded = Map<String, dynamic>.from(raw);
        }
      } catch (_) {
        // Use the status fallback below when Laravel did not return JSON.
      }

      final successful = response.statusCode >= 200 && response.statusCode < 300;
      if (!successful || decoded['success'] == false) {
        throw BuyerCartException(
          _messageFromResponse(decoded, response.statusCode),
          statusCode: response.statusCode,
        );
      }

      return decoded;
    } on BuyerCartException {
      rethrow;
    } catch (_) {
      throw const BuyerCartException(
        'Unable to update your cart right now. Check that the Laravel server is running and reachable.',
      );
    }
  }

  static Map<String, dynamic> _requireDataMap(
    Map<String, dynamic> body,
    String label,
  ) {
    final data = body['data'];
    if (data is! Map) {
      throw BuyerCartException('ShopHop returned an invalid $label response.');
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
    if (message != null && message.isNotEmpty) {
      return message;
    }

    if (statusCode == 401) {
      return 'Your ShopHop session has expired. Please sign in again.';
    }
    if (statusCode == 403) {
      return 'This Buyer account cannot use the cart yet.';
    }
    if (statusCode == 404) {
      return 'This cart item or product is no longer available.';
    }
    if (statusCode == 422) {
      return 'ShopHop could not apply that cart change.';
    }
    if (statusCode >= 500) {
      return 'ShopHop server encountered an error while updating your cart.';
    }
    return 'Unable to update your cart.';
  }
}

List<T> _mapList<T>(
  dynamic value,
  T Function(Map<String, dynamic>) parser,
) {
  if (value is! List) {
    return <T>[];
  }

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
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
