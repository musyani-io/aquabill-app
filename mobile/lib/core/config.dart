/// Application configuration
class Config {
  /// API base URL
  static const String apiBaseUrl = 'http://localhost:8000';

  /// API timeout in seconds
  static const int apiTimeoutSeconds = 30;

  /// Database name for local SQLite
  static const String databaseName = 'aquabill.db';

  /// Enable debug logging
  static const bool debugMode = true;
}
