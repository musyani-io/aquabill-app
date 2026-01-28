/// Application configuration
class Config {
  /// API base URL - Change this to your machine's IP address for physical device testing
  /// For emulator/simulator: http://localhost:8000
  /// For physical device: http://<YOUR_MACHINE_IP>:8000
  static const String apiBaseUrl = 'http://localhost:8000';

  /// API timeout in seconds
  static const int apiTimeoutSeconds = 30;

  /// Database name for local SQLite
  static const String databaseName = 'aquabill.db';

  /// Enable debug logging
  static const bool debugMode = true;
}
