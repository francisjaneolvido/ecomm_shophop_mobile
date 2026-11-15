import 'dart:async';
import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

class AfterSalesService {
  const AfterSalesService._();

  static Map<String, String> _headers(String token) => {
    'Authorization': 'Bearer $token',
    'Accept': 'application/json',
  };

  static Future<AuthApiResult> list(String token, String role) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/$role/after-sales'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message: 'Cannot load return cases. Please retry.',
      );
    }
  }

  static Future<AuthApiResult> wallet(String token, {int page = 1}) async {
    try {
      final response = await http
          .get(
            Uri.parse('${ApiConfig.baseUrl}/buyer/wallet?page=$page'),
            headers: _headers(token),
          )
          .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message: 'Cannot load wallet. Please retry.',
      );
    }
  }

  static Future<AuthApiResult> action(
    String token,
    String role,
    int caseId,
    String action, [
    Map<String, dynamic> fields = const {},
  ]) async {
    try {
      final response = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/$role/after-sales/$caseId/$action'),
            headers: {..._headers(token), 'Content-Type': 'application/json'},
            body: jsonEncode(fields),
          )
          .timeout(const Duration(seconds: 20));
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message: 'Could not update the return case. Please retry.',
      );
    }
  }

  static Future<AuthApiResult> request(
    String token,
    int orderId,
    int itemId,
    int quantity,
    String reason,
    List<PlatformFile> evidence,
  ) => _upload(
    token,
    'buyer/orders/$orderId/after-sales',
    {'order_item_id': '$itemId', 'quantity': '$quantity', 'reason': reason},
    {'evidence[]': evidence},
  );

  static Future<AuthApiResult> sellerPayment(
    String token,
    int caseId,
    String reference,
    PlatformFile proof,
  ) => _upload(
    token,
    'seller/after-sales/$caseId/payment',
    {'reference': reference},
    {
      'proof': [proof],
    },
  );

  static Future<AuthApiResult> sellerInspect(
    String token,
    int caseId,
    String note,
    String condition,
    int quantity,
    List<PlatformFile> photos,
  ) => _upload(
    token,
    'seller/after-sales/$caseId/receive',
    {'note': note, 'condition': condition, 'quantity': '$quantity'},
    {'evidence[]': photos},
  );

  static Future<AuthApiResult> riderPickup(
    String token,
    int caseId,
    PlatformFile proof,
  ) => _upload(token, 'rider/after-sales/$caseId/pickup', {}, {
    'proof': [proof],
  });

  static Future<AuthApiResult> _upload(
    String token,
    String path,
    Map<String, String> fields,
    Map<String, List<PlatformFile>> files,
  ) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/$path'),
      );
      request.headers.addAll(_headers(token));
      request.fields.addAll(fields);
      for (final entry in files.entries) {
        for (final file in entry.value) {
          if (file.bytes != null) {
            request.files.add(
              http.MultipartFile.fromBytes(
                entry.key,
                file.bytes!,
                filename: file.name,
              ),
            );
          } else if (file.path != null && file.path!.isNotEmpty) {
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
              message: 'Cannot read the selected attachment.',
            );
          }
        }
      }
      final stream = await request.send().timeout(const Duration(seconds: 30));
      return AuthApiResult.fromResponse(await http.Response.fromStream(stream));
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message: 'Upload failed. Please retry.',
      );
    }
  }
}
