import 'package:dio/dio.dart';
import 'api_exception.dart';

class AlertResponse {
  final String id;
  final String title;
  final String message;
  final String
  category; // PAYMENT_DUE, SYSTEM_ERROR, ANOMALY, LATE_SUBMISSION, etc.
  final String severity; // INFO, WARNING, CRITICAL
  final bool isRead;
  final DateTime createdAt;
  final DateTime? resolvedAt;
  final String? relatedEntity;
  final String? relatedEntityId;

  AlertResponse({
    required this.id,
    required this.title,
    required this.message,
    required this.category,
    required this.severity,
    required this.isRead,
    required this.createdAt,
    this.resolvedAt,
    this.relatedEntity,
    this.relatedEntityId,
  });

  factory AlertResponse.fromJson(Map<String, dynamic> json) {
    return AlertResponse(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      category: json['category'] ?? '',
      severity: json['severity'] ?? 'INFO',
      isRead: json['is_read'] ?? false,
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      ),
      resolvedAt: json['resolved_at'] != null
          ? DateTime.parse(json['resolved_at'])
          : null,
      relatedEntity: json['related_entity'],
      relatedEntityId: json['related_entity_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'message': message,
      'category': category,
      'severity': severity,
      'is_read': isRead,
      'created_at': createdAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'related_entity': relatedEntity,
      'related_entity_id': relatedEntityId,
    };
  }
}

class AlertStatsResponse {
  final int totalAlerts;
  final int unreadAlerts;
  final int criticalAlerts;
  final int warningAlerts;
  final Map<String, int> alertsByCategory;

  AlertStatsResponse({
    required this.totalAlerts,
    required this.unreadAlerts,
    required this.criticalAlerts,
    required this.warningAlerts,
    required this.alertsByCategory,
  });

  factory AlertStatsResponse.fromJson(Map<String, dynamic> json) {
    return AlertStatsResponse(
      totalAlerts: json['total_alerts'] ?? 0,
      unreadAlerts: json['unread_alerts'] ?? 0,
      criticalAlerts: json['critical_alerts'] ?? 0,
      warningAlerts: json['warning_alerts'] ?? 0,
      alertsByCategory: Map<String, int>.from(json['alerts_by_category'] ?? {}),
    );
  }
}

class AlertApiClient {
  final Dio _dio;
  final String _baseUrl;
  final String _token;

  AlertApiClient({required String baseUrl, required String token})
    : _baseUrl = baseUrl,
      _token = token,
      _dio = Dio(
        BaseOptions(
          baseUrl: baseUrl,
          contentType: 'application/json',
          headers: {'Authorization': 'Bearer $token'},
        ),
      );

  /// Get all alerts
  Future<List<AlertResponse>> getAllAlerts({
    bool? isRead,
    String? category,
    String? severity,
    int limit = 100,
    int offset = 0,
  }) async {
    try {
      final queryParams = <String, dynamic>{
        if (isRead != null) 'is_read': isRead,
        if (category != null) 'category': category,
        if (severity != null) 'severity': severity,
        'limit': limit,
        'offset': offset,
      };

      final response = await _dio.get(
        '/api/alerts',
        queryParameters: queryParams,
      );

      final alerts = response.data['alerts'] as List<dynamic>? ?? [];
      return alerts.map((item) => AlertResponse.fromJson(item)).toList();
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get unread alerts
  Future<List<AlertResponse>> getUnreadAlerts({int limit = 50}) async {
    try {
      final response = await _dio.get(
        '/api/alerts/unread',
        queryParameters: {'limit': limit},
      );

      final alerts = response.data['alerts'] as List<dynamic>? ?? [];
      return alerts.map((item) => AlertResponse.fromJson(item)).toList();
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get alerts by category
  Future<List<AlertResponse>> getAlertsByCategory(
    String category, {
    int limit = 50,
  }) async {
    try {
      final response = await _dio.get(
        '/api/alerts/category/$category',
        queryParameters: {'limit': limit},
      );

      final alerts = response.data['alerts'] as List<dynamic>? ?? [];
      return alerts.map((item) => AlertResponse.fromJson(item)).toList();
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get critical alerts
  Future<List<AlertResponse>> getCriticalAlerts({int limit = 50}) async {
    try {
      final response = await _dio.get(
        '/api/alerts/critical',
        queryParameters: {'limit': limit},
      );

      final alerts = response.data['alerts'] as List<dynamic>? ?? [];
      return alerts.map((item) => AlertResponse.fromJson(item)).toList();
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Get alert statistics
  Future<AlertStatsResponse> getAlertStats() async {
    try {
      final response = await _dio.get('/api/alerts/stats');
      return AlertStatsResponse.fromJson(response.data);
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Mark alert as read
  Future<void> markAsRead(String alertId) async {
    try {
      await _dio.patch('/api/alerts/$alertId', data: {'is_read': true});
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Mark all alerts as read
  Future<void> markAllAsRead() async {
    try {
      await _dio.post('/api/alerts/mark-all-read');
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Resolve/dismiss an alert
  Future<void> resolveAlert(String alertId) async {
    try {
      await _dio.post('/api/alerts/$alertId/resolve');
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Delete an alert
  Future<void> deleteAlert(String alertId) async {
    try {
      await _dio.delete('/api/alerts/$alertId');
    } catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Clear all read alerts
  Future<void> clearReadAlerts() async {
    try {
      await _dio.post('/api/alerts/clear-read');
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
