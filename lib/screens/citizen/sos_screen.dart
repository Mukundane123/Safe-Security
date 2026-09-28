import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/app_config.dart';
import '../../models/sos_alert.dart';
import '../../models/sos_location.dart';
import '../../repositories/repository.dart';
import '../../repositories/repository_exception.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/incident_map.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({super.key});

  @override
  State<SosScreen> createState() => _SosScreenState();
}

enum _SosPhase { idle, counting, sending, sent }

class _SosScreenState extends State<SosScreen> {
  final _locationService = const LocationService();
  final _note = TextEditingController();

  _SosPhase _phase = _SosPhase.idle;
  int _count = 3;
  Timer? _timer;
  Timer? _shareTimer;
  SosAlert? _sent;
  bool _noteExpanded = false;

  @override
  void dispose() {
    _timer?.cancel();
    _shareTimer?.cancel();
    _note.dispose();
    super.dispose();
  }

  /// Pushes the current position every 20s while the alert is live so
  /// responders can follow the trail instead of converging on a stale point.
  void _startSharing(String sosId) {
    _shareTimer?.cancel();
    _shareTimer = Timer.periodic(const Duration(seconds: 20), (t) async {
      final repo = context.read<IRepository>();
      final position = await _locationService.getCurrentPosition();
      if (position == null) return;
      try {
        await repo.updateSosLocation(
          sosId,
          latitude: position.latitude,
          longitude: position.longitude,
        );
      } catch (e) {
        debugPrint('SOS location share failed: $e');
      }
    });
  }

  Future<void> _cancelAlert() async {
    final sos = _sent;
    if (sos == null) return;
    _shareTimer?.cancel();
    final repo = context.read<IRepository>();
    try {
      await repo.updateSosStatus(sos.sosId, SosStatus.cancelled.value);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('SOS alert cancelled.')),
      );
      setState(() {
        _phase = _SosPhase.idle;
        _sent = null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(RepositoryException.messageOf(e))),
      );
    }
  }

  void _startCountdown() {
    setState(() {
      _phase = _SosPhase.counting;
      _count = 3;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_count <= 1) {
        t.cancel();
        _send();
      } else {
        setState(() => _count--);
      }
    });
  }

  void _cancelCountdown() {
    _timer?.cancel();
    setState(() => _phase = _SosPhase.idle);
  }

  Future<void> _send() async {
    setState(() => _phase = _SosPhase.sending);
    final repo = context.read<IRepository>();
    final position = await _locationService.getCurrentPosition();
    try {
      final sos = await repo.triggerSos(
        latitude: position?.latitude ?? AppConfig.kakobaLatitude,
        longitude: position?.longitude ?? AppConfig.kakobaLongitude,
        note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      );
      if (!mounted) return;
      setState(() {
        _phase = _SosPhase.sent;
        _sent = sos;
      });
      if (sos.status == SosStatus.active) _startSharing(sos.sosId);
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _SosPhase.idle);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(RepositoryException.messageOf(e)),
        ),
      );
    }
  }

  Future<void> _call(String number) async {
    final uri = Uri(scheme: 'tel', path: number.replaceAll(RegExp(r'[\s-]'), ''));
    try {
      await launchUrl(uri);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not dial $number')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('SOS Emergency'),
      ),
      body: _phase == _SosPhase.sent
          ? _sentView(context)
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    _phase == _SosPhase.counting
                        ? 'Sending in $_count...'
                        : 'Hold to prepare',
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'One tap sends your live location to your trusted contacts '
                    'and nearby responders.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AppColors.muted),
                  ),
                  const SizedBox(height: 24),
                  _sosButton(context),
                  const SizedBox(height: 24),
                  _noteSection(context),
                  const SizedBox(height: 24),
                  _emergencyNumbers(),
                ],
              ),
            ),
    );
  }

  Widget _sosButton(BuildContext context) {
    if (_phase == _SosPhase.sending) {
      return const SizedBox(
        width: 220,
        height: 220,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return GestureDetector(
      onTap:
          _phase == _SosPhase.counting ? _cancelCountdown : _startCountdown,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 220,
        height: 220,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _phase == _SosPhase.counting
              ? AppColors.primary.withValues(alpha: 0.7)
              : AppColors.primary,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: _phase == _SosPhase.counting ? 40 : 20,
              spreadRadius: _phase == _SosPhase.counting ? 16 : 6,
            ),
          ],
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.6),
            width: 6,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_phase == _SosPhase.counting)
              Text(
                '$_count',
                style: const TextStyle(
                  fontSize: 72,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              )
            else ...[
              const Icon(Icons.sos, color: Colors.white, size: 96),
              const SizedBox(height: 8),
              const Text(
                'TAP TO SEND\nSOS',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _noteSection(BuildContext context) {
    return AnimatedCrossFade(
      duration: const Duration(milliseconds: 200),
      crossFadeState: _noteExpanded
          ? CrossFadeState.showSecond
          : CrossFadeState.showFirst,
      firstChild: OutlinedButton.icon(
        onPressed: () => setState(() => _noteExpanded = true),
        icon: const Icon(Icons.mic_none),
        label: const Text('Add a short note'),
      ),
      secondChild: TextField(
        controller: _note,
        maxLines: 2,
        decoration: const InputDecoration(
          labelText: 'Short message (optional)',
          hintText: 'e.g. I am being followed on Bwanga Street',
        ),
      ),
    );
  }

  Widget _emergencyNumbers() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Call directly',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            const Text(
              'If your connection fails, use these numbers immediately.',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            const SizedBox(height: 8),
            for (final e in kEmergencyNumbers)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone, color: AppColors.primary),
                title: Text('${e.label}: ${e.number}'),
                trailing: const Icon(Icons.call, size: 20),
                onTap: () => _call(e.number),
              ),
          ],
        ),
      ),
    );
  }

  Widget _sentView(BuildContext context) {
    final sos = _sent!;
    final repo = context.read<IRepository>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Icon(Icons.check_circle, color: Colors.green, size: 72),
        const SizedBox(height: 8),
        Text(
          'Your SOS alert was sent',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          'Sent ${Formatters.relative(sos.triggeredAt)} at '
          '${Formatters.coords(sos.latitude, sos.longitude)}.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.muted),
        ),
        const SizedBox(height: 12),
        StreamBuilder<List<SosLocationUpdate>>(
          stream: repo.watchSosLocations(sos.sosId),
          builder: (context, snapshot) {
            final trail = snapshot.data ?? const <SosLocationUpdate>[];
            if (trail.isEmpty) {
              return const Card(
                child: ListTile(
                  leading: Icon(Icons.my_location, color: AppColors.secondary),
                  title: Text('Sharing your live location'),
                  subtitle: Text(
                      'Your first position update is sent within 20 seconds. '
                      'Responders see the trail in real time.'),
                ),
              );
            }
            final last = trail.last;
            return Column(
              children: [
                IncidentMap(
                  incidents: const [],
                  sosAlerts: [sos],
                  sosTrail: trail,
                  centerLatitude: last.latitude,
                  centerLongitude: last.longitude,
                  height: 200,
                ),
                const SizedBox(height: 8),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.route, color: AppColors.secondary),
                    title: Text('${trail.length} positions shared'),
                    subtitle: Text(
                        'Last update ${Formatters.time(last.capturedAt)} at '
                        '${Formatters.coords(last.latitude, last.longitude)}'),
                  ),
                ),
              ],
            );
          },
        ),
        if (sos.notifiedContacts.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.people_outline,
                  color: AppColors.secondary),
              title: const Text('Trusted contacts notified'),
              subtitle: Text(sos.notifiedContacts.join(', ')),
            ),
          ),
        if (sos.notifiedResponders.isNotEmpty)
          Card(
            child: ListTile(
              leading: const Icon(Icons.emergency_outlined,
                  color: AppColors.secondary),
              title: const Text('Nearby responders notified'),
              subtitle: Text(sos.notifiedResponders.join(', ')),
            ),
          ),
        const SizedBox(height: 8),
        _emergencyNumbers(),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () => _call('112'),
          icon: const Icon(Icons.call),
          label: const Text('Call 112 emergency'),
        ),
        const SizedBox(height: 8),
        if (sos.status == SosStatus.active)
          OutlinedButton.icon(
            onPressed: _cancelAlert,
            icon: const Icon(Icons.check_circle_outline),
            label: const Text("I'm safe - cancel alert"),
          )
        else
          OutlinedButton(
            onPressed: () => setState(() {
              _phase = _SosPhase.idle;
              _sent = null;
            }),
            child: const Text('Done'),
          ),
      ],
    );
  }
}