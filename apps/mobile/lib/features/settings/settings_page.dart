import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/router.dart';
import '../../services/api/auth_repository_impl.dart';
import '../../services/notifications/notification_scheduler.dart';
import '../../services/notifications/reminder_settings.dart';
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
    return NightScaffold(
      title: 'Settings',
      showSky: false,
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
          ..._reminderRows(context, ref),
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

  /// The "Nightly reminder" toggle plus, when enabled, a time-picker row.
  /// Saving schedules or cancels a daily local notification.
  List<Widget> _reminderRows(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(reminderControllerProvider);
    final time = TimeOfDay(hour: prefs.time.hour, minute: prefs.time.minute);
    return [
      SwitchListTile(
        secondary: const Icon(Icons.notifications_active_rounded),
        title: const Text('Nightly reminder'),
        subtitle: Text(
          prefs.enabled
              ? 'Every day at ${time.format(context)}'
              : 'Get a nightly nudge to read',
        ),
        value: prefs.enabled,
        onChanged: (value) {
          ref.read(reminderControllerProvider.notifier).setEnabled(value);
          if (value) ref.read(sfxServiceProvider).play(SoundEffect.tap);
        },
      ),
      if (prefs.enabled)
        ListTile(
          leading: const Icon(Icons.schedule_rounded),
          title: const Text('Reminder time'),
          subtitle: Text(time.format(context)),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: time,
              helpText: 'Nightly reminder time',
            );
            if (picked != null) {
              await ref.read(reminderControllerProvider.notifier).setTime(
                    ReminderTime(picked.hour, picked.minute),
                  );
            }
          },
        ),
    ];
  }
}
