import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

class RiderTransitService {
  const RiderTransitService._();
  static Map<String, String> headers(String token) => {
    'Accept': 'application/json', 'Authorization': 'Bearer $token',
  };

  static Future<AuthApiResult> tasks(String token) async => _get('/rider/transfers', token);
  static Future<AuthApiResult> earnings(String token) async => _get('/rider/earnings', token);

  static Future<AuthApiResult> depart(String token, int transferId) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/rider/transfers/$transferId/depart'),
        headers: {...headers(token), 'Content-Type': 'application/json'},
        body: jsonEncode({}),
      ).timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error', message: 'Cannot confirm departure. Refresh before retrying.');
    }
  }

  static Future<AuthApiResult> _get(String path, String token) async {
    try {
      final response = await http.get(Uri.parse('${ApiConfig.baseUrl}$path'),
        headers: headers(token)).timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(success: false, status: 'timeout', message: 'Connection timed out.');
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error', message: 'Cannot contact the ShopHop server.');
    }
  }
}
