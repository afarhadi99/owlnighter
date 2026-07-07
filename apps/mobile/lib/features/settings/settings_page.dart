import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/api/auth_repository_impl.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/util/env.dart';
import '../notifications/notifications_page.dart';

/// Settings tab: notifications, account, and (in debug builds) the admin/debug
/// console entry point.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.notifications_rounded),
            title: const Text('Notifications'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsPage(),
              ),
            ),
          ),
          const ListTile(
            leading: Icon(Icons.record_voice_over_rounded),
            title: Text('Recap voice'),
            subtitle: Text('aura-2-thalia-en'),
          ),
          if (AppEnv.enableAdminDebug)
            ListTile(
              leading: const Icon(Icons.bug_report_rounded),
              title: const Text('Admin / debug'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.adminDebug),
            ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.danger500),
            title: const Text('Sign out'),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
        ],
      ),
    );
  }
}
