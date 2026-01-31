import 'package:dio/dio.dart';
import 'api_exception.dart';

class ConflictResponse {
  final int id;
  final int meterAssignmentId;
  final int cycleId;
  final int? readingId;
  final String conflictType;
  final String description;
  final String severity;
  final String status;
  final DateTime createdAt;
  final String? assignedTo;
  final DateTime? assignedAt;
  final DateTime? resolvedAt;
  final String? resolvedBy;
  final String? resolutionNotes;

  ConflictResponse({
    required this.id,
    required this.meterAssignmentId,
    required this.cycleId,
    this.readingId,
    required this.conflictType,
    required this.description,
    required this.severity,
    required this.status,
    required this.createdAt,
    this.assignedTo,
    this.assignedAt,
    this.resolvedAt,
    this.resolvedBy,
    this.resolutionNotes,
  });

  factory ConflictResponse.fromJson(Map<String, dynamic> json) {
    return ConflictResponse(
      id: json['id'] as int,
      meterAssignmentId: json['meter_assignment_id'] as int,
      cycleId: json['cycle_id'] as int,
      readingId: json['reading_id'] as int?,
      conflictType: json['conflict_type'] as String,
      description: json['description'] as String,
      severity: json['severity'] as String,
      status: json['status'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      assignedTo: json['assigned_to'] as String?,
      assignedAt: json['assigned_at'] != null
          ? DateTime.parse(json['assigned_at'] as String)
          : null,
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
      'conflict_type': conflictType,
      'description': description,
      'severity': severity,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'assigned_to': assignedTo,
      'assigned_at': assignedAt?.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolved_by': resolvedBy,
      'resolution_notes': resolutionNotes,
    };
  }
}

class AssignConflictRequest {
  final String assignedTo;

  AssignConflictRequest({required this.assignedTo});

  Map<String, String> toQueryParams() {
    return {'assigned_to': assignedTo};
  }
}

class ResolveConflictRequest {
  final String resolvedBy;
  final String? resolutionNotes;

  ResolveConflictRequest({required this.resolvedBy, this.resolutionNotes});

  Map<String, String?> toQueryParams() {
    return {
      'resolved_by': resolvedBy,
      if (resolutionNotes != null) 'resolution_notes': resolutionNotes,
    };
  }
}

class ConflictApiClient {
  final Dio _dio;
  final String baseUrl;

  ConflictApiClient({required this.baseUrl, required String token})
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

  /// Get all unresolved conflicts
  Future<List<ConflictResponse>> getUnresolvedConflicts({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/issues/conflicts',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ConflictResponse.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch conflicts: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get conflict by ID
  Future<ConflictResponse> getConflict(int conflictId) async {
    try {
      final response = await _dio.get('/issues/conflicts/$conflictId');

      if (response.statusCode == 200) {
        return ConflictResponse.fromJson(response.data);
      } else {
        throw ApiException('Failed to fetch conflict: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get conflicts for a meter assignment
  Future<List<ConflictResponse>> getConflictsByAssignment(
    int meterAssignmentId,
  ) async {
    try {
      final response = await _dio.get(
        '/issues/conflicts/assignment/$meterAssignmentId',
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ConflictResponse.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch conflicts: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get conflicts assigned to admin
  Future<List<ConflictResponse>> getConflictsByAdmin(String adminId) async {
    try {
      final response = await _dio.get('/issues/conflicts/admin/$adminId');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ConflictResponse.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch conflicts: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Assign a conflict to an admin
  Future<ConflictResponse> assignConflict(
    int conflictId,
    AssignConflictRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/issues/conflicts/$conflictId/assign',
        queryParameters: request.toQueryParams(),
      );

      if (response.statusCode == 200) {
        return ConflictResponse.fromJson(response.data);
      } else {
        throw ApiException('Failed to assign conflict: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Resolve a conflict
  Future<ConflictResponse> resolveConflict(
    int conflictId,
    ResolveConflictRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/issues/conflicts/$conflictId/resolve',
        queryParameters: request.toQueryParams(),
      );

      if (response.statusCode == 200) {
        return ConflictResponse.fromJson(response.data);
      } else {
        throw ApiException(
          'Failed to resolve conflict: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Archive a resolved conflict
  Future<ConflictResponse> archiveConflict(int conflictId) async {
    try {
      final response = await _dio.post('/issues/conflicts/$conflictId/archive');

      if (response.statusCode == 200) {
        return ConflictResponse.fromJson(response.data);
      } else {
        throw ApiException(
          'Failed to archive conflict: ${response.statusCode}',
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
