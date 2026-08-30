import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/motion.dart';
import '../core/theme.dart';

/// How close a trip is to being able to leave.
///
/// The colour is driven by whether anything CRITICAL is outstanding and how soon
/// the trip departs — never by the percentage. Ninety per cent with no driver is
/// not nearly-ready, and painting it amber would be the ring lying about the one
/// thing it exists to say. Red is reserved for blocked AND leaving within the
/// week, because every trip in setup is blocked and a screen of red says nothing.
class ReadinessRing extends StatelessWidget {
  const ReadinessRing({
    super.key,
    required this.percent,
    required this.canBeReady,
    this.daysToDeparture,
    this.status,
    this.size = 44,
  });

  final int? percent;
  final bool? canBeReady;
  final int? daysToDeparture;
  final String? status;
  final double size;

  Color _tone(BuildContext context) {
    if (status == 'COMPLETED' || status == 'CANCELLED') return Tone.muted(context);
    final blocked = canBeReady == false;
    final soon = daysToDeparture != null && daysToDeparture! <= 7;
    if (blocked) return soon ? Tone.danger(context) : Tone.warning(context);
    return (percent ?? 0) >= 100 ? Tone.success(context) : Tone.blue(context);
  }

  @override
  Widget build(BuildContext context) {
    final colour = _tone(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
              progress: (percent ?? 0) / 100,
              colour: colour,
              track: Tone.line(context),
            ),
          ),
          Text(
            percent == null ? '—' : '$percent',
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: colour),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.colour, required this.track});

  final double progress;
  final Color colour;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 4) / 2;
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..color = track;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = colour;

    canvas.drawCircle(centre, radius, base);
    canvas.drawArc(
      Rect.fromCircle(center: centre, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress.clamp(0, 1),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.colour != colour || old.track != track;
}

/// One trip in a list: the ring, where it is going, when it leaves, and — the
/// line the row exists for — what is still stopping it.
class TripRow extends StatelessWidget {
  const TripRow({super.key, required this.trip, required this.onTap});

  final Map<String, dynamic> trip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final days = (trip['daysToDeparture'] as num?)?.toInt();
    final canBeReady = trip['canBeReady'] as bool?;
    final blocking = (trip['blockingLabels'] as List? ?? const []).cast<String>();
    final urgent = canBeReady == false && days != null && days >= 0 && days <= 7;

    return PressableRow(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ReadinessRing(
              percent: (trip['percent'] as num?)?.toInt(),
              canBeReady: canBeReady,
              daysToDeparture: days,
              status: (trip['status'] ?? '').toString(),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    // The countdown aligns to the FIRST line of a title that may
                    // now wrap, rather than floating to the vertical middle.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          (trip['title'] ?? 'Trip').toString(),
                          // Two lines. The title is how somebody identifies the
                          // trip; truncating it to protect a countdown gets the
                          // priority backwards.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, height: 1.25),
                        ),
                      ),
                      if (_countdown(days) != null) ...[
                        const SizedBox(width: 8),
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                          _countdown(days)!,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: urgent ? Tone.danger(context) : Tone.muted(context),
                          ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    _subtitle(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12.5, color: Tone.muted(context)),
                  ),
                  if (blocking.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      // Naming what is missing is the difference between a status
                      // and an instruction.
                      'Still needs ${blocking.map(_shorten).join(', ')}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: urgent ? Tone.danger(context) : Tone.warning(context),
                      ),
                    ),
                  ] else if ((trip['status'] ?? '') == 'READY') ...[
                    const SizedBox(height: 5),
                    Text(
                      'Ready to go',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: Tone.success(context)),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle() {
    final guests = (trip['guests'] as num?)?.toInt() ?? 0;
    final customer = (trip['customer'] ?? '').toString();
    final parts = <String>[
      if (customer.isNotEmpty) customer,
      '$guests guest${guests == 1 ? '' : 's'}',
      if ((trip['driver'] ?? '').toString().isNotEmpty) trip['driver'].toString(),
    ];
    return parts.join(' · ');
  }

  /// "in 3 days" beats a date somebody has to subtract from today.
  static String? _countdown(int? days) {
    if (days == null) return null;
    if (days < 0) return 'under way';
    if (days == 0) return 'today';
    if (days == 1) return 'tomorrow';
    return 'in $days days';
  }

  /// The server sends checklist wording ("Driver assigned"); a blocker list needs
  /// the noun.
  static String _shorten(String label) =>
      label.replaceAll(RegExp(r'\s+(assigned|booked|received|set|confirmed)$', caseSensitive: false), '').toLowerCase();
}

/// One line of a trip's setup: an icon that carries the state, the field, and a
/// tap target that is the whole row.
///
/// The icon colour is the point — green for done, red for a critical gap, grey
/// for optional — so somebody scanning finds the blocking row by shape instead
/// of reading four identical "Missing" labels.
class SetupRow extends StatelessWidget {
  const SetupRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.critical,
    required this.enabled,
    this.actionLabel,
    this.onTap,
  });

  final String label;
  final String? value;
  final IconData icon;
  final bool critical;
  final bool enabled;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final set = (value ?? '').isNotEmpty;
    final tone = set
        ? Tone.success(context)
        : critical
        ? Tone.danger(context)
        : Tone.muted(context);

    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: tone),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 11.5, color: Tone.muted(context))),
                const SizedBox(height: 1),
                Text(
                  set ? value! : (critical ? 'Required before departure' : 'Not set'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: set ? FontWeight.w600 : FontWeight.w400,
                    color: set ? Tone.ink(context) : Tone.muted(context),
                  ),
                ),
              ],
            ),
          ),
          if (enabled && onTap != null)
            Text(
              actionLabel ?? (set ? 'Change' : 'Set'),
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Tone.blue(context)),
            ),
        ],
      ),
    );

    return enabled && onTap != null ? PressableRow(onTap: onTap!, child: row) : row;
  }
}
