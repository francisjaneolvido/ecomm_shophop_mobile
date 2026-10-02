import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class BuyerCatalogException implements Exception {
  const BuyerCatalogException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401 || statusCode == 403;

  @override
  String toString() => message;
}

class BuyerHomeData {
  const BuyerHomeData({
    required this.categories,
    required this.trendingProducts,
    required this.recommendedProducts,
    required this.dealProducts,
    required this.newArrivals,
    required this.cartCount,
  });

  final List<BuyerCategoryData> categories;
  final List<BuyerProductData> trendingProducts;
  final List<BuyerProductData> recommendedProducts;
  final List<BuyerProductData> dealProducts;
  final List<BuyerProductData> newArrivals;
  final int cartCount;

  factory BuyerHomeData.fromJson(Map<String, dynamic> json) {
    return BuyerHomeData(
      categories: _mapList(json['categories'], BuyerCategoryData.fromJson),
      trendingProducts: _mapList(
        json['trending_products'],
        BuyerProductData.fromJson,
      ),
      recommendedProducts: _mapList(
        json['recommended_products'],
        BuyerProductData.fromJson,
      ),
      dealProducts: _mapList(json['deal_products'], BuyerProductData.fromJson),
      newArrivals: _mapList(json['new_arrivals'], BuyerProductData.fromJson),
      cartCount: _asInt(json['cart_count']),
    );
  }
}

class BuyerCategoryData {
  const BuyerCategoryData({
    required this.name,
    required this.slug,
    required this.folder,
    required this.icon,
    required this.subcategories,
    required this.images,
    required this.coverImage,
  });

  final String name;
  final String slug;
  final String folder;
  final String icon;
  final List<String> subcategories;
  final List<String> images;
  final String coverImage;

  factory BuyerCategoryData.fromJson(Map<String, dynamic> json) {
    final rawImages = _stringList(json['images'])
        .map(ApiConfig.resolveMediaUrl)
        .where((url) => url.isNotEmpty)
        .toList(growable: false);

    return BuyerCategoryData(
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      folder: json['folder']?.toString() ?? '',
      icon: json['icon']?.toString() ?? '',
      subcategories: _stringList(json['subcategories']),
      images: rawImages,
      coverImage: ApiConfig.resolveMediaUrl(json['cover_image']?.toString()),
    );
  }
}

class BuyerProductData {
  const BuyerProductData({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.originalPrice,
    required this.discountPercent,
    required this.stock,
    required this.image,
    required this.rating,
    required this.reviews,
    required this.sold,
    required this.hasVariants,
    required this.isLiked,
    required this.isAvailable,
    required this.seller,
  });

  final int id;
  final String name;
  final String category;
  final double price;
  final double? originalPrice;
  final int discountPercent;
  final int stock;
  final String image;
  final double rating;
  final int reviews;
  final int sold;
  final bool hasVariants;
  final bool isLiked;
  final bool isAvailable;
  final BuyerProductSellerData seller;

  factory BuyerProductData.fromJson(Map<String, dynamic> json) {
    final sellerJson = json['seller'] is Map
        ? Map<String, dynamic>.from(json['seller'] as Map)
        : <String, dynamic>{};

    return BuyerProductData(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? 'ShopHop Product',
      category: json['category']?.toString() ?? '',
      price: _asDouble(json['price']),
      originalPrice: json['original_price'] == null
          ? null
          : _asDouble(json['original_price']),
      discountPercent: _asInt(json['discount_percent']),
      stock: _asInt(json['stock']),
      image: ApiConfig.resolveMediaUrl(json['image']?.toString()),
      rating: _asDouble(json['rating']),
      reviews: _asInt(json['reviews']),
      sold: _asInt(json['sold']),
      hasVariants: json['has_variants'] == true,
      isLiked: json['is_liked'] == true,
      isAvailable: json['is_available'] == null
          ? _asInt(json['stock']) > 0
          : json['is_available'] == true,
      seller: BuyerProductSellerData.fromJson(sellerJson),
    );
  }

  BuyerProductData copyWith({
    bool? isLiked,
    bool? isAvailable,
  }) {
    return BuyerProductData(
      id: id,
      name: name,
      category: category,
      price: price,
      originalPrice: originalPrice,
      discountPercent: discountPercent,
      stock: stock,
      image: image,
      rating: rating,
      reviews: reviews,
      sold: sold,
      hasVariants: hasVariants,
      isLiked: isLiked ?? this.isLiked,
      isAvailable: isAvailable ?? this.isAvailable,
      seller: seller,
    );
  }
}

class BuyerProductSellerData {
  const BuyerProductSellerData({
    required this.id,
    required this.businessName,
    required this.municipality,
  });

  final int? id;
  final String businessName;
  final String municipality;

  factory BuyerProductSellerData.fromJson(Map<String, dynamic> json) {
    return BuyerProductSellerData(
      id: json['id'] == null ? null : _asInt(json['id']),
      businessName: json['business_name']?.toString() ?? 'ShopHop Seller',
      municipality: json['municipality']?.toString() ?? '',
    );
  }
}

class BuyerLikesData {
  const BuyerLikesData({
    required this.items,
    required this.count,
  });

  final List<BuyerProductData> items;
  final int count;

  factory BuyerLikesData.fromJson(Map<String, dynamic> json) {
    return BuyerLikesData(
      items: _mapList(json['items'], BuyerProductData.fromJson),
      count: _asInt(json['count']),
    );
  }
}

class BuyerProductListData {
  const BuyerProductListData({
    required this.items,
    required this.pagination,
  });

  final List<BuyerProductData> items;
  final BuyerPaginationData pagination;

  factory BuyerProductListData.fromJson(Map<String, dynamic> json) {
    final paginationJson = json['pagination'] is Map
        ? Map<String, dynamic>.from(json['pagination'] as Map)
        : <String, dynamic>{};

    return BuyerProductListData(
      items: _mapList(json['items'], BuyerProductData.fromJson),
      pagination: BuyerPaginationData.fromJson(paginationJson),
    );
  }
}

class BuyerPaginationData {
  const BuyerPaginationData({
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
    required this.hasMore,
  });

  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;
  final bool hasMore;

  factory BuyerPaginationData.fromJson(Map<String, dynamic> json) {
    return BuyerPaginationData(
      currentPage: _asInt(json['current_page']).clamp(1, 1 << 30).toInt(),
      lastPage: _asInt(json['last_page']).clamp(1, 1 << 30).toInt(),
      perPage: _asInt(json['per_page']),
      total: _asInt(json['total']),
      hasMore: json['has_more'] == true,
    );
  }
}

class BuyerProductDetailData {
  const BuyerProductDetailData({
    required this.product,
    required this.description,
    required this.gallery,
    required this.variants,
    required this.vouchers,
    required this.reviews,
    required this.ratingBreakdown,
    required this.seller,
    required this.relatedProducts,
  });

  final BuyerProductData product;
  final String description;
  final List<String> gallery;
  final List<BuyerVariantData> variants;
  final List<BuyerVoucherData> vouchers;
  final List<BuyerReviewData> reviews;
  final Map<int, int> ratingBreakdown;
  final BuyerSellerDetailData seller;
  final List<BuyerProductData> relatedProducts;

  factory BuyerProductDetailData.fromJson(Map<String, dynamic> json) {
    final sellerJson = json['seller'] is Map
        ? Map<String, dynamic>.from(json['seller'] as Map)
        : <String, dynamic>{};

    final breakdown = <int, int>{};
    if (json['rating_breakdown'] is Map) {
      final raw = Map<dynamic, dynamic>.from(json['rating_breakdown'] as Map);
      for (var stars = 1; stars <= 5; stars++) {
        breakdown[stars] = _asInt(raw[stars] ?? raw['$stars']);
      }
    }

    return BuyerProductDetailData(
      product: BuyerProductData.fromJson(json),
      description: json['description']?.toString().trim() ?? '',
      gallery: _stringList(json['gallery'])
          .map(ApiConfig.resolveMediaUrl)
          .where((url) => url.isNotEmpty)
          .toList(growable: false),
      variants: _mapList(json['variants'], BuyerVariantData.fromJson),
      vouchers: _mapList(json['vouchers'], BuyerVoucherData.fromJson),
      reviews: _mapList(json['reviews_data'], BuyerReviewData.fromJson),
      ratingBreakdown: breakdown,
      seller: BuyerSellerDetailData.fromJson(sellerJson),
      relatedProducts: _mapList(
        json['related_products'],
        BuyerProductData.fromJson,
      ),
    );
  }
}

class BuyerVariantData {
  const BuyerVariantData({
    required this.id,
    required this.name,
    required this.label,
    required this.attributes,
    required this.price,
    required this.stock,
    required this.status,
    required this.inStock,
  });

  final int id;
  final String name;
  final String label;
  final Map<String, dynamic> attributes;
  final double? price;
  final int stock;
  final String status;
  final bool inStock;

  factory BuyerVariantData.fromJson(Map<String, dynamic> json) {
    return BuyerVariantData(
      id: _asInt(json['id']),
      name: json['name']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      attributes: json['attributes'] is Map
          ? Map<String, dynamic>.from(json['attributes'] as Map)
          : <String, dynamic>{},
      price: json['price'] == null ? null : _asDouble(json['price']),
      stock: _asInt(json['stock']),
      status: json['status']?.toString() ?? '',
      inStock: json['in_stock'] == true,
    );
  }
}

class BuyerVoucherData {
  const BuyerVoucherData({
    required this.id,
    required this.code,
    required this.label,
    required this.minOrderAmount,
  });

  final int id;
  final String code;
  final String label;
  final double minOrderAmount;

  factory BuyerVoucherData.fromJson(Map<String, dynamic> json) {
    return BuyerVoucherData(
      id: _asInt(json['id']),
      code: json['code']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      minOrderAmount: _asDouble(json['min_order_amount']),
    );
  }
}

class BuyerReviewData {
  const BuyerReviewData({
    required this.id,
    required this.buyerName,
    required this.rating,
    required this.variant,
    required this.date,
    required this.comment,
    required this.image,
    required this.helpful,
  });

  final int id;
  final String buyerName;
  final int rating;
  final String variant;
  final String date;
  final String comment;
  final String image;
  final int helpful;

  factory BuyerReviewData.fromJson(Map<String, dynamic> json) {
    return BuyerReviewData(
      id: _asInt(json['id']),
      buyerName: json['buyer_name']?.toString() ?? 'ShopHop Buyer',
      rating: _asInt(json['rating']),
      variant: json['variant']?.toString() ?? '—',
      date: json['date']?.toString() ?? '',
      comment: json['comment']?.toString().trim() ?? '',
      image: ApiConfig.resolveMediaUrl(json['image']?.toString()),
      helpful: _asInt(json['helpful']),
    );
  }
}

class BuyerSellerDetailData {
  const BuyerSellerDetailData({
    required this.id,
    required this.userId,
    required this.businessName,
    required this.municipality,
    required this.joined,
    required this.productsCount,
  });

  final int? id;
  final int? userId;
  final String businessName;
  final String municipality;
  final String joined;
  final int productsCount;

  factory BuyerSellerDetailData.fromJson(Map<String, dynamic> json) {
    return BuyerSellerDetailData(
      id: json['id'] == null ? null : _asInt(json['id']),
      userId: json['user_id'] == null ? null : _asInt(json['user_id']),
      businessName: json['business_name']?.toString() ?? 'ShopHop Seller',
      municipality: json['municipality']?.toString() ?? '',
      joined: json['joined']?.toString() ?? '',
      productsCount: _asInt(json['products_count']),
    );
  }
}

class BuyerCatalogService {
  BuyerCatalogService._();

  static Future<BuyerHomeData> getHome({
    required String token,
  }) async {
    final body = await _get('/buyer/home', token: token);
    final data = _requireDataMap(body, 'Buyer Home');
    return BuyerHomeData.fromJson(data);
  }

  static Future<List<BuyerCategoryData>> getCategories({
    required String token,
  }) async {
    final body = await _get('/buyer/categories', token: token);
    return _mapList(body['data'], BuyerCategoryData.fromJson);
  }

  static Future<BuyerProductListData> getProducts({
    required String token,
    String? query,
    String? category,
    String sort = 'popular',
    int page = 1,
    int perPage = 20,
  }) async {
    final body = await _get(
      '/buyer/products',
      token: token,
      queryParameters: {
        if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
        if (category != null && category.trim().isNotEmpty)
          'category': category.trim(),
        'sort': sort,
        'page': '$page',
        'per_page': '$perPage',
      },
    );

    final data = _requireDataMap(body, 'product list');
    return BuyerProductListData.fromJson(data);
  }

  static Future<BuyerProductDetailData> getProduct({
    required String token,
    required int productId,
  }) async {
    final body = await _get('/buyer/products/$productId', token: token);
    final data = _requireDataMap(body, 'product');
    return BuyerProductDetailData.fromJson(data);
  }

  static Future<BuyerLikesData> getLikes({
    required String token,
  }) async {
    final body = await _get('/buyer/likes', token: token);
    final data = _requireDataMap(body, 'likes');
    return BuyerLikesData.fromJson(data);
  }

  static Future<bool> setFavorite({
    required String token,
    required int productId,
    required bool liked,
  }) async {
    final body = await _request(
      '/buyer/likes/$productId',
      token: token,
      method: liked ? 'POST' : 'DELETE',
    );
    final data = _requireDataMap(body, 'favorite');
    return data['is_liked'] == true;
  }

  static Future<Map<String, dynamic>> _get(
    String path, {
    required String token,
    Map<String, String>? queryParameters,
  }) {
    return _request(
      path,
      token: token,
      method: 'GET',
      queryParameters: queryParameters,
    );
  }

  static Future<Map<String, dynamic>> _request(
    String path, {
    required String token,
    required String method,
    Map<String, String>? queryParameters,
  }) async {
    try {
      final baseUri = Uri.parse('${ApiConfig.baseUrl}$path');
      final uri = queryParameters == null || queryParameters.isEmpty
          ? baseUri
          : baseUri.replace(queryParameters: queryParameters);

      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final http.Response response;
      switch (method) {
        case 'POST':
          response = await http
              .post(uri, headers: headers)
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

      Map<String, dynamic> body = <String, dynamic>{};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) {
          body = Map<String, dynamic>.from(decoded);
        }
      } catch (_) {
        // The status-based fallback below is more useful than a JSON error.
      }

      final successful = response.statusCode >= 200 && response.statusCode < 300;
      if (!successful || body['success'] == false) {
        throw BuyerCatalogException(
          body['message']?.toString() ?? _statusMessage(response.statusCode),
          statusCode: response.statusCode,
        );
      }

      return body;
    } on BuyerCatalogException {
      rethrow;
    } catch (_) {
      throw const BuyerCatalogException(
        'Unable to load ShopHop right now. Check that the Laravel server is running and that this device can reach it.',
      );
    }
  }

  static Map<String, dynamic> _requireDataMap(
    Map<String, dynamic> body,
    String label,
  ) {
    final data = body['data'];
    if (data is! Map) {
      throw BuyerCatalogException(
        'ShopHop returned an invalid $label response.',
      );
    }
    return Map<String, dynamic>.from(data);
  }

  static String _statusMessage(int statusCode) {
    if (statusCode == 401) {
      return 'Your ShopHop session has expired. Please sign in again.';
    }
    if (statusCode == 403) {
      return 'This Buyer account cannot access the catalog yet.';
    }
    if (statusCode == 404) {
      return 'This product is no longer available.';
    }
    if (statusCode == 422) {
      return 'ShopHop could not apply that search or filter.';
    }
    if (statusCode >= 500) {
      return 'ShopHop server encountered an error while loading the catalog.';
    }
    return 'Unable to load the ShopHop catalog.';
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

List<String> _stringList(dynamic value) {
  if (value is! List) {
    return <String>[];
  }

  return value
      .map((item) => item?.toString().trim() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

int _asInt(dynamic value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.toInt();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  return double.tryParse(value?.toString() ?? '') ?? 0;
}
