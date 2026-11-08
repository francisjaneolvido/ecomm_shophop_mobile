import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

class RiderBatchService {
  static Future<AuthApiResult> _request(
    String token,
    String path, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/rider/batches$path');
      final headers = {
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      final response =
          await (body == null
                  ? http.get(uri, headers: headers)
                  : http.post(uri, headers: headers, body: jsonEncode(body)))
              .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message:
            'Cannot refresh rider batches. Check your connection and retry.',
      );
    }
  }

  // Refresh every loaded page so queued routes are not silently dropped.
  static Future<AuthApiResult> batches(
    String token, {
    int pages = 1,
    bool history = false,
  }) async {
    final rows = <dynamic>[];
    AuthApiResult? last;
    for (var page = 1; page <= pages; page++) {
      last = await _request(token, '?page=$page&history=${history ? 1 : 0}');
      if (!last.success) return last;
      final values = last.data['batches'];
      if (values is List) rows.addAll(values);
      if (last.data['next_page'] == null) break;
    }
    return AuthApiResult(
      success: true,
      status: 'ok',
      message: 'Batches refreshed.',
      data: {...?last?.data, 'batches': rows},
      statusCode: last?.statusCode,
    );
  }

  static Future<AuthApiResult> show(String token, int id) =>
      _request(token, '/$id');
  static Future<AuthApiResult> pickupFailure(
    String token,
    int batch,
    int item,
    String reason,
  ) => _request(
    token,
    '/$batch/items/$item/pickup-failure',
    body: {'reason': reason},
  );
}
