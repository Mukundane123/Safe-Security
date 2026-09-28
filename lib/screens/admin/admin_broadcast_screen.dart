import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/community_alert.dart';
import '../../repositories/repository.dart';
import '../../theme/app_theme.dart';

class AdminBroadcastScreen extends StatefulWidget {
  const AdminBroadcastScreen({super.key});

  @override
  State<AdminBroadcastScreen> createState() => _AdminBroadcastScreenState();
}

class _AdminBroadcastScreenState extends State<AdminBroadcastScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _area = TextEditingController();
  AlertSeverity _severity = AlertSeverity.warning;
  int _expiresHours = 72;
  bool _sending = false;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    _area.dispose();
    super.dispose();
  }

  Future<void> _broadcast() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _sending = true);
    await context.read<IRepository>().broadcastCommunityAlert(
          title: _title.text,
          body: _body.text,
          area: _area.text.trim().isEmpty ? 'Whole Division' : _area.text.trim(),
          severity: _severity.value,
          expiresInHours: _expiresHours,
        );
    if (!mounted) return;
    setState(() => _sending = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Community alert broadcast to all residents.'),
      ),
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast community alert')),
      body: _sending
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextFormField(
                      controller: _title,
                      decoration: const InputDecoration(
                        labelText: 'Alert title',
                        hintText: 'e.g. Motorcycle thefts on the rise',
                      ),
                      validator: (value) =>
                          (value == null || value.trim().isEmpty)
                              ? 'Enter a title'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _body,
                      minLines: 3,
                      maxLines: 6,
                      decoration: const InputDecoration(
                        labelText: 'Message',
                        hintText:
                            'Clear, verified information residents should act on...',
                        alignLabelWithHint: true,
                      ),
                      validator: (value) =>
                          (value == null || value.trim().length < 20)
                              ? 'Provide a message of at least 20 characters.'
                              : null,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _area,
                      decoration: const InputDecoration(
                        labelText: 'Area / zone',
                        hintText: 'e.g. Nyaikona, or leave blank for the whole division',
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text('Severity',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SegmentedButton<AlertSeverity>(
                      segments: const [
                        ButtonSegment(
                          value: AlertSeverity.info,
                          label: Text('Info'),
                          icon: Icon(Icons.info_outline),
                        ),
                        ButtonSegment(
                          value: AlertSeverity.warning,
                          label: Text('Warning'),
                          icon: Icon(Icons.warning_amber_rounded),
                        ),
                        ButtonSegment(
                          value: AlertSeverity.critical,
                          label: Text('Critical'),
                          icon: Icon(Icons.report_gmailerrorred),
                        ),
                      ],
                      selected: {_severity},
                      onSelectionChanged: (s) =>
                          setState(() => _severity = s.first),
                    ),
                    const SizedBox(height: 20),
                    const Text('Alert expires after',
                        style: TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 12, label: Text('12 hrs')),
                        ButtonSegment(value: 48, label: Text('2 days')),
                        ButtonSegment(value: 72, label: Text('3 days')),
                        ButtonSegment(value: 168, label: Text('1 week')),
                      ],
                      selected: {_expiresHours},
                      onSelectionChanged: (s) =>
                          setState(() => _expiresHours = s.first),
                    ),
                    const SizedBox(height: 28),
                    FilledButton.icon(
                      onPressed: _broadcast,
                      icon: const Icon(Icons.campaign),
                      label: const Text('Broadcast to all residents'),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Recipients receive a push notification and the alert is listed on the Community Alerts screen.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.muted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}