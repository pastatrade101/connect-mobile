import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/theme.dart';
import '../widgets/primitives.dart';

/// Logging an enquiry from a phone: four things, and everything else folded away.
/// Ends on the next step, never on "created".
class CreateEnquirySheet extends StatefulWidget {
  const CreateEnquirySheet({super.key, required this.onOpenThread, this.noun = 'enquiry'});
  final void Function(String conversationId) onOpenThread;
  final String noun;

  @override
  State<CreateEnquirySheet> createState() => _CreateEnquirySheetState();
}

class _CreateEnquirySheetState extends State<CreateEnquirySheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _notes = TextEditingController();
  final _email = TextEditingController();
  final _adults = TextEditingController();

  bool _more = false;
  bool _acknowledge = false;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _created;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _notes.dispose();
    _email.dispose();
    _adults.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = await Api.instance.createEnquiry(
        name: _name.text.trim(),
        phone: _phone.text.trim(),
        email: _email.text.trim(),
        notes: _notes.text.trim(),
        adults: int.tryParse(_adults.text.trim()),
        acknowledge: _acknowledge,
      );
      if (!mounted) return;
      setState(() {
        _created = result;
        _busy = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.message;
        _busy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final created = _created;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 20),
          child: created != null ? _success(created) : _form(context),
        ),
      ),
    );
  }

  Widget _form(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('New ${widget.noun}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 20)),
        const SizedBox(height: 4),
        Text(
          'For the ones that arrive by phone or in person. Website and WhatsApp ${widget.noun}s arrive on their own.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        if (_error != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Brand.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Brand.danger.withValues(alpha: 0.3)),
            ),
            child: Text(_error!, style: const TextStyle(color: Brand.danger, fontSize: 13.5)),
          ),
          const SizedBox(height: 14),
        ],
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Who is it from?', hintText: 'Amina Said'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _phone,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(labelText: 'WhatsApp number', hintText: '+255 712 345 678'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notes,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'What are they asking for?',
            hintText: '4 days Serengeti, mid-range, family of five',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => setState(() => _more = !_more),
            child: Text(_more ? 'Fewer details' : 'More details'),
          ),
        ),
        if (_more) ...[
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _adults,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'How many people'),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            value: _acknowledge,
            onChanged: (v) => setState(() => _acknowledge = v),
            contentPadding: EdgeInsets.zero,
            title: const Text('Send a WhatsApp acknowledgement', style: TextStyle(fontSize: 14.5)),
          ),
        ],
        const SizedBox(height: 14),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
              : Text('Create ${widget.noun}'),
        ),
      ],
    );
  }

  /// The point of finishing is knowing what to do next.
  Widget _success(Map<String, dynamic> created) {
    final conversationId = created['conversationId'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            const Icon(Icons.check_circle_rounded, color: Brand.success, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                '${widget.noun[0].toUpperCase()}${widget.noun.substring(1)} ${created['reference'] ?? ''} created',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Price what they asked for and send it — or reply on WhatsApp first.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 18),
        if (conversationId != null)
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onOpenThread(conversationId.toString());
            },
            icon: const Icon(Icons.forum_rounded, size: 18),
            label: const Text('Reply on WhatsApp'),
          ),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
      ],
    );
  }
}

/// The centre button: what this business can create, led by the primary action.
class QuickCreateSheet extends StatelessWidget {
  const QuickCreateSheet({super.key, required this.actions, required this.onPick});
  final List<dynamic> actions;
  final void Function(String key) onPick;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 4, 14, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
              child: Text('Create', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            ),
            GroupedList(
              margin: EdgeInsets.zero,
              children: [
                for (final action in actions)
                  ListTile(
                    onTap: () => onPick(action.key as String),
                    minVerticalPadding: 14,
                    leading: Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: Brand.blueWash, borderRadius: BorderRadius.circular(10)),
                      child: Icon(action.icon as IconData, color: Brand.blue, size: 19),
                    ),
                    title: Text(action.label as String, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text(action.hint as String, style: Theme.of(context).textTheme.bodySmall),
                    trailing: const Icon(Icons.chevron_right_rounded, size: 19),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
