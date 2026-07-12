import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// A back/close button that always provides an escape hatch: it pops the
/// navigator when possible, otherwise navigates to [fallbackLocation].
///
/// This fixes the post-quiz dead-end. The reading-path screen can be reached
/// via a stack-replacing `context.go(...)` (from the completion flow), where
/// there is nothing to pop and a plain back button would be absent. Here
/// [GoRouter]'s `canPop` is false in that case, so we fall back to the library
/// and the user is never stranded.
class AdaptiveBackButton extends StatelessWidget {
  const AdaptiveBackButton({
    super.key,
    required this.fallbackLocation,
    this.icon = Icons.arrow_back_rounded,
    this.tooltip,
  });

  /// Where to go when there is no route to pop.
  final String fallbackLocation;
  final IconData icon;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip ?? MaterialLocalizations.of(context).backButtonTooltip,
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go(fallbackLocation);
        }
      },
    );
  }
}
