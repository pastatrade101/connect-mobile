import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/primitives.dart';

/// Home answers three questions, in this order, in one viewport:
///   1. What needs me?      → attention rows, straight to the work
///   2. What do I do next?  → one workspace-aware action
///   3. What happened today? → a single compact line, kept secondary
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

  /// Attention items point at filtered work, not at a module.
  void _openAttention(Map<String, dynamic> item) {
    final key = (item['key'] ?? '').toString();
    switch (key) {
      case 'my_unread':
        widget.onOpenInbox(filter: 'mine');
      case 'unread':
      case 'unassigned':
        widget.onOpenInbox(filter: key == 'unassigned' ? 'unassigned' : 'all');
      case 'my_enquiries':
      case 'new_enquiries':
        widget.onOpenWork(kind: 'enquiry');
      case 'orders_to_confirm':
      case 'orders_ready':
        widget.onOpenWork(kind: 'order');
      case 'bookings_unpaid':
        widget.onOpenWork(kind: 'booking');
      case 'quotes_waiting':
        widget.onOpenWork(kind: 'quotation');
      default:
        widget.onOpenWork();
    }
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

    final data = _data ?? const {};
    final attention = (data['attention'] as List? ?? const []).cast<Map<String, dynamic>>();
    final context_ = (data['context'] as List? ?? const []).cast<Map<String, dynamic>>();
    final today = (data['today'] as List? ?? const []).cast<Map<String, dynamic>>();
    final myWork = (data['myWork'] as List? ?? const []).cast<Map<String, dynamic>>();
    final persona = (data['persona'] ?? 'agent').toString();
    final actions = quickActionsFor(session);
    final primary = actions.where((a) => a.primary).firstOrNull;

    // A brand-new workspace has nothing to show but a great deal to explain.
    final started = attention.isNotEmpty || myWork.isNotEmpty || today.any((t) => (t['value'] ?? '0') != '0');

    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          MobileHeader(
            title: _greeting,
            subtitle: attention.isEmpty
                ? '${session.tenantName} · nothing waiting on you'
                : 'Here’s what needs you at ${session.tenantName}',
            initials: initialsOf(session.userName),
            onAccountTap: widget.onOpenAccount,
          ),

          if (attention.isNotEmpty) ...[
            const GroupLabel(text: 'Needs you'),
            GroupedList(
              children: [
                for (final item in attention) AttentionRow(item: item, onTap: () => _openAttention(item)),
              ],
            ),
            const SizedBox(height: 16),
          ] else
            CalmIndicator(
              text: persona == 'agent'
                  ? 'You’re caught up — nothing assigned to you is waiting.'
                  : persona == 'finance'
                      ? 'No payments are waiting to be checked.'
                      : 'All caught up.',
            ),

          if (primary != null) ...[
            const SizedBox(height: 6),
            NextActionButton(
              label: primary.label,
              hint: primary.hint,
              onTap: () => widget.onQuickAction(primary.key),
            ),
            const SizedBox(height: 18),
          ],

          if (!started) ...[
            const GroupLabel(text: 'Getting started'),
            GroupedList(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How work reaches you', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        howWorkArrives(workspaceOf(session.workspace)),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(height: 1.45),
                      ),
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
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          if (myWork.isNotEmpty) ...[
            GroupLabel(
              text: 'Continue working',
              action: 'All',
              onAction: () => widget.onOpenWork(),
            ),
            GroupedList(
              children: [
                for (final item in myWork.take(4))
                  WorkRow(
                    item: {
                      ...item,
                      'customer': item['title'],
                      'reference': item['detail'],
                      'statusLabel': (item['unread'] as num? ?? 0) > 0 ? '${item['unread']} unread' : null,
                    },
                    onTap: () => (item['kind'] ?? '') == 'conversation'
                        ? widget.onOpenThread((item['id'] ?? '').toString())
                        : widget.onOpenWork(kind: 'enquiry'),
                  ),
              ],
            ),
            const SizedBox(height: 18),
          ],

          if (today.isNotEmpty) ...[
            const GroupLabel(text: 'Today'),
            CompactStats(tiles: today.take(3).toList()),
          ],

          if (context_.isNotEmpty) ...[
            const SizedBox(height: 14),
            for (final item in context_)
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                child: Text(
                  (item['label'] ?? '').toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 12.5),
                ),
              ),
          ],
        ],
      ),
    );
  }
}
