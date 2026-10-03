import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/localization/app_strings.dart';

class LanguageService extends ChangeNotifier {
  static final LanguageService _instance = LanguageService._internal();
  factory LanguageService() => _instance;
  LanguageService._internal() {
    _loadLanguage();
  }

  static const String _prefKey = 'user_selected_language_code';

  String get currentCode => 'en';
  Locale get currentLocale => const Locale('en');

  AppLanguage get currentLanguage {
    return AppStrings.supportedLanguages.firstWhere(
      (l) => l.code == 'en',
      orElse: () => AppStrings.supportedLanguages.first,
    );
  }

  List<AppLanguage> get supportedLanguages => [
    AppStrings.supportedLanguages.firstWhere(
      (l) => l.code == 'en',
      orElse: () => AppStrings.supportedLanguages.first,
    ),
  ];

  Future<void> _loadLanguage() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Reset any previously saved non-English preference back to English
      if (prefs.containsKey(_prefKey)) {
        await prefs.remove(_prefKey);
      }
    } catch (e) {
      debugPrint('>>> [LanguageService._loadLanguage] Error: $e');
    }
  }

  Future<void> setLanguage(String code) async {
    // English-only: no-op
  }

  String tr(String key) {
    return AppStrings.get(key, lang: 'en');
  }
}

