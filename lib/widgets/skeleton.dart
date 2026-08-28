import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/theme.dart';

/// What a screen looks like a moment before it has anything to say.
///
/// A spinner tells a person that something is happening. A skeleton tells them
/// *what* is coming — the shape of the answer arrives before the answer does, so
/// the eye is already in the right place when it lands and nothing jumps. That is
/// the whole reason these mirror the real layouts rather than being a generic
/// grey rectangle: a skeleton that does not match what replaces it is a spinner
/// with extra steps, and a worse one, because it promises a shape it then breaks.
///
/// The sweep is applied ONCE, by [Shimmer], to a whole tree of [SkeletonBox]es.
/// Shimmering each box separately looks like a fault — a dozen independent
/// glints with no common direction. One highlight crossing the whole surface
/// reads as a single thing loading, which is what it is.

/// A block standing in for text or a control that has not arrived yet.
class SkeletonBox extends StatelessWidget {
  const SkeletonBox({super.key, this.width, this.height = 12, this.radius = 6});

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        // Faint on purpose. The shimmer needs somewhere to travel, and a dark
        // placeholder block reads as content rather than as an absence.
        color: Tone.isDark(context) ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

/// A round block, for where an avatar or an icon disc will be.
class SkeletonDisc extends StatelessWidget {
  const SkeletonDisc({super.key, this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) => SkeletonBox(width: size, height: size, radius: size / 2);
}

/// Sweeps one highlight across everything inside it, forever, until real content
/// replaces the lot.
class Shimmer extends StatelessWidget {
  const Shimmer({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final dark = Tone.isDark(context);
    return child
        .animate(onPlay: (controller) => controller.repeat())
        .shimmer(
          duration: const Duration(milliseconds: 1250),
          // Slightly off-vertical, so the sweep crosses rows diagonally and the
          // whole surface is clearly one moving thing.
          angle: 0.4,
          color: dark ? Colors.white.withValues(alpha: 0.22) : Colors.white.withValues(alpha: 0.85),
        );
  }
}

/// Rows in a card, for the inbox and for Work: a disc, two lines, a short tail.
///
/// The widths descend and then reset rather than being uniform, because a column
/// of identical bars reads as a barcode; uneven ones read as text.
class SkeletonRows extends StatelessWidget {
  const SkeletonRows({super.key, this.rows = 5, this.disc = true});

  final int rows;
  final bool disc;

  static const _titleWidths = [148.0, 190.0, 120.0, 166.0, 134.0, 178.0];
  static const _bodyWidths = [220.0, 168.0, 246.0, 196.0, 232.0, 180.0];

  @override
  Widget build(BuildContext context) {
    final dark = Tone.isDark(context);
    return Shimmer(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: dark ? Brand.darkSurface : Brand.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: dark ? Brand.darkLine : Brand.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            for (var i = 0; i < rows; i++) ...[
              if (i > 0) Divider(height: 1, indent: 16, color: dark ? Brand.darkLine : Brand.line),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Row(
                  children: [
                    if (disc) ...[const SkeletonDisc(size: 42), const SizedBox(width: 12)],
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: _titleWidths[i % _titleWidths.length], height: 13),
                          const SizedBox(height: 8),
                          SkeletonBox(width: _bodyWidths[i % _bodyWidths.length], height: 11),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    const SkeletonBox(width: 30, height: 10),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Home, which is not a list: a summary card, then a labelled group of rows.
class SkeletonHome extends StatelessWidget {
  const SkeletonHome({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Tone.isDark(context);
    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: NavBar.clearance),
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Today's card.
        Shimmer(
          child: Container(
            height: 104,
            margin: const EdgeInsets.symmetric(horizontal: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: dark ? Brand.darkSurface : Brand.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: dark ? Brand.darkLine : Brand.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [const SkeletonBox(width: 58, height: 11), SkeletonBox(width: 78, height: 11, radius: 6)],
                ),
                const Spacer(),
                Row(
                  children: [
                    for (var i = 0; i < 3; i++) ...[
                      if (i > 0) const SizedBox(width: 26),
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SkeletonBox(width: 34, height: 20),
                          SizedBox(height: 7),
                          SkeletonBox(width: 54, height: 10),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // A group label, then the rows under it.
        const Shimmer(
          child: Padding(padding: EdgeInsets.only(left: 18, bottom: 10), child: SkeletonBox(width: 96, height: 10)),
        ),
        const SkeletonRows(rows: 3),
      ],
    );
  }
}

/// A thread: bubbles alternating sides, at believable lengths.
class SkeletonThread extends StatelessWidget {
  const SkeletonThread({super.key});

  // Width, and whether it is ours. Uneven, because a real conversation is.
  static const _bubbles = [
    (216.0, false),
    (150.0, true),
    (248.0, false),
    (188.0, false),
    (132.0, true),
    (204.0, true),
    (168.0, false),
  ];

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 124),
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final (width, mine) in _bubbles)
            Align(
              alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: SkeletonBox(width: width, height: 42, radius: 14),
              ),
            ),
        ],
      ),
    );
  }
}
