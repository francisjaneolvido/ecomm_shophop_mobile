import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:shophop/core/config/api_config.dart';

class BuyerConversation {
  const BuyerConversation({
    required this.id,
    required this.name,
    required this.last,
    required this.time,
    required this.unread,
  });
  final int id, unread;
  final String name, last, time;
  factory BuyerConversation.fromJson(Map<String, dynamic> json) =>
      BuyerConversation(
        id: (json['id'] as num).toInt(),
        name: json['name']?.toString() ?? 'Shop',
        last: json['last']?.toString() ?? '',
        time: json['time']?.toString() ?? '',
        unread: (json['unread'] as num?)?.toInt() ?? 0,
      );
}

class BuyerChatMessage {
  const BuyerChatMessage({
    required this.id,
    required this.body,
    required this.time,
    required this.mine,
  });
  final int id;
  final String body, time;
  final bool mine;
  factory BuyerChatMessage.fromJson(Map<String, dynamic> json) =>
      BuyerChatMessage(
        id: (json['id'] as num).toInt(),
        body: json['body']?.toString() ?? '',
        time: json['time']?.toString() ?? '',
        mine: json['mine'] == true,
      );
}

class BuyerChatException implements Exception {
  const BuyerChatException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;
  bool get sessionExpired => statusCode == 401;
  bool get accessDenied => statusCode == 403 || statusCode == 404;
}

class BuyerChatService {
  BuyerChatService._();

  static String newMessageId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }

  static Future<List<BuyerConversation>> conversations(String token) async {
    final body = await _request(token, '/conversations');
    return (body['conversations'] as List)
        .map(
          (item) => BuyerConversation.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  static Future<int> open(String token, int sellerUserId) async {
    final body = await _request(
      token,
      '/open',
      data: {'seller_id': sellerUserId},
    );
    return (body['chat_id'] as num).toInt();
  }

  static Future<List<BuyerChatMessage>> messages(
    String token,
    int id, {
    int after = 0,
  }) async {
    final body = await _request(token, '/$id/messages?after=$after');
    return (body['messages'] as List)
        .map(
          (item) =>
              BuyerChatMessage.fromJson(Map<String, dynamic>.from(item as Map)),
        )
        .toList();
  }

  static Future<BuyerChatMessage> send(
    String token,
    int id,
    String message, {
    required String clientMessageId,
  }) async {
    final body = await _request(
      token,
      '/$id/send',
      data: {'body': message, 'client_message_id': clientMessageId},
    );
    return BuyerChatMessage.fromJson(
      Map<String, dynamic>.from(body['message'] as Map),
    );
  }

  static Future<Map<String, dynamic>> _request(
    String token,
    String path, {
    Map<String, dynamic>? data,
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/chat$path');
      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };
      final response =
          await (data == null
                  ? http.get(uri, headers: headers)
                  : http.post(uri, headers: headers, body: jsonEncode(data)))
              .timeout(const Duration(seconds: 20));
      Map<String, dynamic> body = {};
      try {
        final decoded = jsonDecode(response.body);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } on FormatException {
        /* Preserve status handling for non-JSON responses. */
      }
      if (response.statusCode < 200 ||
          response.statusCode >= 300 ||
          body['ok'] != true) {
        var message = response.statusCode == 401
            ? 'Your session expired. Please sign in again.'
            : response.statusCode == 403 || response.statusCode == 404
            ? 'This conversation is not available to your account.'
            : response.statusCode == 429
            ? 'Too many requests. Wait a moment and try again.'
            : 'Unable to connect to messages. Please try again.';
        if (response.statusCode == 422) {
          final errors = body['errors'];
          if (errors is Map &&
              errors.isNotEmpty &&
              errors.values.first is List &&
              (errors.values.first as List).isNotEmpty) {
            message = (errors.values.first as List).first.toString();
          } else {
            message = body['message']?.toString() ?? message;
          }
        }
        throw BuyerChatException(message, statusCode: response.statusCode);
      }
      return body;
    } on BuyerChatException {
      rethrow;
    } catch (_) {
      throw const BuyerChatException(
        'Unable to connect to messages. Check your connection and try again.',
      );
    }
  }
}
