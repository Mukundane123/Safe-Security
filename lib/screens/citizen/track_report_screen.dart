import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/incident.dart';
import '../../models/withdrawal_code.dart';
import '../../repositories/repository.dart';
import '../../repositories/repository_exception.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/category_icon.dart';
import '../../widgets/chips.dart';
import '../../widgets/common.dart';
import '../incident_detail_screen.dart';

/// Opens an anonymous report with its withdrawal code.
///
/// The code is the credential: it is hashed before it ever reaches the
/// network, and the app keeps no copy, so this screen deliberately does not
/// remember it either.
class TrackReportScreen extends StatefulWidget {
  const TrackReportScreen({super.key});

  @override
  State<TrackReportScreen> createState() => _TrackReportScreenState();
}

class _TrackReportScreenState extends State<TrackReportScreen> {
  final _controller = TextEditingController();
  Incident? _incident;
  String _normalized = '';
  bool _searching = false;
  bool _searchedEmpty = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _wellFormed => WithdrawalCode.isWellFormedCode(_controller.text);

  Future<void> _lookup() async {
    final code = WithdrawalCode.normalize(_controller.text);
    if (!WithdrawalCode.isWellFormedCode(code)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter the 16-character code, e.g. ABCD-EFGH-JKLM-NPQR.')),
      );
      return;
    }
    setState(() {
      _searching = true;
      _searchedEmpty = false;
    });
    try {
      final incident =
          await context.read<IRepository>().findIncidentByWithdrawalCode(code);
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchedEmpty = incident == null;
        _incident = incident;
        _normalized = code;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchedEmpty = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(RepositoryException.messageOf(e))),
      );
    }
  }

  Future<void> _withdraw() async {
    final incident = _incident;
    if (incident == null) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Withdraw this report?'),
        content: const Text(
            'The report is deleted permanently. This cannot be undone, and the '
            'code stops working afterwards.'),
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
    if (ok != true || !mounted) return;

    final repo = context.read<IRepository>();
    final messenger = ScaffoldMessenger.of(context);
    try {
      await repo.withdrawAnonymousReport(
        code: _normalized,
        incidentId: incident.incidentId,
      );
      if (!mounted) return;
      setState(() {
        _incident = null;
        _controller.clear();
        _searchedEmpty = false;
      });
      messenger.showSnackBar(
        const SnackBar(content: Text('Report withdrawn and deleted.')),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(content: Text(RepositoryException.messageOf(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Track an anonymous report')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Withdrawal code',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.characters,
                    autocorrect: false,
                    enableSuggestions: false,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _lookup(),
                    inputFormatters: [
                      LengthLimitingTextInputFormatter(19),
                      FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9-]')),
                    ],
                    style: const TextStyle(
                        fontFamily: 'monospace', letterSpacing: 2),
                    decoration: const InputDecoration(
                      hintText: 'ABCD-EFGH-JKLM-NPQR',
                      prefixIcon: Icon(Icons.vpn_key_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: _searching || !_wellFormed ? null : _lookup,
                    icon: _searching
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.search),
                    label: const Text('Find report'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Your code is never stored on this phone. Without it the report '
            'cannot be opened or withdrawn.',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
          if (_searchedEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 32),
              child: EmptyState(
                icon: Icons.search_off,
                title: 'No report matches that code',
                message:
                    'Check the code, or it may already have been withdrawn.',
              ),
            ),
          if (_incident != null) ...[
            const SizedBox(height: 16),
            _result(_incident!),
          ],
        ],
      ),
    );
  }

  Widget _result(Incident incident) {
    final pending = incident.status == IncidentStatus.pending;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIcon(incident.category, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(incident.category.label,
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        incident.locationLabel.isEmpty
                            ? Formatters.coords(incident.location.latitude,
                                incident.location.longitude)
                            : incident.locationLabel,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
                StatusChip(incident.status),
              ],
            ),
            const SizedBox(height: 10),
            Text(incident.description,
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 10),
            Text(
              'Reported ${Formatters.relative(incident.reportedDate)}'
              '${incident.assignedResponderName == null ? '' : ' • Handled by ${incident.assignedResponderName}'}',
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => IncidentDetailScreen(incident: incident),
                      ),
                    ),
                    icon: const Icon(Icons.open_in_new, size: 18),
                    label: const Text('Open'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: pending ? _withdraw : null,
                    icon: const Icon(Icons.undo, size: 18),
                    label: const Text('Withdraw'),
                  ),
                ),
              ],
            ),
            if (!pending)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Text(
                  'This report is already being handled, so it can no longer be '
                  'withdrawn.',
                  style: TextStyle(fontSize: 12, color: AppColors.muted),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
