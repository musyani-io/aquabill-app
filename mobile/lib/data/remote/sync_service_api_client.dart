import 'package:dio/dio.dart';
import 'api_exception.dart';

class SyncQueueItem {
  final String id;
  final String action;
  final String entity;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final int retryCount;
  final String? error;

  SyncQueueItem({
    required this.id,
    required this.action,
    required this.entity,
    required this.data,
    required this.createdAt,
    this.retryCount = 0,
    this.error,
  });

  factory SyncQueueItem.fromJson(Map<String, dynamic> json) {
    return SyncQueueItem(
      id: json['id'] ?? '',
      action: json['action'] ?? '',
      entity: json['entity'] ?? '',
      data: json['data'] ?? {},
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      retryCount: json['retry_count'] ?? 0,
      error: json['error'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'entity': entity,
      'data': data,
      'created_at': createdAt.toIso8601String(),
      'retry_count': retryCount,
      'error': error,
    };
  }
}

class SyncStatusResponse {
  final bool isSyncing;
  final int pendingCount;
  final int totalItems;
  final DateTime? lastSyncTime;
  final List<SyncQueueItem> queue;

  SyncStatusResponse({
    required this.isSyncing,
    required this.pendingCount,
    required this.totalItems,
    this.lastSyncTime,
    required this.queue,
  });

  factory SyncStatusResponse.fromJson(Map<String, dynamic> json) {
    return SyncStatusResponse(
      isSyncing: json['is_syncing'] ?? false,
      pendingCount: json['pending_count'] ?? 0,
      totalItems: json['total_items'] ?? 0,
      lastSyncTime: json['last_sync_time'] != null
          ? DateTime.parse(json['last_sync_time'])
          : null,
      queue:
          (json['queue'] as List<dynamic>?)
              ?.map((item) => SyncQueueItem.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class SyncServiceApiClient {
  final Dio _dio;
  final String _baseUrl;
  final String _token;

  SyncServiceApiClient({required String baseUrl, required String token})
    : _baseUrl = baseUrl,
      _token = token,
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          contentType: 'application/json',
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

  /// Get current sync status
  Future<SyncStatusResponse> getSyncStatus() async {
    try {
      final response = await _dio.get('/api/sync/status');
      return SyncStatusResponse.fromJson(response.data);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get pending sync items
  Future<List<SyncQueueItem>> getPendingItems() async {
    try {
      final response = await _dio.get('/api/sync/pending');
      final items = response.data['items'] as List<dynamic>? ?? [];
      return items.map((item) => SyncQueueItem.fromJson(item)).toList();
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Trigger manual sync
  Future<SyncStatusResponse> triggerSync() async {
    try {
      final response = await _dio.post('/api/sync/trigger');
      return SyncStatusResponse.fromJson(response.data);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Clear sync error for an item
  Future<void> clearError(String itemId) async {
    try {
      await _dio.post('/api/sync/$itemId/clear-error');
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Retry a specific item
  Future<SyncStatusResponse> retryItem(String itemId) async {
    try {
      final response = await _dio.post('/api/sync/$itemId/retry');
      return SyncStatusResponse.fromJson(response.data);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Clear all pending items
  Future<void> clearAllPending() async {
    try {
      await _dio.post('/api/sync/clear-all');
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get sync history
  Future<List<Map<String, dynamic>>> getSyncHistory({int limit = 50}) async {
    try {
      final response = await _dio.get(
        '/api/sync/history',
        queryParameters: {'limit': limit},
      );
      final items = response.data['history'] as List<dynamic>? ?? [];
      return items.cast<Map<String, dynamic>>();
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get sync metrics
  Future<Map<String, dynamic>> getSyncMetrics() async {
    try {
      final response = await _dio.get('/api/sync/metrics');
      return response.data;
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

      return ApiException(message);
    }

    return ApiException(error.toString());
  }
}
