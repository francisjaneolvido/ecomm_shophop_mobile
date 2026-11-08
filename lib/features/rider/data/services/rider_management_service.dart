import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

class RiderManagementService {
  static Future<AuthApiResult> request(
    String path, {
    String? token,
    String method = 'GET',
    Map<String, dynamic>? body,
    http.Client? client,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/rider/$path');
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };
      final http.Response response;
      if (method == 'POST') {
        response =
            await (client?.post(
                      uri,
                      headers: headers,
                      body: jsonEncode(body ?? {}),
                    ) ??
                    http.post(
                      uri,
                      headers: headers,
                      body: jsonEncode(body ?? {}),
                    ))
                .timeout(const Duration(seconds: 25));
      } else if (method == 'PATCH') {
        response =
            await (client?.patch(
                      uri,
                      headers: headers,
                      body: jsonEncode(body ?? {}),
                    ) ??
                    http.patch(
                      uri,
                      headers: headers,
                      body: jsonEncode(body ?? {}),
                    ))
                .timeout(const Duration(seconds: 25));
      } else {
        response =
            await (client?.get(uri, headers: headers) ??
                    http.get(uri, headers: headers))
                .timeout(const Duration(seconds: 25));
      }
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message:
            'Cannot reach Rider Management. Check your connection and retry.',
      );
    }
  }

  static Future<AuthApiResult> options({
    int? companyId,
    int? branchId,
    http.Client? client,
  }) {
    final query = Uri(
      queryParameters: {
        if (companyId != null) 'company_id': '$companyId',
        if (branchId != null) 'branch_id': '$branchId',
      },
    ).query;
    return request(
      'work-options${query.isEmpty ? '' : '?$query'}',
      client: client,
    );
  }

  static Future<AuthApiResult> application(String token) =>
      request('application', token: token);
  static Future<AuthApiResult> confirmBranch(
    String token,
    int branchId,
    List<String> coverage,
  ) => request(
    'application/confirm-branch',
    token: token,
    method: 'POST',
    body: {'branch_id': branchId, 'coverage': coverage},
  );
  static Future<AuthApiResult> remit(String token, int deliveryId) =>
      request('cod/$deliveryId/remit', token: token, method: 'POST');

  static Future<AuthApiResult> activateSession(String token) =>
      request('application/session', token: token, method: 'POST');
  static Future<AuthApiResult> availability(String token, String state) =>
      request(
        'availability',
        token: token,
        method: 'PATCH',
        body: {'state': state},
      );

  static Future<AuthApiResult> documents(
    String token,
    Map<String, PlatformFile> files,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/rider/application/documents'),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      for (final entry in files.entries) {
        final file = entry.value;
        if (file.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              entry.key,
              file.bytes!,
              filename: file.name,
            ),
          );
        } else if (file.path != null) {
          request.files.add(
            await http.MultipartFile.fromPath(
              entry.key,
              file.path!,
              filename: file.name,
            ),
          );
        } else {
          return const AuthApiResult(
            success: false,
            status: 'file_error',
            message: 'Cannot read a selected document. Please select it again.',
          );
        }
      }
      final response = await http.Response.fromStream(
        await request.send().timeout(const Duration(seconds: 30)),
      );
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message: 'Documents could not be uploaded. Please retry.',
      );
    }
  }

  static List<Map<String, dynamic>> rows(dynamic data) => data is List
      ? data.whereType<Map>().map((r) => Map<String, dynamic>.from(r)).toList()
      : [];
}
