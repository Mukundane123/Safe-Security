import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/community_alert.dart';
import '../repositories/repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/category_icon.dart';
import '../widgets/common.dart';

class CommunityAlertsScreen extends StatelessWidget {
  const CommunityAlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Community alerts')),
      body: StreamBuilder<List<CommunityAlert>>(
        stream: repo.watchCommunityAlerts(),
        builder: (context, snapshot) {
          final alerts = snapshot.data;
          if (alerts == null) return const LoadingScreen();
          if (alerts.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No active alerts',
              message:
                  'Verified alerts from the community administration appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: alerts.length,
            itemBuilder: (context, index) {
              final alert = alerts[index];
              final color = AppColors.forSeverity(alert.severity);
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          SeverityIcon(alert.severity),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              alert.title,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(alert.body,
                          style: const TextStyle(fontSize: 14, height: 1.4)),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Icon(Icons.place_outlined,
                              size: 14, color: AppColors.muted),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${alert.area} \u2022 Expires ${Formatters.relative(alert.expiresAt)}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.muted,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              alert.severity.label,
                              style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}