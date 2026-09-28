import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/incident.dart';
import '../repositories/repository.dart';
import '../state/providers.dart';
import '../widgets/common.dart';
import '../widgets/incident_card.dart';
import 'incident_detail_screen.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();
    final userId = context.auth.user!.userId;
    return Scaffold(
      appBar: AppBar(title: const Text('My reports')),
      body: StreamBuilder<List<Incident>>(
        stream: repo.watchMyIncidents(userId),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load reports',
            );
          }
          final incidents = snapshot.data;
          if (incidents == null) return const LoadingScreen();
          if (incidents.isEmpty) {
            return const EmptyState(
              icon: Icons.report_gmailerrorred_outlined,
              title: 'No reports yet',
              message:
                  'When you report an incident it will appear here with its status.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: incidents.length,
            itemBuilder: (context, index) {
              final incident = incidents[index];
              return IncidentCard(
                incident: incident,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => IncidentDetailScreen(incident: incident),
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