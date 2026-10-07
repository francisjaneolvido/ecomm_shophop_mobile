import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

class RiderDeliveryService {
  RiderDeliveryService._();

  static const Duration _requestTimeout = Duration(seconds: 20);

  static Future<AuthApiResult> assignments({required String token}) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/rider/assignments'),
            headers: _headers(token),
          )
          .timeout(_requestTimeout);
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return _timeoutError();
    } catch (_) {
      return _networkError();
    }
  }

  static Future<AuthApiResult> acceptPickup({
    required String token,
    required int deliveryId,
  }) {
    return _post(token, deliveryId, 'accept-pickup');
  }

  static Future<AuthApiResult> confirmPickup({
    required String token,
    required int deliveryId,
  }) {
    return _post(token, deliveryId, 'pickup');
  }

  static Future<AuthApiResult> outForDelivery({
    required String token,
    required int deliveryId,
  }) {
    return _post(token, deliveryId, 'out-for-delivery');
  }

  static Future<AuthApiResult> failDelivery({
    required String token,
    required int deliveryId,
    required String reason,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/rider/assignments/$deliveryId/fail'),
            headers: {
              ..._headers(token),
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'failure_reason': reason.trim()}),
          )
          .timeout(_requestTimeout);
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return _timeoutError();
    } catch (_) {
      return _networkError();
    }
  }

  static Future<AuthApiResult> completeDelivery({
    required String token,
    required int deliveryId,
    required PlatformFile proof,
    required bool cashCollected,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/rider/assignments/$deliveryId/complete'),
      );
      request.headers.addAll(_headers(token));
      if (cashCollected) {
        request.fields['cash_collected'] = '1';
      }

      if (proof.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'proof',
            proof.bytes!,
            filename: proof.name,
          ),
        );
      } else if (proof.path != null && proof.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile.fromPath(
            'proof',
            proof.path!,
            filename: proof.name,
          ),
        );
      } else {
        return const AuthApiResult(
          success: false,
          status: 'file_error',
          message: 'Unable to read the selected delivery proof.',
        );
      }

      final streamed = await request.send().timeout(_requestTimeout);
      final response = await http.Response.fromStream(streamed).timeout(_requestTimeout);
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return _timeoutError();
    } catch (_) {
      return _networkError();
    }
  }

  static Future<AuthApiResult> _post(
    String token,
    int deliveryId,
    String action,
  ) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/rider/assignments/$deliveryId/$action'),
            headers: _headers(token),
          )
          .timeout(_requestTimeout);
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return _timeoutError();
    } catch (_) {
      return _networkError();
    }
  }

  static Map<String, String> _headers(String token) => {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static AuthApiResult _timeoutError() {
    return const AuthApiResult(
      success: false,
      status: 'timeout',
      message: 'ShopHop took too long to respond. Check the server and try again.',
    );
  }

  static AuthApiResult _networkError() {
    return const AuthApiResult(
      success: false,
      status: 'network_error',
      message: 'Unable to connect to ShopHop. Please try again.',
    );
  }
}
