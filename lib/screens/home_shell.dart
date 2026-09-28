import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../state/settings_controller.dart';
import 'admin/admin_dashboard_screen.dart';
import 'admin/admin_incidents_screen.dart';
import 'citizen/dashboard_screen.dart';
import 'citizen/sos_screen.dart';
import 'map/incident_map_screen.dart';
import 'more_screen.dart';
import 'responder/responder_incidents_screen.dart';

/// Role-aware home shell. The visible tabs depend on the signed-in role, so a
/// Citizen never sees responder-only functionality and vice versa.
class HomeShell extends StatefulWidget {
  final AppUser user;
  const HomeShell({super.key, required this.user});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  late final List<_TabSpec> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = _buildTabs(widget.user);
  }

  List<_TabSpec> _buildTabs(AppUser user) {
    switch (user.role) {
      case UserRole.responder:
        return [
          const _TabSpec('Home', Icons.home_outlined, Icons.home,
              ResponderIncidentsScreen()),
          const _TabSpec('Map', Icons.map_outlined, Icons.map,
              IncidentMapScreen()),
          const _TabSpec('SOS', Icons.sos, Icons.sos, SosScreen()),
          _TabSpec('More', Icons.menu, Icons.menu, _More(user)),
        ];
      case UserRole.administrator:
        return [
          const _TabSpec('Dashboard', Icons.insights_outlined,
              Icons.insights, AdminDashboardScreen()),
          const _TabSpec('Incidents', Icons.list_alt_outlined, Icons.list_alt,
              AdminIncidentsScreen()),
          const _TabSpec('Map', Icons.map_outlined, Icons.map,
              IncidentMapScreen()),
          _TabSpec('More', Icons.menu, Icons.menu, _More(user)),
        ];
      case UserRole.citizen:
        return [
          const _TabSpec('Home', Icons.home_outlined, Icons.home,
              DashboardScreen()),
          const _TabSpec('Map', Icons.map_outlined, Icons.map,
              IncidentMapScreen()),
          _TabSpec('SOS', Icons.sos, Icons.sos, const SosScreen()),
          _TabSpec('More', Icons.menu, Icons.menu, _More(user)),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsController>();
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [for (final tab in _tabs) tab.child],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: settings.tr(tab.label),
            ),
        ],
      ),
    );
  }
}

class _TabSpec {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget child;
  const _TabSpec(this.label, this.icon, this.selectedIcon, this.child);
}

class _More extends StatelessWidget {
  final AppUser user;
  const _More(this.user);

  @override
  Widget build(BuildContext context) {
    return MoreScreen(user: user);
  }
}