import 'package:flutter/material.dart';

import '../../shared/theme/theme_re_exports.dart';

/// Notification preferences. The push token registration + delivery is handled
/// by PushService; this screen is the user-facing toggle surface. Toggles are
/// local placeholders until a preferences endpoint exists.
class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});
  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  bool _nightlyReminder = true;
  bool _streakWarning = true;
  bool _celebrations = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: Text('Choose the nudges that keep you reading.'),
          ),
          SwitchListTile(
            title: const Text('Nightly reminder'),
            subtitle: const Text('Your next step is ready to read.'),
            value: _nightlyReminder,
            onChanged: (v) => setState(() => _nightlyReminder = v),
          ),
          SwitchListTile(
            title: const Text('Streak warning'),
            subtitle: const Text('Read tonight to protect your streak.'),
            value: _streakWarning,
            onChanged: (v) => setState(() => _streakWarning = v),
          ),
          SwitchListTile(
            title: const Text('Celebrations'),
            subtitle: const Text('Cheer when you finish tonight.'),
            value: _celebrations,
            onChanged: (v) => setState(() => _celebrations = v),
          ),
        ],
      ),
    );
  }
}
