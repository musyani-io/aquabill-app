/// Error handling utilities for mobile app.

class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  AppException({
    required this.message,
    this.code,
    this.originalError,
  });

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException({
    required String message,
    String? code,
    dynamic originalError,
  }) : super(
          message: message,
          code: code,
          originalError: originalError,
        );
}

class ValidationException extends AppException {
  ValidationException({
    required String message,
    String? code,
    dynamic originalError,
  }) : super(
          message: message,
          code: code,
          originalError: originalError,
        );
}

class ConflictException extends AppException {
  final dynamic conflictData;

  ConflictException({
    required String message,
    this.conflictData,
    String? code,
    dynamic originalError,
  }) : super(
          message: message,
          code: code,
          originalError: originalError,
        );
}

class SyncException extends AppException {
  SyncException({
    required String message,
    String? code,
    dynamic originalError,
  }) : super(
          message: message,
          code: code,
          originalError: originalError,
        );
}
