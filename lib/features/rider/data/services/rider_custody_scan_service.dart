import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

class RiderCustodyScanService {
  const RiderCustodyScanService._();

  static Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<AuthApiResult> preview({
    required String token,
    required String trackingCode,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/rider/scanner/preview').replace(
        queryParameters: {'tracking_code': trackingCode.trim()},
      );
      final response = await http
          .get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(
        success: false,
        status: 'timeout',
        message: 'QR verification timed out. No custody status was changed.',
      );
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message: 'Unable to verify this parcel. Check your connection and try again.',
      );
    }
  }

  static Future<AuthApiResult> confirm({
    required String token,
    required String trackingCode,
    required String expectedAction,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/rider/scanner/confirm'),
            headers: {..._headers(token), 'Content-Type': 'application/json'},
            body: jsonEncode({
              'tracking_code': trackingCode.trim(),
              'expected_action': expectedAction,
            }),
          )
          .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(
        success: false,
        status: 'timeout',
        message:
            'Custody confirmation timed out. Refresh your Rider tasks before scanning again.',
      );
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message:
            'Unable to confirm custody. Check your connection and refresh tasks before retrying.',
      );
    }
  }
}
