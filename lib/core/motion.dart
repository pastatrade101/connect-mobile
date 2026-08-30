import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

/// The app's motion vocabulary, in one place.
///
/// Two rules hold this together, and they are the difference between an app that
/// feels quick and one that feels slow:
///
///   1. NOTHING BLOCKS A READ. Entrance animations run 200–320ms. A person opening
///      the inbox for the fortieth time today must never wait on choreography.
///   2. CONTENT ANIMATES ONCE. A list fades in when it first arrives, not every
///      time a parent rebuilds — which is why these take an index and a key rather
///      than being sprinkled inline.
class Motion {
  const Motion._();

  static const quick = Duration(milliseconds: 180);
  static const enter = Duration(milliseconds: 260);
  static const slow = Duration(milliseconds: 420);

  /// Gap between items in a staggered list. Small: eight rows should be fully in
  /// under half a second, not arriving one at a time like a slideshow.
  static const stagger = Duration(milliseconds: 38);

  /// The one curve for anything arriving on screen.
  static const curve = Curves.easeOutCubic;

  /// How far a card travels as it arrives — a hint of movement, not a slide.
  static const rise = 14.0;
}

/// Something arriving on screen: fade up, once.
extension EntranceAnimation on Widget {
  Widget entrance({int index = 0, Duration? delay}) => animate()
      .fadeIn(duration: Motion.enter, delay: delay ?? Motion.stagger * index, curve: Motion.curve)
      .moveY(begin: Motion.rise, end: 0, duration: Motion.enter, curve: Motion.curve);

  /// For a number or badge that has just changed — a small pop, no bounce.
  Widget pop() => animate().scale(
    begin: const Offset(0.86, 0.86),
    end: const Offset(1, 1),
    duration: Motion.quick,
    curve: Curves.easeOutBack,
  );

  /// A quiet, endless breath for empty states, so a screen with nothing on it
  /// still looks alive rather than broken.
  Widget breathe() => animate(
    onPlay: (c) => c.repeat(reverse: true),
  ).scaleXY(begin: 1, end: 1.04, duration: const Duration(milliseconds: 1900), curve: Curves.easeInOut);
}

/// A row that acknowledges a finger before its screen has loaded.
///
/// Operations apps live on slow networks: the gap between tapping a chat and the
/// thread appearing can be a second. Without this, people tap twice.
class PressableRow extends StatefulWidget {
  const PressableRow({super.key, required this.child, required this.onTap, this.scale = 0.985});
  final Widget child;
  final VoidCallback onTap;
  final double scale;

  @override
  State<PressableRow> createState() => _PressableRowState();
}

class _PressableRowState extends State<PressableRow> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: Motion.quick,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Text scaling, for chrome whose geometry cannot grow.
///
/// A tab bar, a segmented switch and a section label all live in boxes with a
/// fixed height. At iOS's accessibility text sizes their labels overflow — the
/// nav bar reported "BOTTOM OVERFLOWED BY 1.00 PIXELS" on every tab.
///
/// The rule: CONTENT scales freely, because that is the whole point of the
/// setting and a traveller's name at 300% is exactly what somebody needs.
/// CHROME clamps, because a nav label at 300% is not more accessible if it is
/// clipped in half. Wrap only the fixed-geometry parts.
class ChromeText extends StatelessWidget {
  const ChromeText({super.key, required this.child, this.max = 1.3});

  final Widget child;
  final double max;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return MediaQuery(
      data: media.copyWith(textScaler: media.textScaler.clamp(maxScaleFactor: max)),
      child: child,
    );
  }
}
