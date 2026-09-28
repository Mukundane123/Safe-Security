import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../repositories/repository.dart';
import '../repositories/repository_exception.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import 'incident_detail_screen.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  /// Best-effort deep link that opens the incident the notification refers to.
  Future<void> _openLinkedIncident(
      BuildContext context, IRepository repo, String entityId) async {
    try {
      final incidents = await repo.watchAllIncidents().first;
      final match =
          incidents.where((i) => i.incidentId == entityId).firstOrNull;
      if (match == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IncidentDetailScreen(incident: match),
        ),
      );
    } catch (_) {
      // Deep linking is best-effort; ignore errors.
    }
  }

  IconData _iconFor(NotificationType type) => switch (type) {
        NotificationType.sos => Icons.sos,
        NotificationType.incidentUpdate => Icons.update,
        NotificationType.assignment => Icons.assignment_ind,
        NotificationType.communityAlert => Icons.campaign_outlined,
      };

  Color _colorFor(NotificationType type) => switch (type) {
        NotificationType.sos => const Color(0xFFB3261E),
        NotificationType.incidentUpdate => const Color(0xFF1B5E8A),
        NotificationType.assignment => const Color(0xFF6A1B9A),
        NotificationType.communityAlert => const Color(0xFFEF6C00),
      };

  /// Delivery feedback: a push that never reached the device must be visible,
  /// otherwise a user can silently miss an SOS or a status change.
  Widget _deliveryRow(
      BuildContext context, IRepository repo, AppNotification n) {
    late final IconData icon;
    late final String label;
    late final Color color;
    switch (n.deliveryStatus) {
      case DeliveryStatus.failed:
        icon = Icons.error_outline;
        label = 'Not delivered to this device';
        color = AppColors.primary;
      case DeliveryStatus.pending:
        icon = Icons.schedule;
        label = 'Sending...';
        color = AppColors.muted;
      case DeliveryStatus.delivered:
        return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Expanded(
            child: Text(label,
                style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          ),
          if (n.deliveryStatus == DeliveryStatus.failed)
            TextButton(
              onPressed: () => repo.resendNotification(n.notificationId).catchError((Object e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(RepositoryException.messageOf(e))),
                );
              }),
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              child: const Text('Retry', style: TextStyle(fontSize: 12)),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: StreamBuilder<List<AppNotification>>(
        stream: repo.watchNotifications(),
        builder: (context, snapshot) {
          final notifications = snapshot.data;
          if (notifications == null) return const LoadingScreen();
          if (notifications.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none,
              title: 'No notifications',
              message:
                  'SOS alerts, report updates, assignments and community alerts will appear here.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 0),
            itemBuilder: (context, index) {
              final n = notifications[index];
              return ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _colorFor(n.type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(_iconFor(n.type),
                      color: _colorFor(n.type), size: 22),
                ),
                title: Text(
                  n.title,
                  style: TextStyle(
                    fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                    color: AppColors.ink,
                  ),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 2),
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      Formatters.relative(n.sentAt),
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted),
                    ),
                    _deliveryRow(context, repo, n),
                  ],
                ),
                trailing: n.isRead
                    ? null
                    : Container(
                        width: 10,
                        height: 10,
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                onTap: () {
                  if (!n.isRead) repo.markNotificationRead(n.notificationId);
                  final entityId = n.relatedEntityId;
                  if (entityId == null || n.type == NotificationType.communityAlert) {
                    return;
                  }
                  _openLinkedIncident(context, repo, entityId);
                },
              );
            },
          );
        },
      ),
    );
  }
}
