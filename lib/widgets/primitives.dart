import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/theme.dart';

/// The building blocks every screen is made of.
///
/// Written once, on purpose: a phone screen has room for one idea at a time, so the
/// app is rows, chips and grouped lists — not a card around every fact. Cards appear
/// only where grouping says something true about the content.

// ── header ────────────────────────────────────────────────────────────────────

/// Compact top of a screen: what you are looking at, one line of why, and the
/// account. No oversized title bar eating the first viewport.
class MobileHeader extends StatelessWidget {
  const MobileHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.initials,
    this.onAccountTap,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? initials;
  final VoidCallback? onAccountTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 6, 12, 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 23),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, maxLines: 2, style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 13.5)),
                ],
              ],
            ),
          ),
          if (trailing != null) trailing!,
          if (initials != null) ...[
            const SizedBox(width: 6),
            InkWell(
              onTap: onAccountTap,
              borderRadius: BorderRadius.circular(22),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: CircleAvatar(
                  radius: 18,
                  backgroundColor: Brand.blueWash,
                  child: Text(
                    initials!,
                    style: const TextStyle(color: Brand.blue, fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── section label ─────────────────────────────────────────────────────────────

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
          Text(text.toUpperCase(), style: Theme.of(context).textTheme.labelSmall?.copyWith(letterSpacing: 0.9)),
          const Spacer(),
          if (action != null && onAction != null)
            InkWell(
              onTap: onAction,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Text(
                  action!,
                  style: const TextStyle(color: Brand.blue, fontSize: 12.5, fontWeight: FontWeight.w600),
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
        ? Brand.danger
        : urgency == 'high'
            ? Brand.warning
            : Brand.blue;
    final mine = (item['scope'] ?? '') == 'mine';

    return InkWell(
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            Expanded(
              child: Text(
                (item['label'] ?? '').toString(),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontSize: 14.5),
              ),
            ),
            if (mine)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(color: Brand.blueWash, borderRadius: BorderRadius.circular(6)),
                child: const Text('you', style: TextStyle(color: Brand.blue, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, size: 19, color: Theme.of(context).textTheme.bodySmall?.color),
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
          const Icon(Icons.check_circle_rounded, size: 16, color: Brand.success),
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
          backgroundColor: Brand.blueWash,
          foregroundColor: Brand.blue,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Material(
        color: Brand.blue,
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
                      Text(label, style: const TextStyle(color: Colors.white, fontSize: 15.5, fontWeight: FontWeight.w700)),
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
class CompactStats extends StatelessWidget {
  const CompactStats({super.key, required this.tiles});
  final List<Map<String, dynamic>> tiles;

  @override
  Widget build(BuildContext context) {
    if (tiles.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 14),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
      decoration: BoxDecoration(
        color: dark ? Brand.darkSurface : Brand.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: dark ? Brand.darkLine : Brand.line),
      ),
      child: Row(
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0)
              Container(width: 1, height: 26, color: dark ? Brand.darkLine : Brand.line),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    (tiles[i]['value'] ?? '0').toString(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _short((tiles[i]['label'] ?? '').toString()),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// "New chats today" reads as "Chats" once it is sitting under a number.
  static String _short(String label) => label
      .replaceAll(RegExp(r'\btoday\b', caseSensitive: false), '')
      .replaceAll(RegExp(r'^(New|Your)\s+', caseSensitive: false), '')
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

    return InkWell(
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
                    Text(reference, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
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
    final tone = _toneFor(label);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: dark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(label, style: TextStyle(color: tone, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }

  static Color _toneFor(String label) {
    final l = label.toLowerCase();
    if (l.contains('paid') || l.contains('confirmed') || l.contains('accepted') || l.contains('received')) {
      return Brand.success;
    }
    if (l.contains('awaiting') || l.contains('waiting') || l.contains('pending') || l.contains('new')) {
      return Brand.warning;
    }
    if (l.contains('cancel') || l.contains('fail') || l.contains('declin')) return Brand.danger;
    return Brand.blue;
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
              decoration: BoxDecoration(color: Brand.inkFaint.withValues(alpha: 0.5), shape: BoxShape.circle),
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
          Icon(icon, size: 32, color: Brand.inkFaint),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onAction,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46), padding: const EdgeInsets.symmetric(horizontal: 22)),
              child: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
