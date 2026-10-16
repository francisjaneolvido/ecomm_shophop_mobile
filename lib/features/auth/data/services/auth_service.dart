import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;

import 'package:shophop/core/config/api_config.dart';

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

  factory AuthApiResult.fromResponse(http.Response response) {
    Map<String, dynamic>? body;

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map<String, dynamic>) {
        body = decoded;
      }
    } catch (_) {
      // A tunnel/hosting error can be an HTML document rather than API JSON.
    }

    if (body == null) {
      return AuthApiResult(
        success: false,
        status: 'unexpected_response',
        message: response.statusCode >= 500
            ? 'ShopHop is temporarily unavailable. Please try again later.'
            : 'ShopHop returned a non-API response. Check your connection '
                'and app server settings.',
        statusCode: response.statusCode,
      );
    }

    final rawErrors = body['errors'];
    final errors = rawErrors is Map
        ? Map<String, dynamic>.from(rawErrors)
        : <String, dynamic>{};
    final isHttpSuccess = response.statusCode >= 200 && response.statusCode < 300;

    return AuthApiResult(
      success: isHttpSuccess && body['success'] == true,
      status: body['status']?.toString() ??
          (isHttpSuccess && body['success'] == true ? 'ok' : 'error'),
      message: body['message']?.toString() ??
          _firstValidationMessage(errors) ??
          'Something went wrong. Please try again.',
      data: body['data'] is Map<String, dynamic>
          ? body['data'] as Map<String, dynamic>
          : <String, dynamic>{},
      errors: errors,
      statusCode: response.statusCode,
    );
  }

  static String? _firstValidationMessage(Map<String, dynamic> errors) {
    for (final value in errors.values) {
      if (value is List && value.isNotEmpty) {
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

  static const Map<String, String> _jsonHeaders = {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  };

  static Future<AuthApiResult> registerBuyer({
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
    String? regionCode,
    String? regionName,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/buyer/register'),
      );
      request.headers['Accept'] = 'application/json';
      request.fields.addAll({
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'middle_initial': middleInitial.trim(),
        'sex': sex,
        'email': email.trim(),
        'contact_no': contactNo.trim(),
        'birthday': birthday.trim(),
        if (regionCode != null) 'region_code': regionCode,
        if (regionName != null) 'region_name': regionName,
        'province_code': provinceCode,
        'province_name': provinceName,
        'municipality_code': municipalityCode,
        'municipality_name': municipalityName,
        'barangay_code': barangayCode,
        'barangay_name': barangayName,
        'street_address': streetAddress.trim(),
        'password': password,
        'password_confirmation': password,
        'terms': '1',
      });

      final attached = await _attachFile(request, 'valid_id', validId);
      if (!attached) {
        return const AuthApiResult(
          success: false,
          status: 'file_error',
          message: 'Unable to read the selected valid ID.',
        );
      }

      return _sendMultipart(request);
    } catch (_) {
      return _networkError();
    }
  }

  /// Seller mobile registration uses the same Laravel users/sellers tables and
  /// private Admin-review document storage as Seller web registration.
  static Future<AuthApiResult> registerSeller({
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
    required String businessName,
    required String businessCategory,
    required PlatformFile validId,
    required PlatformFile businessPermit,
    required String password,
    String? regionCode,
    String? regionName,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/seller/register'),
      );
      request.headers['Accept'] = 'application/json';
      request.fields.addAll({
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'middle_initial': middleInitial.trim(),
        'sex': sex,
        'email': email.trim().toLowerCase(),
        'contact_no': contactNo.trim(),
        'birthday': birthday.trim(),
        if (regionCode != null) 'region_code': regionCode,
        if (regionName != null) 'region_name': regionName,
        'province_code': provinceCode,
        'province_name': provinceName,
        'municipality_code': municipalityCode,
        'municipality_name': municipalityName,
        'barangay_code': barangayCode,
        'barangay_name': barangayName,
        'street_address': streetAddress.trim(),
        'business_name': businessName.trim(),
        'business_category': businessCategory.trim(),
        'password': password,
        'password_confirmation': password,
        'terms': '1',
      });

      final validIdAttached = await _attachFile(request, 'valid_id', validId);
      final permitAttached =
          await _attachFile(request, 'business_permit', businessPermit);
      if (!validIdAttached || !permitAttached) {
        return const AuthApiResult(
          success: false,
          status: 'file_error',
          message: 'Unable to read one of the selected Seller documents.',
        );
      }
      return _sendMultipart(request);
    } catch (_) {
      return _networkError();
    }
  }

  static Future<AuthApiResult> riderLogisticsCenters() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/rider/logistics-centers'),
        headers: const {'Accept': 'application/json'},
      );
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return _networkError();
    }
  }

  static Future<AuthApiResult> registerRider({
    required int logisticsPartnerId,
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
    required String vehicleType,
    required String plateNumber,
    required PlatformFile orCr,
    required PlatformFile idOrLicense,
    required String password,
    String? regionCode,
    String? regionName,
  }) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('${ApiConfig.baseUrl}/rider/register'),
      );
      request.headers['Accept'] = 'application/json';
      request.fields.addAll({
        'logistics_partner_id': logisticsPartnerId.toString(),
        'first_name': firstName.trim(),
        'last_name': lastName.trim(),
        'middle_initial': middleInitial.trim(),
        'sex': sex,
        'email': email.trim(),
        'contact_no': contactNo.trim(),
        'birthday': birthday.trim(),
        if (regionCode != null) 'region_code': regionCode,
        if (regionName != null) 'region_name': regionName,
        'province_code': provinceCode,
        'province_name': provinceName,
        'municipality_code': municipalityCode,
        'municipality_name': municipalityName,
        'barangay_code': barangayCode,
        'barangay_name': barangayName,
        'street_address': streetAddress.trim(),
        'vehicle_type': vehicleType.trim(),
        'plate_number': plateNumber.trim(),
        'password': password,
        'password_confirmation': password,
        'terms': '1',
      });

      final orCrAttached = await _attachFile(request, 'or_cr', orCr);
      final idAttached =
          await _attachFile(request, 'id_or_license', idOrLicense);
      if (!orCrAttached || !idAttached) {
        return const AuthApiResult(
          success: false,
          status: 'file_error',
          message: 'Unable to read one of the selected Rider documents.',
        );
      }

      return _sendMultipart(request);
    } catch (_) {
      return _networkError();
    }
  }

  static Future<AuthApiResult> login({
    required String email,
    required String password,
    required bool rememberMe,
  }) {
    return _postJson(
      '${ApiConfig.baseUrl}/login',
      {
        'email': email.trim(),
        'password': password,
        'remember': rememberMe,
      },
    );
  }

  static Future<AuthApiResult> me({required String token}) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/me'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message: 'Unable to validate your ShopHop session.',
      );
    }
  }

  static Future<AuthApiResult> logout({required String token}) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}/logout'),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return const AuthApiResult(
        success: false,
        status: 'network_error',
        message: 'Unable to reach the server while signing out.',
      );
    }
  }

  static Future<AuthApiResult> verifyBuyerEmail({
    required String email,
    required String code,
  }) {
    return _postJson(
      '${ApiConfig.baseUrl}/buyer/verify-email',
      {'email': email.trim(), 'code': code.trim()},
    );
  }

  static Future<AuthApiResult> resendBuyerVerification({
    required String email,
  }) {
    return _postJson(
      '${ApiConfig.baseUrl}/buyer/verify-email/resend',
      {'email': email.trim()},
    );
  }

  static Future<AuthApiResult> verifySellerEmail({
    required String email,
    required String code,
  }) {
    return _postJson(
      '${ApiConfig.baseUrl}/seller/verify-email',
      {'email': email.trim().toLowerCase(), 'code': code.trim()},
    );
  }

  static Future<AuthApiResult> resendSellerVerification({
    required String email,
  }) {
    return _postJson(
      '${ApiConfig.baseUrl}/seller/verify-email/resend',
      {'email': email.trim().toLowerCase()},
    );
  }

  static Future<AuthApiResult> verifyRiderEmail({
    required String email,
    required String code,
  }) {
    return _postJson(
      '${ApiConfig.baseUrl}/rider/verify-email',
      {'email': email.trim(), 'code': code.trim()},
    );
  }

  static Future<AuthApiResult> resendRiderVerification({
    required String email,
  }) {
    return _postJson(
      '${ApiConfig.baseUrl}/rider/verify-email/resend',
      {'email': email.trim()},
    );
  }

  static Future<bool> _attachFile(
    http.MultipartRequest request,
    String field,
    PlatformFile file,
  ) async {
    if (file.bytes != null) {
      request.files.add(
        http.MultipartFile.fromBytes(
          field,
          file.bytes!,
          filename: file.name,
        ),
      );
      return true;
    }

    if (file.path != null && file.path!.isNotEmpty) {
      request.files.add(
        await http.MultipartFile.fromPath(
          field,
          file.path!,
          filename: file.name,
        ),
      );
      return true;
    }

    return false;
  }

  static Future<AuthApiResult> _sendMultipart(
    http.MultipartRequest request,
  ) async {
    final streamed = await request.send();
    final response = await http.Response.fromStream(streamed);
    return AuthApiResult.fromResponse(response);
  }

  static Future<AuthApiResult> _postJson(
    String url,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );
      return AuthApiResult.fromResponse(response);
    } catch (_) {
      return _networkError();
    }
  }

  static AuthApiResult _networkError() {
    return const AuthApiResult(
      success: false,
      status: 'network_error',
      message:
          'Unable to connect to ShopHop. Check your internet connection and try again.',
    );
  }
}
