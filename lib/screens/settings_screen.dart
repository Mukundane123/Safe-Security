import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_language.dart';
import '../models/notification_preferences.dart';
import '../repositories/repository.dart';
import '../repositories/repository_exception.dart';
import '../state/settings_controller.dart';
import '../theme/app_theme.dart';

/// App appearance and notification settings. Appearance is persisted
/// automatically through [SettingsController]; notification preferences are
/// written to the user profile so the backend can honour them.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _save(BuildContext context, NotificationPreferences prefs) {
    final repo = context.read<IRepository>();
    final messenger = ScaffoldMessenger.of(context);
    repo.saveNotificationPreferences(prefs).catchError((Object e) {
      messenger.showSnackBar(
        SnackBar(content: Text(RepositoryException.messageOf(e))),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Scaffold(
      appBar: AppBar(title: Text(settings.tr('Settings'))),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          SwitchListTile(
            value: settings.isDark,
            onChanged: settings.setDarkMode,
            secondary:
                const Icon(Icons.dark_mode_outlined, color: AppColors.primary),
            title: Text(settings.isDark ? 'Dark theme' : 'Light theme'),
            subtitle: const Text(
                'Lower brightness when reading the app at night.'),
          ),
          const Divider(),
          const _SectionLabel('Notifications'),
          StreamBuilder<NotificationPreferences>(
            stream: context.read<IRepository>().watchNotificationPreferences(),
            builder: (context, snapshot) {
              final prefs =
                  snapshot.data ?? const NotificationPreferences();
              return Column(
                children: [
                  SwitchListTile(
                    value: prefs.incidentUpdates,
                    onChanged: (v) => _save(
                        context, prefs.copyWith(incidentUpdates: v)),
                    secondary: const Icon(
                        Icons.update_outlined, color: AppColors.secondary),
                    title: const Text('Incident status updates'),
                    subtitle: const Text(
                        'Progress on reports you submitted or follow.'),
                  ),
                  SwitchListTile(
                    value: prefs.assignments,
                    onChanged: (v) =>
                        _save(context, prefs.copyWith(assignments: v)),
                    secondary: const Icon(
                        Icons.assignment_ind_outlined, color: AppColors.secondary),
                    title: const Text('Responder assignments'),
                    subtitle: const Text(
                        'Alerts when a responder is assigned to you.'),
                  ),
                  SwitchListTile(
                    value: prefs.communityAlerts,
                    onChanged: (v) =>
                        _save(context, prefs.copyWith(communityAlerts: v)),
                    secondary: const Icon(
                        Icons.campaign_outlined, color: AppColors.secondary),
                    title: const Text('Community alerts'),
                    subtitle: const Text(
                        'Area-wide advisories from moderators and authorities.'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.sos, color: AppColors.primary),
                    title: Text('SOS alerts'),
                    subtitle: Text(
                        'Always on. SOS warnings are safety critical and '
                        'cannot be switched off.'),
                  ),
                ],
              );
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Language',
                style: const TextStyle(
                    fontSize: 13, color: AppColors.muted)),
          ),
          RadioGroup<AppLanguage>(
            groupValue: settings.language,
            onChanged: (v) {
              if (v != null) settings.setLanguage(v);
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final lang in AppLanguage.values)
                  RadioListTile<AppLanguage>(
                    value: lang,
                    title: Text(lang.label),
                    subtitle: Text(lang.code),
                  ),
              ],
            ),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text(
              'Changing language translates the main navigation and a few '
              'core labels. More strings are being added over time.',
              style: TextStyle(fontSize: 12, color: AppColors.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(text,
            style:
                const TextStyle(fontSize: 13, color: AppColors.muted)),
      );
}