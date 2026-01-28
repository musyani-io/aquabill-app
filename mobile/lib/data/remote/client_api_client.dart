import 'package:dio/dio.dart';
import '/core/error_handler.dart';
import 'client_dtos.dart';

class ClientApiClient {
  final String baseUrl;
  final Dio _dio;

  ClientApiClient({required this.baseUrl})
    : _dio = Dio(BaseOptions(baseUrl: baseUrl));

  bool _isSuccess(int? statusCode) =>
      statusCode != null && statusCode >= 200 && statusCode < 300;

  dynamic _ensureMap(dynamic data) => data is Map ? data : {};

  ApiException _buildApiException(
    Response response, {
    required String fallback,
  }) {
    try {
      final data = _ensureMap(response.data);
      final message = data['detail'] ?? data['message'] ?? fallback;
      return ApiException(
        message: message.toString(),
        statusCode: response.statusCode ?? 500,
      );
    } catch (e) {
      return ApiException(
        message: fallback,
        statusCode: response.statusCode ?? 500,
      );
    }
  }

  ApiException _handleDioError(DioException e) {
    if (e.response != null) {
      return _buildApiException(e.response!, fallback: 'API error');
    }
    return ApiException(message: e.message ?? 'Network error', statusCode: 0);
  }

  /// Create a new client (admin only)
  Future<ClientResponse> createClient(
    String token,
    ClientCreateRequest request,
  ) async {
    try {
      final response = await _dio.post(
        '/api/v1/clients',
        data: request.toJson(),
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (_isSuccess(response.statusCode)) {
        return ClientResponse.fromJson(_ensureMap(response.data));
      }

      throw _buildApiException(response, fallback: 'Failed to create client');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get client by ID
  Future<ClientResponse> getClient(int clientId) async {
    try {
      final response = await _dio.get('/api/v1/clients/$clientId');

      if (_isSuccess(response.statusCode)) {
        return ClientResponse.fromJson(_ensureMap(response.data));
      }

      throw _buildApiException(response, fallback: 'Failed to fetch client');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// List all clients
  Future<List<ClientResponse>> listClients({
    int skip = 0,
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/api/v1/clients',
        queryParameters: {'skip': skip, 'limit': limit},
      );

      if (_isSuccess(response.statusCode)) {
        final data = response.data;
        if (data is List) {
          return data
              .map((e) => ClientResponse.fromJson(e as Map<String, dynamic>))
              .toList();
        }
        return [];
      }

      throw _buildApiException(response, fallback: 'Failed to fetch clients');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Update client (admin only)
  Future<ClientResponse> updateClient(
    String token,
    int clientId,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _dio.patch(
        '/api/v1/clients/$clientId',
        data: updates,
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (_isSuccess(response.statusCode)) {
        return ClientResponse.fromJson(_ensureMap(response.data));
      }

      throw _buildApiException(response, fallback: 'Failed to update client');
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Delete client (admin only)
  Future<void> deleteClient(String token, int clientId) async {
    try {
      final response = await _dio.delete(
        '/api/v1/clients/$clientId',
        options: Options(headers: {'Authorization': 'Bearer $token'}),
      );

      if (!_isSuccess(response.statusCode)) {
        throw _buildApiException(response, fallback: 'Failed to delete client');
      }
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }
}
