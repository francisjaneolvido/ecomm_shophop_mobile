import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:shophop/core/config/api_config.dart';
import 'package:shophop/features/auth/data/services/auth_service.dart';

class SellerWorkspaceService {
  const SellerWorkspaceService._();

  static const maxProductVideoBytes = 25 * 1024 * 1024;

  static Future<AuthApiResult> get(String token, String path) =>
      _send('GET', token, path);

  static Future<AuthApiResult> patch(
    String token,
    String path,
    Map<String, dynamic> payload,
  ) => _send('PATCH', token, path, payload);

  static Future<AuthApiResult> post(String token, String path) =>
      _send('POST', token, path);

  static Future<AuthApiResult> postWithBody(
    String token,
    String path,
    Map<String, dynamic> payload,
  ) => _send('POST', token, path, payload);

  static Future<AuthApiResult> updateLogo({
    required String token,
    PlatformFile? logo,
    bool remove = false,
  }) async {
    final client = http.Client();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/seller/profile/logo'),
      );
      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });
      if (remove) request.fields['remove_logo'] = '1';
      if (logo != null && logo.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'logo',
            logo.bytes!,
            filename: logo.name,
          ),
        );
      }
      final streamed = await client
          .send(request)
          .timeout(const Duration(seconds: 30));
      return AuthApiResult.fromResponse(
        await http.Response.fromStream(streamed),
      );
    } on TimeoutException {
      return const AuthApiResult(
        success: false,
        status: 'timeout',
        message: 'Logo upload timed out. Please retry.',
      );
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message: 'Could not update shop logo. Check your connection.',
      );
    } finally {
      client.close();
    }
  }

  /// Simple product fields + optional product photos (shared Seller Web database).
  static Future<AuthApiResult> saveProduct({
    required String token,
    int? productId,
    required Map<String, String> fields,
    List<PlatformFile> images = const [],
    PlatformFile? video,
    bool removeVideo = false,
  }) async {
    if (video != null) {
      if (video.size > maxProductVideoBytes ||
          (video.bytes?.length ?? 0) > maxProductVideoBytes) {
        return const AuthApiResult(
          success: false,
          status: 'validation_error',
          message: 'The product video must be 25 MB or smaller.',
        );
      }
      if (video.extension?.toLowerCase() != 'mp4' ||
          video.bytes == null ||
          video.bytes!.isEmpty) {
        return const AuthApiResult(
          success: false,
          status: 'validation_error',
          message: 'Could not read the MP4 video. Select it again and retry.',
        );
      }
    }
    final path = productId == null
        ? 'inventory/products'
        : 'inventory/products/$productId';
    final client = http.Client();
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/seller/$path'),
      );
      request.headers['Authorization'] = 'Bearer $token';
      request.headers['Accept'] = 'application/json';
      request.fields.addAll(fields);
      if (removeVideo) request.fields['remove_video'] = '1';
      if (video?.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'video',
            video!.bytes!,
            filename: video.name,
            contentType: MediaType('video', 'mp4'),
          ),
        );
      }
      for (var i = 0; i < images.length; i++) {
        final image = images[i];
        if (image.bytes == null) continue;
        request.files.add(
          http.MultipartFile.fromBytes(
            'images[$i]',
            image.bytes!,
            filename: image.name,
          ),
        );
      }
      final response = await (() async => http.Response.fromStream(
        await client.send(request),
      ))().timeout(const Duration(minutes: 2));
      if (response.statusCode == 413) {
        return const AuthApiResult(
          success: false,
          status: 'upload_too_large',
          statusCode: 413,
          message:
              'The server could not accept this upload. Use one MP4 up to 25 MB and up to 8 photos (5 MB each). Your draft is kept; try again after checking the server upload limit.',
        );
      }
      return AuthApiResult.fromResponse(response);
    } on TimeoutException {
      return const AuthApiResult(
        success: false,
        status: 'timeout',
        message: 'Product upload timed out. Refresh inventory before retrying.',
      );
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message: 'Could not send product. Check your network connection.',
      );
    } finally {
      client.close();
    }
  }

  static Future<AuthApiResult> _send(
    String method,
    String token,
    String path, [
    Map<String, dynamic>? payload,
  ]) async {
    try {
      final request = http.Request(
        method,
        Uri.parse('${ApiConfig.baseUrl}/seller/$path'),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      });
      if (payload != null) request.body = jsonEncode(payload);
      final client = http.Client();
      try {
        final streamed = await client
            .send(request)
            .timeout(const Duration(seconds: 22));
        return AuthApiResult.fromResponse(
          await http.Response.fromStream(streamed),
        );
      } finally {
        client.close();
      }
    } on TimeoutException {
      return const AuthApiResult(
        success: false,
        status: 'timeout',
        message: 'Request timed out. Please retry.',
      );
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message:
            'Cannot connect to ShopHop. Check Laravel and your connection.',
      );
    }
  }
}
