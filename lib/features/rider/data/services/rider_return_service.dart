import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

/// Return tasks use the existing Rider token; no separate user registration.
class RiderReturnService {
  static Map<String, String> headers(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  static Future<AuthApiResult> tasks(String token) async {
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/rider/returns'),
        headers: headers(token)).timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(r);
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error',
        message: 'Cannot load return tasks. Please retry.');
    }
  }

  static Future<AuthApiResult> collect(String token, int id) async {
    try {
      final r = await http.post(Uri.parse('${ApiConfig.baseUrl}/rider/returns/$id/pickup'),
        headers: headers(token)).timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(r);
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error',
        message: 'Unable to confirm collection. Please retry.');
    }
  }

  static Future<AuthApiResult> handover(String token, int id, PlatformFile proof) async {
    try {
      final request = http.MultipartRequest('POST',
        Uri.parse('${ApiConfig.baseUrl}/rider/returns/$id/handover'));
      request.headers.addAll(headers(token));
      if (proof.bytes != null) {
        request.files.add(http.MultipartFile.fromBytes('proof', proof.bytes!, filename: proof.name));
      } else if (proof.path != null && proof.path!.isNotEmpty) {
        request.files.add(await http.MultipartFile.fromPath('proof', proof.path!, filename: proof.name));
      } else {
        return const AuthApiResult(success: false, status: 'file_error', message: 'Cannot read selected photo.');
      }
      final stream = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(stream);
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return const AuthApiResult(success: false, status: 'network_error',
        message: 'Photo upload failed. Please retry.');
    }
  }
}
