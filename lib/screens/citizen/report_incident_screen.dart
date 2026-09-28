import 'dart:io';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../models/incident.dart';
import '../../repositories/repository.dart';
import '../../repositories/repository_exception.dart';
import '../../services/location_service.dart';
import '../../services/offline_report_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/voice_note_recorder.dart';
import '../incident_detail_screen.dart';

class ReportIncidentScreen extends StatefulWidget {
  const ReportIncidentScreen({super.key});

  @override
  State<ReportIncidentScreen> createState() => _ReportIncidentScreenState();
}

class _ReportIncidentScreenState extends State<ReportIncidentScreen> {
  final _formKey = GlobalKey<FormState>();
  final _description = TextEditingController();
  final _picker = ImagePicker();
  final _locationService = const LocationService();

  IncidentCategory? _category;
  Position? _position;
  bool _locating = true;
  bool _submitting = false;
  final List<String> _photos = [];
  String? _voiceNotePath;
  int _offlinePending = 0;

  @override
  void initState() {
    super.initState();
    _obtainLocation();
    _refreshQueueCount();
  }

  Future<void> _refreshQueueCount() async {
    final repo = context.read<IRepository>();
    final offline = OfflineReportService(repo);
    final pending = await offline.pendingCount();
    if (!mounted) return;
    setState(() => _offlinePending = pending);
  }

  Future<void> _syncOffline() async {
    final repo = context.read<IRepository>();
    final offline = OfflineReportService(repo);
    final sent = await offline.flush();
    await _refreshQueueCount();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
            sent > 0 ? 'Synced $sent saved report(s).' : 'Still offline - report kept for later.'),
      ),
    );
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _obtainLocation() async {
    setState(() => _locating = true);
    final position = await _locationService.getCurrentPosition();
    if (!mounted) return;
    setState(() {
      _position = position;
      _locating = false;
    });
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await _picker.pickMultiImage(
        imageQuality: 70,
        maxWidth: 1280,
      );
      if (picked.isEmpty || !mounted) return;
      setState(() {
        _photos.addAll(picked.map((x) => x.path));
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not access photo library.')),
        );
      }
    }
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final position = _position;
    if (position == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Wait for your GPS location before submitting.'),
        ),
      );
      return;
    }
    setState(() => _submitting = true);
    final repo = context.read<IRepository>();
    final label = position.latitude == AppConfig.kakobaLatitude &&
            position.longitude == AppConfig.kakobaLongitude
        ? 'Kakoba (reference point)'
        : Formatters.coords(position.latitude, position.longitude);

    try {
      final incident = await repo.reportIncident(
        category: _category?.value ?? IncidentCategory.other.value,
        description: _description.text.trim(),
        latitude: position.latitude,
        longitude: position.longitude,
        locationLabel: label,
        photoPaths: _photos,
        voiceNotePath: _voiceNotePath,
      );
      if (!mounted) return;
      setState(() => _submitting = false);
      await _showConfirmation(incident);
    } catch (e) {
      if (!mounted) return;
      final error = RepositoryException.messageOf(e);
      if (RepositoryException.isNetwork(e) && !repo.isDemo) {
        final offline = OfflineReportService(repo);
        await offline.enqueue(
          category: _category?.value ?? IncidentCategory.other.value,
          description: _description.text.trim(),
          latitude: position.latitude,
          longitude: position.longitude,
          locationLabel: label,
          photoPaths: _photos,
          voiceNotePath: _voiceNotePath,
        );
        await _refreshQueueCount();
        if (!mounted) return;
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'No connection - report saved on this phone and will sync automatically when online.'),
          ),
        );
      } else {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error)),
        );
      }
    }
  }

  Future<void> _showConfirmation(Incident incident) async {
    final repo = context.read<IRepository>();
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Incident reported'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Your reference number is\n${incident.incidentId.toUpperCase()}.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            if (!repo.isDemo)
              const Text(
                'An AI classifier is reviewing your report and responders have '
                'been notified.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13),
              )
            else
              Text(
                'The system classified your report as\n'
                '${incident.category.label} (${incident.priority.label} priority). '
                'Responders have been notified.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => IncidentDetailScreen(incident: incident),
                ),
              );
            },
            child: const Text('Track status'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report an incident')),
      body: _submitting
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _incidentTypePicker(),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _description,
                      minLines: 4,
                      maxLines: 6,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'What happened?',
                        hintText:
                            'Describe the incident and anything responders should know...',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().length < 20)
                              ? 'Please describe the incident in at least 20 characters.'
                              : null,
                    ),
                    const SizedBox(height: 16),
                    _locationTile(),
                    const SizedBox(height: 16),
                    _photoSection(),
                    const SizedBox(height: 16),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Voice description',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 8),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: [
                            VoiceNoteRecorder(
                              onRecorded: (path) =>
                                  _voiceNotePath = path ?? _voiceNotePath,
                            ),
                            if (_offlinePending > 0) ...[
                              const Divider(height: 16),
                              Row(
                                children: [
                                  const Icon(Icons.offline_pin,
                                      size: 18, color: AppColors.primary),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '$_offlinePending report(s) saved for offline sync.',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: _syncOffline,
                                    child: const Text('Sync now'),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _submit,
                      icon: const Icon(Icons.send),
                      label: const Text('Submit report'),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _incidentTypePicker() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Incident type',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          _category == null
              ? 'Not sure? Leave blank and the AI assistant will classify it for responders.'
              : _category!.label,
          style: TextStyle(
            fontSize: 12,
            color: _category == null ? AppColors.muted : AppColors.forCategory(_category!),
            fontStyle: _category == null ? FontStyle.italic : FontStyle.normal,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => setState(() => _category = null),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _category == null ? AppColors.ink : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _category == null ? AppColors.ink : Colors.grey),
                ),
                child: const Text(
                  'Auto (AI)',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
            for (final c in IncidentCategory.values.take(10))
              _CategoryPill(
                label: c.label,
                selected: _category == c,
                onTap: () => setState(() => _category = c),
              ),
          ],
        ),
      ],
    );
  }

  Widget _locationTile() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.place_outlined, color: AppColors.secondary),
            const SizedBox(width: 12),
            Expanded(
              child: _locating
                  ? const Text('Detecting GPS location...',
                      style: TextStyle(color: AppColors.muted))
                  : _position == null
                      ? const Text('Location unavailable',
                          style: TextStyle(color: AppColors.muted))
                      : Text(
                          Formatters.coords(
                              _position!.latitude, _position!.longitude),
                          style: const TextStyle(
                              fontWeight: FontWeight.w600),
                        ),
            ),
            TextButton.icon(
              onPressed: _locating ? null : _obtainLocation,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Evidence photos',
                style: TextStyle(fontWeight: FontWeight.w600)),
            TextButton.icon(
              onPressed: _pickPhoto,
              icon: const Icon(Icons.add_a_photo_outlined, size: 18),
              label: const Text('Add photo'),
            ),
          ],
        ),
        if (_photos.isNotEmpty)
          SizedBox(
            height: 72,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) => Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.file(
                      File(_photos[index]),
                      width: 72,
                      height: 72,
                      fit: BoxFit.cover,
                    ),
                  ),
                  Positioned(
                    top: 0,
                    right: 0,
                    child: InkWell(
                      onTap: () => setState(() => _photos.removeAt(index)),
                      child: Container(
                        decoration: const BoxDecoration(
                          color: Colors.black54,
                          shape: BoxShape.circle,
                        ),
                        padding: const EdgeInsets.all(2),
                        child: const Icon(Icons.close,
                            color: Colors.white, size: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _CategoryPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _CategoryPill({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : AppColors.ink,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
