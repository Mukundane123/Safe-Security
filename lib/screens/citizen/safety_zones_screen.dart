import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/safety_zone.dart';
import '../../repositories/repository.dart';
import '../../services/location_service.dart';
import '../../state/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

/// Lists the defined safety / high-risk zones. Administrators can add zones at
/// their current location or the division reference point.
class SafetyZonesScreen extends StatelessWidget {
  const SafetyZonesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthController>();
    final canManage = auth.isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety zones'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add zone',
              onPressed: () => _addZone(context),
            ),
        ],
      ),
      body: StreamBuilder<List<SafetyZone>>(
        stream: context.watch<IRepository>().watchSafetyZones(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
                icon: Icons.error_outline, title: 'Could not load zones');
          }
          final zones = snapshot.data;
          if (zones == null) return const LoadingScreen();
          if (zones.isEmpty) {
            return const EmptyState(
              icon: Icons.gpp_good_outlined,
              title: 'No safety zones yet',
              message: 'Zones highlight places that need extra caution.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: zones.length,
            itemBuilder: (context, index) {
              final zone = zones[index];
              return Card(
                child: ListTile(
                  leading: _riskIcon(zone.risk),
                  title: Text(zone.name,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      '${zone.risk.label} risk \u2022 ${zone.radiusMeters.round()} m radius'
                      '${zone.note == null ? '' : '\n${zone.note}'}'),
                  isThreeLine: zone.note != null,
                  trailing: canManage
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: AppColors.muted),
                          tooltip: 'Remove zone',
                          onPressed: () =>
                              context.read<IRepository>().removeSafetyZone(zone.zoneId),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }

  Widget _riskIcon(ZoneRisk risk) {
    final color = risk == ZoneRisk.high
        ? AppColors.primary
        : risk == ZoneRisk.normal
            ? AppColors.priorityNormal
            : AppColors.priorityLow;
    return CircleAvatar(
      backgroundColor: color.withValues(alpha: 0.12),
      child: Icon(
        risk == ZoneRisk.high
            ? Icons.warning_amber_rounded
            : Icons.info_outline,
        color: color,
      ),
    );
  }

  Future<void> _addZone(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final noteCtrl = TextEditingController();
    var radius = 300.0;
    var risk = ZoneRisk.normal;

    final pos = await const LocationService().getCurrentPosition();
    final lat = pos?.latitude ?? 0;
    final lng = pos?.longitude ?? 0;
    final hasFix = pos != null;
    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('Add a safety zone',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    hasFix
                        ? 'Will be placed at your current location'
                        : 'No GPS fix - will use the reference point (Kakoba).',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Zone name',
                        hintText: 'e.g. Nyaikona Market'),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                        labelText: 'Safety note (optional)'),
                  ),
                  const SizedBox(height: 12),
                  StatefulBuilder(
                    builder: (context, setSheetState) => Column(
                      children: [
                        Row(
                          children: [
                            const Text('Risk level:'),
                            const Spacer(),
                            for (final r in ZoneRisk.values)
                              Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                child: ChoiceChip(
                                  label: Text(r.label),
                                  selected: risk == r,
                                  onSelected: (_) =>
                                      setSheetState(() => risk = r),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Text('Radius:'),
                            Expanded(
                              child: Slider(
                                value: radius,
                                min: 100,
                                max: 1000,
                                divisions: 9,
                                label: '${radius.round()} m',
                                onChanged: (v) =>
                                    setSheetState(() => radius = v),
                              ),
                            ),
                            Text('${radius.round()} m'),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () async {
                      if (!formKey.currentState!.validate()) return;
                      final repo = context.read<IRepository>();
                      await repo.addSafetyZone(
                        name: nameCtrl.text,
                        latitude: hasFix ? lat : AppConfig.kakobaLatitude,
                        longitude: hasFix ? lng : AppConfig.kakobaLongitude,
                        radiusMeters: radius,
                        risk: risk.value,
                        note: noteCtrl.text.trim().isEmpty
                            ? null
                            : noteCtrl.text.trim(),
                      );
                      if (sheetContext.mounted) Navigator.pop(sheetContext);
                    },
                    child: const Text('Add zone'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}