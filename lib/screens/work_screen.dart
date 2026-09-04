import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/primitives.dart';
import '../widgets/skeleton.dart';
import '../widgets/swipe_to_delete.dart';
import 'quotation_sheet.dart';

/// Everything in flight, grouped by what it is — and each row carries the step the
/// server says comes next, so nobody has to work out which module to open.
class WorkScreen extends StatefulWidget {
  const WorkScreen({
    super.key,
    this.initialKind,
    this.pinned = false,
    required this.onCreate,
    this.onBack,
    this.onOpenAccount,
  });

  /// Show ONLY [initialKind], titled as that kind, with no tab strip.
  ///
  /// This is what makes Enquiries a destination of its own rather than a second
  /// door onto Work. Without it the two tabs land on the same screen under the
  /// same title — the exact redundancy that got the create button's "Open inbox"
  /// removed.
  final bool pinned;

  /// The account page, opened from the avatar in this screen's header.
  ///
  /// Every tab carries it, because the bottom bar no longer does: a destination
  /// that is one tap from anywhere does not need a sixth of the bar as well.
  final VoidCallback? onOpenAccount;
  final String? initialKind;

  /// Present only when this screen was PUSHED — see MobileHeader.onBack.
  final VoidCallback? onBack;
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
    final kinds = session == null ? const <({String kind, String label})>[] : workKindsFor(session);
    _tabs = widget.pinned && widget.initialKind != null
        // One kind, so `_tabs.length > 1` is false and the strip does not render.
        ? [(kind: widget.initialKind, label: _labelFor(kinds, widget.initialKind!))]
        : [
            (kind: null, label: 'All'),
            ...kinds.map((k) => (kind: k.kind, label: k.label)),
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

  /// The workspace's own word for a kind — "Enquiries" for an operator, and
  /// whatever [workKindsFor] calls it for anyone else. Falls back to the kind
  /// itself so a pinned tab is never left with an empty title.
  static String _labelFor(List<({String kind, String label})> kinds, String kind) {
    for (final k in kinds) {
      if (k.kind == kind) return k.label;
    }
    return kind;
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
          avatarUrl: Api.instance.session?.operatorLogoUrl,
          initials: initialsOf(Api.instance.session?.operatorName ?? Api.instance.session?.tenantName ?? ''),
          onAccountTap: widget.onOpenAccount,
          title: widget.pinned ? _tabs.first.label : 'Work',
          // Pinned, the count has to be the count of what is actually on screen.
          // "6 things in flight" over a list of 4 enquiries is just wrong.
          subtitle: switch (widget.pinned
              ? _items.where((i) => i['kind'] == widget.initialKind).length
              : _items.length) {
            0 => 'Nothing is open right now',
            final n => widget.pinned ? '$n open' : '$n things in flight',
          },
          onBack: widget.onBack,
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
              indicatorColor: Tone.accent(context),
              labelColor: Tone.accent(context),
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
              : TabBarView(
                  controller: _controller,
                  // The rows own horizontal gestures, so the tabs give theirs up.
                  //
                  // Both wanted the same drag and the TabBarView kept winning the
                  // arena, so a swipe on a row usually changed tab instead of
                  // revealing Delete — which made the whole list feel like
                  // nothing could be deleted. Tabs are still one tap away and
                  // visible; a swipe-to-delete that only works sometimes is
                  // worse than a tab strip you have to tap.
                  physics: const NeverScrollableScrollPhysics(),
                  children: [for (final tab in _tabs) _page(session, tab.kind)],
                ),
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
        // Clear the floating nav.
        padding: const EdgeInsets.fromLTRB(0, 8, 0, NavBar.clearance),
        children: [
          GroupedList(
            children: [
              for (final item in visible)
                SwipeToDelete(
                  // Orders are a different module and have their own screens.
                  // Quotations ARE deletable here even though the website owns
                  // them: the mirror only ever pushes what still exists, so a
                  // quotation deleted over there would otherwise sit on this
                  // list forever with no way to clear it.
                  enabled: item['kind'] != 'order',
                  onDelete: () => _delete(item),
                  child: WorkRow(
                    item: item,
                    onTap: () => _showDetail(context, item),
                    // The next action DOES the thing where we can. "Create
                    // quotation" opening a read-only detail sheet was a button
                    // that described work rather than starting it.
                    onNext: item['next'] == null ? null : () => _next(context, item),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static String _label(String kind) => switch (kind) {
    'enquiry' => 'Enquiry',
    'booking' => 'Booking',
    'quotation' => 'Quotation',
    _ => 'Item',
  };

  /// Same wording as everywhere else: the server's message when it gave one.
  String _message(Object error) => error is ApiException ? error.message : 'That did not work. Try again.';

  /// Hide one row, with a way back.
  ///
  /// The list updates before the request does, because a delete that waits on a
  /// round trip feels broken on a Tanzanian mobile connection. If the server
  /// refuses, the row comes back and says why — an optimistic update has to be
  /// honest about being wrong.
  Future<void> _delete(Map<String, dynamic> item) async {
    final kind = item['kind'] as String;
    final id = item['id'] as String;
    final index = _items.indexWhere((i) => i['id'] == id);
    if (index < 0) return;

    setState(() => _items = [..._items]..removeAt(index));
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();

    try {
      await Api.instance.deleteWorkItem(kind, id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _items = [..._items]..insert(index, item));
      messenger.showSnackBar(SnackBar(content: Text(_message(e))));
      return;
    }
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text('${_label(kind)} deleted'),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () async {
            try {
              await Api.instance.restoreWorkItem(kind, id);
              await load();
            } catch (e) {
              if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(e))));
            }
          },
        ),
      ),
    );
  }

  /// Act on the next step, or fall back to explaining it.
  ///
  /// Only quoting is done on the phone: it is the step that follows a
  /// marketplace enquiry, it is time-critical, and the enquiry already carries
  /// everything the quotation needs. Everything else still opens the detail
  /// sheet and points at the portal, which is honest about where those records
  /// are actually edited.
  Future<void> _next(BuildContext context, Map<String, dynamic> item) async {
    final next = item['next'] as Map<String, dynamic>?;
    final customer = (item['customer'] ?? 'this customer').toString();

    // A saved draft finishes here too: the phone that raised it can send it.
    if (item['kind'] == 'quotation' && next?['key'] == 'send_quotation') {
      await _sendQuotation(context, item['id'] as String, customer, (item['reference'] ?? '').toString());
      return;
    }

    final isQuote = item['kind'] == 'enquiry' && (next?['key'] == 'quote' || next?['key'] == 'create_quotation');
    if (!isQuote) {
      _showDetail(context, item);
      return;
    }

    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => QuotationSheet(enquiryId: item['id'] as String, customerName: customer),
    );
    if (created == true) await load();
  }

  /// Confirm first: this puts a price in front of a customer, and a mis-tap on a
  /// list row is not consent to do that.
  Future<void> _sendQuotation(BuildContext context, String id, String customer, String reference) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Send this quotation?'),
        content: Text('$reference goes to $customer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Not yet')),
          FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Send')),
        ],
      ),
    );
    if (go != true) return;
    try {
      await Api.instance.sendQuotation(id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sent to $customer.')));
      await load();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e is ApiException ? e.message : 'Could not send it. Try again.')));
    }
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
    final selected = DefaultTextStyle.of(context).style.color == Tone.accent(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label),
        if (count > 0) ...[
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: selected ? Tone.accentWash(context) : Theme.of(context).dividerColor.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: selected ? Tone.accent(context) : Theme.of(context).textTheme.bodySmall?.color,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
