import 'package:flutter/material.dart';

import '../core/motion.dart';

/// Illustration slots, drawn in code.
///
/// These were Rive-backed. The package shipped a 2.7 MB native runtime to every
/// phone for artwork that did not exist yet, so it came out — on Tanzanian mobile
/// data that is a quarter of the download for nothing on screen.
///
/// The seam is deliberately unchanged. When there are real `.riv` files, add
/// `rive` back to pubspec and restore the player inside [RiveArt]; every call
/// site already passes a name and a fallback, so nothing else moves.
///
///   assets/rive/splash.riv        — first launch, while the session is restored
///   assets/rive/empty_inbox.riv   — the inbox with no conversations
///   assets/rive/empty_work.riv    — Work with nothing open
///   assets/rive/success.riv       — after something completes
class RiveArt extends StatelessWidget {
  const RiveArt({super.key, required this.name, required this.fallback, this.size = 120});

  /// The artwork this slot would use, once one exists.
  final String name;

  /// What is drawn today.
  final Widget fallback;

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: size,
    child: Center(child: fallback),
  );
}

/// The mark, breathing, while the session is restored.
class BrandSplash extends StatelessWidget {
  const BrandSplash({super.key});

  @override
  Widget build(BuildContext context) => Center(
    child: RiveArt(
      name: 'splash',
      size: 128,
      fallback: Image.asset('assets/logo.png', width: 96, height: 96).breathe(),
    ),
  );
}
