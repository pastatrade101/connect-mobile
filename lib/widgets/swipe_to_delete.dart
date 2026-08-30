import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Swipe left to reveal Delete.
///
/// Deliberately NOT Dismissible: that swipes the row away in one motion, which
/// is the wrong gesture for something destructive on a list you scroll with
/// your thumb. Revealing a button costs a second deliberate tap, and the row
/// stays put until you make it.
class SwipeToDelete extends StatefulWidget {
  const SwipeToDelete({super.key, required this.child, required this.onDelete, this.enabled = true});

  final Widget child;
  final VoidCallback onDelete;

  /// Off for kinds that cannot be deleted, so the gesture is not offered where
  /// it would only ever fail.
  final bool enabled;

  @override
  State<SwipeToDelete> createState() => _SwipeToDeleteState();
}

class _SwipeToDeleteState extends State<SwipeToDelete> with SingleTickerProviderStateMixin {
  static const _revealed = 96.0;
  double _offset = 0;
  bool _open = false;

  void _settle() {
    setState(() {
      _open = _offset < -_revealed / 2;
      _offset = _open ? -_revealed : 0;
    });
  }

  void _close() => setState(() {
    _open = false;
    _offset = 0;
  });

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    // GroupedList paints the card; the rows inside it are TRANSPARENT. So the
    // sliding content has to carry its own opaque background, or the red sits
    // visible behind every row at rest instead of only when revealed.
    final dark = Theme.of(context).brightness == Brightness.dark;
    final surface = dark ? Brand.darkSurface : Brand.surface;

    return Stack(
      children: [
        // Not painted at all while closed: at rest there is nothing behind the
        // row to bleed through the card's antialiased corners.
        if (_offset != 0)
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerRight,
              child: SizedBox(
                width: _revealed,
                child: Material(
                  color: Brand.danger,
                  child: InkWell(
                    onTap: _open
                        ? () {
                            _close();
                            widget.onDelete();
                          }
                        : null,
                    child: const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.delete_outline_rounded, color: Colors.white, size: 20),
                        SizedBox(height: 2),
                        Text('Delete', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        // The transform wraps the GESTURE DETECTOR, not just its child.
        //
        // With it inside, the detector's own box stayed full-width while only
        // the paint moved — and being opaque and above the button in the stack,
        // it swallowed the tap on Delete. The button was revealed and unusable.
        // Translating the detector too means the revealed strip genuinely is
        // not part of it, so the tap reaches the button underneath.
        AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOutCubic,
          transform: Matrix4.translationValues(_offset, 0, 0),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => setState(() {
              // Left only, and never further than the button is wide.
              _offset = (_offset + d.delta.dx).clamp(-_revealed, 0.0);
            }),
            onHorizontalDragEnd: (_) => _settle(),
            // An open row swallows the next tap to close itself. Opening a
            // record by accident when you meant to put the row back is worse
            // than a second tap.
            onTap: _open ? _close : null,
            child: ColoredBox(
              color: surface,
              child: AbsorbPointer(absorbing: _open, child: widget.child),
            ),
          ),
        ),
      ],
    );
  }
}
