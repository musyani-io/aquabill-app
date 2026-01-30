import 'package:dio/dio.dart';
import 'api_exception.dart';

/// Data transfer objects for Payment API

class PaymentResponse {
  final int id;
  final int meterAssignmentId;
  final int cycleId;
  final double amount;
  final String reference;
  final String method; // CASH, MPESA, BANK_TRANSFER
  final String? notes;
  final String recordedBy;
  final DateTime createdAt;
  final DateTime updatedAt;

  PaymentResponse({
    required this.id,
    required this.meterAssignmentId,
    required this.cycleId,
    required this.amount,
    required this.reference,
    required this.method,
    this.notes,
    required this.recordedBy,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PaymentResponse.fromJson(Map<String, dynamic> json) {
    return PaymentResponse(
      id: json['id'] as int,
      meterAssignmentId: json['meter_assignment_id'] as int,
      cycleId: json['cycle_id'] as int,
      amount: (json['amount'] as num).toDouble(),
      reference: json['reference'] as String,
      method: json['method'] as String,
      notes: json['notes'] as String?,
      recordedBy: json['recorded_by'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  String get methodDisplayName {
    switch (method) {
      case 'CASH':
        return 'Cash';
      case 'MPESA':
        return 'M-Pesa';
      case 'BANK_TRANSFER':
        return 'Bank Transfer';
      default:
        return method;
    }
  }
}

class CreatePaymentRequest {
  final int meterAssignmentId;
  final int cycleId;
  final double amount;
  final String reference;
  final String method; // CASH, MPESA, BANK_TRANSFER
  final String? notes;
  final String recordedBy;

  CreatePaymentRequest({
    required this.meterAssignmentId,
    required this.cycleId,
    required this.amount,
    required this.reference,
    required this.method,
    this.notes,
    required this.recordedBy,
  });

  Map<String, dynamic> toJson() {
    return {
      'meter_assignment_id': meterAssignmentId,
      'cycle_id': cycleId,
      'amount': amount,
      'reference': reference,
      'method': method,
      if (notes != null) 'notes': notes,
      'recorded_by': recordedBy,
    };
  }
}

/// API client for Payment endpoints
class PaymentApiClient {
  final Dio _dio;

  PaymentApiClient(String baseUrl, String token)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  /// Create a new payment
  Future<PaymentResponse> createPayment(CreatePaymentRequest request) async {
    try {
      final response = await _dio.post(
        '/billing/payments',
        data: request.toJson(),
      );

      if (response.statusCode == 201) {
        return PaymentResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException('Failed to record payment: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get single payment by ID
  Future<PaymentResponse> getPayment(int paymentId) async {
    try {
      final response = await _dio.get('/billing/payments/$paymentId');

      if (response.statusCode == 200) {
        return PaymentResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException('Failed to fetch payment: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// List all payments
  Future<List<PaymentResponse>> listPayments({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/billing/payments',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map(
              (json) => PaymentResponse.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw ApiException('Failed to fetch payments: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// List payments by meter assignment
  Future<List<PaymentResponse>> listPaymentsByAssignment(
    int meterAssignmentId,
  ) async {
    try {
      final response = await _dio.get(
        '/billing/payments/assignment/$meterAssignmentId',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map(
              (json) => PaymentResponse.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw ApiException('Failed to fetch payments: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// List payments by client
  Future<List<PaymentResponse>> listPaymentsByClient(int clientId) async {
    try {
      final response = await _dio.get('/billing/payments/client/$clientId');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map(
              (json) => PaymentResponse.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw ApiException('Failed to fetch payments: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode ?? 0;
      final message = e.response!.data.toString();

      switch (statusCode) {
        case 401:
          return ApiException('Unauthorized: Please login again');
        case 403:
          return ApiException('Forbidden: Insufficient permissions');
        case 404:
          return ApiException('Not found: $message');
        case 400:
          return ApiException('Bad request: $message');
        default:
          return ApiException('Server error ($statusCode): $message');
      }
    } else if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return ApiException('Connection timeout');
    } else if (e.type == DioExceptionType.unknown) {
      return ApiException('Network error: ${e.message}');
    } else {
      return ApiException('Request failed: ${e.message}');
    }
  }
}
