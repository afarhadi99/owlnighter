import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/api/auth_repository_impl.dart';
import '../../services/sfx/sfx_service.dart';
import '../../services/sfx/sound_effect.dart';
import '../../services/sfx/sound_settings.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/util/env.dart';

/// Settings tab: audio, recap voice, reminders (coming soon), account, and — in
/// debug builds — a Developer section with the admin/debug console.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.music_note_rounded),
            title: const Text('Sound effects'),
            subtitle: const Text('Taps, chimes, and celebration sounds'),
            value: ref.watch(soundEnabledProvider),
            onChanged: (value) {
              ref.read(soundEnabledProvider.notifier).setEnabled(value);
              // Play a confirming tick when turning sound on.
              if (value) ref.read(sfxServiceProvider).play(SoundEffect.tap);
            },
          ),
          const ListTile(
            leading: Icon(Icons.record_voice_over_rounded),
            title: Text('Recap voice'),
            subtitle: Text('Thalia — English (US)'),
          ),
          // Reminders aren't wired yet — an explicitly disabled row so nothing
          // dead-ends (replaces the old chevron that went to an empty page).
          const ListTile(
            enabled: false,
            leading: Icon(Icons.notifications_rounded),
            title: Text('Reminders'),
            subtitle: Text('Coming soon'),
          ),
          const Divider(),
          ListTile(
            leading:
                const Icon(Icons.logout_rounded, color: AppColors.danger500),
            title: const Text('Sign out'),
            onTap: () => ref.read(authRepositoryProvider).signOut(),
          ),
          if (AppEnv.enableAdminDebug) ...[
            const Divider(),
            const Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.xs,
              ),
              child: Text('Developer', style: AppType.caption),
            ),
            ListTile(
              leading: const Icon(Icons.bug_report_rounded),
              title: const Text('Admin / debug'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.push(Routes.adminDebug),
            ),
          ],
        ],
      ),
    );
  }
}
