/// Layout rules for screens wider than a phone.
///
/// The app is designed for a phone held in one hand, and that design is the one
/// that must not move. Everything here is therefore a no-op below the
/// breakpoints: a phone is narrower than every threshold in this file, so its
/// layout resolves exactly as it did before any of this existed.
///
/// On an iPad the same widgets were being stretched to the full width of a
/// 13-inch screen — rows a thousand points wide with the chevron marooned at the
/// far end, a nav bar spread edge to edge, and the whole page sitting in the top
/// third with nothing under it. Wide screens get a measured column and, where
/// the content genuinely divides, two of them.
library;

import 'package:flutter/widgets.dart';

/// Where a phone layout stops being the right answer. Comfortably above the
/// widest phone in portrait (an iPhone 16 Pro Max is 440) and below the
/// narrowest iPad (an iPad mini is 744), so no phone ever crosses it.
const double kTabletBreakpoint = 700;

/// The widest a column of rows and running text should get. Past this, a row's
/// label and its trailing control drift so far apart that they stop reading as
/// one row.
const double kContentMaxWidth = 980;

/// Two columns only once each would still be wider than a phone.
const double kTwoColumnBreakpoint = 900;

/// The nav bar's own cap. It is a set of five targets, not a container: stretched
/// across an iPad the icons end up further apart than a thumb or an eye wants.
const double kNavMaxWidth = 620;

bool isTablet(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= kTabletBreakpoint;

/// Centres [child] and stops it stretching. Below [maxWidth] — which is every
/// phone — this adds a Center and nothing else.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) => Center(
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}
