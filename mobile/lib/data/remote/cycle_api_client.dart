import 'package:dio/dio.dart';

/// Data transfer objects for Cycle API
class CycleResponse {
  final int id;
  final String? name;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime targetDate;
  final String status; // OPEN, PENDING_REVIEW, APPROVED, CLOSED, ARCHIVED
  final DateTime updatedAt;

  CycleResponse({
    required this.id,
    this.name,
    required this.startDate,
    required this.endDate,
    required this.targetDate,
    required this.status,
    required this.updatedAt,
  });

  factory CycleResponse.fromJson(Map<String, dynamic> json) {
    return CycleResponse(
      id: json['id'] as int,
      name: json['name'] as String?,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      targetDate: DateTime.parse(json['target_date'] as String),
      status: json['status'] as String,
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  bool get isOpen => status == 'OPEN';
  bool get isPendingReview => status == 'PENDING_REVIEW';
  bool get isApproved => status == 'APPROVED';
  bool get isClosed => status == 'CLOSED';
  bool get isArchived => status == 'ARCHIVED';

  String get statusDisplayName {
    switch (status) {
      case 'OPEN':
        return 'Open';
      case 'PENDING_REVIEW':
        return 'Pending Review';
      case 'APPROVED':
        return 'Approved';
      case 'CLOSED':
        return 'Closed';
      case 'ARCHIVED':
        return 'Archived';
      default:
        return status;
    }
  }
}

class CreateCycleRequest {
  final DateTime startDate;
  final DateTime endDate;
  final DateTime targetDate;
  final String? name;
  final String status;

  CreateCycleRequest({
    required this.startDate,
    required this.endDate,
    required this.targetDate,
    this.name,
    this.status = 'OPEN',
  });

  Map<String, dynamic> toJson() {
    return {
      'start_date': startDate.toIso8601String().split('T')[0],
      'end_date': endDate.toIso8601String().split('T')[0],
      'target_date': targetDate.toIso8601String().split('T')[0],
      if (name != null) 'name': name,
      'status': status,
    };
  }
}

class ScheduleCyclesRequest {
  final DateTime startDate;
  final int numCycles;
  final int cycleLengthDays;
  final int submissionWindowDays;

  ScheduleCyclesRequest({
    required this.startDate,
    required this.numCycles,
    this.cycleLengthDays = 30,
    this.submissionWindowDays = 5,
  });

  Map<String, dynamic> toJson() {
    return {
      'start_date': startDate.toIso8601String().split('T')[0],
      'num_cycles': numCycles,
      'cycle_length_days': cycleLengthDays,
      'submission_window_days': submissionWindowDays,
    };
  }
}

class TransitionCycleRequest {
  final String status;

  TransitionCycleRequest({required this.status});

  Map<String, dynamic> toJson() {
    return {'status': status};
  }
}

/// API client for Cycle endpoints
class CycleApiClient {
  final Dio _dio;

  CycleApiClient(String baseUrl, String token)
    : _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          headers: {'Authorization': 'Bearer $token'},
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 10),
        ),
      );

  /// List all cycles
  Future<List<CycleResponse>> listCycles({
    int skip = 0,
    int limit = 100,
  }) async {
    try {
      final response = await _dio.get(
        '/cycles',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => CycleResponse.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('Failed to fetch cycles: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get cycles by status
  Future<List<CycleResponse>> getCyclesByStatus(String status) async {
    try {
      final response = await _dio.get('/cycles/status/$status');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => CycleResponse.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('Failed to fetch cycles: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get current open cycle
  Future<CycleResponse> getOpenCycle() async {
    try {
      final response = await _dio.get('/cycles/open/current');

      if (response.statusCode == 200) {
        return CycleResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException(
          'Failed to fetch open cycle: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get cycle by ID
  Future<CycleResponse> getCycle(int cycleId) async {
    try {
      final response = await _dio.get('/cycles/$cycleId');

      if (response.statusCode == 200) {
        return CycleResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException('Failed to fetch cycle: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Create a new cycle
  Future<CycleResponse> createCycle(CreateCycleRequest request) async {
    try {
      final response = await _dio.post('/cycles', data: request.toJson());

      if (response.statusCode == 201) {
        return CycleResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException('Failed to create cycle: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Schedule multiple cycles
  Future<List<CycleResponse>> scheduleCycles(
    ScheduleCyclesRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/cycles/schedule',
        data: request.toJson(),
      );

      if (response.statusCode == 201) {
        final List<dynamic> data = response.data as List<dynamic>;
        return data
            .map((json) => CycleResponse.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        throw ApiException('Failed to schedule cycles: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Transition cycle status
  Future<CycleResponse> transitionCycleStatus(
    int cycleId,
    TransitionCycleRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/cycles/$cycleId/transition',
        data: request.toJson(),
      );

      if (response.statusCode == 200) {
        return CycleResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException(
          'Failed to transition cycle: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Auto-transition overdue cycles
  Future<Map<String, dynamic>> autoTransitionOverdue() async {
    try {
      final response = await _dio.post('/cycles/auto-transition/overdue');

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      } else {
        throw ApiException('Failed to auto-transition: ${response.statusCode}');
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

/// Simple API exception class
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}
