import 'package:flutter/material.dart';

import '../models/incident.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import 'category_icon.dart';
import 'chips.dart';

class IncidentCard extends StatelessWidget {
  final Incident incident;
  final VoidCallback? onTap;
  final bool showPriority;
  final String? subtitleExtra;
  const IncidentCard({
    super.key,
    required this.incident,
    this.onTap,
    this.showPriority = true,
    this.subtitleExtra,
  });

  @override
  Widget build(BuildContext context) {
    final locationLine = incident.locationLabel.isEmpty
        ? Formatters.coords(incident.location.latitude, incident.location.longitude)
        : incident.locationLabel;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CategoryIcon(incident.category),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.category.label,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.place_outlined,
                            size: 14, color: AppColors.muted),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            locationLine,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.muted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      incident.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, color: AppColors.ink),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Text(
                          Formatters.relative(incident.reportedDate),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.muted,
                          ),
                        ),
                        if (subtitleExtra != null) ...[
                          const Text('  \u2022  ',
                              style: TextStyle(color: AppColors.muted)),
                          Expanded(
                            child: Text(
                              subtitleExtra!,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (showPriority) PriorityChip(incident.priority),
                  const SizedBox(height: 6),
                  StatusChip(incident.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}