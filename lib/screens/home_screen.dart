import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/primitives.dart';

/// Home is three questions, in this order, and never more than that:
///
///   ACT      — what needs me right now, and why
///   CONTINUE — what was I in the middle of, as business rather than chatter
///   OVERVIEW — how is today going, kept quiet at the bottom
///
/// Every line on this screen is written by the server: the attention model decides
/// what is waiting, and the shared next-action resolver decides what state a
/// customer is in. The phone lays it out; it does not re-derive any of it.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.onOpenThread,
    required this.onOpenInbox,
    required this.onOpenWork,
    required this.onQuickAction,
    required this.onOpenAccount,
  });

  final void Function(String conversationId) onOpenThread;
  final void Function({String filter}) onOpenInbox;
  final void Function({String? kind}) onOpenWork;
  final void Function(String actionKey) onQuickAction;
  final VoidCallback onOpenAccount;

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await Api.instance.me();
      if (!mounted) return;
      setState(() {
        _data = data;
        _error = null;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  String get _greeting {
    final hour = DateTime.now().hour;
    final part = hour < 12 ? 'Good morning' : (hour < 17 ? 'Good afternoon' : 'Good evening');
    final name = (Api.instance.session?.userName ?? '').trim().split(RegExp(r'\s+')).first;
    return name.isEmpty ? part : '$part, $name';
  }

  /// Attention rows land on the filtered work they describe, never on a module.
  void _openAttention(Map<String, dynamic> item) {
    switch ((item['key'] ?? '').toString()) {
      case 'my_unread':
        widget.onOpenInbox(filter: 'mine');
      case 'unassigned':
        widget.onOpenInbox(filter: 'unassigned');
      case 'unread':
        widget.onOpenInbox(filter: 'all');
      case 'my_enquiries':
      case 'new_enquiries':
        widget.onOpenWork(kind: 'enquiry');
      case 'orders_to_confirm':
      case 'orders_ready':
        widget.onOpenWork(kind: 'order');
      case 'bookings_unpaid':
      case 'payments_reported':
      case 'payments_failed':
      case 'payments_outstanding':
        widget.onOpenWork(kind: 'booking');
      case 'quotes_waiting':
        widget.onOpenWork(kind: 'quotation');
      default:
        widget.onOpenWork();
    }
  }

  /// A customer row opens the conversation when there is one; otherwise the record.
  void _openContinue(Map<String, dynamic> item) {
    final conversationId = item['conversationId'];
    if (conversationId != null) {
      widget.onOpenThread(conversationId.toString());
      return;
    }
    final kind = (item['kind'] ?? '').toString();
    widget.onOpenWork(kind: kind == 'conversation' ? null : kind);
  }

  /// Older servers only send the chat-shaped list; read it in the same shape so a
  /// phone that is ahead of the deployment still shows something sensible.
  List<Map<String, dynamic>> _continuing(Map<String, dynamic> data) {
    final fresh = (data['continueWorking'] as List?)?.cast<Map<String, dynamic>>();
    if (fresh != null) return fresh;
    return (data['myWork'] as List? ?? const [])
        .cast<Map<String, dynamic>>()
        .map(
          (item) => {
            'customer': item['title'],
            'state': (item['kind'] ?? '') == 'conversation' ? 'WhatsApp conversation' : 'Enquiry',
            'detail': item['detail'],
            'kind': item['kind'],
            'conversationId': (item['kind'] ?? '') == 'conversation' ? item['id'] : null,
          },
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final session = Api.instance.session;
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null || session == null) {
      return Center(
        child: TeachingEmptyState(
          icon: Icons.cloud_off_rounded,
          title: 'Could not reach Connect',
          body: _error ?? 'Check your connection and try again.',
          actionLabel: 'Try again',
          onAction: load,
        ),
      );
    }

    final data = _data ?? const <String, dynamic>{};
    final attention = (data['attention'] as List? ?? const []).cast<Map<String, dynamic>>();
    final notes = (data['context'] as List? ?? const []).cast<Map<String, dynamic>>();
    final today = (data['today'] as List? ?? const []).cast<Map<String, dynamic>>();
    final continuing = _continuing(data);
    final persona = (data['persona'] ?? 'agent').toString();
    final actions = quickActionsFor(session);
    final primary = actions.where((a) => a.primary).firstOrNull;

    // A workspace with no history needs teaching, not an empty dashboard.
    final started =
        attention.isNotEmpty ||
        continuing.isNotEmpty ||
        today.any((t) => (t['value'] ?? '0').toString() != '0');

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          MobileHeader(
            title: _greeting,
            subtitle: _subtitle(session.tenantName, attention),
            initials: initialsOf(session.userName),
            onAccountTap: widget.onOpenAccount,
            // The bell counts customers waiting for a reply and goes straight to
            // them — yours first if any of them are yours.
            alerts: _unread(attention),
            onAlerts: session.can('conversations:read')
                ? () => widget.onOpenInbox(
                    filter: attention.any((a) => a['key'] == 'my_unread') ? 'mine' : 'all',
                  )
                : null,
          ),

          // ── ACT ────────────────────────────────────────────────────────────
          if (attention.isNotEmpty) ...[
            const GroupLabel(text: 'Needs you'),
            GroupedList(
              children: [
                for (final item in attention) AttentionRow(item: item, onTap: () => _openAttention(item)),
              ],
            ),
          ] else
            CalmIndicator(text: _calmLine(persona)),

          // ── CONTINUE ───────────────────────────────────────────────────────
          if (continuing.isNotEmpty) ...[
            const SizedBox(height: 18),
            GroupLabel(text: 'Continue working', action: 'All work', onAction: () => widget.onOpenWork()),
            GroupedList(
              children: [
                for (final item in continuing.take(4))
                  ContinueRow(item: item, onTap: () => _openContinue(item)),
              ],
            ),
          ],

          // One quiet line for the thing you occasionally have to type in yourself.
          // Everything else that can be created lives on the + button.
          if (primary != null && started) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: TextButton.icon(
                onPressed: () => widget.onQuickAction(primary.key),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: Text(primary.label),
                style: TextButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
              ),
            ),
          ],

          // ── Getting started (only while there is genuinely nothing) ─────────
          if (!started) ...[
            const SizedBox(height: 14),
            const GroupLabel(text: 'Getting started'),
            GroupedList(
              children: [
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How work reaches you', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        howWorkArrives(workspaceOf(session.workspace)),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
                      ),
                      if (actions.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final action in actions)
                              OutlinedButton.icon(
                                onPressed: () => widget.onQuickAction(action.key),
                                icon: Icon(action.icon, size: 17),
                                label: Text(action.label),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(0, 44),
                                  padding: const EdgeInsets.symmetric(horizontal: 14),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],

          // ── OVERVIEW ───────────────────────────────────────────────────────
          if (today.isNotEmpty) ...[
            const SizedBox(height: 20),
            const GroupLabel(text: 'Today'),
            CompactStats(tiles: today.take(3).toList()),
          ],

          if (notes.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final note in notes)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: Text(
                  (note['label'] ?? '').toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5),
                ),
              ),
          ],
        ],
      ),
    );
  }

  /// Conversations waiting for a reply, from the same attention model as the rows.
  static int _unread(List<Map<String, dynamic>> attention) => attention
      .where((a) => a['key'] == 'my_unread' || a['key'] == 'unread')
      .fold<int>(0, (sum, a) => sum + (a['count'] as num? ?? 0).toInt());

  /// The header names the business and counts what is waiting — one line, always.
  /// Anything longer wraps on a 375pt phone and pushes the real content down.
  static String _subtitle(String tenant, List<Map<String, dynamic>> attention) {
    if (attention.isEmpty) return '$tenant · all clear';
    final mine = attention.where((a) => a['scope'] == 'mine').length;
    if (mine > 0) return '$tenant · $mine for you';
    return '$tenant · ${attention.length} waiting';
  }

  static String _calmLine(String persona) => switch (persona) {
    'agent' => 'You’re caught up — nothing assigned to you is waiting.',
    'finance' => 'No payments are waiting to be checked.',
    'viewer' => 'Nothing new to look at.',
    _ => 'All caught up — nothing is waiting on the business.',
  };
}
