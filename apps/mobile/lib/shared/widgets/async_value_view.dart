import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/theme_re_exports.dart';

/// Standard renderer for a Riverpod [AsyncValue]: spinner while loading, a
/// retryable error state, and the [data] builder on success. Keeps every
/// feature screen from re-implementing the same three branches.
class AsyncValueView<T> extends StatelessWidget {
  const AsyncValueView({
    super.key,
    required this.value,
    required this.data,
    this.onRetry,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: data,
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, _) => _ErrorState(message: '$err', onRetry: onRetry),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded,
                size: 48, color: AppColors.inkMuted),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Something went wrong',
              style: AppType.headline.copyWith(color: AppColors.ink),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppType.caption.copyWith(color: AppColors.inkMuted),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: AppSpacing.lg),
              FilledButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
