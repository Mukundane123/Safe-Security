import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/ai_classification_log.dart';
import '../../repositories/repository.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';
import '../incident_detail_screen.dart';

/// Administrator view over every automated classification decision.
///
/// Answers two questions the incident list cannot: what did the classifier
/// decide, and did a human correct it?
class AiAuditLogScreen extends StatelessWidget {
  const AiAuditLogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('AI decision log')),
      body: StreamBuilder<List<AiClassificationLog>>(
        stream: repo.watchAiClassificationLogs(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const ErrorState(
              message: 'The audit log is not available to your account.',
            );
          }
          final logs = snapshot.data;
          if (logs == null) return const LoadingScreen();
          if (logs.isEmpty) {
            return const EmptyState(
              icon: Icons.psychology_outlined,
              title: 'No classifications yet',
              message:
                  'Every automated classification is recorded here as soon as the backend makes it.',
            );
          }
          final corrected = logs.where((l) => l.wasCorrected).length;
          final agreed = logs.where((l) => l.agreedWithReporter).length;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                child: Text(
                  '${logs.length} decisions logged — $agreed matched the reporter, '
                  '$corrected were overridden by a human.',
                  style: const TextStyle(fontSize: 13, color: AppColors.muted),
                ),
              ),
              for (final log in logs) _tile(context, repo, log),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(
      BuildContext context, IRepository repo, AiClassificationLog log) {
    final confidencePct = (log.confidence * 100).round();
    final lowConfidence = log.confidence < 0.5;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: InkWell(
        onTap: () => _openIncident(context, repo, log.incidentId),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${log.inputCategory ?? 'unspecified'} → ${log.outputCategory}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: (lowConfidence ? AppColors.primary : AppColors.secondary)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$confidencePct% confidence',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: lowConfidence ? AppColors.primary : AppColors.secondary,
                      ),
                    ),
                  ),
                ],
              ),
              if (log.outputSubCategory != null)
                Text(log.outputSubCategory!,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
              if (log.summary != null) ...[
                const SizedBox(height: 6),
                Text(log.summary!, style: const TextStyle(fontSize: 13)),
              ],
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _tag(Icons.schedule, '${log.durationMs}ms'),
                  _tag(Icons.psychology_outlined, log.model),
                  if (log.outputPriority != null)
                    _tag(Icons.flag_outlined, log.outputPriority!),
                  if (log.duplicateOf != null)
                    _tag(Icons.copy_all_outlined, 'duplicate'),
                  if (log.wasCorrected)
                    _tag(Icons.edit_note, 'corrected to ${log.overriddenCategory}'),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${Formatters.dateTime(log.createdAt)} · incident ${log.incidentId}',
                style: const TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.muted),
        const SizedBox(width: 3),
        Text(label,
            style: const TextStyle(fontSize: 11, color: AppColors.muted)),
      ],
    );
  }

  Future<void> _openIncident(
      BuildContext context, IRepository repo, String incidentId) async {
    try {
      final incidents = await repo.watchAllIncidents().first;
      final match = incidents.where((i) => i.incidentId == incidentId).firstOrNull;
      if (match == null || !context.mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => IncidentDetailScreen(incident: match),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open incident: $incidentId')),
      );
    }
  }
}
