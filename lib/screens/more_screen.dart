import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../repositories/repository.dart';
import '../state/auth_controller.dart';
import '../state/settings_controller.dart';
import '../theme/app_theme.dart';
import 'admin/admin_broadcast_screen.dart';
import 'admin/admin_csv_export_screen.dart';
import 'admin/admin_users_screen.dart';
import 'admin/ai_audit_log_screen.dart';
import 'citizen/check_in_screen.dart';
import 'citizen/safety_zones_screen.dart';
import 'citizen/track_report_screen.dart';
import 'community_alerts_screen.dart';
import 'emergency_resources_screen.dart';
import 'my_reports_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'responder/location_broadcast_screen.dart';
import 'responder/sos_console_screen.dart';
import 'settings_screen.dart';
import 'trusted_contacts_screen.dart';

class MoreScreen extends StatelessWidget {
  final AppUser user;
  const MoreScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final isDemo = context.watch<IRepository>().isDemo;
    final settings = context.watch<SettingsController>();
    final items = <_MenuItem>[
      _MenuItem(
        Icons.notifications_outlined,
        'Notifications',
        () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
      ),
      _MenuItem(
        Icons.campaign_outlined,
        'Community alerts',
        () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CommunityAlertsScreen())),
      ),
      if (user.role == UserRole.citizen)
        _MenuItem(
          Icons.receipt_long_outlined,
          'My reports',
          () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const MyReportsScreen())),
        ),
      if (user.role == UserRole.citizen)
        _MenuItem(
          Icons.vpn_key_outlined,
          'Track anonymous report',
          () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const TrackReportScreen())),
        ),
      if (user.role == UserRole.citizen)
        _MenuItem(
          Icons.people_outline,
          'Trusted contacts',
          () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TrustedContactsScreen())),
        ),
      if (user.role == UserRole.administrator) ...[
        _MenuItem(
          Icons.campaign,
          'Broadcast community alert',
          () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AdminBroadcastScreen())),
        ),
        _MenuItem(
          Icons.manage_accounts_outlined,
          'Manage users',
          () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AdminUsersScreen())),
        ),
        _MenuItem(
          Icons.table_chart_outlined,
          'Export reports (CSV)',
          () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AdminCsvExportScreen())),
        ),
        _MenuItem(
          Icons.psychology_outlined,
          'AI decision log',
          () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const AiAuditLogScreen())),
        ),
      ],
      if (user.role == UserRole.citizen)
        _MenuItem(
          Icons.directions_walk_outlined,
          'Safe check-in',
          () => Navigator.of(context)
              .push(MaterialPageRoute(builder: (_) => const CheckInScreen())),
        ),
      if (user.role == UserRole.responder)
        _MenuItem(
          Icons.radar,
          'Share my location',
          () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LocationBroadcastScreen())),
        ),
      _MenuItem(
        Icons.local_hospital_outlined,
        'Emergency facilities',
        () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const EmergencyResourcesScreen())),
      ),
      if (user.role == UserRole.responder || user.role == UserRole.administrator)
        _MenuItem(
          Icons.sos,
          'SOS console',
          () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SosConsoleScreen())),
        ),
      _MenuItem(
        Icons.shield_outlined,
        'Safety zones',
        () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SafetyZonesScreen())),
      ),
      _MenuItem(
        Icons.settings_outlined,
        'Settings',
        () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
      ),
      _MenuItem(
        Icons.person_outline,
        'Profile',
        () => Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => ProfileScreen(user: user))),
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(settings.tr('More')),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: isDemo
                  ? const Text('demo mode',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic))
                  : const Text('live',
                      style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary.withValues(alpha: 0.12),
              child: Text(
                user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                style:
                    const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary),
              ),
            ),
            title: Text(user.name,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${user.role.label} \u2022 ${user.email}'),
          ),
          const Divider(),
          for (final item in items)
            ListTile(
              leading: Icon(item.icon),
              title: Text(settings.tr(item.label)),
              trailing: const Icon(Icons.chevron_right, size: 20),
              onTap: item.onTap,
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.primary),
            title: Text(settings.tr('Sign out')),
            onTap: () async {
              final auth = context.read<AuthController>();
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Sign out'),
                  content:
                      const Text('Are you sure you want to sign out of SafeGuard?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              );
              if (ok == true) await auth.signOut();
            },
          ),
        ],
      ),
    );
  }
}

class _MenuItem {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _MenuItem(this.icon, this.label, this.onTap);
}