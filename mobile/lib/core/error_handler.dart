/// Error handling utilities for mobile app.
library;

class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException({required this.message, this.code, this.originalError});

  @override
  String toString() => message;
}

/// API/HTTP exception carrying an optional status code
class ApiException extends AppException {
  final int? statusCode;

  ApiException({
    required super.message,
    this.statusCode,
    super.code,
    super.originalError,
  });
}

class NetworkException extends AppException {
  NetworkException({required super.message, super.code, super.originalError});
}

class ValidationException extends AppException {
  ValidationException({
    required super.message,
    super.code,
    super.originalError,
  });
}

class ConflictException extends AppException {
  final dynamic conflictData;

  ConflictException({
    required super.message,
    this.conflictData,
    super.code,
    super.originalError,
  });
}

class SyncException extends AppException {
  SyncException({required super.message, super.code, super.originalError});
}
