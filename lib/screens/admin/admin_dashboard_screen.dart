import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/incident.dart';
import '../../repositories/repository.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/incident_card.dart';
import '../incident_detail_screen.dart';
import 'admin_broadcast_screen.dart';
import 'admin_incidents_screen.dart';
import 'admin_users_screen.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Administrator dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_outlined),
            tooltip: 'Broadcast alert',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AdminBroadcastScreen()),
            ),
          ),
        ],
      ),
      body: StreamBuilder<List<Incident>>(
        stream: repo.watchAllIncidents(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load analytics',
            );
          }
          final incidents = snapshot.data;
          if (incidents == null) return const LoadingScreen();
          return RefreshIndicator(
            onRefresh: () =>
                Future.delayed(const Duration(milliseconds: 400)),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                _statCards(incidents),
                _categoryChart(context, incidents),
                _statusChart(context, incidents),
                _hotspots(incidents),
                _quickLinks(context),
                _recent(context, incidents),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _statCards(List<Incident> incidents) {
    final total = incidents.length;
    final open = incidents
        .where((i) => i.status != IncidentStatus.resolved &&
            i.status != IncidentStatus.closed &&
            i.status != IncidentStatus.duplicate)
        .length;
    final resolved = incidents
        .where((i) => i.status == IncidentStatus.resolved)
        .length;
    final resolvedWithTime = incidents
        .where((i) =>
            i.status == IncidentStatus.resolved && i.resolvedDate != null)
        .toList();
    final avgMinutes = resolvedWithTime.isEmpty
        ? 0
        : (resolvedWithTime
                    .map((i) => i.resolvedDate!
                        .difference(i.reportedDate)
                        .inMinutes)
                    .reduce((a, b) => a + b) /
                resolvedWithTime.length)
            .round();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overview',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 10),
          Row(
            children: [
              _stat('$total', 'Total'),
              _stat('$open', 'Open'),
              _stat('$resolved', 'Resolved'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _stat(avgMinutes <= 0 ? '--' : '$avgMinutes', 'Avg response (min)'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String value, String label) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              Text(label,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.muted)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoryChart(BuildContext context, List<Incident> incidents) {
    final counts = <IncidentCategory, int>{};
    for (final i in incidents) {
      counts[i.category] = (counts[i.category] ?? 0) + 1;
    }
    final entries = counts.entries.toList();
    if (entries.isEmpty) return const SizedBox.shrink();
    return _ChartCard(
      title: 'Incidents by category',
      legend: _legend(
        entries.map((e) => (e.key.label, AppColors.forCategory(e.key))).toList(),
      ),
      child: SizedBox(
        height: 220,
        child: PieChart(
          PieChartData(
            sectionsSpace: 2,
            centerSpaceRadius: 40,
            sections: [
              for (final entry in entries)
                PieChartSectionData(
                  value: entry.value.toDouble(),
                  title: '${entry.value}',
                  radius: 46,
                  color: AppColors.forCategory(entry.key),
                  titleStyle: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statusChart(BuildContext context, List<Incident> incidents) {
    final counts = <IncidentStatus, int>{};
    for (final i in incidents) {
      counts[i.status] = (counts[i.status] ?? 0) + 1;
    }
    const order = [
      IncidentStatus.pending,
      IncidentStatus.assigned,
      IncidentStatus.inProgress,
      IncidentStatus.resolved,
      IncidentStatus.closed,
      IncidentStatus.duplicate,
    ];
    final data = order
        .map((s) => (s, counts[s] ?? 0))
        .where((e) => e.$2 > 0)
        .toList();
    if (data.isEmpty) return const SizedBox.shrink();
    return _ChartCard(
      title: 'Incidents by status',
      child: SizedBox(
        height: 180,
        child: BarChart(
          BarChartData(
            alignment: BarChartAlignment.spaceAround,
            borderData: FlBorderData(show: false),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(
                sideTitles: const SideTitles(showTitles: false),
              ),
              topTitles: AxisTitles(
                sideTitles: const SideTitles(showTitles: false),
              ),
              rightTitles: AxisTitles(
                sideTitles: const SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (v, meta) {
                    final index = v.toInt();
                    if (index < 0 || index >= data.length) {
                      return const SizedBox.shrink();
                    }
                    final label = compactStatusLabel(data[index].$1);
                    return Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(label,
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.muted)),
                    );
                  },
                ),
              ),
            ),
            gridData: const FlGridData(show: false),
            barGroups: [
              for (var i = 0; i < data.length; i++)
                BarChartGroupData(
                  x: i,
                  barRods: [
                    BarChartRodData(
                      toY: data[i].$2.toDouble(),
                      color: AppColors.forStatus(data[i].$1),
                      width: 22,
                      borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(6)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  String compactStatusLabel(IncidentStatus s) => switch (s) {
        IncidentStatus.pending => 'Pend',
        IncidentStatus.assigned => 'Assign',
        IncidentStatus.inProgress => 'InProg',
        IncidentStatus.resolved => 'Resolv',
        IncidentStatus.closed => 'Closed',
        IncidentStatus.duplicate => 'Dup',
      };

  Widget _hotspots(List<Incident> incidents) {
    final counts = <String, int>{};
    for (final i in incidents) {
      final label = i.locationLabel.isEmpty ? 'Unknown' : i.locationLabel;
      counts[label] = (counts[label] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).toList();
    if (top.isEmpty) return const SizedBox.shrink();
    return _ChartCard(
      title: 'Frequently reported areas',
      child: Column(
        children: [
          for (final entry in top)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.place_outlined,
                  color: AppColors.primary),
              title: Text(entry.key),
              trailing: Text(
                '${entry.value}',
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }

  Widget _legend(List<(String, Color)> items) {
    return Wrap(
      spacing: 12,
      runSpacing: 6,
      children: [
        for (final (label, color) in items)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 12)),
            ],
          ),
      ],
    );
  }

  Widget _quickLinks(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminIncidentsScreen()),
              ),
              icon: const Icon(Icons.list_alt),
              label: const Text('Manage incidents'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
              ),
              icon: const Icon(Icons.people_outline),
              label: const Text('Manage users'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _recent(BuildContext context, List<Incident> incidents) {
    final recent = incidents.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text('Latest incidents',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        ),
        for (final incident in recent)
          IncidentCard(
            incident: incident,
            subtitleExtra: incident.reporterName,
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

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? legend;
  const _ChartCard({required this.title, required this.child, this.legend});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            const SizedBox(height: 12),
            child,
            if (legend != null) ...[
              const SizedBox(height: 10),
              legend!,
            ],
          ],
        ),
      ),
    );
  }
}