/// Shared API exception class for all API clients
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => message;
}
