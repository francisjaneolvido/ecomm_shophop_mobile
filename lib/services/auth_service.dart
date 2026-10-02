import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';

class AuthApiResult {
  const AuthApiResult({
    required this.success,
    required this.status,
    required this.message,
    this.data = const {},
    this.errors = const {},
    this.statusCode,
  });

  final bool success;
  final String status;
  final String message;
  final Map<String, dynamic> data;
  final Map<String, dynamic> errors;
  final int? statusCode;

  factory AuthApiResult.fromResponse(
    http.Response response,
  ) {
    Map<String, dynamic> body = {};

    try {
      final decoded =
          jsonDecode(response.body);

      if (decoded
          is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {
      // Keep a clean fallback below.
    }

    final rawErrors = body['errors'];
    final errors =
        rawErrors is Map
            ? Map<String, dynamic>.from(
                rawErrors,
              )
            : <String, dynamic>{};

    return AuthApiResult(
      success:
          body['success'] == true ||
          (response.statusCode >= 200 &&
              response.statusCode < 300),
      status:
          body['status']?.toString() ??
          (response.statusCode >= 200 &&
                  response.statusCode <
                      300
              ? 'ok'
              : 'error'),
      message:
          body['message']?.toString() ??
          _firstValidationMessage(
            errors,
          ) ??
          'Something went wrong. Please try again.',
      data:
          body['data']
                  is Map<String, dynamic>
              ? body['data']
                  as Map<String, dynamic>
              : <String, dynamic>{},
      errors: errors,
      statusCode:
          response.statusCode,
    );
  }

  static String?
      _firstValidationMessage(
    Map<String, dynamic> errors,
  ) {
    for (final value
        in errors.values) {
      if (value is List &&
          value.isNotEmpty) {
        return value.first.toString();
      }

      if (value != null) {
        return value.toString();
      }
    }

    return null;
  }
}

class AuthService {
  AuthService._();

  static const Map<String, String>
      _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  static Future<AuthApiResult>
      registerBuyer({
    required String firstName,
    required String lastName,
    required String middleInitial,
    required String sex,
    required String email,
    required String contactNo,
    required String birthday,
    required String provinceCode,
    required String provinceName,
    required String municipalityCode,
    required String municipalityName,
    required String barangayCode,
    required String barangayName,
    required String streetAddress,
    required PlatformFile validId,
    required String password,
  }) async {
    try {
      final request =
          http.MultipartRequest(
        'POST',
        Uri.parse(
          '${ApiConfig.baseUrl}/buyer/register',
        ),
      );

      request.headers['Accept'] =
          'application/json';

      request.fields.addAll({
        'first_name':
            firstName.trim(),
        'last_name':
            lastName.trim(),
        'middle_initial':
            middleInitial.trim(),
        'sex': sex,
        'email': email.trim(),
        'contact_no':
            contactNo.trim(),
        'birthday':
            birthday.trim(),
        'province_code':
            provinceCode,
        'province_name':
            provinceName,
        'municipality_code':
            municipalityCode,
        'municipality_name':
            municipalityName,
        'barangay_code':
            barangayCode,
        'barangay_name':
            barangayName,
        'street_address':
            streetAddress.trim(),
        'password': password,
        'password_confirmation':
            password,
        'terms': '1',
      });

      if (validId.bytes != null) {
        request.files.add(
          http.MultipartFile.fromBytes(
            'valid_id',
            validId.bytes!,
            filename: validId.name,
          ),
        );
      } else if (validId.path !=
              null &&
          validId.path!.isNotEmpty) {
        request.files.add(
          await http.MultipartFile
              .fromPath(
            'valid_id',
            validId.path!,
            filename: validId.name,
          ),
        );
      } else {
        return const AuthApiResult(
          success: false,
          status: 'file_error',
          message:
              'Unable to read the selected valid ID.',
        );
      }

      final streamed =
          await request.send();

      final response =
          await http.Response
              .fromStream(streamed);

      return AuthApiResult
          .fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status:
            'network_error',
        message:
            'Unable to connect to ShopHop. Make sure the Laravel server is running and try again.',
      );
    }
  }


  static Future<AuthApiResult>
      login({
    required String email,
    required String password,
    required bool rememberMe,
  }) async {
    return _postJson(
      '${ApiConfig.baseUrl}/login',
      {
        'email': email.trim(),
        'password': password,
        'remember': rememberMe,
      },
    );
  }

  static Future<AuthApiResult>
      me({
    required String token,
  }) async {
    try {
      final response =
          await http.get(
        Uri.parse(
          '${ApiConfig.baseUrl}/me',
        ),
        headers: {
          'Accept':
              'application/json',
          'Authorization':
              'Bearer $token',
        },
      );

      return AuthApiResult
          .fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message:
            'Unable to validate your ShopHop session.',
      );
    }
  }

  static Future<AuthApiResult>
      logout({
    required String token,
  }) async {
    try {
      final response =
          await http.post(
        Uri.parse(
          '${ApiConfig.baseUrl}/logout',
        ),
        headers: {
          'Accept':
              'application/json',
          'Authorization':
              'Bearer $token',
        },
      );

      return AuthApiResult
          .fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message:
            'Unable to reach the server while signing out.',
      );
    }
  }

  static Future<AuthApiResult>
      verifyBuyerEmail({
    required String email,
    required String code,
  }) async {
    return _postJson(
      '${ApiConfig.baseUrl}/buyer/verify-email',
      {
        'email': email.trim(),
        'code': code.trim(),
      },
    );
  }

  static Future<AuthApiResult>
      resendBuyerVerification({
    required String email,
  }) async {
    return _postJson(
      '${ApiConfig.baseUrl}/buyer/verify-email/resend',
      {
        'email': email.trim(),
      },
    );
  }

  static Future<AuthApiResult>
      _postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final response =
          await http.post(
        Uri.parse(url),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );

      return AuthApiResult
          .fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status:
            'network_error',
        message:
            'Unable to connect to ShopHop. Make sure the Laravel server is running and try again.',
      );
    }
  }
}
