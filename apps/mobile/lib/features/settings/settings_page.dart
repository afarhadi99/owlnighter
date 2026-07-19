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

/// Settings tab, rebuilt to the cozy-nocturnal prototype: grouped "cards" with
/// icon-tiled rows, polished pill toggles, and a lamp-gold section label above
/// each group. Every control keeps its real provider/persistence — only the
/// presentation changed.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return NightScaffold(
      showSky: false,
      automaticallyImplyLeading: false,
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
          // Hero header, matching the prototype's "Preferences / Settings".
          Text(
            'PREFERENCES',
            style: AppType.caption.copyWith(
              color: AppColors.lamp,
              letterSpacing: 2.4,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          const Text('Settings', style: AppType.title),
          const SizedBox(height: AppSpacing.lg),

          // ── Nightly reminder ────────────────────────────────────────────
          const _SectionLabel('Nightly reminder'),
          _SettingsGroup(children: _reminderRows(context, ref)),

          // ── Sound & feel ────────────────────────────────────────────────
          const _SectionLabel('Sound & feel'),
          _SettingsGroup(
            children: [
              _ToggleRow(
                icon: Icons.volume_up_rounded,
                title: 'Sound effects',
                subtitle: 'Taps, chimes, and celebration sounds',
                value: ref.watch(soundEnabledProvider),
                onChanged: (value) {
                  ref.read(soundEnabledProvider.notifier).setEnabled(value);
                  // Play a confirming tick when turning sound on.
                  if (value) ref.read(sfxServiceProvider).play(SoundEffect.tap);
                },
              ),
              const _NavRow(
                icon: Icons.graphic_eq_rounded,
                title: 'Recap voice',
                subtitle: 'Thalia — English (US)',
              ),
            ],
          ),

          // ── Account ─────────────────────────────────────────────────────
          const _SectionLabel('Account'),
          _SettingsGroup(
            children: [
              _NavRow(
                icon: Icons.replay_rounded,
                title: 'Replay welcome tour',
                onTap: () {
                  ref.read(sfxServiceProvider).play(SoundEffect.tap);
                  context.push(Routes.onboarding);
                },
              ),
              _NavRow(
                icon: Icons.info_outline_rounded,
                title: 'About owlnighter',
                subtitle: 'Version 1.0 · a book at bedtime',
                onTap: () => _showAbout(context),
              ),
              _NavRow(
                icon: Icons.logout_rounded,
                title: 'Sign out',
                danger: true,
                onTap: () => ref.read(authRepositoryProvider).signOut(),
              ),
            ],
          ),

          if (AppEnv.enableAdminDebug) ...[
            const _SectionLabel('Developer'),
            _SettingsGroup(
              children: [
                _NavRow(
                  icon: Icons.bug_report_rounded,
                  title: 'Admin / debug',
                  onTap: () => context.push(Routes.adminDebug),
                ),
              ],
            ),
          ],
          ],
        ),
      ),
    );
  }

  /// The "Nightly reminder" toggle plus, when enabled, a time-picker row.
  /// Saving schedules or cancels a daily local notification.
  List<Widget> _reminderRows(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(reminderControllerProvider);
    final time = TimeOfDay(hour: prefs.time.hour, minute: prefs.time.minute);
    return [
      _ToggleRow(
        icon: Icons.notifications_active_rounded,
        iconTint: _IconTint.lamp,
        title: 'Nightly reminder',
        subtitle: prefs.enabled
            ? 'Every day at ${time.format(context)}'
            : 'Get a nightly nudge to read',
        value: prefs.enabled,
        onChanged: (value) {
          ref.read(reminderControllerProvider.notifier).setEnabled(value);
          if (value) ref.read(sfxServiceProvider).play(SoundEffect.tap);
        },
      ),
      if (prefs.enabled)
        _NavRow(
          icon: Icons.schedule_rounded,
          title: 'Reminder time',
          trailingText: time.format(context),
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

  void _showAbout(BuildContext context) {
    showAboutDialog(
      context: context,
      applicationName: 'owlnighter',
      applicationVersion: 'Version 1.0 · a book at bedtime',
      children: const [
        Padding(
          padding: EdgeInsets.only(top: AppSpacing.sm),
          child: Text(
            'A book at bedtime, kept gently alive. Read a little each night, '
            'keep your lamp lit, and let the owl stay up with you.',
          ),
        ),
      ],
    );
  }
}

/// A lamp-gold uppercase section label above each settings group.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, AppSpacing.lg, 4, AppSpacing.sm),
      child: Text(
        text.toUpperCase(),
        style: AppType.caption.copyWith(
          color: AppColors.faint,
          letterSpacing: 2,
          fontSize: 11,
        ),
      ),
    );
  }
}

/// A grouped "card" that stacks its [children] rows with hairline dividers,
/// matching the prototype's `.card` container.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.night700, AppColors.night800],
        ),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, thickness: 1, color: AppColors.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

enum _IconTint { twilight, lamp, danger }

/// The small rounded icon tile at the head of every settings row.
class _RowIcon extends StatelessWidget {
  const _RowIcon({required this.icon, required this.tint});
  final IconData icon;
  final _IconTint tint;

  @override
  Widget build(BuildContext context) {
    final (Color fg, Color bg) = switch (tint) {
      _IconTint.twilight => (AppColors.twilightHi, const Color(0x248E82F2)),
      _IconTint.lamp => (AppColors.lamp, const Color(0x24FFCE7A)),
      _IconTint.danger => (AppColors.danger500, const Color(0x24FB6F7C)),
    };
    return Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.sm),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 19, color: fg),
    );
  }
}

/// A settings row carrying a polished pill [_PillToggle]. The whole row is
/// tappable (flips the toggle) so the control has a large, forgiving hit area.
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
    this.iconTint = _IconTint.twilight,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  final _IconTint iconTint;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: title,
      child: InkWell(
        onTap: () => onChanged(!value),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          child: Row(
            children: [
              _RowIcon(icon: icon, tint: iconTint),
              const SizedBox(width: AppSpacing.md - 3),
              Expanded(child: _RowText(title: title, subtitle: subtitle)),
              const SizedBox(width: AppSpacing.sm),
              _PillToggle(value: value),
            ],
          ),
        ),
      ),
    );
  }
}

/// A read-only or navigational row (chevron / trailing text). When [onTap] is
/// null it renders as a static informational row.
class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: 14,
      ),
      child: Row(
        children: [
          _RowIcon(
            icon: icon,
            tint: danger ? _IconTint.danger : _IconTint.twilight,
          ),
          const SizedBox(width: AppSpacing.md - 3),
          Expanded(
            child: _RowText(
              title: title,
              subtitle: subtitle,
              titleColor: danger ? AppColors.danger500 : null,
            ),
          ),
          if (trailingText != null) ...[
            Text(
              trailingText!,
              style: AppType.label.copyWith(
                color: AppColors.twilightHi,
                fontSize: 13,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
          ],
          if (onTap != null && !danger)
            const Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: AppColors.faint,
            ),
        ],
      ),
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, child: row);
  }
}

class _RowText extends StatelessWidget {
  const _RowText({required this.title, this.subtitle, this.titleColor});
  final String title;
  final String? subtitle;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          style: AppType.label.copyWith(
            color: titleColor ?? AppColors.moon,
            fontSize: 14.5,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: AppType.caption.copyWith(
              color: AppColors.faint,
              fontSize: 11.5,
            ),
          ),
        ],
      ],
    );
  }
}

/// The iOS-style pill toggle from the prototype: a plum track that fills with a
/// twilight gradient when on, and a knob that springs across. Honors reduced
/// motion by snapping instead of animating.
class _PillToggle extends StatelessWidget {
  const _PillToggle({required this.value});
  final bool value;

  @override
  Widget build(BuildContext context) {
    final reduce = reduceMotionOf(context);
    return IgnorePointer(
      child: AnimatedContainer(
        duration: reduce ? Duration.zero : AppMotion.fast,
        curve: AppMotion.standard,
        width: 48,
        height: 28,
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          gradient: value
              ? const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [AppColors.twilightHi, AppColors.twilight],
                )
              : null,
          color: value ? null : AppColors.night600,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          border: Border.all(
            color: value ? Colors.transparent : AppColors.line,
          ),
        ),
        alignment: value ? Alignment.centerRight : Alignment.centerLeft,
        child: AnimatedContainer(
          duration: reduce ? Duration.zero : AppMotion.fast,
          curve: AppMotion.spring,
          width: 22,
          height: 22,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(color: Color(0x66000000), blurRadius: 5),
            ],
          ),
        ),
      ),
    );
  }
}
