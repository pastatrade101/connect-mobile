import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../widgets/primitives.dart';
import '../widgets/rive_art.dart';

/// The chat list. Same three filters as the portal, same meaning: "You:" is who
/// spoke last, the chip on the right is who owns the thread.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key, required this.onOpenThread});
  final void Function(String conversationId) onOpenThread;

  @override
  State<InboxScreen> createState() => InboxScreenState();
}

class InboxScreenState extends State<InboxScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _threads = const [];
  String _filter = 'all';
  String _query = '';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Called when Home sends the user here with a specific filter in mind.
  void applyFilter(String filter) {
    if (_filter == filter) return;
    setState(() {
      _filter = filter;
      _loading = true;
    });
    load();
  }

  Future<void> load() async {
    try {
      final data = await Api.instance.inbox(filter: _filter);
      if (!mounted) return;
      setState(() {
        _threads = (data['threads'] as List? ?? const []).cast<Map<String, dynamic>>();
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

  List<Map<String, dynamic>> get _visible {
    if (_query.trim().isEmpty) return _threads;
    final q = _query.toLowerCase();
    return _threads
        .where(
          (t) =>
              (t['name'] ?? '').toString().toLowerCase().contains(q) ||
              (t['preview'] ?? '').toString().toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MobileHeader(
          title: 'Inbox',
          subtitle: _threads.isEmpty
              ? 'Conversations appear as customers write in'
              : '${_threads.where((t) => (t['unread'] as num? ?? 0) > 0).length} waiting for a reply',
          trailing: IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, size: 20),
            onPressed: load,
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Column(
            children: [
              TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Search chats',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  isDense: true,
                  suffixIcon: _query.isEmpty
                      ? null
                      : IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () {
                            _search.clear();
                            setState(() => _query = '');
                          },
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final option in const [('all', 'All'), ('mine', 'Mine'), ('unassigned', 'Open')])
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: _FilterChip(
                        label: option.$2,
                        selected: _filter == option.$1,
                        onTap: () {
                          setState(() {
                            _filter = option.$1;
                            _loading = true;
                          });
                          load();
                        },
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _InboxMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load your chats',
                  body: _error!,
                )
              : _visible.isEmpty
              ? _InboxMessage(
                  icon: Icons.forum_outlined,
                  title: _query.isNotEmpty ? 'Nothing matches that' : 'No chats here yet',
                  body: _query.isNotEmpty
                      ? 'Try a different name or number.'
                      : _filter == 'mine'
                      ? 'Chats assigned to you will appear here.'
                      : 'WhatsApp conversations appear here as customers write in.',
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    // Clear the floating nav, or the last thread hides under it.
                    padding: const EdgeInsets.only(bottom: NavBar.clearance),
                    itemCount: _visible.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, indent: 76),
                    itemBuilder: (context, i) => _ThreadTile(
                      // Keyed by conversation so a refresh does not replay the whole
                      // list — only genuinely new rows animate in.
                      key: ValueKey(_visible[i]['id']),
                      thread: _visible[i],
                      onTap: () => widget.onOpenThread((_visible[i]['id'] ?? '').toString()),
                    ).entrance(index: i.clamp(0, 8)),
                  ),
                ),
        ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Tone.blue(context) : (dark ? Brand.darkPanel : Brand.surface),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? Tone.blue(context) : (dark ? Brand.darkLine : Brand.line)),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Theme.of(context).textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({super.key, required this.thread, required this.onTap});
  final Map<String, dynamic> thread;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final unread = (thread['unread'] as num? ?? 0).toInt();
    final name = (thread['name'] ?? '').toString();
    final preview = (thread['preview'] ?? 'No messages yet').toString();
    final fromCustomer = thread['lastFromCustomer'] == true;
    final assignedToMe = thread['assignedToMe'] == true;
    final assignedTo = thread['assignedToName'];

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      // The same avatar continues into the conversation, so the eye keeps hold
      // of who it is across the screen change.
      leading: Hero(
        tag: 'customer-${thread['id']}',
        child: CircleAvatar(
          radius: 24,
          backgroundColor: Tone.blueWash(context),
          child: Text(
            initialsOf(name),
            style: TextStyle(color: Tone.blue(context), fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w600,
                fontSize: 15.5,
              ),
            ),
          ),
          Text(
            _when(thread['lastMessageAt']),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5),
          ),
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Row(
          children: [
            Expanded(
              child: Text(
                fromCustomer ? preview : 'You: $preview',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (!assignedToMe && assignedTo != null)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: Theme.of(context).brightness == Brightness.dark ? Brand.darkPanel : Brand.ground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  assignedTo.toString(),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).textTheme.bodySmall?.color,
                  ),
                ),
              ),
            if (unread > 0)
              Container(
                margin: const EdgeInsets.only(left: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFF25D366),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$unread',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ),
          ],
        ),
      ),
    );
  }

  static String _when(dynamic iso) {
    if (iso == null) return '';
    final at = DateTime.tryParse(iso.toString())?.toLocal();
    if (at == null) return '';
    final now = DateTime.now();
    final sameDay = at.year == now.year && at.month == now.month && at.day == now.day;
    if (sameDay) return DateFormat.Hm().format(at);
    if (now.difference(at).inDays < 7) return DateFormat.E().format(at);
    return DateFormat('d MMM').format(at);
  }
}

class _InboxMessage extends StatelessWidget {
  const _InboxMessage({required this.icon, required this.title, required this.body});
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RiveArt(
              name: 'empty_inbox',
              size: 92,
              fallback: Icon(icon, size: 36, color: Tone.muted(context)).breathe(),
            ),
            const SizedBox(height: 14),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(body, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
