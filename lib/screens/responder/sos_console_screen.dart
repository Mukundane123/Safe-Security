import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/sos_alert.dart';
import '../../models/sos_location.dart';
import '../../repositories/repository.dart';
import '../../repositories/repository_exception.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../utils/navigation.dart';
import '../../widgets/common.dart';
import '../../widgets/incident_map.dart';

/// Live console for responders and administrators: every SOS alert raised in
/// the division, with the sender's live trail and one-tap status changes.
class SosConsoleScreen extends StatelessWidget {
  final bool activeOnly;
  const SosConsoleScreen({super.key, this.activeOnly = true});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SOS console'),
        actions: [
          StreamBuilder<List<SosAlert>>(
            stream: repo.watchSosAlerts(),
            builder: (context, snapshot) {
              final active = snapshot.data
                      ?.where((s) => s.status == SosStatus.active)
                      .length ??
                  0;
              return Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Center(
                  child: active == 0
                      ? const Text('None active')
                      : Chip(
                          avatar: const Icon(Icons.sos, size: 18),
                          label: Text('$active active'),
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.15),
                        ),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<SosAlert>>(
        stream: repo.watchSosAlerts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load SOS alerts',
              message: RepositoryException.messageOf(snapshot.error!),
            );
          }
          final alerts = snapshot.data;
          if (alerts == null) return const LoadingScreen();
          final visible = activeOnly
              ? alerts.where((s) => s.status == SosStatus.active).toList()
              : alerts;

          if (visible.isEmpty) {
            return const EmptyState(
              icon: Icons.shield_outlined,
              title: 'No SOS alerts',
              message:
                  'Distress alerts raised by citizens appear here immediately, '
                  'with their live location.',
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.only(bottom: 24),
            itemCount: visible.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) => _SosTile(
              alert: visible[i],
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => SosDetailScreen(sosId: visible[i].sosId),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Single alert: map, live trail, notification fan-out and status actions.
class SosDetailScreen extends StatelessWidget {
  final String sosId;
  const SosDetailScreen({super.key, required this.sosId});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();

    return Scaffold(
      appBar: AppBar(title: const Text('SOS alert')),
      body: StreamBuilder<List<SosAlert>>(
        stream: repo.watchSosAlerts(),
        builder: (context, snapshot) {
          final alerts = snapshot.data ?? const <SosAlert>[];
          SosAlert? match;
          for (final a in alerts) {
            if (a.sosId == sosId) match = a;
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const LoadingScreen();
          }
          if (match == null) {
            return const EmptyState(
              icon: Icons.help_outline,
              title: 'Alert not found',
            );
          }
          return _body(context, repo, match);
        },
      ),
    );
  }

  Widget _body(BuildContext context, IRepository repo, SosAlert sos) {
    return StreamBuilder<List<SosLocationUpdate>>(
      stream: repo.watchSosLocations(sos.sosId),
      builder: (context, snapshot) {
        final trail = snapshot.data ?? const <SosLocationUpdate>[];
        final SosLocationUpdate latest = trail.isEmpty
            ? SosLocationUpdate(
                sosId: sos.sosId,
                latitude: sos.latitude,
                longitude: sos.longitude,
                capturedAt: sos.triggeredAt,
              )
            : trail.last;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            IncidentMap(
              incidents: const [],
              sosAlerts: [sos],
              sosTrail: trail,
              centerLatitude: latest.latitude,
              centerLongitude: latest.longitude,
              height: 280,
            ),
            const SizedBox(height: 16),
            _header(sos, trail.length),
            const SizedBox(height: 12),
            if (sos.note != null && sos.note!.isNotEmpty) _note(sos.note!),
            const SizedBox(height: 12),
            _distanceTo(latest),
            const SizedBox(height: 12),
            _notified(sos),
            const SizedBox(height: 16),
            _actions(context, repo, sos),
          ],
        );
      },
    );
  }

  Widget _header(SosAlert sos, int trailPoints) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person, color: AppColors.secondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sos.userName.isEmpty ? 'Unknown sender' : sos.userName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                ),
                _StatusChip(status: sos.status),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Raised ${Formatters.relative(sos.triggeredAt)} '
              '(${Formatters.time(sos.triggeredAt)})',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            Text(
              Formatters.coords(sos.latitude, sos.longitude),
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 6),
            Text(
              trailPoints > 1
                  ? 'Live trail: $trailPoints positions received'
                  : 'Waiting for live location updates...',
              style: const TextStyle(fontSize: 13, color: AppColors.secondary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _note(String note) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.notes, color: AppColors.secondary),
        title: const Text('Message from sender'),
        subtitle: Text(note),
      ),
    );
  }

  Widget _distanceTo(SosLocationUpdate latest) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.route, color: AppColors.secondary),
        title: const Text('Navigate to the sender'),
        subtitle: Text(
          'Last position ${Formatters.coords(latest.latitude, latest.longitude)} '
          'at ${Formatters.time(latest.capturedAt)}',
        ),
        trailing: const Icon(Icons.directions, color: AppColors.primary),
        onTap: () => openDirections(latest.latitude, latest.longitude),
      ),
    );
  }

  Widget _notified(SosAlert sos) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Notified (${sos.notifiedContacts.length + sos.notifiedResponders.length})',
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            if (sos.notifiedContacts.isEmpty && sos.notifiedResponders.isEmpty)
              const Text('No one was reached for this alert.',
                  style: TextStyle(color: AppColors.muted)),
            for (final c in sos.notifiedContacts)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline, size: 20),
                title: Text(c),
              ),
            for (final r in sos.notifiedResponders)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.emergency_outlined, size: 20),
                title: Text(r),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actions(BuildContext context, IRepository repo, SosAlert sos) {
    if (sos.status != SosStatus.active &&
        sos.status != SosStatus.acknowledged) {
      return OutlinedButton.icon(
        onPressed: () => Navigator.of(context).pop(),
        icon: const Icon(Icons.check),
        label: const Text('Close'),
      );
    }

    return Column(
      children: [
        Row(
          children: [
            if (sos.status == SosStatus.active)
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => _setStatus(context, repo, sos,
                      SosStatus.acknowledged.value, 'Acknowledged'),
                  icon: const Icon(Icons.pan_tool_alt_outlined),
                  label: const Text('Acknowledge'),
                ),
              ),
            if (sos.status == SosStatus.active) const SizedBox(width: 10),
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                ),
                onPressed: () => _setStatus(
                    context, repo, sos, SosStatus.resolved.value, 'Resolved'),
                icon: const Icon(Icons.task_alt),
                label: const Text('Resolve'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
          label: const Text('Back to console'),
        ),
      ],
    );
  }

  Future<void> _setStatus(
    BuildContext context,
    IRepository repo,
    SosAlert sos,
    String status,
    String verb,
  ) async {
    try {
      await repo.updateSosStatus(sos.sosId, status);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Alert $verb.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(RepositoryException.messageOf(e))),
      );
    }
  }

}

class _SosTile extends StatelessWidget {  final SosAlert alert;
  final VoidCallback onTap;
  const _SosTile({required this.alert, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: const CircleAvatar(
        backgroundColor: AppColors.primary,
        child: Icon(Icons.sos, color: Colors.white),
      ),
      title: Text(
        alert.userName.isEmpty ? 'Unknown sender' : alert.userName,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        '${Formatters.relative(alert.triggeredAt)} - '
        '${alert.note?.isNotEmpty == true ? alert.note! : 'No message'}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: _StatusChip(status: alert.status),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final SosStatus status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      SosStatus.active => AppColors.primary,
      SosStatus.acknowledged => const Color(0xFFEF6C00),
      SosStatus.resolved => const Color(0xFF2E7D32),
      SosStatus.cancelled => AppColors.muted,
    };
    final label = switch (status) {
      SosStatus.active => 'ACTIVE',
      SosStatus.acknowledged => 'ACK',
      SosStatus.resolved => 'RESOLVED',
      SosStatus.cancelled => 'CANCELLED',
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }
}
