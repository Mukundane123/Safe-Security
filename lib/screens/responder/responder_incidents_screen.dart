import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/incident.dart';
import '../../repositories/repository.dart';
import '../../state/auth_controller.dart';
import '../../widgets/common.dart';
import '../../widgets/incident_card.dart';
import '../incident_detail_screen.dart';

class ResponderIncidentsScreen extends StatelessWidget {
  const ResponderIncidentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();
    final responderId = context.watch<AuthController>().user!.userId;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Assigned incidents'),
      ),
      body: StreamBuilder<List<Incident>>(
        stream: repo.watchAssignedIncidents(responderId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load incidents',
            );
          }
          final incidents = snapshot.data;
          if (incidents == null) return const LoadingScreen();
          final open = incidents
              .where((i) => i.status != IncidentStatus.resolved &&
                  i.status != IncidentStatus.closed)
              .length;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              _summary(incidents.length, open, incidents),
              if (incidents.isEmpty)
                const EmptyState(
                  icon: Icons.assignment_outlined,
                  title: 'No assignments yet',
                  message:
                      'Incidents assigned to you by the administrator will appear here.',
                )
              else
                for (final incident in incidents)
                  IncidentCard(
                    incident: incident,
                    subtitleExtra:
                        incident.assignedResponderName ?? 'unassigned',
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            IncidentDetailScreen(incident: incident),
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  Widget _summary(int total, int open, List<Incident> incidents) {
    final urgent = incidents
        .where((i) => i.priority == IncidentPriority.urgent &&
            i.status != IncidentStatus.resolved &&
            i.status != IncidentStatus.closed)
        .length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCard(
              label: 'Open',
              value: '$open',
              color: const Color(0xFFEF6C00),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'Urgent',
              value: '$urgent',
              color: const Color(0xFFB3261E),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _SummaryCard(
              label: 'Total',
              value: '$total',
              color: const Color(0xFF1B5E8A),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          Text(label,
              style:
                  const TextStyle(fontSize: 12, color: Color(0xFF6B6A6F))),
        ],
      ),
    );
  }
}