import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_user.dart';
import '../../repositories/repository.dart';
import '../../state/providers.dart';
import '../../theme/app_theme.dart';
import '../../utils/formatters.dart';
import '../../widgets/common.dart';

class AdminUsersScreen extends StatelessWidget {
  const AdminUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = context.watch<IRepository>();
    return Scaffold(
      appBar: AppBar(title: const Text('Manage users')),
      body: StreamBuilder<List<AppUser>>(
        stream: repo.watchUsers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const EmptyState(
              icon: Icons.error_outline,
              title: 'Could not load users',
            );
          }
          final users = snapshot.data;
          if (users == null) return const LoadingScreen();
          if (users.isEmpty) {
            return const EmptyState(
              icon: Icons.people_outline,
              title: 'No users yet',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              final isSelf = user.userId == context.auth.user?.userId;
              return Card(
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.secondary.withValues(alpha: 0.12),
                    child: Text(
                      user.name.isNotEmpty ? user.name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  title: Row(
                    children: [
                      Flexible(
                        child: Text(user.name,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600)),
                      ),
                      if (isSelf)
                        Container(
                          margin: const EdgeInsets.only(left: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1B5E8A)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text('you',
                              style: TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF1B5E8A))),
                        ),
                    ],
                  ),
                  subtitle: Text(
                    '${user.role.label} \u2022 ${user.email}\n'
                    '${user.phone.isEmpty ? 'no phone' : user.phone} \u2022 '
                    '${user.status.label} \u2022 joined ${Formatters.date(user.createdDate)}',
                  ),
                  isThreeLine: true,
                  trailing: isSelf
                      ? null
                      : PopupMenuButton<String>(
                          onSelected: (action) => _handleAction(
                              context, repo, user, action),
                          itemBuilder: (menuContext) => [
                            if (user.status == AccountStatus.active)
                              const PopupMenuItem(
                                value: 'suspend',
                                child: Text('Suspend account'),
                              )
                            else
                              const PopupMenuItem(
                                value: 'activate',
                                child: Text('Reactivate account'),
                              ),
                            const PopupMenuItem(
                              value: 'delete',
                              child: Text('Delete account'),
                            ),
                          ],
                        ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    IRepository repo,
    AppUser user,
    String action,
  ) async {
    if (action == 'delete') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text('Delete ${user.name}?'),
          content: const Text(
              'This removes the account. Incidents already reported remain.'),
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
      if (ok == true) await repo.deleteUser(user.userId);
      return;
    }
    await repo.setUserStatus(
      user.userId,
      action == 'suspend' ? AccountStatus.suspended : AccountStatus.active,
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'suspend'
                ? '${user.name} was suspended.'
                : '${user.name} was reactivated.',
          ),
        ),
      );
    }
  }
}