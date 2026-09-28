import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_language.dart';

/// App-wide preferences (dark mode + language) persisted locally so the choice
/// survives restarts. Dependencies are injected in `main()`.
class SettingsController extends ChangeNotifier {
  static const _themeKey = 'settings.themeMode';
  static const _langKey = 'settings.language';

  SettingsController._(this._prefs, ThemeMode themeMode, AppLanguage language)
      : _themeMode = themeMode,
        _language = language;

  final SharedPreferences _prefs;
  ThemeMode _themeMode;
  AppLanguage _language;

  ThemeMode get themeMode => _themeMode;
  AppLanguage get language => _language;
  bool get isDark => _themeMode == ThemeMode.dark;

  static Future<SettingsController> load() async {
    final prefs = await SharedPreferences.getInstance();
    final mode = prefs.getString(_themeKey) == 'dark'
        ? ThemeMode.dark
        : ThemeMode.light;
    return SettingsController._(
      prefs,
      mode,
      AppLanguage.fromCode(prefs.getString(_langKey)),
    );
  }

  Future<void> setDarkMode(bool dark) async {
    _themeMode = dark ? ThemeMode.dark : ThemeMode.light;
    await _prefs.setString(_themeKey, _themeMode.name);
    notifyListeners();
  }

  Future<void> setLanguage(AppLanguage language) async {
    _language = language;
    await _prefs.setString(_langKey, language.code);
    notifyListeners();
  }

  /// Tiny look-up point for a handful of UI strings so switching language is
  /// visible without localizing the entire app (starter implementation).
  String tr(String key) {
    if (_language == AppLanguage.english) return key;
    return _luganda[key] ?? key;
  }

  static const Map<String, String> _luganda = {
    'Home': 'Eka',
    'Map': 'Maapu',
    'SOS': 'Okuyamba',
    'More': 'Ebirala',
    'Dashboard': 'Ekkuata',
    'Incidents': 'Ebyaliwo',
    'Notifications': 'Amawulire',
    'Settings': 'Enteekateeka',
    'Profile': 'Endabika yange',
    'Sign out': 'Kenddeyo',
    'Incident map': 'Maapu y\'ebisaawo',
    'My location': 'Wendi',
    'Safety zones': 'Ebifo eby\'amaanyi',
    'Safe check-in': 'Okwogerako endaba',
    'Community alerts': 'Okulabula komuniti',
    'Send': 'Tuma',
    'Cancel': 'Ggyawo',
    'Save': 'Kuuma',
  };
}