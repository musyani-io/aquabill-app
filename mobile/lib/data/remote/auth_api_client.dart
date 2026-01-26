import 'package:dio/dio.dart';

import '../../core/error_handler.dart';
import 'auth_dtos.dart';

class AuthApiClient {
  final Dio _dio;
  final String baseUrl;

  AuthApiClient({
    Dio? dio,
    required this.baseUrl,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               baseUrl: baseUrl,
               connectTimeout: const Duration(seconds: 15),
               receiveTimeout: const Duration(seconds: 20),
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

      if (response.statusCode == 200) {
        return LoginResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException(
          message: response.data['detail'] ?? 'Registration failed',
          statusCode: response.statusCode,
        );
      }
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

      if (response.statusCode == 200) {
        return LoginResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException(
          message: response.data['detail'] ?? 'Login failed',
          statusCode: response.statusCode,
        );
      }
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

      if (response.statusCode == 200) {
        return LoginResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException(
          message: response.data['detail'] ?? 'Login failed',
          statusCode: response.statusCode,
        );
      }
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
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return CollectorResponse.fromJson(response.data as Map<String, dynamic>);
      } else {
        throw ApiException(
          message: response.data['detail'] ?? 'Failed to create collector',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get all collectors for the current admin
  Future<CollectorListResponse> listCollectors(String token) async {
    try {
      final response = await _dio.get(
        '/api/v1/admin/collectors',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode == 200) {
        return CollectorListResponse.fromJson(
          response.data as Map<String, dynamic>,
        );
      } else {
        throw ApiException(
          message: response.data['detail'] ?? 'Failed to fetch collectors',
          statusCode: response.statusCode,
        );
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Delete a collector account (admin only)
  Future<void> deleteCollector(String token, int collectorId) async {
    try {
      final response = await _dio.delete(
        '/api/v1/admin/collectors/$collectorId',
        options: Options(
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

      if (response.statusCode != 204) {
        throw ApiException(
          message: response.data['detail'] ?? 'Failed to delete collector',
          statusCode: response.statusCode,
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
      final detail = e.response!.data is Map<String, dynamic>
          ? e.response!.data['detail']
          : null;
      message = detail ?? e.message ?? 'An error occurred';
    } else if (e.type == DioExceptionType.connectionTimeout) {
      message = 'Connection timeout';
    } else if (e.type == DioExceptionType.receiveTimeout) {
      message = 'Request timeout';
    } else if (e.type == DioExceptionType.unknown) {
      message = 'Network error: ${e.error}';
    }

    return ApiException(message: message, statusCode: statusCode);
  }
}
