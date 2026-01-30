import 'package:dio/dio.dart';
import 'api_exception.dart';
import 'reading_dtos.dart';

class ReadingApiClient {
  final Dio _dio;
  final String baseUrl;

  ReadingApiClient({required this.baseUrl, required String token})
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

  /// Get all pending (unapproved) readings for admin review
  Future<List<ReadingResponse>> getPendingReadings() async {
    try {
      final response = await _dio.get('/readings/pending');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ReadingResponse.fromJson(json)).toList();
      } else {
        throw ApiException(
          'Failed to fetch pending readings: ${response.statusCode}',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get reading by ID
  Future<ReadingResponse> getReading(int readingId) async {
    try {
      final response = await _dio.get('/readings/$readingId');

      if (response.statusCode == 200) {
        return ReadingResponse.fromJson(response.data);
      } else {
        throw ApiException('Failed to fetch reading: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Approve a reading
  Future<ReadingResponse> approveReading(
    int readingId,
    ApproveReadingRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/readings/$readingId/approve',
        queryParameters: request.toQueryParams(),
      );

      if (response.statusCode == 200) {
        return ReadingResponse.fromJson(response.data);
      } else {
        throw ApiException('Failed to approve reading: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Reject a reading
  Future<Map<String, dynamic>> rejectReading(
    int readingId,
    RejectReadingRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/readings/$readingId/reject',
        queryParameters: request.toQueryParams(),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw ApiException('Failed to reject reading: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get readings by cycle
  Future<List<ReadingResponse>> getReadingsByCycle(int cycleId) async {
    try {
      final response = await _dio.get('/readings/cycle/$cycleId');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => ReadingResponse.fromJson(json)).toList();
      } else {
        throw ApiException('Failed to fetch readings: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get readings with rollover flag
  Future<List<ReadingResponse>> getRolloversForReview() async {
    try {
      final response = await _dio.get('/readings/pending');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data
            .map((json) => ReadingResponse.fromJson(json))
            .where((reading) => reading.hasRollover)
            .toList();
      } else {
        throw ApiException('Failed to fetch rollovers: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Verify a rollover reading (confirm genuine rollover)
  Future<ReadingResponse> verifyRollover(
    int readingId,
    VerifyRolloverRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/readings/$readingId/verify-rollover',
        queryParameters: request.toQueryParams(),
      );

      if (response.statusCode == 200) {
        return ReadingResponse.fromJson(response.data);
      } else {
        throw ApiException('Failed to verify rollover: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Reject rollover claim (mark as meter fault or false positive)
  Future<Map<String, dynamic>> rejectRollover(
    int readingId,
    RejectRolloverRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/readings/$readingId/reject-rollover',
        queryParameters: request.toQueryParams(),
      );

      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw ApiException('Failed to reject rollover: ${response.statusCode}');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(DioException e) {
    if (e.response != null) {
      final statusCode = e.response!.statusCode;
      final message = e.response!.data['detail'] ?? e.message;

      if (statusCode == 401) {
        return ApiException('Unauthorized. Please log in again.');
      } else if (statusCode == 403) {
        return ApiException('Forbidden. You do not have permission.');
      } else if (statusCode == 404) {
        return ApiException('Reading not found.');
      } else {
        return ApiException(message ?? 'Unknown error occurred');
      }
    } else {
      // Network error
      return ApiException('Network error: ${e.message}');
    }
  }
}
