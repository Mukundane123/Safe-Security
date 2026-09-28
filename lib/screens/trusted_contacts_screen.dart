import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/trusted_contact.dart';
import '../repositories/repository.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/common.dart';

class TrustedContactsScreen extends StatefulWidget {
  const TrustedContactsScreen({super.key});

  @override
  State<TrustedContactsScreen> createState() => _TrustedContactsScreenState();
}

class _TrustedContactsScreenState extends State<TrustedContactsScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a name and phone number.')),
      );
      return;
    }
    setState(() => _saving = true);
    await context.read<IRepository>().addTrustedContact(
          name: _name.text,
          phone: _phone.text,
        );
    if (!mounted) return;
    setState(() {
      _saving = false;
      _name.clear();
      _phone.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Trusted contacts')),
      body: StreamBuilder<List<TrustedContact>>(
        stream: repo.watchTrustedContacts(),
        builder: (context, snapshot) {
          final contacts = snapshot.data;
          if (contacts == null) return const LoadingScreen();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'When you press SOS, these people are alerted instantly '
                'with your location.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              if (contacts.isEmpty)
                const EmptyState(
                  icon: Icons.people_outline,
                  title: 'No trusted contacts yet',
                  message: 'Add a relative or friend to receive your SOS alerts.',
                )
              else
                for (final contact in contacts) _contactTile(contact, repo),
              const SizedBox(height: 8),
              _addForm(repo),
            ],
          );
        },
      ),
    );
  }

  Widget _addForm(IRepository repo) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Add a contact',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full name',
                prefixIcon: Icon(Icons.person_outline),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone number',
                prefixIcon: Icon(Icons.phone_outlined),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _saving ? null : _add,
              icon: const Icon(Icons.person_add_alt_1),
              label: Text(_saving ? 'Adding...' : 'Add contact'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _contactTile(TrustedContact contact, IRepository repo) {
    final confirmed =
        contact.confirmationStatus == ContactConfirmation.confirmed;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (confirmed ? AppColors.secondary : AppColors.muted)
                  .withValues(alpha: 0.15),
          child: Icon(
            Icons.person,
            color: confirmed ? AppColors.secondary : AppColors.muted,
          ),
        ),
        title: Text(contact.contactName),
        subtitle: Text(
          '${contact.contactPhone}\nAdded ${Formatters.date(contact.createdDate)}',
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!confirmed)
              Tooltip(
                message: 'Awaiting confirmation',
                child: const Icon(Icons.timelapse, size: 20),
              ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.primary),
              onPressed: () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text('Remove ${contact.contactName}?'),
                    content: const Text(
                        'This contact will no longer receive your SOS alerts.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext, false),
                        child: const Text('Cancel'),
                      ),
                      FilledButton(
                        onPressed: () => Navigator.pop(dialogContext, true),
                        child: const Text('Remove'),
                      ),
                    ],
                  ),
                );
                if (ok == true) repo.removeTrustedContact(contact.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}