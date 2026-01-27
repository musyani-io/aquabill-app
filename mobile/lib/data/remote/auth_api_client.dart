import 'package:dio/dio.dart';

import '../../core/error_handler.dart';
import 'auth_dtos.dart';

class AuthApiClient {
  final Dio _dio;
  final String baseUrl;

  AuthApiClient({Dio? dio, required this.baseUrl})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: const Duration(seconds: 15),
              receiveTimeout: const Duration(seconds: 20),
              contentType: Headers.jsonContentType,
              responseType: ResponseType.json,
            ),
          );

  /// Register a new admin account
  Future<LoginResponse> registerAdmin(AdminRegisterRequest request) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/admin/register',
        data: request.toJson(),
      );

      if (_isSuccess(response.statusCode)) {
        return LoginResponse.fromJson(_ensureMap(response.data));
      }

      throw _buildApiException(response, fallback: 'Registration failed');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Login as admin
  Future<LoginResponse> loginAdmin(AdminLoginRequest request) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/admin/login',
        data: request.toJson(),
      );

      if (_isSuccess(response.statusCode)) {
        return LoginResponse.fromJson(_ensureMap(response.data));
      }

      throw _buildApiException(response, fallback: 'Login failed');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Login as collector (password only)
  Future<LoginResponse> loginCollector(
    int collectorId,
    CollectorLoginRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/api/v1/auth/collector/login',
        queryParameters: {'collector_id': collectorId},
        data: request.toJson(),
      );

      if (_isSuccess(response.statusCode)) {
        return LoginResponse.fromJson(_ensureMap(response.data));
      }

      throw _buildApiException(response, fallback: 'Login failed');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Create a new collector account (admin only)
  Future<CollectorResponse> createCollector(
    String token,
    CollectorCreateRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/api/v1/admin/collectors',
        data: request.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (_isSuccess(response.statusCode)) {
        return CollectorResponse.fromJson(_ensureMap(response.data));
      }

      throw _buildApiException(
        response,
        fallback: 'Failed to create collector',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get all collectors for the current admin
  Future<CollectorListResponse> listCollectors(String token) async {
    try {
      final response = await _dio.get(
        '/api/v1/admin/collectors',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (_isSuccess(response.statusCode)) {
        return CollectorListResponse.fromJson(_ensureMap(response.data));
      }

      throw _buildApiException(
        response,
        fallback: 'Failed to fetch collectors',
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Delete a collector account (admin only)
  Future<void> deleteCollector(String token, int collectorId) async {
    try {
      final response = await _dio.delete(
        '/api/v1/admin/collectors/$collectorId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!_isSuccess(response.statusCode, allowNoContent: true)) {
        throw _buildApiException(
          response,
          fallback: 'Failed to delete collector',
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Handle DioException and convert to ApiException
  ApiException _handleDioError(DioException e) {
    String message = 'An error occurred';
    int? statusCode;

    if (e.response != null) {
      statusCode = e.response!.statusCode;
      final detail = _extractDetail(e.response!.data);
      message = detail ?? e.message ?? 'An error occurred';
    } else if (e.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.sendTimeout) {
      message = 'Send timeout';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      message = 'Request timeout';
    } else if (e.type == DioExceptionType.cancel) {
      message = 'Request cancelled';
    } else if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.unknown) {
      message = 'Network error: ${e.error}';
    }

    return ApiException(message: message, statusCode: statusCode);
  }

  bool _isSuccess(int? statusCode, {bool allowNoContent = false}) {
    if (statusCode == null) return false;
    if (allowNoContent && statusCode == 204) return true;
    return statusCode >= 200 && statusCode < 300;
  }

  Map<String, dynamic> _ensureMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    throw ApiException(message: 'Unexpected response format');
  }

  ApiException _buildApiException(
    Response<dynamic> response, {
    required String fallback,
  }) {
    final detail = _extractDetail(response.data);
    return ApiException(
      message: detail ?? fallback,
      statusCode: response.statusCode,
    );
  }

  String? _extractDetail(dynamic data) {
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) return detail;
    }
    return null;
  }
}
