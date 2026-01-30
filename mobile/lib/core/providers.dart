import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    final languages = {
      'en': 'English',
      'sw': 'Swahili',
      'fr': 'Français',
    };
    return languages[code] ?? code;
  }

  List<String> get supportedLanguages => ['en', 'sw', 'fr'];
}
