import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

class LogisticsScanService {
  const LogisticsScanService._();

  static Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<AuthApiResult> branches(String token) async {
    try {
      final response = await http
          .get(Uri.parse('${ApiConfig.baseUrl}/logistics/scanner/branches'),
              headers: _headers(token))
          .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(success: false, status: 'timeout', message: 'Request timed out. Try again.');
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error', message: 'Unable to contact ShopHop server.');
    }
  }

  /// Read-only preview. This is not a handoff; final confirmation revalidates the parcel.
  static Future<AuthApiResult> preview({
    required String token,
    required int branchId,
    required String trackingCode,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/logistics/scanner/preview')
          .replace(queryParameters: {
        'sorting_center_id': branchId.toString(),
        'tracking_code': trackingCode.trim(),
      });
      final response = await http.get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(success: false, status: 'timeout', message: 'Preview timed out. No parcel status was changed.');
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error', message: 'Cannot preview parcel. Check connection and try again.');
    }
  }

  static Future<AuthApiResult> history({
    required String token,
    required int branchId,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/logistics/scanner/history')
          .replace(queryParameters: {'sorting_center_id': branchId.toString()});
      final response = await http.get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(success: false, status: 'timeout', message: 'Could not load scan history.');
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error', message: 'Could not load scan history. Check connection.');
    }
  }

  static Future<AuthApiResult> receive({
    required String token,
    required int branchId,
    required String trackingCode,
  }) async {
    try {
      final response = await http
          .post(Uri.parse('${ApiConfig.baseUrl}/logistics/scanner/receive'),
              headers: {..._headers(token), 'Content-Type': 'application/json'},
              body: jsonEncode({'sorting_center_id': branchId, 'tracking_code': trackingCode.trim()}))
          .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(success: false, status: 'timeout', message: 'Request timed out. Refresh before scanning the parcel again.');
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error', message: 'Unable to contact ShopHop server. Check scan history before retrying.');
    }
  }

  static Future<AuthApiResult> manifests({
    required String token,
    required int branchId,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/logistics/scanner/manifests')
          .replace(queryParameters: {'sorting_center_id': branchId.toString()});
      final response = await http.get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(success: false, status: 'timeout', message: 'Could not load outbound manifests.');
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error', message: 'Could not load outbound manifests. Check connection.');
    }
  }

  static Future<AuthApiResult> loadPreview({
    required String token,
    required int branchId,
    required int manifestId,
    required String trackingCode,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/logistics/scanner/load-preview')
          .replace(queryParameters: {
        'sorting_center_id': branchId.toString(),
        'manifest_id': manifestId.toString(),
        'tracking_code': trackingCode.trim(),
      });
      final response = await http.get(uri, headers: _headers(token))
          .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(success: false, status: 'timeout', message: 'Loading verification timed out. No parcel was changed.');
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error', message: 'Unable to verify this parcel for loading.');
    }
  }

  static Future<AuthApiResult> loadParcel({
    required String token,
    required int branchId,
    required int manifestId,
    required String trackingCode,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/logistics/scanner/load'),
        headers: {..._headers(token), 'Content-Type': 'application/json'},
        body: jsonEncode({
          'sorting_center_id': branchId,
          'manifest_id': manifestId,
          'tracking_code': trackingCode.trim(),
        }),
      ).timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(success: false, status: 'timeout', message: 'Loading confirmation timed out. Refresh the manifest before retrying.');
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error', message: 'Unable to mark this parcel loaded.');
    }
  }

}
