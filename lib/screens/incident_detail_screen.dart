import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../models/incident.dart';
import '../repositories/repository.dart';
import '../repositories/repository_exception.dart';
import '../state/auth_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../utils/navigation.dart';
import '../widgets/category_icon.dart';
import '../widgets/chips.dart';
import '../widgets/common.dart';
import '../widgets/community_reports_section.dart';
import '../widgets/incident_map.dart';
import 'chat_screen.dart';

/// Full incident view. Actions shown depend on the signed-in role:
///  * Citizen - view status / withdraw while pending.
///  * Responder - confirm classification and update status.
///  * Administrator - everything, plus assignment to responders.
class IncidentDetailScreen extends StatefulWidget {
  final Incident incident;
  const IncidentDetailScreen({super.key, required this.incident});

  @override
  State<IncidentDetailScreen> createState() => _IncidentDetailScreenState();
}

class _IncidentDetailScreenState extends State<IncidentDetailScreen> {
  late Incident _incident;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _incident = widget.incident;
  }

  IRepository get _repo => context.read<IRepository>();
  AuthController get _auth => context.read<AuthController>();

  Future<void> _run(Future<void> Function() action, String success) async {
    setState(() => _busy = true);
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(success)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(RepositoryException.messageOf(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _applySuggestion() async {
    final suggestion = _incident.aiSuggestion;
    if (suggestion.category == null) return;
    await _run(
      () => _repo.confirmClassification(
        _incident.incidentId,
        category: suggestion.category!,
        priority: suggestion.priority ?? IncidentPriority.normal.value,
        subCategory: suggestion.subCategory,
      ),
      'Classification confirmed.',
    );
  }

  Future<void> _changeStatus(IncidentStatus status) async {
    await _run(
      () => _repo.updateIncidentStatus(
        _incident.incidentId,
        status.value,
        resolvedAt: status == IncidentStatus.resolved
            ? DateTime.now()
            : null,
      ),
      'Status updated to ${status.label}.',
    );
  }

  Future<void> _assignIncident() async {
    final messenger = ScaffoldMessenger.of(context);
    final responders = <AppUser>[];
    final sub = _repo.watchUsers().listen((users) {
      responders
        ..clear()
        ..addAll(users.where((u) => u.role == UserRole.responder && u.status == AccountStatus.active));
    });
    await Future.delayed(const Duration(milliseconds: 300));
    sub.cancel();
    if (!mounted) return;

    if (responders.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No active responders to assign.')),
      );
      return;
    }
    final selected = await showModalBottomSheet<AppUser>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Assign incident to responder',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
            for (final r in responders)
              ListTile(
                leading: const Icon(Icons.emergency_outlined,
                    color: AppColors.secondary),
                title: Text(r.name),
                subtitle: Text(r.email),
                onTap: () => Navigator.pop(sheetContext, r),
              ),
          ],
        ),
      ),
    );
    if (selected == null) return;
    await _run(
      () => _repo.assignIncident(_incident.incidentId, selected.userId),
      'Assigned to ${selected.name}.',
    );
  }

  Future<void> _withdraw() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw report?'),
        content: const Text(
            'This report will be removed. You can submit a new report at any time.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Keep report'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Withdraw'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => _repo.deleteIncident(_incident.incidentId),
      'Report withdrawn.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _editDescription(Incident incident) async {
    final controller = TextEditingController(text: incident.description);
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit report'),
        content: TextField(
          controller: controller,
          maxLines: 6,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'What happened',
            helperText: 'Add or correct details while the report is pending.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final text = controller.text.trim();
    controller.dispose();
    if (saved != true || text.isEmpty || text == incident.description) return;
    await _run(
      () => _repo.updateIncidentDescription(
        incidentId: incident.incidentId,
        description: text,
      ),
      'Report updated.',
    );
  }

  Future<void> _deleteIncident() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete incident?'),
        content: const Text('This removes the incident record permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => _repo.deleteIncident(_incident.incidentId),
      'Incident deleted.',
    );
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = _incident.reporterId == _auth.user?.userId;
    final canManage = _auth.isResponder || _auth.isAdmin;
    return Scaffold(
      appBar: AppBar(
        title: Text(_incident.category.label),
        actions: [
          IconButton(
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: 'Chat about this incident',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatScreen(incident: _incident),
              ),
            ),
          ),
        ],
      ),
      body: _busy
          ? const LoadingScreen(message: 'Updating...')
          : StreamBuilder<List<Incident>>(
              stream: _repo.watchAllIncidents(),
              builder: (context, snapshot) {
                final all = snapshot.data ?? const <Incident>[];
                final live = all
                        .where((i) => i.incidentId == _incident.incidentId)
                        .firstOrNull ??
                    _incident;
                if (live != _incident) _incident = live;
                return _buildContent(context, live, isOwner, canManage);
              },
            ),
    );
  }

  Widget _buildContent(BuildContext context, Incident incident, bool isOwner, bool canManage) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        _header(incident),
        const SizedBox(height: 4),
        _aiSuggestion(incident, canManage),
        _description(incident),
        _voiceNote(incident),
        _mapSection(incident),
        _details(incident),
        if (incident.photoUrls.isNotEmpty) _photos(incident),
        _actions(incident, isOwner, canManage),
        CommunityReportsSection(incidentId: incident.incidentId),
      ],
    );
  }
  Widget _header(Incident incident) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CategoryIcon(incident.category, size: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      incident.category.label,
                      style: const TextStyle(
                          fontSize: 20, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${incident.incidentId.toUpperCase()} \u2022 '
                      '${Formatters.relative(incident.reportedDate)}',
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  PriorityChip(incident.priority),
                  const SizedBox(height: 6),
                  StatusChip(incident.status),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _aiSuggestion(Incident incident, bool canManage) {
    final suggestion = incident.aiSuggestion;
    if (suggestion.category == null && suggestion.summary == null) {
      return const SizedBox.shrink();
    }
    final color = AppColors.secondary;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.auto_awesome, color: Color(0xFF6A1B9A)),
                const SizedBox(width: 8),
                const Text('AI classification',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                const Spacer(),
                Text(
                  '${(suggestion.confidence * 100).round()}% confidence',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (suggestion.category != null)
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _suggestionChip(
                    'Category',
                    IncidentCategory.fromValue(suggestion.category).label,
                    color,
                  ),
                  if (suggestion.subCategory != null)
                    _suggestionChip('Sub-category', suggestion.subCategory!, color),
                  _suggestionChip(
                    'Priority',
                    IncidentPriority.fromValue(suggestion.priority).label,
                    color,
                  ),
                ],
              ),
            if (suggestion.summary != null) ...[
              const SizedBox(height: 8),
              Text(suggestion.summary!,
                  style: const TextStyle(fontSize: 13, height: 1.3)),
            ],
            if (suggestion.duplicateOf != null) ...[
              const SizedBox(height: 8),
              Text(
                'Possible duplicate of ${suggestion.duplicateOf!.toUpperCase()}.',
                style: const TextStyle(
                    color: AppColors.statusDuplicate, fontSize: 13),
              ),
            ],
            if (canManage && suggestion.category != null &&
                incident.status == IncidentStatus.pending) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _applySuggestion,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                  ),
                  icon: const Icon(Icons.check, size: 18),
                  label: const Text('Accept & confirm'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _suggestionChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _description(Incident incident) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Description',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(incident.description,
              style: const TextStyle(fontSize: 14, height: 1.5)),
        ],
      ),
    );
  }

  Widget _voiceNote(Incident incident) {
    final url = incident.voiceNoteUrl;
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    final player = AudioPlayer();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Card(
        child: ListTile(
          leading: const Icon(Icons.graphic_eq, color: AppColors.secondary),
          title: const Text('Voice description'),
          subtitle: const Text('Recorded by the reporter'),
          trailing: IconButton(
            icon: const Icon(Icons.play_circle_outline),
            tooltip: 'Play voice note',
            onPressed: () async {
              await player.stop();
              if (url.startsWith('http')) {
                await player.play(UrlSource(url));
              } else {
                await player.play(DeviceFileSource(url));
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _mapSection(Incident incident) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: IncidentMap(
        incidents: [incident],
        currentUserLabel: 'Incident location',
        height: 220,
      ),
    );
  }

  Widget _details(Incident incident) {
    return Card(
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.place_outlined),
            title: const Text('Location'),
            subtitle: Text(incident.locationLabel.isEmpty
                ? Formatters.coords(incident.location.latitude,
                    incident.location.longitude)
                : '${incident.locationLabel}\n'
                    '${Formatters.coords(incident.location.latitude, incident.location.longitude)}'),
            isThreeLine: true,
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined),
            title: const Text('Reported by'),
            subtitle: Text(incident.reporterName),
          ),
          const Divider(height: 0),
          ListTile(
            leading: const Icon(Icons.emergency_outlined),
            title: const Text('Assigned responder'),
            subtitle: Text(
                incident.assignedResponderName ?? 'Not yet assigned'),
          ),
          if (incident.resolvedDate != null) const Divider(height: 0),
          if (incident.resolvedDate != null)
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Resolved'),
              subtitle: Text(Formatters.dateTime(incident.resolvedDate!)),
            ),
        ],
      ),
    );
  }

  Widget _photos(Incident incident) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Evidence photos',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SizedBox(
            height: 160,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: incident.photoUrls.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final url = incident.photoUrls[index];
                return GestureDetector(
                  onTap: () => showDialog<void>(
                    context: context,
                    builder: (_) => Dialog(
                      child: InteractiveViewer(
                        child: _photo(url),
                      ),
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _photo(url),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _photo(String url) {
    if (url.startsWith('http')) {
      return Image.network(url, width: 200, height: 160, fit: BoxFit.cover);
    }
    try {
      return Image.file(File(url), width: 200, height: 160, fit: BoxFit.cover);
    } catch (_) {
      return Container(
        width: 200,
        height: 160,
        color: AppColors.muted.withValues(alpha: 0.15),
        child: const Icon(Icons.image, size: 40, color: AppColors.muted),
      );
    }
  }

  Widget _actions(Incident incident, bool isOwner, bool canManage) {
    final status = incident.status;
    final pending = status == IncidentStatus.pending;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (canManage &&
              status != IncidentStatus.closed &&
              status != IncidentStatus.resolved) ...[
            OutlinedButton.icon(
              onPressed: () => openDirections(
                incident.location.latitude,
                incident.location.longitude,
                label: incident.locationLabel.isEmpty
                    ? null
                    : incident.locationLabel,
              ),
              icon: const Icon(Icons.directions),
              label: const Text('Navigate to incident'),
            ),
            const SizedBox(height: 12),
          ],
          if (canManage) ...[
            if (pending)
              FilledButton.icon(
                onPressed: _assignIncident,
                icon: const Icon(Icons.assignment_ind),
                label: const Text('Assign to responder'),
              ),
            if (!pending) const SizedBox(height: 4),
            Text('Update status', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final s in _statusOptions(status))
                  OutlinedButton(
                    onPressed: () => _changeStatus(s),
                    child: Text(s.label),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_auth.isAdmin)
              TextButton.icon(
                onPressed: _deleteIncident,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete incident'),
                style: TextButton.styleFrom(foregroundColor: AppColors.primary),
              ),
          ],
          if (isOwner && !canManage && pending) ...[
            OutlinedButton.icon(
              onPressed: () => _editDescription(incident),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit my report'),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _withdraw,
              icon: const Icon(Icons.undo),
              label: const Text('Withdraw report (still pending)'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
          if (isOwner && !canManage && !pending)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Your report is being handled. You will be notified when its status changes.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  List<IncidentStatus> _statusOptions(IncidentStatus current) {
    final options = <IncidentStatus>[];
    void add(IncidentStatus s) {
      if (s != current) options.add(s);
    }

    add(IncidentStatus.assigned);
    add(IncidentStatus.inProgress);
    add(IncidentStatus.resolved);
    add(IncidentStatus.duplicate);
    add(IncidentStatus.closed);
    return options;
  }
}
