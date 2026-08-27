import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:rive/rive.dart';

import '../core/motion.dart';

/// A Rive animation when there is one, a coded animation when there is not.
///
/// Rive files are authored artwork — they come out of the Rive editor, not out of
/// code. Rather than ship a screen that is blank until somebody draws one, every
/// slot here has a real fallback that already looks finished. Drop a `.riv` into
/// `assets/rive/` with the matching name and it takes over on the next launch,
/// with no code change.
///
/// Expected files, all optional:
///   assets/rive/splash.riv        — the mark, on first launch
///   assets/rive/empty_inbox.riv   — nothing in the inbox yet
///   assets/rive/empty_work.riv    — nothing open
///   assets/rive/success.riv       — something completed
class RiveArt extends StatefulWidget {
  const RiveArt({
    super.key,
    required this.name,
    required this.fallback,
    this.size = 120,
    this.fit = Fit.contain,
  });

  /// File name without the extension, e.g. `empty_inbox`.
  final String name;

  /// What to show when that file is not in the bundle — which is the normal case
  /// until artwork exists.
  final Widget fallback;

  final double size;
  final Fit fit;

  @override
  State<RiveArt> createState() => _RiveArtState();
}

class _RiveArtState extends State<RiveArt> {
  /// null = still looking, false = not bundled, true = play it.
  bool? _present;

  @override
  void initState() {
    super.initState();
    _look();
  }

  Future<void> _look() async {
    try {
      await rootBundle.load('assets/rive/${widget.name}.riv');
      if (mounted) setState(() => _present = true);
    } catch (_) {
      // Absent is the expected case, not an error worth logging every launch.
      if (mounted) setState(() => _present = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_present == null) return SizedBox(height: widget.size, width: widget.size);
    if (_present == false) return widget.fallback;
    // rive 0.14 builds through a file loader and a state machine rather than the
    // old one-line asset widget. If the file is malformed we quietly fall back
    // rather than showing a broken box on someone's dashboard.
    return SizedBox(
      height: widget.size,
      width: widget.size,
      child: RiveWidgetBuilder(
        fileLoader: FileLoader.fromAsset('assets/rive/${widget.name}.riv', riveFactory: Factory.rive),
        builder: (context, state) => switch (state) {
          RiveLoaded() => RiveWidget(controller: state.controller, fit: widget.fit),
          RiveFailed() => widget.fallback,
          RiveLoading() => const SizedBox.shrink(),
        },
      ),
    );
  }
}

/// The mark, breathing, while the session is restored. Replaced by
/// `assets/rive/splash.riv` the moment one exists.
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
