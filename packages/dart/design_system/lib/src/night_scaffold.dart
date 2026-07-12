import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'art/night_sky.dart';
import 'tokens.dart';

/// The canonical screen shell for owlnighter.
///
/// This is the *root fix* for the "black band behind the app bar" bug: instead
/// of the previous pattern of a fully-transparent [Scaffold] + transparent
/// [AppBar] that let the raw (black) Android window background show through the
/// region behind the bar, [NightScaffold] gives the [Scaffold] a **real**
/// theme-matching background ([AppColors.night900]) and sets
/// [Scaffold.extendBodyBehindAppBar] so the body (and its [NightSky]) paints all
/// the way up under a transparent [AppBar]. There is therefore never any
/// window background peeking through — the band is gone whether or not the
/// caller asks for the star field.
///
/// The [AppBar] itself is transparent with zero elevation and a light
/// [SystemUiOverlayStyle] so the status-bar icons stay legible against the dark
/// sky.
///
/// The [body] renders inside a [Stack]: a [Positioned.fill] [NightSky] (only
/// when [showSky] is true) sits behind a [SafeArea] wrapping the caller's body.
/// Screens that opt out of the sky ([showSky] `false`) still get the night900
/// background and the extend-behind behaviour — they simply don't paint stars.
class NightScaffold extends StatelessWidget {
  const NightScaffold({
    super.key,
    this.title,
    required this.body,
    this.appBarBottom,
    this.actions,
    this.floatingActionButton,
    this.showSky = true,
    this.starCount = 40,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  /// Optional app-bar title. When null (and there are no [actions], [leading],
  /// or [appBarBottom], and nothing needs an implied back button) the app bar
  /// is still shown so [extendBodyBehindAppBar] has a consistent inset.
  final String? title;

  /// The screen content, laid over the (optional) sky and inside a [SafeArea].
  final Widget body;

  /// Optional widget shown at the bottom of the app bar (e.g. a [TabBar] or a
  /// progress indicator).
  final PreferredSizeWidget? appBarBottom;

  /// Optional trailing action widgets for the app bar.
  final List<Widget>? actions;

  /// Optional floating action button, forwarded to [Scaffold].
  final Widget? floatingActionButton;

  /// Whether to paint a [NightSky] behind the body. Even when false the
  /// scaffold keeps its night900 background and extend-behind behaviour, so the
  /// black band never returns.
  final bool showSky;

  /// Star count forwarded to [NightSky] when [showSky] is true.
  final int starCount;

  /// Optional leading widget for the app bar (e.g. a custom back button).
  final Widget? leading;

  /// Whether the app bar should imply a leading widget (back button). Forwarded
  /// to [AppBar.automaticallyImplyLeading].
  final bool automaticallyImplyLeading;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // A real, theme-matching background — the actual fix. No transparency
      // tricks, so nothing behind the bar can show the black window.
      backgroundColor: AppColors.night900,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: title == null ? null : Text(title!),
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
        actions: actions,
        bottom: appBarBottom,
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      floatingActionButton: floatingActionButton,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (showSky) Positioned.fill(child: NightSky(starCount: starCount)),
          SafeArea(child: body),
        ],
      ),
    );
  }
}
