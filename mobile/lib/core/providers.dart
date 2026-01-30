import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App color palette for consistent theming
class AppColors {
  // Primary color - Ocean Blue
  static const Color primaryBlue = Color(0xFF1E88E5);
  static const Color primaryBlueDark = Color(0xFF1565C0);

  // Secondary colors
  static const Color accentGreen = Color(0xFF43A047);
  static const Color accentOrange = Color(0xFFFFA500);
  static const Color accentRed = Color(0xFFE53935);

  // Neutral colors
  static const Color surfaceLight = Color(0xFFFAFAFA);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color cardDark = Color(0xFF1E1E1E);

  // Text colors
  static const Color textLight = Color(0xFF212121);
  static const Color textDark = Color(0xFFEEEEEE);
  static const Color textHintLight = Color(0xFF757575);
  static const Color textHintDark = Color(0xFFB0BEC5);

  // Status colors
  static const Color success = Color(0xFF43A047);
  static const Color warning = Color(0xFFFFB300);
  static const Color error = Color(0xFFE53935);
  static const Color info = Color(0xFF1E88E5);
}

/// Theme helper for creating coordinated light and dark themes
class AppThemeHelper {
  static ThemeData buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.light(
        primary: AppColors.primaryBlue,
        primaryContainer: AppColors.primaryBlue.withOpacity(0.1),
        secondary: AppColors.accentGreen,
        secondaryContainer: AppColors.accentGreen.withOpacity(0.1),
        tertiary: AppColors.accentOrange,
        tertiaryContainer: AppColors.accentOrange.withOpacity(0.1),
        error: AppColors.error,
        errorContainer: AppColors.error.withOpacity(0.1),
        outline: Colors.grey.shade300,
        outlineVariant: Colors.grey.shade200,
        surface: AppColors.surfaceLight,
        inverseSurface: AppColors.textLight,
        inversePrimary: AppColors.primaryBlueDark,
      ),
      scaffoldBackgroundColor: AppColors.surfaceLight,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 2,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardLight,
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardLight,
        indicatorColor: AppColors.primaryBlue.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: AppColors.primaryBlue);
          }
          return const TextStyle(color: Colors.grey);
        }),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade200, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey.shade800,
        contentTextStyle: const TextStyle(color: Colors.white),
        elevation: 6,
      ),
    );
  }

  static ThemeData buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.dark(
        primary: AppColors.primaryBlue,
        primaryContainer: AppColors.primaryBlue.withOpacity(0.3),
        secondary: AppColors.accentGreen,
        secondaryContainer: AppColors.accentGreen.withOpacity(0.3),
        tertiary: AppColors.accentOrange,
        tertiaryContainer: AppColors.accentOrange.withOpacity(0.3),
        error: AppColors.error,
        errorContainer: AppColors.error.withOpacity(0.3),
        outline: Colors.grey.shade700,
        outlineVariant: Colors.grey.shade800,
        surface: AppColors.surfaceDark,
        inverseSurface: AppColors.textDark,
        inversePrimary: Colors.lightBlue,
      ),
      scaffoldBackgroundColor: AppColors.surfaceDark,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.surfaceDark,
        foregroundColor: AppColors.textDark,
        elevation: 2,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.primaryBlue),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardDark,
        elevation: 2,
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.cardDark,
        indicatorColor: AppColors.primaryBlue.withOpacity(0.3),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(color: AppColors.primaryBlue);
          }
          return TextStyle(color: Colors.grey.shade500);
        }),
      ),
      dividerTheme: DividerThemeData(color: Colors.grey.shade800, thickness: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.cardDark,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade700),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: Colors.grey.shade900,
        contentTextStyle: const TextStyle(color: Colors.white),
        elevation: 6,
      ),
    );
  }
}

/// Theme provider for managing light/dark mode
class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'aquabill_theme_mode';
  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final savedMode = _prefs.getString(_themeKey);
    if (savedMode != null) {
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.toString() == savedMode,
        orElse: () => ThemeMode.system,
      );
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    await _prefs.setString(_themeKey, mode.toString());
    notifyListeners();
  }
}

/// Language provider for managing app language
class LanguageProvider extends ChangeNotifier {
  static const String _languageKey = 'aquabill_language';
  late SharedPreferences _prefs;
  String _languageCode = 'en';

  String get languageCode => _languageCode;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    _languageCode = _prefs.getString(_languageKey) ?? 'en';
  }

  Future<void> setLanguage(String code) async {
    _languageCode = code;
    await _prefs.setString(_languageKey, code);
    notifyListeners();
  }

  String getLanguageName(String code) {
    final languages = {'en': 'English', 'sw': 'Swahili', 'fr': 'Français'};
    return languages[code] ?? code;
  }

  List<String> get supportedLanguages => ['en', 'sw', 'fr'];
}
