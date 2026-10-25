import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

class SellerEarningsService {
  const SellerEarningsService._();

  static Future<AuthApiResult> load(String token) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/seller/earnings'),
        headers: {'Accept': 'application/json', 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(success: false, status: 'timeout', message: 'Seller earnings request timed out.');
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error', message: 'Unable to load Seller earnings.');
    }
  }
}
