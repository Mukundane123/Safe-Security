import 'package:flutter/material.dart';

import '../models/incident.dart';
import '../theme/app_theme.dart';

class StatusChip extends StatelessWidget {
  final IncidentStatus status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    return _Chip(
      color: AppColors.forStatus(status),
      label: status.label,
    );
  }
}

class PriorityChip extends StatelessWidget {
  final IncidentPriority priority;
  const PriorityChip(this.priority, {super.key});

  @override
  Widget build(BuildContext context) {
    return _Chip(
      color: AppColors.forPriority(priority),
      label: priority.label,
    );
  }
}

class _Chip extends StatelessWidget {
  final Color color;
  final String label;
  const _Chip({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}