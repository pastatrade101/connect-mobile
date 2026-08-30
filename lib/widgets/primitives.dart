import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/motion.dart';
import '../core/theme.dart';

/// The building blocks every screen is made of.
///
/// Written once, on purpose: a phone screen has room for one idea at a time, so the
/// app is rows, chips and grouped lists — not a card around every fact. Cards appear
/// only where grouping says something true about the content.

// ── header ────────────────────────────────────────────────────────────────────

/// The top of a screen, kept deliberately short.
///
/// One line of who and where, one small line of context, and the two controls a
/// phone actually needs there: what is new, and me. It used to run to three lines
/// on a narrow phone and push the real work below the fold.
class MobileHeader extends StatelessWidget {
  const MobileHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.initials,
    this.onAccountTap,
    this.trailing,
    this.onAlerts,
    this.alerts = 0,
    this.subtitleTone,
    this.onBack,
  });

  final String title;
  final String? subtitle;
  final String? initials;
  final VoidCallback? onAccountTap;
  final Widget? trailing;

  /// The bell. Absent on screens where "what is new" makes no sense.
  final VoidCallback? onAlerts;

  /// Messages waiting for a reply — shown on the bell, capped at 99+.
  final int alerts;

  /// Colour for the subtitle when it is carrying bad news rather than context.
  final Color? subtitleTone;

  /// Set on a PUSHED screen. The tabs are roots and have nowhere to go back to,
  /// so this is absent there — but a screen you arrived at from somewhere else
  /// and cannot leave is a dead end, and the edge-swipe is not a visible one.
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      // A back chevron sits where a toolbar's leading icon does, so the left
      // inset tightens to let it — otherwise the title shifts right of every
      // other screen's.
      padding: EdgeInsets.fromLTRB(onBack == null ? 16 : 4, 4, 8, 10),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              iconSize: 22,
              visualDensity: VisualDensity.compact,
              tooltip: 'Back',
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontSize: 19, height: 1.15, letterSpacing: -0.3),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12.5,
                      height: 1.25,
                      color: subtitleTone,
                      fontWeight: subtitleTone != null ? FontWeight.w600 : null,
                    ),
                  ),
              ],
            ),
          ),
          if (onAlerts != null) _Bell(count: alerts, onTap: onAlerts!),
          if (trailing != null) trailing!,
          if (initials != null)
            InkWell(
              onTap: onAccountTap,
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: CircleAvatar(
                  radius: 16,
                  backgroundColor: Tone.blueWash(context),
                  child: Text(
                    initials!,
                    style: TextStyle(color: Tone.blue(context), fontWeight: FontWeight.w700, fontSize: 12.5),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// What is new, with the count on it. Quiet when there is nothing.
class _Bell extends StatelessWidget {
  const _Bell({required this.count, required this.onTap});
  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodySmall?.color;
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(
              count > 0 ? Icons.notifications_rounded : Icons.notifications_none_rounded,
              size: 22,
              color: count > 0 ? (Theme.of(context).brightness == Brightness.dark ? Brand.darkInk : Brand.ink) : muted,
            ),
            if (count > 0)
              Positioned(
                top: 6,
                right: count > 9 ? 2 : 6,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(
                    color: Tone.danger(context),
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 9.5,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class GroupLabel extends StatelessWidget {
  const GroupLabel({super.key, required this.text, this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 12, 8),
      child: Row(
        children: [
          // Flexible, not fixed: a long label at a large text size overflowed the
          // row rather than shortening.
          Flexible(
            child: Text(
              text.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.9),
            ),
          ),
          const Spacer(),
          if (action != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  action!,
                  style: TextStyle(color: Tone.blue(context), fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// A grouped list: one surface, hairline separators, rows inside. The mobile
/// convention, instead of a rounded white rectangle per fact.
class GroupedList extends StatelessWidget {
  const GroupedList({super.key, required this.children, this.margin});
  final List<Widget> children;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    if (children.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: margin ?? const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: dark ? Brand.darkSurface : Brand.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? Brand.darkLine : Brand.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) Divider(height: 1, indent: 16, color: dark ? Brand.darkLine : Brand.line),
            children[i],
          ],
        ],
      ),
    );
  }
}

// ── attention ─────────────────────────────────────────────────────────────────

/// One thing waiting on this person. Tapping goes to the work, never to a module.
class AttentionRow extends StatelessWidget {
  const AttentionRow({super.key, required this.item, required this.onTap});
  final Map<String, dynamic> item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final urgency = (item['urgency'] ?? 'normal').toString();
    final color = urgency == 'critical'
        ? Tone.danger(context)
        : urgency == 'high'
        ? Tone.warning(context)
        : Tone.blue(context);
    final mine = (item['scope'] ?? '') == 'mine';
    final count = (item['count'] as num? ?? 0).toInt();

    // The server writes the reason; the count is what is waiting behind it.
    final why = (item['title'] ?? item['label'] ?? '').toString();
    final what = (item['detail'] ?? '').toString();

    return PressableRow(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 62),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 12, top: 2),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          why,
                          maxLines: 2,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15, height: 1.25),
                        ),
                      ),
                      if (mine)
                        Container(
                          margin: const EdgeInsets.only(left: 7),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: Tone.blueWash(context),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            'you',
                            style: TextStyle(color: Tone.blue(context), fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  if (what.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      what,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (count > 0)
              Container(
                constraints: const BoxConstraints(minWidth: 26),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: urgency == 'normal' ? 0.10 : 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$count',
                  style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w700),
                ).pop(),
              ),
            Icon(Icons.chevron_right_rounded, size: 19, color: Theme.of(context).textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }
}

/// A customer you were already dealing with: who they are, where the business
/// stands, and the one fact that makes it actionable. Never a chat preview —
/// the state comes from the lifecycle record behind the conversation.
class ContinueRow extends StatelessWidget {
  const ContinueRow({super.key, required this.item, required this.onTap, this.onNext});
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback? onNext;

  static const _icons = {
    'enquiry': Icons.help_outline_rounded,
    'quotation': Icons.request_quote_outlined,
    'booking': Icons.event_available_outlined,
    'order': Icons.inventory_2_outlined,
    'conversation': Icons.forum_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final kind = (item['kind'] ?? 'conversation').toString();
    final next = item['next'] as Map<String, dynamic>?;
    final detail = (item['detail'] ?? '').toString();
    final muted = Theme.of(context).textTheme.bodySmall?.color;

    return PressableRow(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 72),
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: Tone.blueWash(context), borderRadius: BorderRadius.circular(10)),
              child: Icon(_icons[kind] ?? Icons.forum_outlined, size: 18, color: Tone.blue(context)),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (item['customer'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15.5),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    (item['state'] ?? '').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13, color: muted),
                  ),
                  if (detail.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(
                      detail,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5),
                    ),
                  ],
                ],
              ),
            ),
            if (next != null && onNext != null) ...[
              const SizedBox(width: 8),
              NextActionButton(label: next['label'].toString(), onTap: onNext!, dense: true),
            ] else
              Icon(Icons.chevron_right_rounded, size: 19, color: muted),
          ],
        ),
      ),
    );
  }
}

/// Nothing waiting: one quiet line, not a card that eats the screen.
class CalmIndicator extends StatelessWidget {
  const CalmIndicator({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 2, 18, 6),
      child: Row(
        children: [
          Icon(Icons.check_circle_rounded, size: 16, color: Tone.success(context)),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13.5))),
        ],
      ),
    );
  }
}

// ── next action ───────────────────────────────────────────────────────────────

/// The one thing to do, from the server's resolver. Used on Home, on work rows and
/// after a successful create — so the app never ends a workflow at "done".
class NextActionButton extends StatelessWidget {
  const NextActionButton({super.key, required this.label, this.hint, required this.onTap, this.dense = false});
  final String label;
  final String? hint;
  final VoidCallback onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    if (dense) {
      return TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          minimumSize: const Size(0, 36),
          backgroundColor: Tone.blueWash(context),
          foregroundColor: Tone.blue(context),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Material(
        color: Tone.blue(context),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700),
                      ),
                      if (hint != null) ...[
                        const SizedBox(height: 2),
                        Text(hint!, style: const TextStyle(color: Color(0xCCFFFFFF), fontSize: 12.5)),
                      ],
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_rounded, color: Colors.white, size: 19),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── compact stats ─────────────────────────────────────────────────────────────

/// Today, in one line. Secondary information stays secondary.
/// Today, at the top, on the only decorated surface in the app.
///
/// Everything else here is a white row on a grey ground, deliberately. This one
/// card earns its colour by being the single glanceable summary of the day —
/// and it is the last thing the eye should stop on, not the first thing it fights.
class TodayCard extends StatelessWidget {
  const TodayCard({super.key, required this.tiles, this.currency = ''});
  final List<Map<String, dynamic>> tiles;

  /// Amounts are shown in the business's own currency, never bare.
  final String currency;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final shown = tiles.take(3).toList();
    final dark = Tone.isDark(context);

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 2, 14, 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        // At night the card stops being a lamp: a deep surface lifted a little off
        // the black, with the blue kept for the accents rather than the whole field.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark ? const [Color(0xFF16202C), Color(0xFF0D131B)] : const [Color(0xFF1C84EE), Color(0xFF0F5FB8)],
        ),
        border: dark ? Border.all(color: Brand.darkLine) : null,
        boxShadow: dark
            ? null
            : [BoxShadow(color: Brand.blue.withValues(alpha: 0.28), blurRadius: 18, offset: const Offset(0, 8))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned(
            right: -46,
            top: -58,
            child: _Disc(size: 168, color: dark ? Brand.darkBlue : Colors.white, opacity: dark ? 0.07 : 0.13),
          ),
          Positioned(
            right: 54,
            bottom: -74,
            child: _Disc(size: 132, color: dark ? Brand.darkBlue : Colors.white, opacity: dark ? 0.05 : 0.08),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      'TODAY',
                      style: TextStyle(
                        color: dark ? Brand.darkBlue : Colors.white.withValues(alpha: 0.75),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      DateFormat('EEE d MMM').format(DateTime.now()),
                      style: TextStyle(
                        color: dark ? Brand.darkInkSoft : Colors.white.withValues(alpha: 0.7),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (var i = 0; i < shown.length; i++) ...[
                      if (i > 0)
                        Container(
                          width: 1,
                          height: 30,
                          margin: const EdgeInsets.symmetric(horizontal: 10),
                          color: dark ? Brand.darkLine : Colors.white.withValues(alpha: 0.22),
                        ),
                      Expanded(
                        child: _Stat(tile: shown[i], currency: currency),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({required this.size, required this.opacity, required this.color});
  final double size;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color.withValues(alpha: opacity),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.tile, required this.currency});
  final Map<String, dynamic> tile;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final dark = Tone.isDark(context);
    final value_ = dark ? Brand.darkInk : Colors.white;
    final label_ = dark ? Brand.darkInkSoft : Colors.white.withValues(alpha: 0.78);
    final unit = dark ? Brand.darkBlue : Colors.white.withValues(alpha: 0.8);
    final money = (tile['kind'] ?? 'count') == 'money';
    final raw = (tile['value'] ?? '0').toString();
    final value = money ? _money(raw) : raw;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            if (money && currency.isNotEmpty) ...[
              Text(
                currency,
                style: TextStyle(color: unit, fontSize: 11.5, fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 3),
            ],
            Flexible(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: value_,
                  fontSize: 22,
                  height: 1.1,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          _short((tile['label'] ?? '').toString()),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: label_, fontSize: 11.5, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  /// Whole shillings on a phone: the cents are noise at this size.
  static String _money(String raw) {
    final n = double.tryParse(raw) ?? 0;
    return NumberFormat.decimalPattern('en').format(n.round());
  }

  /// "New chats today" reads as "Chats" once it is sitting under a number.
  static String _short(String label) => label
      .replaceAll(RegExp(r'\btoday\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'^(New)\s+', caseSensitive: false), '')
      .trim()
      .replaceFirstMapped(RegExp(r'^\w'), (m) => m[0]!.toUpperCase());
}

// ── work + activity rows ──────────────────────────────────────────────────────

/// A lifecycle object: what it is, who it belongs to, and its next step.
class WorkRow extends StatelessWidget {
  const WorkRow({super.key, required this.item, required this.onTap, this.onNext});
  final Map<String, dynamic> item;
  final VoidCallback onTap;
  final VoidCallback? onNext;

  static const _kindLabel = {
    'enquiry': 'Enquiry',
    'quotation': 'Quotation',
    'booking': 'Booking',
    'order': 'Order',
    'conversation': 'Chat',
  };

  @override
  Widget build(BuildContext context) {
    final kind = (item['kind'] ?? '').toString();
    final next = item['next'] as Map<String, dynamic>?;
    final customer = (item['customer'] ?? item['title'] ?? '').toString();
    final reference = (item['reference'] ?? item['detail'] ?? '').toString();

    return PressableRow(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        _kindLabel[kind] ?? kind,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(fontSize: 10.5, letterSpacing: 0.7),
                      ),
                      if (item['statusLabel'] != null) ...[
                        const SizedBox(width: 6),
                        StatusChip(label: item['statusLabel'].toString()),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    customer.isEmpty ? reference : customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  if (customer.isNotEmpty && reference.isNotEmpty)
                    Text(
                      reference,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            if (next != null && onNext != null) ...[
              const SizedBox(width: 10),
              NextActionButton(label: next['label'].toString(), onTap: onNext!, dense: true),
            ] else
              Icon(Icons.chevron_right_rounded, size: 19, color: Theme.of(context).textTheme.bodySmall?.color),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tone = _toneFor(context, label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: dark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(color: tone, fontSize: 10.5, fontWeight: FontWeight.w700),
      ),
    );
  }

  static Color _toneFor(BuildContext context, String label) {
    final l = label.toLowerCase();
    if (l.contains('paid') || l.contains('confirmed') || l.contains('accepted') || l.contains('received')) {
      return Tone.success(context);
    }
    if (l.contains('awaiting') || l.contains('waiting') || l.contains('pending') || l.contains('new')) {
      return Tone.warning(context);
    }
    if (l.contains('cancel') || l.contains('fail') || l.contains('declin')) return Tone.danger(context);
    return Tone.blue(context);
  }
}

/// Something that happened, in one line of business language.
class ActivityRow extends StatelessWidget {
  const ActivityRow({super.key, required this.text, required this.at, this.onTap});
  final String text;
  final dynamic at;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 6,
              height: 6,
              margin: const EdgeInsets.only(top: 6, right: 11),
              decoration: BoxDecoration(color: Tone.muted(context).withValues(alpha: 0.5), shape: BoxShape.circle),
            ),
            Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 14))),
            const SizedBox(width: 8),
            Text(relativeTime(at), style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
          ],
        ),
      ),
    );
  }
}

String relativeTime(dynamic iso) {
  if (iso == null) return '';
  final at = DateTime.tryParse(iso.toString())?.toLocal();
  if (at == null) return '';
  final diff = DateTime.now().difference(at);
  if (diff.inMinutes < 1) return 'now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m';
  if (diff.inHours < 24) return '${diff.inHours}h';
  if (diff.inDays < 7) return '${diff.inDays}d';
  return DateFormat('d MMM').format(at);
}

// ── teaching empty state ──────────────────────────────────────────────────────

/// An empty screen is the best moment to explain how work arrives.
class TeachingEmptyState extends StatelessWidget {
  const TeachingEmptyState({
    super.key,
    required this.title,
    required this.body,
    this.actionLabel,
    this.onAction,
    this.icon = Icons.inbox_outlined,
  });

  final String title;
  final String body;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 30, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: Tone.muted(context)).breathe(),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 46),
                padding: const EdgeInsets.symmetric(horizontal: 22),
              ),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
