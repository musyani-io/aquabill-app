import 'package:dio/dio.dart';
import 'api_exception.dart';

class SMSMessageResponse {
  final int id;
  final int? clientId;
  final String phoneNumber;
  final String messageBody;
  final String status; // PENDING, SENT, DELIVERED, FAILED, PERMANENTLY_FAILED
  final String? deliveryStatus; // PENDING, SENT, DELIVERED, FAILED
  final DateTime createdAt;
  final DateTime? sentAt;
  final DateTime? deliveredAt;
  final int retryCount;
  final int maxRetries;
  final DateTime? lastAttemptAt;
  final DateTime? nextRetryAt;
  final String? gatewayReference;
  final String? errorReason;

  SMSMessageResponse({
    required this.id,
    this.clientId,
    required this.phoneNumber,
    required this.messageBody,
    required this.status,
    this.deliveryStatus,
    required this.createdAt,
    this.sentAt,
    this.deliveredAt,
    required this.retryCount,
    required this.maxRetries,
    this.lastAttemptAt,
    this.nextRetryAt,
    this.gatewayReference,
    this.errorReason,
  });

  factory SMSMessageResponse.fromJson(Map<String, dynamic> json) {
    return SMSMessageResponse(
      id: json['id'] as int,
      clientId: json['client_id'] as int?,
      phoneNumber: json['phone_number'] as String,
      messageBody: json['message_body'] as String,
      status: json['status'] as String,
      deliveryStatus: json['delivery_status'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      sentAt: json['sent_at'] != null
          ? DateTime.parse(json['sent_at'] as String)
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.parse(json['delivered_at'] as String)
          : null,
      retryCount: json['retry_count'] as int? ?? 0,
      maxRetries: json['max_retries'] as int? ?? 3,
      lastAttemptAt: json['last_attempt_at'] != null
          ? DateTime.parse(json['last_attempt_at'] as String)
          : null,
      nextRetryAt: json['next_retry_at'] != null
          ? DateTime.parse(json['next_retry_at'] as String)
          : null,
      gatewayReference: json['gateway_reference'] as String?,
      errorReason: json['error_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'client_id': clientId,
      'phone_number': phoneNumber,
      'message_body': messageBody,
      'status': status,
      'delivery_status': deliveryStatus,
      'created_at': createdAt.toIso8601String(),
      'sent_at': sentAt?.toIso8601String(),
      'delivered_at': deliveredAt?.toIso8601String(),
      'retry_count': retryCount,
      'max_retries': maxRetries,
      'last_attempt_at': lastAttemptAt?.toIso8601String(),
      'next_retry_at': nextRetryAt?.toIso8601String(),
      'gateway_reference': gatewayReference,
      'error_reason': errorReason,
    };
  }
}

class SMSApiClient {
  final Dio _dio;
  final String baseUrl;

  SMSApiClient({required this.baseUrl, required String token})
    : _dio = Dio(
        BaseOptions(
          baseUrl: '$baseUrl/api/v1',
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  /// Get all SMS messages
  Future<List<SMSMessageResponse>> getAllSMS({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/sms',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => SMSMessageResponse.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch SMS messages: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get SMS by ID
  Future<SMSMessageResponse> getSMS(int smsId) async {
    try {
      final response = await _dio.get('/sms/$smsId');

      if (response.statusCode == 200) {
        return SMSMessageResponse.fromJson(response.data);
      } else {
        throw ApiException('Failed to fetch SMS: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get pending SMS (not yet sent)
  Future<List<SMSMessageResponse>> getPendingSMS({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/sms/pending',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => SMSMessageResponse.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch pending SMS: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get SMS for specific client
  Future<List<SMSMessageResponse>> getSMSByClient(
    int clientId, {
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/sms/client/$clientId',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => SMSMessageResponse.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch SMS for client: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get SMS by phone number
  Future<List<SMSMessageResponse>> getSMSByPhone(
    String phoneNumber, {
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/sms/phone/$phoneNumber',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => SMSMessageResponse.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch SMS for phone: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get SMS for failed delivery (needs retry or manual follow-up)
  Future<List<SMSMessageResponse>> getFailedSMS({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/sms/failed',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => SMSMessageResponse.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch failed SMS: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(DioException e) {
    if (e.response != null) {
      final message =
          e.response?.data['detail'] ?? e.message ?? 'Unknown error';
      return ApiException(message);
    }
    return ApiException(e.message ?? 'Network error');
  }
}
