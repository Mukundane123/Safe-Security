import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../models/check_in.dart';
import '../../models/safety_zone.dart';
import '../../repositories/repository.dart';
import '../../services/location_service.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/geo.dart';

/// Safe check-in: the citizen broadcasts a live journey to trusted contacts,
/// sees their progress on a map with safety zones, and is warned if they enter
/// a high-risk zone or go past their expected arrival time.
class CheckInScreen extends StatefulWidget {
  const CheckInScreen({super.key});

  @override
  State<CheckInScreen> createState() => _CheckInScreenState();
}

class _CheckInScreenState extends State<CheckInScreen> {
  final _locationService = const LocationService();
  final _destinationCtrl = TextEditingController();
  Timer? _ticker;
  CheckIn? _active;
  Position? _position;
  bool _busy = false;
  final Set<String> _alertedZones = {};
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    for (final sub in _subs) {
      sub.cancel();
    }
    _destinationCtrl.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final repo = context.read<IRepository>();
    _subs.add(repo.watchCheckIns().listen((checkIns) {
      if (!mounted) return;
      final active =
          checkIns.where((c) => c.status == CheckInStatus.active).firstOrNull;
      setState(() => _active = active);
      if (active != null) {
        _startTicker();
      } else {
        _ticker?.cancel();
      }
    }));
    final pos = await _locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() => _position = pos);
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 8), (_) async {
      final active = _active;
      final pos = await _locationService.getCurrentPosition();
      if (!mounted) return;
      setState(() => _position = pos);
      if (pos != null && active != null && active.status == CheckInStatus.active) {
        await context.repo.updateCheckInLocation(
          active.checkInId,
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        _checkZones(pos.latitude, pos.longitude);
      }
    });
  }

  Future<void> _checkZones(double lat, double lng) async {
    final zones = await context.repo.watchSafetyZones().first;
    for (final zone in zones) {
      if (_alertedZones.contains(zone.zoneId) || !isWithinZone(lat, lng, zone)) {
        continue;
      }
      _alertedZones.add(zone.zoneId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: zone.risk == ZoneRisk.high
                ? AppColors.primary
                : AppColors.secondary,
            content: Text(
                '${zone.risk.label} zone: ${zone.name}. ${zone.note ?? ''}'),
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  Future<void> _start() async {
    final destination = _destinationCtrl.text.trim();
    if (destination.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final pos = await _locationService.getCurrentPosition();
      if (!mounted) return;
      await context.repo.startCheckIn(
        destination: destination,
        latitude: pos?.latitude ?? 0,
        longitude: pos?.longitude ?? 0,
        expectedMinutes: 30,
      );
      _destinationCtrl.clear();
      _startTicker();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Journey tracking started. Trusted contacts can now follow you.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _complete({required bool arrived}) async {
    final active = _active;
    if (active == null) return;
    _ticker?.cancel();
    await context.repo.completeCheckIn(active.checkInId, arrived: arrived);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              arrived ? 'Marked as arrived. Stay safe!' : 'Check-in cancelled.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final active = _active;
    return Scaffold(
      appBar: AppBar(title: const Text('Safe check-in')),
      body: active == null ? _startView() : _trackingView(active),
    );
  }

  Widget _startView() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.navigation, size: 56, color: AppColors.secondary),
        const SizedBox(height: 8),
        const Text(
          'Tell the community where you are going and how long it should take. '
          'If you are late or enter a flagged zone, trusted contacts get alerted.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _destinationCtrl,
          decoration: const InputDecoration(
            labelText: 'Destination',
            hintText: 'e.g. Home, Nyaikona Road',
            prefixIcon: Icon(Icons.place_outlined),
          ),
        ),
        const SizedBox(height: 16),
        StreamBuilder<List<SafetyZone>>(
          stream: context.repo.watchSafetyZones(),
          builder: (context, snapshot) {
            final zones = snapshot.data ?? const <SafetyZone>[];
            if (zones.isEmpty) return const SizedBox.shrink();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(Icons.gpp_good, size: 18, color: AppColors.secondary),
                        SizedBox(width: 6),
                        Text('Active safety zones',
                            style: TextStyle(fontWeight: FontWeight.w700)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    for (final zone in zones)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(
                              zone.risk == ZoneRisk.high
                                  ? Icons.warning_amber_rounded
                                  : Icons.info_outline,
                              size: 16,
                              color: zone.risk == ZoneRisk.high
                                  ? AppColors.primary
                                  : AppColors.secondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text('${zone.name} (${zone.risk.label})',
                                    style: const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: _busy ? null : _start,
          icon: const Icon(Icons.navigation),
          label: const Text('Start sharing my journey'),
        ),
      ],
    );
  }

  Widget _trackingView(CheckIn checkIn) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              const Icon(Icons.navigation, color: AppColors.secondary),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('In transit to',
                        style:
                            TextStyle(fontSize: 12, color: AppColors.muted)),
                    Text(checkIn.destination,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _overdueBanner(checkIn),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _buildMap(checkIn),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _complete(arrived: true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('I arrived safely'),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: () => _complete(arrived: false),
                icon: const Icon(Icons.close, color: AppColors.muted),
                tooltip: 'Cancel check-in',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overdueBanner(CheckIn checkIn) {
    final arrival = checkIn.expectedArrival.toLocal();
    final label = checkIn.isOverdue
        ? 'Past expected arrival time - your trusted contacts have been alerted.'
        : 'Expected arrival: ${arrival.hour}:'
            '${arrival.minute.toString().padLeft(2, '0')}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: checkIn.isOverdue
            ? AppColors.primary.withValues(alpha: 0.1)
            : AppColors.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(
            checkIn.isOverdue ? Icons.warning_amber_rounded : Icons.schedule,
            color: checkIn.isOverdue ? AppColors.primary : AppColors.secondary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(label, style: const TextStyle(fontSize: 13, height: 1.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildMap(CheckIn checkIn) {
    final wayPoints = checkIn.waypoints;
    final lat = _position?.latitude ??
        (wayPoints.isNotEmpty ? wayPoints.last.latitude : -0.6132);
    final lng = _position?.longitude ??
        (wayPoints.isNotEmpty ? wayPoints.last.longitude : 30.6651);
    return FlutterMap(
      options: MapOptions(
        initialCenter: LatLng(
          wayPoints.isNotEmpty ? wayPoints.last.latitude : -0.6132,
          wayPoints.isNotEmpty ? wayPoints.last.longitude : 30.6651,
        ),
        initialZoom: 14,
        interactionOptions: const InteractionOptions(
            flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.example.safesecurity',
          maxZoom: 19,
        ),
        StreamBuilder<List<SafetyZone>>(
          stream: context.repo.watchSafetyZones(),
          builder: (context, snapshot) {
            final zoneList = snapshot.data ?? const <SafetyZone>[];
            return CircleLayer(
              circles: [
                for (final zone in zoneList)
                  CircleMarker(
                    point: LatLng(zone.latitude, zone.longitude),
                    radius: zone.radiusMeters.toDouble(),
                    useRadiusInMeter: true,
                    color: (zone.risk == ZoneRisk.high
                            ? AppColors.primary
                            : AppColors.secondary)
                        .withValues(alpha: 0.15),
                    borderColor: (zone.risk == ZoneRisk.high
                            ? AppColors.primary
                            : AppColors.secondary)
                        .withValues(alpha: 0.5),
                    borderStrokeWidth: 2,
                  ),
              ],
            );
          },
        ),
        PolylineLayer(polylines: [
          if (wayPoints.length > 1)
            Polyline(
              points: [
                for (final w in wayPoints) LatLng(w.latitude, w.longitude)
              ],
              strokeWidth: 4,
              color: AppColors.secondary.withValues(alpha: 0.9),
            ),
        ]),
        MarkerLayer(markers: [
          Marker(
            point: LatLng(lat, lng),
            width: 40,
            height: 40,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.secondary,
                border: Border.all(color: Colors.white, width: 3),
              ),
              child:
                  const Icon(Icons.navigation, color: Colors.white, size: 20),
            ),
          ),
          if (wayPoints.isNotEmpty)
            Marker(
              point: LatLng(wayPoints.first.latitude, wayPoints.first.longitude),
              width: 36,
              height: 36,
              child: const Tooltip(
                message: 'Start',
                child: Icon(Icons.flag, color: AppColors.primary, size: 30),
              ),
            ),
        ]),
      ],
    );
  }
}