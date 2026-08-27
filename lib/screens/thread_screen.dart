import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';
import '../core/theme.dart';

/// One conversation, WhatsApp-shaped: tinted canvas, bubbles with the tail on the
/// right for what we sent, and a composer pinned to the bottom above the keyboard.
class ThreadScreen extends StatefulWidget {
  const ThreadScreen({super.key, required this.conversationId});
  final String conversationId;

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen> {
  final _composer = TextEditingController();
  final _scroll = ScrollController();
  Map<String, dynamic>? _conversation;
  List<Map<String, dynamic>> _messages = const [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.thread(widget.conversationId);
      if (!mounted) return;
      setState(() {
        _conversation = data['conversation'] as Map<String, dynamic>?;
        _messages = (data['messages'] as List? ?? const []).cast<Map<String, dynamic>>();
        _loading = false;
        _error = null;
      });
      _jumpToLatest();
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _loading = false;
      });
    }
  }

  void _jumpToLatest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  Future<void> _send() async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Api.instance.send(widget.conversationId, text);
      _composer.clear();
      await _load();
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _takeChat() async {
    try {
      await Api.instance.assignToMe(widget.conversationId);
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This chat is yours now')));
      }
    } on ApiException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final name = (_conversation?['name'] ?? 'Conversation').toString();
    final phone = _conversation?['phone'];
    final assignedToMe = _conversation?['assignedToMe'] == true;
    final canSend = Api.instance.session?.can('whatsapp:send') ?? false;
    final canAssign = Api.instance.session?.can('conversations:assign') ?? false;

    return Scaffold(
      backgroundColor: dark ? Brand.darkGround : Brand.chatGround,
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: dark ? Brand.darkPanel : Brand.chatBar,
        title: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: dark ? Brand.darkLine : const Color(0xFFDFE5E7),
              child: Text(
                initialsOf(name),
                style: TextStyle(
                  color: dark ? Brand.darkInk : const Color(0xFF54656F),
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (phone != null)
                    Text('+$phone', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (canAssign && !assignedToMe)
            TextButton(onPressed: _takeChat, child: const Text('Take')),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          if (assignedToMe)
            Container(
              width: double.infinity,
              color: dark ? Brand.darkSurface : Brand.surface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                'Assigned to you',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(28),
                          child: Text(_error!, textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: ListView.builder(
                          controller: _scroll,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(12, 14, 12, 14),
                          itemCount: _messages.length,
                          itemBuilder: (context, i) => _Bubble(message: _messages[i]),
                        ),
                      ),
          ),
          _Composer(
            controller: _composer,
            enabled: canSend && !_sending,
            sending: _sending,
            onSend: _send,
            disabledHint: canSend ? null : 'You do not have permission to send messages',
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});
  final Map<String, dynamic> message;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final outbound = (message['direction'] ?? '') == 'OUTBOUND';
    final at = DateTime.tryParse((message['createdAt'] ?? '').toString())?.toLocal();

    return Align(
      alignment: outbound ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 7),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.78),
        decoration: BoxDecoration(
          color: outbound
              ? (dark ? Brand.darkBubbleOut : Brand.bubbleOut)
              : (dark ? Brand.darkPanel : Brand.bubbleIn),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(10),
            topRight: const Radius.circular(10),
            bottomLeft: Radius.circular(outbound ? 10 : 2),
            bottomRight: Radius.circular(outbound ? 2 : 10),
          ),
          boxShadow: const [BoxShadow(color: Color(0x1F0B141A), blurRadius: 1, offset: Offset(0, 1))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              (message['text'] ?? '').toString(),
              style: TextStyle(fontSize: 15, height: 1.35, color: dark ? Brand.darkInk : const Color(0xFF111B21)),
            ),
            const SizedBox(height: 3),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  at == null ? '' : DateFormat.Hm().format(at),
                  style: TextStyle(fontSize: 10.5, color: dark ? Brand.darkInkSoft : const Color(0xFF667781)),
                ),
                if (outbound) ...[
                  const SizedBox(width: 4),
                  Icon(
                    (message['status'] ?? '') == 'FAILED' ? Icons.error_outline_rounded : Icons.done_all_rounded,
                    size: 14,
                    color: (message['status'] ?? '') == 'FAILED'
                        ? Brand.danger
                        : (message['status'] == 'READ' ? const Color(0xFF53BDEB) : (dark ? Brand.darkInkSoft : const Color(0xFF667781))),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.onSend,
    this.disabledHint,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final VoidCallback onSend;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return SafeArea(
      top: false,
      child: Container(
        color: dark ? Brand.darkPanel : Brand.chatBar,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                minLines: 1,
                maxLines: 5,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: disabledHint ?? 'Message',
                  filled: true,
                  fillColor: dark ? Brand.darkSurface : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                ),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 46,
              height: 46,
              child: FilledButton(
                onPressed: enabled ? onSend : null,
                style: FilledButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(46, 46),
                  shape: const CircleBorder(),
                  backgroundColor: const Color(0xFF00A884),
                ),
                child: sending
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.send_rounded, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
