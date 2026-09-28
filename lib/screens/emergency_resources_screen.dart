import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/emergency_resource.dart';
import '../repositories/repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';
import '../widgets/incident_map.dart';

/// Directory of static emergency facilities around Kakoba: hospitals, police
/// posts, fire stations, safe havens and rally points, with one-tap dialling
/// and directions.
class EmergencyResourcesScreen extends StatelessWidget {
  final EmergencyResourceType? filter;
  const EmergencyResourcesScreen({super.key, this.filter});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency facilities'),
        bottom: filter == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(44),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Showing ${filter!.label.toLowerCase()}s',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ),
                ),
              ),
      ),
      body: StreamBuilder<List<EmergencyResource>>(
        stream: repo.watchEmergencyResources(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load the directory',
            );
          }
          final all = snapshot.data;
          if (all == null) return const LoadingScreen();
          final resources =
              filter == null ? all : all.where((r) => r.type == filter).toList();

          if (resources.isEmpty) {
            return const EmptyState(
              icon: Icons.local_hospital_outlined,
              title: 'No facilities listed',
              message:
                  'Facilities around Kakoba Division appear here once an '
                  'administrator adds them to the emergency_resources collection.',
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: IncidentMap(
                  incidents: const [],
                  resources: resources,
                  height: 220,
                ),
              ),
              for (final type in EmergencyResourceType.values)
                if (filter == null &&
                    resources.any((r) => r.type == type)) ...[
                  SectionHeader('${type.label}s'),
                  for (final r in resources.where((r) => r.type == type))
                    _ResourceTile(resource: r),
                ],
              if (filter != null)
                for (final r in resources) _ResourceTile(resource: r),
            ],
          );
        },
      ),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final EmergencyResource resource;
  const _ResourceTile({required this.resource});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
        child: Icon(_iconFor(resource.type), color: AppColors.secondary),
      ),
      title: Text(resource.name,
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        [
          resource.type.label,
          if (resource.openHours != null) resource.openHours!,
          if (resource.description != null) resource.description!,
          Formatters.coords(resource.latitude, resource.longitude),
        ].join(' - '),
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (resource.phone != null)
            IconButton(
              tooltip: 'Call',
              icon: const Icon(Icons.call, color: AppColors.primary),
              onPressed: () => _call(resource.phone!),
            ),
          IconButton(
            tooltip: 'Directions',
            icon: const Icon(Icons.directions, color: AppColors.secondary),
            onPressed: () => _directions(),
          ),
        ],
      ),
    );
  }

  Future<void> _call(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone.replaceAll(RegExp(r'[\s-]'), ''));
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('Could not dial $phone: $e');
    }
  }

  Future<void> _directions() async {
    final uri = Uri.parse('google.navigation:q=${resource.latitude},'
        '${resource.longitude}&mode=d');
    final fallback = Uri.parse('https://www.google.com/maps/dir/?api=1'
        '&destination=${resource.latitude},${resource.longitude}');
    try {
      if (!await launchUrl(uri) && !await launchUrl(fallback)) {
        throw StateError('No maps app available');
      }
    } catch (e) {
      debugPrint('Could not open directions: $e');
    }
  }

  static IconData _iconFor(EmergencyResourceType type) => switch (type) {
        EmergencyResourceType.hospital => Icons.local_hospital,
        EmergencyResourceType.police => Icons.local_police,
        EmergencyResourceType.fire => Icons.local_fire_department,
        EmergencyResourceType.safeHaven => Icons.home_work,
        EmergencyResourceType.rallyPoint => Icons.groups,
      };
}
