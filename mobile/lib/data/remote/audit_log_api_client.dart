import 'package:dio/dio.dart';
import 'api_exception.dart';

class AuditLogResponse {
  final int id;
  final String action; // CREATED, UPDATED, DELETED, APPROVED, REJECTED, etc.
  final String entityType; // client, meter, reading, cycle, etc.
  final int? entityId;
  final String performedBy;
  final DateTime timestamp;
  final String? description;
  final Map<String, dynamic>? changedFields;
  final String? ipAddress;

  AuditLogResponse({
    required this.id,
    required this.action,
    required this.entityType,
    this.entityId,
    required this.performedBy,
    required this.timestamp,
    this.description,
    this.changedFields,
    this.ipAddress,
  });

  factory AuditLogResponse.fromJson(Map<String, dynamic> json) {
    return AuditLogResponse(
      id: json['id'] as int,
      action: json['action'] as String,
      entityType: json['entity_type'] as String,
      entityId: json['entity_id'] as int?,
      performedBy: json['performed_by'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      description: json['description'] as String?,
      changedFields: json['changed_fields'] as Map<String, dynamic>?,
      ipAddress: json['ip_address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'entity_type': entityType,
      'entity_id': entityId,
      'performed_by': performedBy,
      'timestamp': timestamp.toIso8601String(),
      'description': description,
      'changed_fields': changedFields,
      'ip_address': ipAddress,
    };
  }
}

class AuditLogApiClient {
  final Dio _dio;
  final String baseUrl;

  AuditLogApiClient({required this.baseUrl, required String token})
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

  /// Get all audit logs
  Future<List<AuditLogResponse>> getAllAuditLogs({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/audit/logs',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AuditLogResponse.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch audit logs: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get audit log by ID
  Future<AuditLogResponse> getAuditLog(int logId) async {
    try {
      final response = await _dio.get('/audit/logs/$logId');

      if (response.statusCode == 200) {
        return AuditLogResponse.fromJson(response.data);
      } else {
        throw ApiException('Failed to fetch audit log: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get audit logs for specific entity
  Future<List<AuditLogResponse>> getAuditLogsForEntity(
    String entityType,
    int entityId, {
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/audit/logs/$entityType/$entityId',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AuditLogResponse.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch audit logs: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get audit logs by action type
  Future<List<AuditLogResponse>> getAuditLogsByAction(
    String action, {
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/audit/logs/action/$action',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AuditLogResponse.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch audit logs: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get audit logs by user
  Future<List<AuditLogResponse>> getAuditLogsByUser(
    String username, {
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/audit/logs/user/$username',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => AuditLogResponse.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch audit logs: ${response.statusCode}',
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
