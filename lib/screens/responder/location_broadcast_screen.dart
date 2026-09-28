import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import '../../repositories/repository.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';

/// Lets a responder broadcast their live position so citizens and the admin
/// can see responding teams on the incident map. Stops broadcasting when the
/// screen closes unless the switch is kept on for a session.
class LocationBroadcastScreen extends StatefulWidget {
  const LocationBroadcastScreen({super.key});

  @override
  State<LocationBroadcastScreen> createState() => _LocationBroadcastScreenState();
}

class _LocationBroadcastScreenState extends State<LocationBroadcastScreen> {
  final _locationService = const LocationService();
  Timer? _timer;
  bool _broadcasting = false;
  Position? _position;
  DateTime? _lastUpdate;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    if (_broadcasting) {
      context.read<IRepository>().updateResponderLocation(
        broadcasting: false,
        latitude: _position?.latitude ?? 0,
        longitude: _position?.longitude ?? 0,
      );
    }
    super.dispose();
  }

  Future<void> _refresh() async {
    final pos = await _locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _position = pos;
      _lastUpdate = DateTime.now();
    });
  }

  Future<void> _toggle(bool on) async {
    if (on) {
      await _refresh();
      await _post(false);
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 8), (_) => _post(true));
    } else {
      _timer?.cancel();
      await _post(false);
    }
    if (!mounted) return;
    setState(() => _broadcasting = on);
  }

  Future<void> _post(bool broadcast) async {
    final pos = _position;
    await context.read<IRepository>().updateResponderLocation(
      broadcasting: broadcast,
      latitude: pos?.latitude ?? 0,
      longitude: pos?.longitude ?? 0,
    );
    if (broadcast && mounted) {
      setState(() => _lastUpdate = DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Share my location')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: SwitchListTile(
              value: _broadcasting,
              onChanged: _toggle,
              activeTrackColor: AppColors.primary,
              title: const Text('Broadcast live position',
                  style: TextStyle(fontWeight: FontWeight.w700)),
              subtitle: const Text(
                  'Appear on the incident map so citizens and admins can see you respond.'),
              secondary: const Icon(Icons.radar, color: AppColors.secondary),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _infoRow(
                    Icons.place_outlined,
                    _position == null
                        ? 'Waiting for GPS...'
                        : '${_position!.latitude.toStringAsFixed(5)}, '
                            '${_position!.longitude.toStringAsFixed(5)}',
                  ),
                  const SizedBox(height: 12),
                  _infoRow(
                    Icons.schedule,
                    _lastUpdate == null
                        ? 'Not broadcasting'
                        : 'Last updated ${_lastUpdate!.hour}:'
                            '${_lastUpdate!.minute.toString().padLeft(2, '0')}',
                  ),
                  const SizedBox(height: 12),
                  _infoRow(
                    Icons.wifi,
                    _broadcasting ? 'Visible to citizens and admins' : 'Hidden',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tip: keep this crash-course demonstration friendly - position is '
            'refreshed every few seconds. Broadcasting stops when you leave this screen.',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.secondary),
        const SizedBox(width: 10),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 14))),
      ],
    );
  }
}