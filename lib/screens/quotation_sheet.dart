import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/api.dart';

/// Quoting a marketplace enquiry from a phone.
///
/// The enquiry already knows who is asking, when they want to travel, how many
/// of them there are and — because they came from a published listing — exactly
/// which trip and what it costs. So the sheet opens on the ANSWER rather than a
/// form: known facts are printed as facts, and the only things wearing a box
/// are the values an operator actually decides.
///
/// Adults and children are counted separately because a family is not four
/// identical adults. The enquiry carries the split and the quotation stores it,
/// so quoting two children at the adult rate was losing that distinction at
/// exactly the moment it costs money. The child RATE is never invented: it
/// starts at the adult price and stays there until the operator says otherwise,
/// because no tour in this catalogue publishes a child price.
///
/// The one thing never guessed is the price itself. Where the tour has no
/// published figure the field opens empty and the send button stays disabled,
/// because a confident 0.00 in front of a customer is worse than a blank.
class QuotationSheet extends StatefulWidget {
  const QuotationSheet({super.key, required this.enquiryId, required this.customerName});
  final String enquiryId;
  final String customerName;

  @override
  State<QuotationSheet> createState() => _QuotationSheetState();
}

class _QuotationSheetState extends State<QuotationSheet> {
  Map<String, dynamic>? _draft;
  String? _error;
  bool _busy = false;
  Map<String, dynamic>? _done;

  /// Shown, not typed: the tour's title comes from the enquiry. The controller
  /// exists for the one case where there is no tour behind the enquiry, which
  /// is the only time the operator is asked to name what they are quoting.
  final _title = TextEditingController();
  final _adultPrice = TextEditingController();
  final _childPrice = TextEditingController();
  final _message = TextEditingController();
  final _included = TextEditingController();

  int _adults = 1;
  int _children = 0;
  DateTime? _validUntil;
  bool _showDetails = false;

  /// Until the operator touches it, the child rate follows the adult one. A
  /// child price that silently stopped tracking would quote yesterday's number.
  bool _childPriceEdited = false;

  static final _money = NumberFormat('#,##0.##', 'en_US');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _title.dispose();
    _adultPrice.dispose();
    _childPrice.dispose();
    _message.dispose();
    _included.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final draft = await Api.instance.quotationDraft(widget.enquiryId);
      if (!mounted) return;
      final items = (draft['items'] as List?) ?? const [];
      final first = items.isEmpty ? null : items.first as Map<String, dynamic>;
      final enquiry = (draft['enquiry'] as Map<String, dynamic>?) ?? const {};
      setState(() {
        _draft = draft;
        _title.text = (first?['description'] ?? '').toString();
        // A published 0 is "no price set", not a free trip — leave it blank so
        // the operator names the number instead of confirming a zero.
        final published = double.tryParse((first?['unitPrice'] ?? '').toString());
        final opening = (published == null || published <= 0) ? '' : _money.format(published);
        _adultPrice.text = opening;
        _childPrice.text = opening;
        _adults = (enquiry['adults'] as int?) ?? 1;
        _children = (enquiry['children'] as int?) ?? 0;
      });
    } catch (e) {
      if (mounted) setState(() => _error = _errorText(e));
    }
  }

  /* ------------------------------------------------------------- reading -- */

  String get _currency => (_draft?['currency'] ?? 'USD').toString();

  Map<String, dynamic>? get _firstItem {
    final items = (_draft?['items'] as List?) ?? const [];
    return items.isEmpty ? null : items.first as Map<String, dynamic>;
  }

  /// A tour priced for the whole group is not multiplied by the party size.
  ///
  /// Getting this wrong quotes a family of four at four times the real price,
  /// so the party stays visible either way but only ever multiplies a
  /// per-person figure.
  bool get _perGroup => _firstItem?['basis'] == 'per group';

  double? get _published {
    final value = double.tryParse((_firstItem?['unitPrice'] ?? '').toString());
    return value == null || value <= 0 ? null : value;
  }

  String? get _tourTitle {
    final tour = _draft?['tour'] as Map<String, dynamic>?;
    final title = tour?['title']?.toString().trim();
    return (title == null || title.isEmpty) ? null : title;
  }

  /// What the operator typed, in the shape the server will accept.
  ///
  /// People type "1,200" and "1 200" on a phone; the server takes digits and at
  /// most two decimals. Normalising here means a thousands separator is a
  /// formatting habit rather than a rejected quotation.
  static String _normalise(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[,\s]'), '').trim();
    final value = double.tryParse(cleaned);
    return value == null ? '' : value.toStringAsFixed(2);
  }

  String get _adultRate => _normalise(_adultPrice.text);
  String get _childRate => _normalise(_childPrice.text);

  double get _adultUnit => double.tryParse(_adultRate) ?? 0;
  double get _childUnit => double.tryParse(_childRate) ?? 0;

  int get _travellers => _adults + _children;

  /// Per group, the published figure IS the total. Per person, adults and
  /// children are priced on their own rates and added.
  double get _total => _perGroup ? _adultUnit : (_adults * _adultUnit) + (_children * _childUnit);

  String get _lineTitle => _tourTitle ?? _title.text.trim();

  // A child can genuinely be free, so the bar is a positive TOTAL rather than a
  // positive price on every line.
  bool get _ready => _lineTitle.isNotEmpty && _travellers > 0 && _total > 0;

  /* ------------------------------------------------------------- writing -- */

  void _setAdults(int next) => _setCount(() => _adults = next.clamp(0, 40), next);
  void _setChildren(int next) => _setCount(() => _children = next.clamp(0, 40), next);

  void _setCount(VoidCallback apply, int next) {
    if (next < 0 || next > 40) return;
    HapticFeedback.selectionClick();
    setState(apply);
  }

  Future<void> _pickValidUntil() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _validUntil ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked != null && mounted) setState(() => _validUntil = picked);
  }

  /// The party, for the server to turn into lines.
  ///
  /// The phone shows a running total so the operator is never surprised, but it
  /// does not decide the line structure: adults, children and their rates go up
  /// and the server composes, using the same function the portal calls. One
  /// rule, in one place, on the screen where getting it wrong costs money.
  Map<String, dynamic> _party() => {
    'title': _lineTitle,
    if (_included.text.trim().isNotEmpty) 'included': _included.text.trim(),
    'perGroup': _perGroup,
    'adults': _adults,
    'children': _children,
    'adultPrice': _adultRate,
    if (_children > 0) 'childPrice': _childRate.isEmpty ? '0.00' : _childRate,
  };

  Future<void> _submit({required bool send}) async {
    if (!_ready || _busy) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final enquiry = (_draft?['enquiry'] as Map<String, dynamic>?) ?? const {};
      final result = await Api.instance.createQuotation(
        bookingRequestId: widget.enquiryId,
        currency: _currency,
        notes: _message.text.trim(),
        startDate: enquiry['startDate']?.toString(),
        endDate: enquiry['endDate']?.toString(),
        // The party the operator just confirmed, not the one the enquiry arrived
        // with — those can differ, and the quotation should say what is being
        // quoted.
        adults: _adults,
        children: _children,
        validUntil: _validUntil == null ? null : DateFormat('yyyy-MM-dd').format(_validUntil!),
        send: send,
        party: _party(),
      );
      if (!mounted) return;
      setState(() {
        _done = result;
        _busy = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = _errorText(e);
        _busy = false;
      });
    }
  }

  /* ------------------------------------------------------------- display -- */

  /// "15 Sep", or "15 Sep – 21 Sep" when the enquiry gave both ends.
  static String? _when(Object? start, Object? end) {
    final from = DateTime.tryParse(start?.toString() ?? '');
    if (from == null) return null;
    final to = DateTime.tryParse(end?.toString() ?? '');
    return to == null ? _day(from) : '${_day(from)} – ${_day(to)}';
  }

  static const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  static String _day(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  /// Capitalise a name that was typed all in lower case, and leave every other
  /// name exactly as its owner wrote it — "josee mushi" becomes "Josee Mushi",
  /// while "McDonald" and "de Souza" survive untouched.
  static String _properName(String raw) => raw
      .split(' ')
      .map((word) => word.isEmpty || word != word.toLowerCase() ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');

  static String _errorText(Object e) => e is ApiException ? e.message : 'Something went wrong. Try again.';

  String _amount(double value) => '$_currency ${_money.format(value)}';

  String _people(int n, String one, String many) => '$n ${n == 1 ? one : many}';

  /// "2 adults × USD 2,950 + 2 children × USD 1,475" — the sum, written out.
  String get _basisLine {
    if (_perGroup) {
      return [
        'Whole group',
        _people(_adults, 'adult', 'adults'),
        if (_children > 0) _people(_children, 'child', 'children'),
      ].join(' · ');
    }
    final parts = [
      if (_adults > 0) '${_people(_adults, 'adult', 'adults')} × ${_amount(_adultUnit)}',
      if (_children > 0) '${_people(_children, 'child', 'children')} × ${_amount(_childUnit)}',
    ];
    return parts.join('  +  ');
  }

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return ConstrainedBox(
      // Tall enough for the whole form, never taller than the screen. The sheet
      // stays a sheet: the list it came from is still visible above it.
      constraints: BoxConstraints(maxHeight: media.size.height * 0.88),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 2, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _done != null ? _sent(text, scheme) : _form(text, scheme),
              ),
            ),
          ),
          // The actions never scroll away, and lift with the keyboard so the
          // price field and the button it feeds are on screen together.
          if (_draft != null || _done != null) _actions(text, scheme, media),
        ],
      ),
    );
  }

  /* --------------------------------------------------------------- parts -- */

  Widget _sectionLabel(TextTheme text, ColorScheme scheme, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Text(
      label.toUpperCase(),
      style: text.labelSmall?.copyWith(letterSpacing: 0.9, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant),
    ),
  );

  Widget _rule(ColorScheme scheme) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Divider(height: 1, thickness: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
  );

  Widget _priceField({
    required TextEditingController controller,
    required String label,
    required TextTheme text,
    required ColorScheme scheme,
    void Function(String)? onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(label, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: 6),
      TextField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.done,
        style: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true,
          prefixText: '$_currency ',
          hintText: '0',
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: const OutlineInputBorder(),
        ),
        onChanged: onChanged ?? (_) => setState(() {}),
      ),
    ],
  );

  Widget _counterRow({
    required TextTheme text,
    required ColorScheme scheme,
    required String label,
    required int value,
    required ValueChanged<int> onChange,
    required int min,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(child: Text(label, style: text.bodyLarge)),
        _StepButton(
          icon: Icons.remove_rounded,
          onTap: value > min ? () => onChange(value - 1) : null,
          semantic: 'One $label fewer',
        ),
        SizedBox(
          width: 56,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        _StepButton(
          icon: Icons.add_rounded,
          onTap: value < 40 ? () => onChange(value + 1) : null,
          semantic: 'One $label more',
        ),
      ],
    ),
  );

  List<Widget> _form(TextTheme text, ColorScheme scheme) {
    if (_error != null && _draft == null) {
      return [
        const SizedBox(height: 10),
        Text(_error!, style: text.bodyMedium?.copyWith(color: scheme.error)),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
        ),
      ];
    }
    if (_draft == null) {
      return [const SizedBox(height: 60), const Center(child: CircularProgressIndicator()), const SizedBox(height: 60)];
    }

    final enquiry = (_draft!['enquiry'] as Map<String, dynamic>?) ?? const {};
    final when = _when(enquiry['startDate'], enquiry['endDate']);

    return [
      // ── who and what ──────────────────────────────────────────────────────
      Text('Create quotation', style: text.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 14),
      Text(_properName(widget.customerName), style: text.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
      if (_tourTitle != null) ...[
        const SizedBox(height: 2),
        Text(_tourTitle!, style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
      ],
      const SizedBox(height: 2),
      Text(
        [if (when != null) when, _people(_travellers, 'traveller', 'travellers')].join(' · '),
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),

      // An enquiry with no tour behind it is the only case where the operator
      // has to say what they are quoting for.
      if (_tourTitle == null) ...[
        const SizedBox(height: 16),
        TextField(
          controller: _title,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'What you are quoting for'),
          onChanged: (_) => setState(() {}),
        ),
      ],

      _rule(scheme),

      // ── travellers ────────────────────────────────────────────────────────
      // Before the price, because how many are going decides what the price
      // means.
      _sectionLabel(text, scheme, 'Travellers'),
      _counterRow(text: text, scheme: scheme, label: 'Adults', value: _adults, min: 0, onChange: _setAdults),
      _counterRow(text: text, scheme: scheme, label: 'Children', value: _children, min: 0, onChange: _setChildren),

      _rule(scheme),

      // ── price ─────────────────────────────────────────────────────────────
      _sectionLabel(text, scheme, _perGroup ? 'Price for the group' : 'Price per person'),
      // The published figure is information, so it is printed, not boxed. It
      // also never changes here: quoting is not editing the listing.
      Row(
        children: [
          Text('Published', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
          const SizedBox(width: 10),
          Text(
            _published == null ? 'Not set' : _amount(_published!),
            style: text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: _published == null ? scheme.onSurfaceVariant : scheme.onSurface,
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _priceField(
              controller: _adultPrice,
              label: _perGroup ? 'Your quote' : (_children > 0 ? 'Adults' : 'Your quote'),
              text: text,
              scheme: scheme,
              onChanged: (value) => setState(() {
                // The child rate follows the adult one until it is set apart.
                if (!_childPriceEdited) _childPrice.text = value;
              }),
            ),
          ),
          // Only when there are children to price. No invented discount: it
          // opens at the adult rate and the operator decides.
          if (_children > 0 && !_perGroup) ...[
            const SizedBox(width: 14),
            Expanded(
              child: _priceField(
                controller: _childPrice,
                label: 'Children',
                text: text,
                scheme: scheme,
                onChanged: (_) => setState(() => _childPriceEdited = true),
              ),
            ),
          ],
        ],
      ),

      _rule(scheme),

      // ── total ─────────────────────────────────────────────────────────────
      // The one filled card on the sheet: the number the customer will see.
      Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'TOTAL',
              style: text.labelSmall?.copyWith(letterSpacing: 0.9, fontWeight: FontWeight.w700, color: scheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              _total > 0 ? _amount(_total) : '—',
              style: text.headlineSmall?.copyWith(fontWeight: FontWeight.w700, color: scheme.onSurface),
            ),
            if (_total > 0) ...[
              const SizedBox(height: 3),
              Text(_basisLine, style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            ],
          ],
        ),
      ),

      const SizedBox(height: 20),

      // ── message ───────────────────────────────────────────────────────────
      Text('Message to traveller (optional)', style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      const SizedBox(height: 6),
      TextField(
        controller: _message,
        maxLines: 2,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          hintText: 'Add a short message…',
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(),
        ),
      ),

      const SizedBox(height: 6),

      // ── everything else, folded away ──────────────────────────────────────
      //
      // Two fields, both of which the quotation already has columns for and both
      // of which the traveller actually sees on their quote page. Anything
      // beyond this belongs in the portal, not on a phone at the roadside.
      if (!_showDetails)
        TextButton.icon(
          onPressed: () => setState(() => _showDetails = true),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add details'),
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10)),
        )
      else ...[
        const SizedBox(height: 10),
        InkWell(
          onTap: _pickValidUntil,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Icon(Icons.event_rounded, size: 19, color: scheme.onSurfaceVariant),
                const SizedBox(width: 10),
                Text('Valid until', style: text.bodyMedium),
                const Spacer(),
                Text(
                  _validUntil == null ? 'Not set' : DateFormat('d MMM yyyy').format(_validUntil!),
                  style: text.bodyMedium?.copyWith(
                    color: _validUntil == null ? scheme.onSurfaceVariant : scheme.onSurface,
                    fontWeight: _validUntil == null ? FontWeight.w400 : FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right_rounded, size: 20, color: scheme.onSurfaceVariant),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text("What's included (optional)", style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        TextField(
          controller: _included,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'Park fees, lodging, transport…',
            isDense: true,
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(),
          ),
        ),
      ],

      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(_error!, style: text.bodySmall?.copyWith(color: scheme.error)),
      ],
    ];
  }

  List<Widget> _sent(TextTheme text, ColorScheme scheme) {
    final reference = (_done!['reference'] ?? '').toString();
    final sent = _done!['sent'] == true;
    final sendError = _done!['sendError'];
    return [
      const SizedBox(height: 12),
      Icon(sent ? Icons.check_circle_rounded : Icons.save_rounded, size: 44, color: scheme.primary),
      const SizedBox(height: 12),
      Text(sent ? 'Quotation sent' : 'Quotation saved', style: text.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(
        sent ? '$reference has gone to ${_properName(widget.customerName)}.' : '$reference is saved as a draft.',
        style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
      // Saved but not delivered is its own outcome, and saying "sent" here would
      // leave an operator believing a customer has a price they never received.
      if (sendError != null) ...[
        const SizedBox(height: 10),
        Text(sendError.toString(), style: text.bodySmall?.copyWith(color: scheme.error)),
      ],
      const SizedBox(height: 8),
    ];
  }

  Widget _actions(TextTheme text, ColorScheme scheme, MediaQueryData media) {
    final bottom = media.viewInsets.bottom > 0 ? media.viewInsets.bottom + 12 : media.padding.bottom + 12;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottom),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
      ),
      child: _done != null
          ? SizedBox(
              height: 50,
              width: double.infinity,
              child: FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Done')),
            )
          : Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: _busy || !_ready ? null : () => _submit(send: false),
                      child: const Text('Save draft'),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: SizedBox(
                    height: 50,
                    child: FilledButton(
                      onPressed: _busy || !_ready ? null : () => _submit(send: true),
                      child: Text(_busy ? 'Sending…' : 'Send quotation'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// A 48pt tap target for one thumb, which is the whole reason the party is a
/// pair of steppers and not two more number fields to type into.
class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap, required this.semantic});
  final IconData icon;
  final VoidCallback? onTap;
  final String semantic;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final enabled = onTap != null;
    return Semantics(
      button: true,
      label: semantic,
      child: Material(
        color: enabled ? scheme.surfaceContainerHighest : scheme.surfaceContainerHighest.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.6)),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            height: 44,
            width: 44,
            child: Icon(
              icon,
              size: 22,
              color: enabled ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
        ),
      ),
    );
  }
}
