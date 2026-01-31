import 'package:dio/dio.dart';
import 'api_exception.dart';

class PenaltyResponse {
  final int id;
  final int meterAssignmentId;
  final int? cycleId;
  final double amount;
  final String reason;
  final String? notes;
  final String status; // PENDING, APPLIED, WAIVED
  final DateTime createdAt;
  final String imposedBy;
  final DateTime? appliedAt;
  final DateTime? waivedAt;
  final String? waivedBy;
  final String? waiverReason;

  PenaltyResponse({
    required this.id,
    required this.meterAssignmentId,
    this.cycleId,
    required this.amount,
    required this.reason,
    this.notes,
    required this.status,
    required this.createdAt,
    required this.imposedBy,
    this.appliedAt,
    this.waivedAt,
    this.waivedBy,
    this.waiverReason,
  });

  factory PenaltyResponse.fromJson(Map<String, dynamic> json) {
    return PenaltyResponse(
      id: json['id'] as int,
      meterAssignmentId: json['meter_assignment_id'] as int,
      cycleId: json['cycle_id'] as int?,
      amount: (json['amount'] as num).toDouble(),
      reason: json['reason'] as String,
      notes: json['notes'] as String?,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      imposedBy: json['imposed_by'] as String,
      appliedAt: json['applied_at'] != null
          ? DateTime.parse(json['applied_at'] as String)
          : null,
      waivedAt: json['waived_at'] != null
          ? DateTime.parse(json['waived_at'] as String)
          : null,
      waivedBy: json['waived_by'] as String?,
      waiverReason: json['waiver_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meter_assignment_id': meterAssignmentId,
      'cycle_id': cycleId,
      'amount': amount,
      'reason': reason,
      'notes': notes,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'imposed_by': imposedBy,
      'applied_at': appliedAt?.toIso8601String(),
      'waived_at': waivedAt?.toIso8601String(),
      'waived_by': waivedBy,
      'waiver_reason': waiverReason,
    };
  }
}

class WaivePenaltyRequest {
  final String waivedBy;
  final String? waiverReason;

  WaivePenaltyRequest({required this.waivedBy, this.waiverReason});

  Map<String, String?> toQueryParams() {
    return {
      'waived_by': waivedBy,
      if (waiverReason != null) 'waiver_reason': waiverReason,
    };
  }
}

class PenaltyApiClient {
  final Dio _dio;
  final String baseUrl;

  PenaltyApiClient({required this.baseUrl, required String token})
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

  /// Get all penalties
  Future<List<PenaltyResponse>> getAllPenalties({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/billing/penalties',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => PenaltyResponse.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch penalties: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get penalty by ID
  Future<PenaltyResponse> getPenalty(int penaltyId) async {
    try {
      final response = await _dio.get('/billing/penalties/$penaltyId');

      if (response.statusCode == 200) {
        return PenaltyResponse.fromJson(response.data);
      } else {
        throw ApiException('Failed to fetch penalty: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get penalties for a meter assignment
  Future<List<PenaltyResponse>> getPenaltiesByAssignment(
    int meterAssignmentId,
  ) async {
    try {
      final response = await _dio.get(
        '/billing/penalties/assignment/$meterAssignmentId',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => PenaltyResponse.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch penalties: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get pending penalties (not yet applied)
  Future<List<PenaltyResponse>> getPendingPenalties({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/billing/penalties/status/PENDING',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => PenaltyResponse.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch pending penalties: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Waive a penalty
  Future<PenaltyResponse> waivePenalty(
    int penaltyId,
    WaivePenaltyRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/billing/penalties/$penaltyId/waive',
        queryParameters: request.toQueryParams(),
      );

      if (response.statusCode == 200) {
        return PenaltyResponse.fromJson(response.data);
      } else {
        throw ApiException('Failed to waive penalty: ${response.statusCode}');
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
