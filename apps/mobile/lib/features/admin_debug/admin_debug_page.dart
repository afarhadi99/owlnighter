import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/deep_links/deep_links.dart';
import '../../services/offline_sync/offline_providers.dart';
import '../../shared/theme/theme_re_exports.dart';
import '../../shared/util/env.dart';

/// On-device debug console: inspect config, drain the sync queue manually, and
/// test deep-link routing. Compiled in only when ENABLE_ADMIN_DEBUG is set.
class AdminDebugPage extends ConsumerWidget {
  const AdminDebugPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(syncQueueProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Admin / debug')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _kv('API base URL', AppEnv.apiBaseUrl),
          _kv('App link host', AppEnv.appLinkHost),
          _kv('Deep-link scheme', '${DeepLinks.scheme}://'),
          const Divider(),
          FutureBuilder<int>(
            future: queue.pendingCount(),
            builder: (_, snap) => ListTile(
              title: const Text('Pending sync operations'),
              trailing: Text('${snap.data ?? 0}'),
            ),
          ),
          FilledButton.tonal(
            onPressed: queue.drain,
            child: const Text('Drain sync queue now'),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: Text('Sample deep link:'),
          ),
          SelectableText(
            DeepLinks.stepLink('PLAN_ID', 'STEP_ID').toString(),
            style: AppType.caption,
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => ListTile(
        dense: true,
        title: Text(k, style: AppType.caption),
        subtitle: SelectableText(v, style: AppType.body),
      );
}
