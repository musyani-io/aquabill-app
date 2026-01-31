/// Application configuration
class Config {
  /// API base URL - Change this to your machine's IP address for physical device testing
  /// For Android emulator: http://10.0.2.2:8000 (special alias to reach host machine)
  /// For iOS simulator: http://localhost:8000
  /// For physical device: http://<YOUR_MACHINE_IP>:8000
  static const String apiBaseUrl = 'http://10.0.2.2:8000';

  /// API timeout in seconds
  static const int apiTimeoutSeconds = 30;

  /// Database name for local SQLite
  static const String databaseName = 'aquabill.db';

  /// Enable debug logging
  static const bool debugMode = true;
}
