import 'package:dio/dio.dart';
import 'api_exception.dart';

class AnomalyResponse {
  final int id;
  final int meterAssignmentId;
  final int cycleId;
  final int? readingId;
  final String anomalyType;
  final String description;
  final String severity;
  final String status;
  final DateTime detectedAt;
  final DateTime? acknowledgedAt;
  final String? acknowledgedBy;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNotes;

  AnomalyResponse({
    required this.id,
    required this.meterAssignmentId,
    required this.cycleId,
    this.readingId,
    required this.anomalyType,
    required this.description,
    required this.severity,
    required this.status,
    required this.detectedAt,
    this.acknowledgedAt,
    this.acknowledgedBy,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNotes,
  });

  factory AnomalyResponse.fromJson(Map<String, dynamic> json) {
    return AnomalyResponse(
      id: json['id'] as int,
      meterAssignmentId: json['meter_assignment_id'] as int,
      cycleId: json['cycle_id'] as int,
      readingId: json['reading_id'] as int?,
      anomalyType: json['anomaly_type'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String,
      status: json['status'] as String,
      detectedAt: DateTime.parse(json['detected_at'] as String),
      acknowledgedAt: json['acknowledged_at'] != null
          ? DateTime.parse(json['acknowledged_at'] as String)
          : null,
      acknowledgedBy: json['acknowledged_by'] as String?,
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'] as String)
          : null,
      resolvedBy: json['resolved_by'] as String?,
      resolutionNotes: json['resolution_notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'meter_assignment_id': meterAssignmentId,
      'cycle_id': cycleId,
      'reading_id': readingId,
      'anomaly_type': anomalyType,
      'description': description,
      'severity': severity,
      'status': status,
      'detected_at': detectedAt.toIso8601String(),
      'acknowledged_at': acknowledgedAt?.toIso8601String(),
      'acknowledged_by': acknowledgedBy,
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolved_by': resolvedBy,
      'resolution_notes': resolutionNotes,
    };
  }
}

class AcknowledgeAnomalyRequest {
  final String acknowledgedBy;

  AcknowledgeAnomalyRequest({required this.acknowledgedBy});

  Map<String, String> toQueryParams() {
    return {'acknowledged_by': acknowledgedBy};
  }
}

class ResolveAnomalyRequest {
  final String resolvedBy;
  final String? resolutionNotes;

  ResolveAnomalyRequest({required this.resolvedBy, this.resolutionNotes});

  Map<String, String?> toQueryParams() {
    return {
      'resolved_by': resolvedBy,
      if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
    };
  }
}

class AnomalyApiClient {
  final Dio _dio;
  final String baseUrl;

  AnomalyApiClient({required this.baseUrl, required String token})
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

  /// Get all detected anomalies
  Future<List<AnomalyResponse>> getDetectedAnomalies({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/issues/anomalies',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AnomalyResponse.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch anomalies: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get anomaly by ID
  Future<AnomalyResponse> getAnomaly(int anomalyId) async {
    try {
      final response = await _dio.get('/issues/anomalies/$anomalyId');

      if (response.statusCode == 200) {
        return AnomalyResponse.fromJson(response.data);
      } else {
        throw ApiException('Failed to fetch anomaly: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get anomalies for a meter assignment
  Future<List<AnomalyResponse>> getAnomaliesByAssignment(
    int meterAssignmentId,
  ) async {
    try {
      final response = await _dio.get(
        '/issues/anomalies/assignment/$meterAssignmentId',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AnomalyResponse.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch anomalies: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Acknowledge an anomaly
  Future<AnomalyResponse> acknowledgeAnomaly(
    int anomalyId,
    AcknowledgeAnomalyRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/issues/anomalies/$anomalyId/acknowledge',
        queryParameters: request.toQueryParams(),
      );

      if (response.statusCode == 200) {
        return AnomalyResponse.fromJson(response.data);
      } else {
        throw ApiException(
          'Failed to acknowledge anomaly: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Resolve an anomaly
  Future<AnomalyResponse> resolveAnomaly(
    int anomalyId,
    ResolveAnomalyRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/issues/anomalies/$anomalyId/resolve',
        queryParameters: request.toQueryParams(),
      );

      if (response.statusCode == 200) {
        return AnomalyResponse.fromJson(response.data);
      } else {
        throw ApiException('Failed to resolve anomaly: ${response.statusCode}');
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
