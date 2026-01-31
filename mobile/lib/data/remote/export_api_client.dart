import 'package:dio/dio.dart';
import 'api_exception.dart';

class ExportApiClient {
  final Dio _dio;
  final String _baseUrl;
  final String _token;

  ExportApiClient({required String baseUrl, required String token})
    : _baseUrl = baseUrl,
      _token = token,
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          contentType: 'application/json',
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

  /// Export readings data
  /// Format: 'csv' or 'pdf'
  /// Returns file bytes
  Future<List<int>> exportReadings({
    required String format,
    required DateTime startDate,
    required DateTime endDate,
    String? clientId,
    String? meter,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'format': format,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        if (clientId != null) 'client_id': clientId,
        if (meter != null) 'meter': meter,
      };

      final response = await _dio.get(
        '/api/exports/readings',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      return response.data as List<int>;
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Export ledger entries
  Future<List<int>> exportLedger({
    required String format,
    required DateTime startDate,
    required DateTime endDate,
    String? clientId,
    String? type,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'format': format,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        if (clientId != null) 'client_id': clientId,
        if (type != null) 'type': type,
      };

      final response = await _dio.get(
        '/api/exports/ledger',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      return response.data as List<int>;
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Export payment records
  Future<List<int>> exportPayments({
    required String format,
    required DateTime startDate,
    required DateTime endDate,
    String? clientId,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'format': format,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        if (clientId != null) 'client_id': clientId,
        if (status != null) 'status': status,
      };

      final response = await _dio.get(
        '/api/exports/payments',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      return response.data as List<int>;
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Export billing cycles
  Future<List<int>> exportCycles({
    required String format,
    String? status,
    String? region,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'format': format,
        if (status != null) 'status': status,
        if (region != null) 'region': region,
      };

      final response = await _dio.get(
        '/api/exports/cycles',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      return response.data as List<int>;
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Export penalties
  Future<List<int>> exportPenalties({
    required String format,
    required DateTime startDate,
    required DateTime endDate,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'format': format,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        if (status != null) 'status': status,
      };

      final response = await _dio.get(
        '/api/exports/penalties',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      return response.data as List<int>;
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Export clients/accounts
  Future<List<int>> exportClients({
    required String format,
    String? zone,
    String? status,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'format': format,
        if (zone != null) 'zone': zone,
        if (status != null) 'status': status,
      };

      final response = await _dio.get(
        '/api/exports/clients',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      return response.data as List<int>;
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Generate comprehensive report (all entities and summary)
  Future<List<int>> generateComprehensiveReport({
    required String format,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'format': format,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
      };

      final response = await _dio.get(
        '/api/exports/comprehensive-report',
        queryParameters: queryParams,
        options: Options(
          responseType: ResponseType.bytes,
          followRedirects: true,
        ),
      );

      return response.data as List<int>;
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(dynamic error) {
    if (error is DioException) {
      String message = error.message ?? 'Unknown error';

      if (error.response != null) {
        try {
          final data = error.response!.data;
          if (data is Map<String, dynamic>) {
            message = data['detail'] ?? data['message'] ?? message;
          }
        } catch (e) {
          // Keep the original message
        }
      }

      return ApiException(
        message: message,
        statusCode: error.response?.statusCode,
      );
    }

    return ApiException(message: error.toString());
  }
}
