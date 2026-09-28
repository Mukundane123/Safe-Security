import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/community_alert.dart';
import '../../models/incident.dart';
import '../../repositories/repository.dart';
import '../../state/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/common.dart';
import '../../widgets/incident_card.dart';
import '../community_alerts_screen.dart';
import '../incident_detail_screen.dart';
import '../my_reports_screen.dart';
import 'report_incident_screen.dart';
import 'sos_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final repo = context.watch<IRepository>();
    final user = auth.user!;
    final first = (user.name.isNotEmpty ? user.name.split(' ').first : 'there');

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SafeGuard'),
            Text(
              'Welcome back, $first',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CommunityAlertsScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Incident>>(
        stream: repo.watchMyIncidents(user.userId),
        builder: (context, snapshot) {
          final incidents = snapshot.data ?? const <Incident>[];
          return RefreshIndicator(
            onRefresh: () => Future.delayed(
                const Duration(milliseconds: 400)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.add_alert,
                          label: 'Report\nincident',
                          color: const Color(0xFF1B5E8A),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReportIncidentScreen(),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _QuickAction(
                          icon: Icons.sos,
                          label: 'Send\nSOS',
                          color: const Color(0xFFB3261E),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SosScreen()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                _statsRow(incidents),
                const SizedBox(height: 8),
                _recentAlerts(context),
                _recentReports(context, incidents),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statsRow(List<Incident> incidents) {
    final total = incidents.length;
    final resolved = incidents
        .where((i) => i.status == IncidentStatus.resolved ||
            i.status == IncidentStatus.closed)
        .length;
    final pending =
        incidents.where((i) => i.status == IncidentStatus.pending).length;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          _StatTile('Total', '$total'),
          _StatTile('Pending', '$pending'),
          _StatTile('Resolved', '$resolved'),
        ],
      ),
    );
  }

  Widget _recentAlerts(BuildContext context) {
    final repo = context.watch<IRepository>();
    return StreamBuilder<List<CommunityAlert>>(
      stream: repo.watchCommunityAlerts(),
      builder: (context, snapshot) {
        final alerts = snapshot.data ?? const <CommunityAlert>[];
        final recent = alerts.take(2).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeader(
              'Community alerts',
              actionLabel: 'View all',
              onAction: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const CommunityAlertsScreen()),
              ),
            ),
            if (recent.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No active alerts for your area.'),
                ),
              )
            else
              for (final alert in recent)
                Card(
                  child: ListTile(
                    leading: SeverityIcon(alert.severity),
                    title: Text(alert.title,
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text(
                      '${alert.area} \u2022 ${Formatters.relative(alert.issuedAt)}',
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CommunityAlertsScreen(),
                      ),
                    ),
                  ),
                ),
          ],
        );
      },
    );
  }

  Widget _recentReports(BuildContext context, List<Incident> incidents) {
    final recent = incidents.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          'My recent reports',
          actionLabel: recent.isNotEmpty ? 'See all' : null,
          onAction: recent.isEmpty
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MyReportsScreen()),
                  ),
        ),
        if (incidents.isEmpty)
          const EmptyState(
            icon: Icons.report_gmailerrorred_outlined,
            title: 'No reports yet',
            message:
                'Tap \u201cReport incident\u201d to tell responders what is happening.',
          )
        else
          for (final incident in recent)
            IncidentCard(
              incident: incident,
              showPriority: false,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IncidentDetailScreen(incident: incident),
                ),
              ),
            ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        height: 96,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, color.withValues(alpha: 0.78)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 32),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  const _StatTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                ),
              ),
              Text(label,
                  style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }
}