import 'package:flutter/material.dart';

import '../models/community_alert.dart';
import '../models/incident.dart';

/// Central design tokens for the SafeGuard UI.
class AppColors {
  AppColors._();

  static const Color primary = Color(0xFFB3261E);
  static const Color primaryDark = Color(0xFF7A1D18);
  static const Color secondary = Color(0xFF1B5E8A);
  static const Color background = Color(0xFFF7F6F3);
  static const Color surface = Colors.white;
  static const Color ink = Color(0xFF1C1B1F);
  static const Color muted = Color(0xFF6B6A6F);

  static const Color categoryRobbery = Color(0xFFC62828);
  static const Color categoryFire = Color(0xFFEF6C00);
  static const Color categoryMedical = Color(0xFF1565C0);
  static const Color categoryAccident = Color(0xFF6A1B9A);
  static const Color categoryDomestic = Color(0xFFAD1457);
  static const Color categorySuspicious = Color(0xFF00838F);
  static const Color categoryAssault = Color(0xFFD81B60);
  static const Color categoryFight = Color(0xFF5D4037);
  static const Color categoryMissing = Color(0xFF303F9F);
  static const Color categoryFlood = Color(0xFF0277BD);
  static const Color categoryOther = Color(0xFF546E7A);

  static const Color priorityUrgent = Color(0xFFB3261E);
  static const Color priorityHigh = Color(0xFFE65100);
  static const Color priorityNormal = Color(0xFFF9A825);
  static const Color priorityLow = Color(0xFF2E7D32);

  static const Color statusPending = Color(0xFFF9A825);
  static const Color statusAssigned = Color(0xFF1E88E5);
  static const Color statusInProgress = Color(0xFF6A1B9A);
  static const Color statusResolved = Color(0xFF2E7D32);
  static const Color statusClosed = Color(0xFF546E7A);
  static const Color statusDuplicate = Color(0xFF757575);

  static const Color alertInfo = Color(0xFF1565C0);
  static const Color alertWarning = Color(0xFFEF6C00);
  static const Color alertCritical = Color(0xFFB3261E);

  static Color forCategory(IncidentCategory category) => switch (category) {
        IncidentCategory.robbery => categoryRobbery,
        IncidentCategory.fire => categoryFire,
        IncidentCategory.medical => categoryMedical,
        IncidentCategory.accident => categoryAccident,
        IncidentCategory.domestic => categoryDomestic,
        IncidentCategory.suspicious => categorySuspicious,
        IncidentCategory.assault => categoryAssault,
        IncidentCategory.fight => categoryFight,
        IncidentCategory.missing => categoryMissing,
        IncidentCategory.flood => categoryFlood,
        IncidentCategory.other => categoryOther,
      };

  static Color forPriority(IncidentPriority priority) => switch (priority) {
        IncidentPriority.low => priorityLow,
        IncidentPriority.normal => priorityNormal,
        IncidentPriority.high => priorityHigh,
        IncidentPriority.urgent => priorityUrgent,
      };

  static Color forStatus(IncidentStatus status) => switch (status) {
        IncidentStatus.pending => statusPending,
        IncidentStatus.assigned => statusAssigned,
        IncidentStatus.inProgress => statusInProgress,
        IncidentStatus.resolved => statusResolved,
        IncidentStatus.closed => statusClosed,
        IncidentStatus.duplicate => statusDuplicate,
      };

  static Color forSeverity(AlertSeverity severity) => switch (severity) {
        AlertSeverity.info => alertInfo,
        AlertSeverity.warning => alertWarning,
        AlertSeverity.critical => alertCritical,
      };
}

ThemeData buildAppTheme({Brightness brightness = Brightness.light}) {
  final isDark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: brightness,
  ).copyWith(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    surface: isDark ? const Color(0xFF1C1B1F) : AppColors.surface,
    onSurface: isDark ? const Color(0xFFE6E1E5) : AppColors.ink,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: isDark ? const Color(0xFF121212) : AppColors.background,
    appBarTheme: AppBarTheme(
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      titleTextStyle: const TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      color: isDark ? const Color(0xFF2A292E) : Colors.white,
      elevation: 1,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(52),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        side: const BorderSide(color: AppColors.primary),
        minimumSize: const Size.fromHeight(48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: isDark ? const Color(0xFF2A292E) : Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDADADA)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFDADADA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: isDark ? const Color(0xFF1C1B1F) : Colors.white,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        final selected = states.contains(WidgetState.selected);
        return TextStyle(
          fontSize: 12,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
          color: selected ? AppColors.primary : AppColors.muted,
        );
      }),
    ),
  );
}

/// Dark variant used when the user toggles dark mode in Settings.
ThemeData buildDarkAppTheme() => buildAppTheme(brightness: Brightness.dark);