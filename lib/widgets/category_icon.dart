import 'package:flutter/material.dart';

import '../models/community_alert.dart';
import '../models/incident.dart';
import '../theme/app_theme.dart';

IconData iconForCategory(IncidentCategory category) => switch (category) {
      IncidentCategory.robbery => Icons.paid,
      IncidentCategory.fire => Icons.local_fire_department,
      IncidentCategory.medical => Icons.medical_services,
      IncidentCategory.accident => Icons.car_crash,
      IncidentCategory.domestic => Icons.night_shelter,
      IncidentCategory.suspicious => Icons.visibility,
      IncidentCategory.assault => Icons.gpp_bad,
      IncidentCategory.fight => Icons.sports_kabaddi,
      IncidentCategory.missing => Icons.person_search,
      IncidentCategory.flood => Icons.water_damage,
      IncidentCategory.other => Icons.report,
    };

IconData iconForSeverity(AlertSeverity severity) => switch (severity) {
      AlertSeverity.info => Icons.info_outline,
      AlertSeverity.warning => Icons.warning_amber_rounded,
      AlertSeverity.critical => Icons.report_gmailerrorred,
    };

/// Round coloured icon used to represent an incident category or alert.
class CategoryIcon extends StatelessWidget {
  final IncidentCategory category;
  final double size;
  const CategoryIcon(this.category, {super.key, this.size = 44});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forCategory(category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(
        iconForCategory(category),
        color: color,
        size: size * 0.55,
      ),
    );
  }
}

class SeverityIcon extends StatelessWidget {
  final AlertSeverity severity;
  final double size;
  const SeverityIcon(this.severity, {super.key, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final color = AppColors.forSeverity(severity);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(
        iconForSeverity(severity),
        color: color,
        size: size * 0.55,
      ),
    );
  }
}