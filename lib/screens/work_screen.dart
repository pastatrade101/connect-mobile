import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/primitives.dart';
import '../widgets/skeleton.dart';

/// Everything in flight, grouped by what it is — and each row carries the step the
/// server says comes next, so nobody has to work out which module to open.
class WorkScreen extends StatefulWidget {
  const WorkScreen({super.key, this.initialKind, required this.onCreate});
  final String? initialKind;
  final void Function(String actionKey) onCreate;

  @override
  State<WorkScreen> createState() => WorkScreenState();
}

class WorkScreenState extends State<WorkScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _items = const [];
  bool _loading = true;
  String? _error;

  /// One tab per kind this business actually runs, led by everything together.
  /// Built once: a workspace does not change under a signed-in session.
  late final List<({String? kind, String label})> _tabs;
  late final TabController _controller;

  @override
  void initState() {
    super.initState();
    final session = Api.instance.session;
    _tabs = [
      (kind: null, label: 'All'),
      if (session != null) ...workKindsFor(session).map((k) => (kind: k.kind, label: k.label)),
    ];
    final start = widget.initialKind == null ? 0 : _indexOf(widget.initialKind);
    _controller = TabController(length: _tabs.length, vsync: this, initialIndex: start);
    load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _indexOf(String? kind) {
    final i = _tabs.indexWhere((t) => t.kind == kind);
    return i < 0 ? 0 : i;
  }

  /// Home sends people here pointed at one kind of work.
  void focusKind(String? kind) {
    final i = _indexOf(kind);
    if (i != _controller.index) _controller.animateTo(i);
  }

  Future<void> load() async {
    try {
      final data = await Api.instance.work();
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List? ?? const []).cast<Map<String, dynamic>>();
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

  @override
  Widget build(BuildContext context) {
    final session = Api.instance.session;
    if (session == null) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;
    final muted = Theme.of(context).textTheme.bodySmall?.color;

    return Column(
      children: [
        MobileHeader(
          title: 'Work',
          subtitle: _items.isEmpty ? 'Nothing is open right now' : '${_items.length} things in flight',
        ),
        if (_tabs.length > 1)
          Container(
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: dark ? Brand.darkLine : Brand.line)),
            ),
            child: TabBar(
              controller: _controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              indicatorSize: TabBarIndicatorSize.label,
              indicatorWeight: 3,
              indicatorColor: Tone.blue(context),
              labelColor: Tone.blue(context),
              unselectedLabelColor: muted,
              dividerHeight: 0,
              splashBorderRadius: BorderRadius.circular(10),
              labelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500),
              tabs: [
                for (final tab in _tabs)
                  Tab(
                    height: 46,
                    child: _TabLabel(
                      label: tab.label,
                      count: tab.kind == null ? _items.length : _items.where((i) => i['kind'] == tab.kind).length,
                    ),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const SkeletonRows(rows: 5)
              : _error != null
              ? Center(
                  child: TeachingEmptyState(
                    icon: Icons.cloud_off_rounded,
                    title: 'Could not load your work',
                    body: _error!,
                    actionLabel: 'Try again',
                    onAction: load,
                  ),
                )
              // Swiping sideways moves between tabs — the gesture people already
              // expect from every other tabbed app on the phone.
              : TabBarView(controller: _controller, children: [for (final tab in _tabs) _page(session, tab.kind)]),
        ),
      ],
    );
  }

  Widget _page(Session session, String? kind) {
    final visible = kind == null ? _items : _items.where((i) => i['kind'] == kind).toList();
    if (visible.isEmpty) {
      return RefreshIndicator(
        onRefresh: load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            TeachingEmptyState(
              icon: Icons.check_circle_outline_rounded,
              title: 'Nothing open here',
              body: howWorkArrives(workspaceOf(session.workspace)),
              actionLabel: quickActionsFor(session).firstOrNull?.label,
              onAction: quickActionsFor(session).isEmpty
                  ? null
                  : () => widget.onCreate(quickActionsFor(session).first.key),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Clear the floating nav, raised + included.
        padding: const EdgeInsets.fromLTRB(0, 8, 0, NavBar.clearance),
        children: [
          GroupedList(
            children: [
              for (final item in visible)
                WorkRow(
                  item: item,
                  onTap: () => _showDetail(context, item),
                  onNext: item['next'] == null ? null : () => _showDetail(context, item),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// The phone shows what it is and what comes next; the portal is where the full
  /// record lives, so this never pretends to be an editor.
  void _showDetail(BuildContext context, Map<String, dynamic> item) {
    final next = item['next'] as Map<String, dynamic>?;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text((item['reference'] ?? '').toString(), style: Theme.of(sheetContext).textTheme.titleMedium),
                  const SizedBox(width: 8),
                  if (item['statusLabel'] != null) StatusChip(label: item['statusLabel'].toString()),
                ],
              ),
              if (item['customer'] != null) ...[
                const SizedBox(height: 4),
                Text(item['customer'].toString(), style: Theme.of(sheetContext).textTheme.bodySmall),
              ],
              if (_amount(item['outstanding']) > 0) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(Icons.payments_outlined, size: 16, color: Tone.warning(context)),
                    const SizedBox(width: 6),
                    Text(
                      'Outstanding ${item['currency']} ${item['outstanding']}',
                      style: TextStyle(color: Tone.warning(context), fontWeight: FontWeight.w600, fontSize: 13.5),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 18),
              if (next != null) ...[
                Text(
                  next['hint']?.toString() ?? 'What happens next',
                  style: Theme.of(sheetContext).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(
                      context,
                    ).showSnackBar(SnackBar(content: Text('${next['label']} — finish this in the portal for now')));
                  },
                  child: Text(next['label'].toString()),
                ),
              ] else
                Text('Nothing is waiting on this one.', style: Theme.of(sheetContext).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

/// Amounts arrive as strings; a missing one is simply zero.
double _amount(dynamic value) => double.tryParse('${value ?? 0}') ?? 0;

/// A tab label with how many are behind it. The count is never the loud part.
class _TabLabel extends StatelessWidget {
  const _TabLabel({required this.label, required this.count});
  final String label;
  final int count;

  @override
  Widget build(BuildContext context) {
    final selected = DefaultTextStyle.of(context).style.color == Tone.blue(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: selected ? Tone.blueWash(context) : Theme.of(context).dividerColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: selected ? Tone.blue(context) : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
