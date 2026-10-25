import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

class LinehaulService {
  const LinehaulService._();
  static Map<String, String> _headers(String token) => {'Accept': 'application/json', 'Authorization': 'Bearer $token'};

  static Future<AuthApiResult> earnings(String token) async {
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/linehaul/earnings'), headers: _headers(token)).timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(r);
    } on TimeoutException { return const AuthApiResult(success:false,status:'timeout',message:'Linehaul earnings timed out.'); }
    catch (_) { return const AuthApiResult(success:false,status:'network_error',message:'Unable to load Linehaul earnings.'); }
  }

  static Future<AuthApiResult> trips(String token) async {
    try {
      final r = await http.get(Uri.parse('${ApiConfig.baseUrl}/linehaul/trips'), headers: _headers(token)).timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(r);
    } on TimeoutException { return const AuthApiResult(success:false,status:'timeout',message:'Linehaul trips timed out.'); }
    catch (_) { return const AuthApiResult(success:false,status:'network_error',message:'Unable to load Linehaul trips.'); }
  }

  static Future<AuthApiResult> preview({required String token, required String manifestCode}) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/linehaul/manifest/preview').replace(queryParameters: {'manifest_code': manifestCode.trim()});
      final r = await http.get(uri, headers: _headers(token)).timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(r);
    } on TimeoutException { return const AuthApiResult(success:false,status:'timeout',message:'Manifest verification timed out.'); }
    catch (_) { return const AuthApiResult(success:false,status:'network_error',message:'Unable to verify manifest.'); }
  }

  static Future<AuthApiResult> confirm({required String token, required String manifestCode, required String action}) async {
    try {
      final r = await http.post(Uri.parse('${ApiConfig.baseUrl}/linehaul/manifest/confirm'), headers: {..._headers(token),'Content-Type':'application/json'}, body: jsonEncode({'manifest_code':manifestCode.trim(),'action':action})).timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(r);
    } on TimeoutException { return const AuthApiResult(success:false,status:'timeout',message:'Linehaul confirmation timed out. Refresh before retrying.'); }
    catch (_) { return const AuthApiResult(success:false,status:'network_error',message:'Unable to confirm Linehaul handoff.'); }
  }
}
