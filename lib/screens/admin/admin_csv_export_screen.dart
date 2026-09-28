import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../models/incident.dart';
import '../../repositories/repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';

/// Lets the admin download all incident reports as a CSV file and copy the
/// data to the clipboard for offline reporting into a spreadsheet.
class AdminCsvExportScreen extends StatefulWidget {
  const AdminCsvExportScreen({super.key});

  @override
  State<AdminCsvExportScreen> createState() => _AdminCsvExportScreenState();
}

class _AdminCsvExportScreenState extends State<AdminCsvExportScreen> {
  List<Incident>? _incidents;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final incidents =
        await context.read<IRepository>().watchAllIncidents().first;
    if (!mounted) return;
    setState(() {
      _incidents = incidents;
      _loading = false;
    });
  }

  String _escape(Object value) {
    final s = value.toString().replaceAll('"', '""');
    return '"$s"';
  }

  List<String> _rows() {
    final rows = [
      'incidentId,category,status,reporter,location,latitude,longitude,'
      'reportedAt,description,photos,voiceNote'
    ];
    for (final i in _incidents ?? <Incident>[]) {
      rows.add([
        _escape(i.incidentId),
        _escape(i.category.label),
        _escape(i.status.label),
        _escape(i.reporterName),
        _escape(i.locationLabel),
        i.location.latitude.toString(),
        i.location.longitude.toString(),
        _escape(Formatters.dateTime(i.reportedDate)),
        _escape(i.description),
        i.photoUrls.length.toString(),
        _escape(i.voiceNoteUrl ?? ''),
      ].join(','));
    }
    return rows;
  }

  Future<void> _saveFile() async {
    final csv = _rows().join('\n');
    final dir = await getApplicationDocumentsDirectory();
    final stamp = DateTime.now().toIso8601String().split('.').first
        .replaceAll(':', '-');
    final file = File('${dir.path}${Platform.pathSeparator}'
        'safeguard_incidents_$stamp.csv');
    await file.writeAsString(csv, flush: true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved ${file.path}')),
    );
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _rows().join('\n')));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('CSV copied to clipboard.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final incidents = _incidents ?? const <Incident>[];
    final pending = incidents
        .where((i) => i.status == IncidentStatus.pending)
        .length;

    return Scaffold(
      appBar: AppBar(title: const Text('Export incident reports')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  color: AppColors.secondary.withValues(alpha: 0.08),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${incidents.length} reports total',
                            style: const TextStyle(
                                fontSize: 18, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text('$pending still pending review',
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.download,
                              color: AppColors.primary),
                          title: const Text('Save as CSV file'),
                          subtitle: const Text(
                              'Writes the full report table onto this device.'),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: _saveFile,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.copy,
                              color: AppColors.secondary),
                          title: const Text('Copy CSV to clipboard'),
                          subtitle: const Text(
                              'Paste into a spreadsheet or chat.'),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: _copy,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'CSV columns: incident id, category, status, reporter, '
                  'location, latitude, longitude, reported at, description, '
                  'photo count, voice note.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
    );
  }
}