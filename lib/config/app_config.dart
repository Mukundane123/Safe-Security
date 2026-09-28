/// Build-time configuration for SafeGuard.
class AppConfig {
  AppConfig._();

  /// Force the offline demo repository even when Firebase is present.
  static const bool forceDemoMode = bool.fromEnvironment(
    'DEMO_MODE',
    defaultValue: false,
  );

  /// Default area used for reports/alerts in the case-study division.
  static const String defaultArea = 'Kakoba Division';

  /// Reference point for the case-study area (Kakoba Division, Mbarara City).
  static const double kakobaLatitude = -0.6132;
  static const double kakobaLongitude = 30.6651;
}

/// Emergency numbers shown on the SOS screen (Uganda).
const List<({String label, String number})> kEmergencyNumbers = [
  (label: 'Police', number: '112'),
  (label: 'Fire & Rescue', number: '112'),
  (label: 'Ambulance (NAD)', number: '0800-100-222'),
  (label: 'Uganda Red Cross', number: '0414-258-491'),
];