import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/incident.dart';
import '../../repositories/repository.dart';
import '../../widgets/common.dart';
import '../../widgets/incident_card.dart';
import '../incident_detail_screen.dart';

class AdminIncidentsScreen extends StatefulWidget {
  const AdminIncidentsScreen({super.key});

  @override
  State<AdminIncidentsScreen> createState() => _AdminIncidentsScreenState();
}

class _AdminIncidentsScreenState extends State<AdminIncidentsScreen> {
  String _filter = 'all';

  static const _filters = [
    ('all', 'All'),
    ('pending', 'Pending'),
    ('assigned', 'Assigned'),
    ('in_progress', 'In progress'),
    ('resolved', 'Resolved'),
  ];

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('All incidents')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final (value, label) in _filters)
                  Padding(
                    padding: const EdgeInsets.only(right: 8, top: 8),
                    child: FilterChip(
                      label: Text(label),
                      selected: _filter == value,
                      onSelected: (_) =>
                          setState(() => _filter = value),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Incident>>(
              stream: repo.watchAllIncidents(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const EmptyState(
                    icon: Icons.error_outline,
                    title: 'Could not load incidents',
                  );
                }
                final incidents = snapshot.data;
                if (incidents == null) return const LoadingScreen();
                final filtered = _filter == 'all'
                    ? incidents
                    : incidents
                        .where((i) => i.status.value == _filter)
                        .toList();
                if (filtered.isEmpty) {
                  return const EmptyState(
                    icon: Icons.list_alt,
                    title: 'No incidents in this view',
                    message: 'Reports submitted by citizens appear here.',
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.only(bottom: 16, top: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final incident = filtered[index];
                    return IncidentCard(
                      incident: incident,
                      subtitleExtra: incident.reporterName,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              IncidentDetailScreen(incident: incident),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}