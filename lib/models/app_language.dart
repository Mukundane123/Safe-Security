/// Display language for the app. SafeGuard ships with English plus starter
/// Luganda translations for the core navigation and safety phrases.
enum AppLanguage {
  english('en', 'English'),
  luganda('lg', 'Luganda');

  const AppLanguage(this.code, this.label);
  final String code;
  final String label;

  static AppLanguage fromCode(String? code) {
    return AppLanguage.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLanguage.english,
    );
  }
}