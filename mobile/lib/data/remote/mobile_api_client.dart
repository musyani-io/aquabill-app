import 'dart:async';

import 'package:dio/dio.dart';

import '../../core/error_handler.dart';
import '../models/models.dart';
import 'dtos.dart';

class MobileApiClient {
  MobileApiClient({
    Dio? dio,
    required this.baseUrl,
    Future<String?> Function()? tokenProvider,
  })  : _dio = dio ??
            Dio(
              BaseOptions(
                baseUrl: baseUrl,
                connectTimeout: const Duration(seconds: 15),
                receiveTimeout: const Duration(seconds: 20),
                responseType: ResponseType.json,
              ),
            ),
        _tokenProvider = tokenProvider;

  final Dio _dio;
  final String baseUrl;
  final Future<String?> Function()? _tokenProvider;

  Future<BootstrapPayload> fetchBootstrap() async {
    try {
      final response = await _dio.get(
        '/mobile/bootstrap',
        options: Options(headers: await _headers()),
      );
      final data = response.data as Map<String, dynamic>;
      return _mapBootstrap(data);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<UpdatesPayload> fetchUpdates(DateTime since) async {
    try {
      final response = await _dio.get(
        '/mobile/updates',
        queryParameters: {'since': since.toIso8601String()},
        options: Options(headers: await _headers()),
      );
      final data = response.data as Map<String, dynamic>;
      return _mapUpdates(data);
    } on DioException catch (e) {
      _handleDioError(e);
      rethrow;
    }
  }

  Future<SubmitReadingResult> submitReading({
    required int meterAssignmentId,
    required int cycleId,
    required double absoluteValue,
    required String submittedBy,
    required DateTime submittedAt,
    String? clientTz,
    String? source,
    double? previousApprovedReading,
    String? deviceId,
    String? appVersion,
    int? conflictId,
    String? submissionNotes,
  }) async {
    final payload = {
      'meter_assignment_id': meterAssignmentId,
      'cycle_id': cycleId,
      'absolute_value': absoluteValue,
      'submitted_by': submittedBy,
      'submitted_at': submittedAt.toIso8601String(),
      'client_tz': clientTz,
      'source': source ?? 'mobile',
      'previous_approved_reading': previousApprovedReading,
      'device_id': deviceId,
      'app_version': appVersion,
      'conflict_id': conflictId,
      'submission_notes': submissionNotes,
    }..removeWhere((_, value) => value == null);

    try {
      final response = await _dio.post(
        '/mobile/readings',
        data: payload,
        options: Options(headers: await _headers()),
      );
      return SubmitReadingResult.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 409 && e.response?.data != null) {
        throw ConflictException(
          message: 'Conflict detected',
          conflictData: e.response?.data,
          originalError: e,
        );
      }
      _handleDioError(e);
      rethrow;
    }
  }

  // ---------- Mappers ----------

  BootstrapPayload _mapBootstrap(Map<String, dynamic> data) {
    return BootstrapPayload(
      clients: _mapList(data['clients'], ClientModel.fromLocalMap),
      meters: _mapList(data['meters'], MeterModel.fromLocalMap),
      assignments:
          _mapList(data['assignments'], MeterAssignmentModel.fromLocalMap),
      cycles: _mapList(data['cycles'], CycleModel.fromLocalMap),
      readings: _mapList(data['readings'], ReadingModel.fromLocalMap),
      lastSync: DateTime.parse(data['last_sync'] as String),
    );
  }

  UpdatesPayload _mapUpdates(Map<String, dynamic> data) {
    return UpdatesPayload(
      clients: _mapList(data['clients'], ClientModel.fromLocalMap),
      meters: _mapList(data['meters'], MeterModel.fromLocalMap),
      assignments:
          _mapList(data['assignments'], MeterAssignmentModel.fromLocalMap),
      cycles: _mapList(data['cycles'], CycleModel.fromLocalMap),
      readings: _mapList(data['readings'], ReadingModel.fromLocalMap),
      tombstones: _mapList(data['tombstones'], TombstoneModel.fromJson),
      lastSync: DateTime.parse(data['last_sync'] as String),
    );
  }

  List<T> _mapList<T>(dynamic value, T Function(Map<String, dynamic>) mapper) {
    if (value == null) return <T>[];
    return (value as List)
        .map((item) => mapper(item as Map<String, dynamic>))
        .toList();
  }

  // ---------- Helpers ----------

  Future<Map<String, String>> _headers() async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    if (_tokenProvider != null) {
      final token = await _tokenProvider!.call();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }
    return headers;
  }

  Never _handleDioError(DioException e) {
    final status = e.response?.statusCode;
    final message = e.message ?? 'Network error';

    if (status == 401 || status == 403) {
      throw NetworkException(
          message: 'Unauthorized', code: '$status', originalError: e);
    }
    if (status != null && status >= 500) {
      throw NetworkException(
          message: 'Server error ($status)', code: '$status', originalError: e);
    }
    if (status == 400) {
      throw ValidationException(
          message: 'Validation error', code: '$status', originalError: e);
    }

    throw NetworkException(
        message: message, code: status?.toString(), originalError: e);
  }
}
