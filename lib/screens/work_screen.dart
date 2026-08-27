import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../core/workspace.dart';
import '../widgets/primitives.dart';

/// Everything in flight, grouped by what it is — and each row carries the step the
/// server says comes next, so nobody has to work out which module to open.
class WorkScreen extends StatefulWidget {
  const WorkScreen({super.key, this.initialKind, required this.onCreate});
  final String? initialKind;
  final void Function(String actionKey) onCreate;

  @override
  State<WorkScreen> createState() => WorkScreenState();
}

class WorkScreenState extends State<WorkScreen> {
  List<Map<String, dynamic>> _items = const [];
  String? _kind;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    load();
  }

  void focusKind(String? kind) {
    setState(() => _kind = kind);
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
    final kinds = workKindsFor(session);
    final visible = _kind == null ? _items : _items.where((i) => i['kind'] == _kind).toList();

    return Column(
      children: [
        MobileHeader(
          title: 'Work',
          subtitle: _items.isEmpty ? 'Nothing is open right now' : '${_items.length} things in flight',
        ),
        if (kinds.length > 1)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                _KindChip(label: 'All', selected: _kind == null, onTap: () => setState(() => _kind = null)),
                for (final k in kinds)
                  _KindChip(
                    label: k.label,
                    count: _items.where((i) => i['kind'] == k.kind).length,
                    selected: _kind == k.kind,
                    onTap: () => setState(() => _kind = k.kind),
                  ),
              ],
            ),
          ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
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
                  : visible.isEmpty
                      ? SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: TeachingEmptyState(
                            icon: Icons.check_circle_outline_rounded,
                            title: 'Nothing open here',
                            body: howWorkArrives(workspaceOf(session.workspace)),
                            actionLabel: quickActionsFor(session).firstOrNull?.label,
                            onAction: quickActionsFor(session).isEmpty
                                ? null
                                : () => widget.onCreate(quickActionsFor(session).first.key),
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: load,
                          child: ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(0, 8, 0, 28),
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
                        ),
        ),
      ],
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
                    const Icon(Icons.payments_outlined, size: 16, color: Brand.warning),
                    const SizedBox(width: 6),
                    Text(
                      'Outstanding ${item['currency']} ${item['outstanding']}',
                      style: const TextStyle(color: Brand.warning, fontWeight: FontWeight.w600, fontSize: 13.5),
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
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${next['label']} — finish this in the portal for now')),
                    );
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

class _KindChip extends StatelessWidget {
  const _KindChip({required this.label, required this.selected, required this.onTap, this.count});
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int? count;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: selected ? Brand.blue : (dark ? Brand.darkSurface : Brand.surface),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: selected ? Brand.blue : (dark ? Brand.darkLine : Brand.line)),
          ),
          child: Text(
            count == null || count == 0 ? label : '$label $count',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: selected ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
        ),
      ),
    );
  }
}
