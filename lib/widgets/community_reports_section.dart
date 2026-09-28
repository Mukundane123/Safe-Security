import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/community_report.dart';
import '../repositories/repository.dart';
import '../repositories/repository_exception.dart';
import '../state/auth_controller.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// Public "what is happening now" wall for an incident. Residents post short
/// updates; responders and administrators can mark an update as verified so
/// readers can tell confirmed information from rumour.
class CommunityReportsSection extends StatefulWidget {
  final String incidentId;
  const CommunityReportsSection({super.key, required this.incidentId});

  @override
  State<CommunityReportsSection> createState() => _CommunityReportsSectionState();
}

class _CommunityReportsSectionState extends State<CommunityReportsSection> {
  final _controller = TextEditingController();
  bool _posting = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _posting = true);
    final repo = context.read<IRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.addCommunityReport(incidentId: widget.incidentId, text: text);
      _controller.clear();
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(RepositoryException.messageOf(e))),
      );
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  Future<void> _verify(CommunityReport report) async {
    final repo = context.read<IRepository>();
    try {
      await repo.verifyCommunityReport(report.reportId, verified: !report.verified);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(RepositoryException.messageOf(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();
    final isAdmin = context.watch<AuthController>().isAdmin;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Row(
            children: [
              const Icon(Icons.campaign_outlined, color: AppColors.secondary),
              const SizedBox(width: 8),
              const Text('Community updates',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        StreamBuilder<List<CommunityReport>>(
          stream: repo.watchCommunityReports(widget.incidentId),
          builder: (context, snapshot) {
            final reports = snapshot.data ?? const <CommunityReport>[];
            if (reports.isEmpty) {
              return const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  'No updates yet. Share what you can see or have seen.',
                  style: TextStyle(color: AppColors.muted, fontSize: 13),
                ),
              );
            }
            return Column(
              children: [
                for (final r in reports)
                  ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.secondary.withValues(alpha: 0.15),
                      child: Text(
                        r.authorName.isEmpty
                            ? '?'
                            : r.authorName[0].toUpperCase(),
                        style: const TextStyle(color: AppColors.secondary),
                      ),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                          child: Text(r.authorName,
                              style: const TextStyle(fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(width: 6),
                        Text(r.authorRole,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                        if (r.verified) ...[
                          const SizedBox(width: 6),
                          const Icon(Icons.verified,
                              size: 15, color: AppColors.secondary),
                        ],
                      ],
                    ),
                    subtitle: Text(
                      '${r.text}\n${Formatters.relative(r.postedAt)}',
                      style: const TextStyle(fontSize: 13),
                    ),
                    isThreeLine: true,
                    trailing: isAdmin
                        ? IconButton(
                            tooltip: r.verified ? 'Unverify' : 'Mark verified',
                            icon: Icon(
                              r.verified
                                  ? Icons.verified
                                  : Icons.verified_outlined,
                              color: r.verified
                                  ? AppColors.secondary
                                  : AppColors.muted,
                            ),
                            onPressed: () => _verify(r),
                          )
                        : null,
                  ),
              ],
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 280,
                  decoration: const InputDecoration(
                    hintText: 'Add an update...',
                    isDense: true,
                    counterText: '',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                onPressed: _posting ? null : _post,
                icon: _posting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
