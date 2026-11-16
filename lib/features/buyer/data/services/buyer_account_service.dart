import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';

class BuyerAccountProfile {
  const BuyerAccountProfile({
    required this.firstName,
    required this.lastName,
    required this.middleInitial,
    required this.email,
    required this.phone,
    required this.sex,
    required this.birthday,
    required this.sexOptions,
    this.avatarUrl,
  });

  final String firstName, lastName, middleInitial, email, phone, sex;
  final DateTime? birthday;
  final List<String> sexOptions;
  final String? avatarUrl;
  String get name => '$firstName $lastName'.trim();

  factory BuyerAccountProfile.fromJson(Map<String, dynamic> json) =>
      BuyerAccountProfile(
        firstName: json['first_name']?.toString() ?? '',
        avatarUrl: json['avatar_url']?.toString(),
        lastName: json['last_name']?.toString() ?? '',
        middleInitial: json['middle_initial']?.toString() ?? '',
        email: json['email']?.toString() ?? '',
        phone: json['contact_no']?.toString() ?? '',
        sex: json['sex']?.toString() ?? '',
        birthday: DateTime.tryParse(json['birthday']?.toString() ?? ''),
        sexOptions:
            (json['sex_options'] is List
                    ? json['sex_options'] as List
                    : const ['Male', 'Female'])
                .map((value) => value.toString())
                .toList(),
      );
}

class BuyerAccountException implements Exception {
  const BuyerAccountException(
    this.message, {
    this.statusCode,
    this.errors = const {},
  });
  final String message;
  final int? statusCode;
  final Map<String, String> errors;
  bool get isUnauthorized => statusCode == 401 || statusCode == 403;
}

class BuyerAccountService {
  BuyerAccountService._();

  static Future<BuyerAccountProfile> uploadAvatar(
    String token,
    PlatformFile file,
  ) async {
    final bytes = file.bytes;
    final mime = lookupMimeType(file.name, headerBytes: bytes);
    if (bytes == null ||
        bytes.isEmpty ||
        !['image/jpeg', 'image/png', 'image/webp'].contains(mime)) {
      throw const BuyerAccountException('Choose a JPG, PNG or WebP image.');
    }
    if (bytes.length > 2 * 1024 * 1024) {
      throw const BuyerAccountException(
        'Profile photo must be 2 MB or smaller.',
      );
    }
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/buyer/profile/avatar'),
      );
      request.headers.addAll({
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      });
      request.files.add(
        http.MultipartFile.fromBytes(
          'avatar',
          bytes,
          filename: file.name,
          contentType: MediaType.parse(mime!),
        ),
      );
      final client = http.Client();
      try {
        final response = await (() async => http.Response.fromStream(
          await client.send(request),
        ))().timeout(const Duration(seconds: 30));
        return _profile(_decode(response));
      } finally {
        client.close();
      }
    } on BuyerAccountException {
      rethrow;
    } catch (_) {
      throw const BuyerAccountException(
        'Your photo could not be uploaded. Please try again.',
      );
    }
  }

  static Future<BuyerAccountProfile> load(String token) async =>
      _profile(await _request(token, '/profile'));

  static Future<BuyerAccountProfile> save(
    String token,
    Map<String, dynamic> fields,
  ) async => _profile(await _request(token, '/profile', fields: fields));

  static Future<void> changePassword(
    String token, {
    required String current,
    required String password,
    required String confirmation,
  }) async {
    await _request(
      token,
      '/password',
      fields: {
        'current_password': current,
        'password': password,
        'password_confirmation': confirmation,
      },
    );
  }

  static BuyerAccountProfile _profile(Map<String, dynamic> payload) {
    if (payload['data'] is! Map) {
      throw const BuyerAccountException(
        'Could not load your account. Please try again.',
      );
    }
    return BuyerAccountProfile.fromJson(
      Map<String, dynamic>.from(payload['data'] as Map),
    );
  }

  static Future<Map<String, dynamic>> _request(
    String token,
    String path, {
    Map<String, dynamic>? fields,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/buyer$path');
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response =
          await (fields == null
                  ? http.get(uri, headers: headers)
                  : http.patch(uri, headers: headers, body: jsonEncode(fields)))
              .timeout(const Duration(seconds: 25));
      return _decode(response);
    } on BuyerAccountException {
      rethrow;
    } catch (_) {
      throw const BuyerAccountException(
        'Unable to connect. Check your connection and try again.',
      );
    }
  }

  static Map<String, dynamic> _decode(http.Response response) {
    Map<String, dynamic> payload = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
    } on FormatException {
      /* A proxy may return an HTML error page. */
    }
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        payload['success'] != true) {
      final errors = <String, String>{};
      if (payload['errors'] is Map) {
        for (final entry in (payload['errors'] as Map).entries) {
          final messages = entry.value;
          if (messages is List && messages.isNotEmpty) {
            errors[entry.key.toString()] = messages.first.toString();
          }
        }
      }
      throw BuyerAccountException(
        response.statusCode == 401
            ? 'Your session expired. Please sign in again.'
            : response.statusCode >= 500
            ? 'Could not save your changes. Please try again.'
            : (errors.values.firstOrNull ??
                  payload['message']?.toString() ??
                  'Unable to complete your request. Please try again.'),
        statusCode: response.statusCode,
        errors: errors,
      );
    }
    return payload;
  }
}
