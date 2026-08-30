import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../widgets/primitives.dart';
import '../widgets/skeleton.dart';
import '../widgets/trip_readiness.dart';

/// One trip, set up from the field.
///
/// This is the screen somebody uses standing next to a Land Cruiser, so it is
/// built for one decision at a time: tap a row, type a name, done. Every row is
/// a single field and every save returns the SERVER's fresh readiness verdict —
/// the app never recomputes whether a trip can leave, because a second opinion
/// on that question is exactly the thing that drifts.
class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await Api.instance.trip(widget.tripId);
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException ? error.message : 'Could not load this trip.';
        _loading = false;
      });
    }
  }

  Map<String, dynamic> get _trip => (_data?['trip'] ?? const {}) as Map<String, dynamic>;
  Map<String, dynamic> get _readiness => (_data?['readiness'] ?? const {}) as Map<String, dynamic>;
  Map<String, dynamic> get _can => (_data?['can'] ?? const {}) as Map<String, dynamic>;
  bool get _canWrite => _can['write'] == true;

  Future<void> _save(String field, Object? value) async {
    setState(() => _busy = true);
    try {
      await Api.instance.updateTrip(widget.tripId, {field: value});
      // Reload rather than patching locally: changing a driver can change the
      // trip's STATUS (a READY trip whose driver is removed drops back to
      // preparing), and guessing at that on the client is how the phone starts
      // disagreeing with the server.
      await _load();
    } catch (error) {
      if (!mounted) return;
      _complain(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _setStatus(String status) async {
    setState(() => _busy = true);
    try {
      await Api.instance.setTripStatus(widget.tripId, status);
      await _load();
    } catch (error) {
      if (!mounted) return;
      // The server refuses a trip that cannot leave and says exactly what is
      // missing. Show that sentence rather than a generic failure.
      _complain(error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _complain(Object error) {
    final message = error is ApiException ? error.message : 'That did not work. Try again.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _edit(String field, String label, String? current, String hint) async {
    final controller = TextEditingController(text: current ?? '');
    // What the customer was actually sold. Offering it beats making somebody
    // retype a lodge name they can see on the booking — and a typo here is a
    // hotel nobody has confirmed.
    final suggestions = ((_data?['suggestions'] as Map<String, dynamic>?)?[field] as List? ?? const [])
        .map((e) => e.toString())
        .where((s) => s.isNotEmpty && s != current)
        .toList();
    final value = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
        child: Container(
          decoration: BoxDecoration(
            color: Tone.surface(sheetContext),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Tone.muted(sheetContext).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(label, style: Theme.of(sheetContext).textTheme.titleMedium),
              if (suggestions.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('On the booking', style: TextStyle(fontSize: 11.5, color: Tone.muted(sheetContext))),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in suggestions)
                      ActionChip(
                        label: Text(option, style: TextStyle(color: Tone.blue(sheetContext))),
                        // Explicit tokens. A bare Material chip takes the seed's
                        // neutral ramp rather than Brand — the one unstyled
                        // control in the app, and near-illegible in dark.
                        backgroundColor: Tone.wash(sheetContext, Tone.blue(sheetContext)),
                        side: BorderSide(color: Tone.line(sheetContext)),
                        onPressed: () => Navigator.pop(sheetContext, option),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text('Or type something else', style: TextStyle(fontSize: 11.5, color: Tone.muted(sheetContext))),
                const SizedBox(height: 6),
              ] else
                const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(hintText: hint),
                onSubmitted: (v) => Navigator.pop(sheetContext, v),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if ((current ?? '').isNotEmpty)
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext, ''),
                      child: Text('Clear', style: TextStyle(color: Tone.danger(sheetContext))),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(sheetContext), child: const Text('Cancel')),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(sheetContext, controller.text),
                    child: const Text('Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (value == null) return;
    await _save(field, value.trim().isEmpty ? null : value.trim());
  }

  /// Handing the trip to somebody. A picker rather than a text field, because
  /// the answer is always one of a known, small list of colleagues.
  Future<void> _assign() async {
    final members = ((_data?['members'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final current = _trip['operationsUserId']?.toString();
    final chosen = await showModalBottomSheet<Map<String, String?>>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: Tone.surface(sheetContext),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(0, 10, 0, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Tone.muted(sheetContext).withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [Text('Who is preparing this trip?', style: Theme.of(sheetContext).textTheme.titleMedium)],
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final m in members)
                    ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Tone.wash(sheetContext, Tone.blue(sheetContext)),
                        child: Text(
                          initialsOf((m['name'] ?? '').toString()),
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Tone.blue(sheetContext)),
                        ),
                      ),
                      title: Text((m['name'] ?? '').toString()),
                      subtitle: Text((m['role'] ?? '').toString()),
                      trailing: current == m['id']
                          ? Icon(Icons.check_rounded, color: Tone.success(sheetContext))
                          : null,
                      onTap: () => Navigator.pop(sheetContext, {'id': (m['id'] ?? '').toString()}),
                    ),
                  if (current != null)
                    ListTile(
                      leading: Icon(Icons.person_off_outlined, color: Tone.muted(sheetContext)),
                      title: const Text('Nobody yet'),
                      onTap: () => Navigator.pop(sheetContext, {'id': null}),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
    if (chosen == null) return;
    await _save('operationsUserId', chosen['id']);
  }

  @override
  Widget build(BuildContext context) {
    // The gradient wraps the WHOLE scaffold, not just the body. Decorating only
    // the body left the toolbar sitting over nothing, which renders black — and
    // a dark title on black is unreadable.
    return DecoratedBox(
      decoration: appBackground(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        // A real AppBar rather than the in-list header the tabs use: this is a
        // PUSHED screen, so it needs a back affordance, and the readiness verdict
        // has to stay on screen while somebody scrolls through the setup rows —
        // it is the number they are trying to move.
        appBar: AppBar(
          titleSpacing: 0,
          backgroundColor: Colors.transparent,
          surfaceTintColor: Colors.transparent,
          title: _loading
              ? const SizedBox.shrink()
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (_trip['title'] ?? 'Trip').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      _headerSubtitle(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: Tone.muted(context)),
                    ),
                  ],
                ),
          actions: [
            if (!_loading)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: ReadinessRing(
                  percent: (_readiness['percent'] as num?)?.toInt(),
                  canBeReady: _readiness['canBeReady'] as bool?,
                  daysToDeparture: _daysToDeparture,
                  status: (_trip['status'] ?? '').toString(),
                  size: 38,
                ),
              ),
          ],
        ),
        body: SafeArea(
          bottom: false,
          child: _loading
              ? const SkeletonRows(rows: 6, disc: false)
              : _error != null
              ? TeachingEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load this trip',
                  body: _error!,
                  actionLabel: 'Try again',
                  onAction: () {
                    setState(() {
                      _loading = true;
                      _error = null;
                    });
                    _load();
                  },
                )
              : _body(context),
        ),
      ),
    );
  }

  Widget _body(BuildContext context) {
    final blocking = (_readiness['blocking'] as List? ?? const []).cast<String>();
    final canBeReady = _readiness['canBeReady'] == true;
    final status = (_trip['status'] ?? '').toString();

    return ListView(
      padding: const EdgeInsets.only(top: 4, bottom: 32),
      children: [
        // The one action that matters, chosen by the readiness model rather than
        // by which button somebody felt like showing.
        if (_canWrite && status != 'COMPLETED' && status != 'CANCELLED')
          _ActionCard(
            busy: _busy,
            title: switch (status) {
              'PREPARING' when canBeReady => 'Everything critical is in place',
              'PREPARING' => '${blocking.length} thing${blocking.length == 1 ? '' : 's'} still stopping this trip',
              'READY' => 'Ready to go',
              _ => 'Trip under way',
            },
            body: switch (status) {
              'PREPARING' when canBeReady => 'Mark it ready so the team knows it can leave.',
              'PREPARING' => 'Still needs ${blocking.join(', ')}.',
              'READY' => 'Start it when the travellers are on their way.',
              _ => 'Complete it when they are home.',
            },
            actionLabel: switch (status) {
              'PREPARING' => 'Mark ready',
              'READY' => 'Start trip',
              _ => 'Complete trip',
            },
            enabled: switch (status) {
              'PREPARING' => canBeReady,
              _ => true,
            },
            onAction: () => _setStatus(switch (status) {
              'PREPARING' => 'READY',
              'READY' => 'IN_PROGRESS',
              _ => 'COMPLETED',
            }),
          ).entrance(),

        const GroupLabel(text: 'Setup'),
        GroupedList(
          children: [
            for (final row in _setupRows)
              SetupRow(
                label: row.label,
                value: row.value,
                icon: row.icon,
                critical: row.critical,
                enabled: _canWrite && !_busy,
                onTap: () => _edit(row.field, row.label, row.value, row.hint),
              ),
            if (_can['assign'] == true)
              SetupRow(
                label: 'Operations owner',
                value: _ownerName,
                icon: Icons.badge_outlined,
                // Not blocking: a trip with everything booked can still leave
                // while nobody has formally claimed it.
                critical: false,
                enabled: !_busy,
                actionLabel: _ownerName == null ? 'Assign' : 'Change',
                onTap: _assign,
              ),
            SetupRow(
              label: 'Hotel confirmed',
              value: _trip['hotelConfirmed'] == true ? 'Confirmed with the property' : null,
              icon: Icons.check_circle_outline_rounded,
              critical: false,
              enabled: _canWrite && !_busy,
              actionLabel: _trip['hotelConfirmed'] == true ? 'Undo' : 'Confirm',
              onTap: () => _save('hotelConfirmed', _trip['hotelConfirmed'] != true),
            ),
          ],
        ),

        // Money is shown and never edited here. Operations needs to know a
        // balance is outstanding before a departure; changing it is the
        // booking's job, and the booking lives in the portal.
        if (_booking['hasBalance'] == true) ...[
          const SizedBox(height: 14),
          const GroupLabel(text: 'Before they travel'),
          GroupedList(
            children: [
              SetupRow(
                label: 'Balance outstanding',
                value: _balanceText,
                icon: Icons.payments_outlined,
                critical: false,
                enabled: false,
              ),
            ],
          ),
        ],

        if (_travelers.isNotEmpty) ...[
          const SizedBox(height: 14),
          GroupLabel(text: 'Guests · ${_travelers.length}'),
          GroupedList(
            children: [
              for (final t in _travelers)
                SetupRow(
                  label: (t['name'] ?? 'Traveller').toString(),
                  value: _travelerLine(t),
                  icon: Icons.person_outline_rounded,
                  critical: false,
                  enabled: false,
                ),
            ],
          ),
        ],

        if (_itinerary.isNotEmpty) ...[
          const SizedBox(height: 14),
          const GroupLabel(text: 'Itinerary'),
          GroupedList(
            children: [
              for (final item in _itinerary)
                SetupRow(
                  label: item['dayNumber'] == null ? 'Not scheduled' : 'Day ${item['dayNumber']}',
                  value: (item['title'] ?? '').toString(),
                  icon: Icons.place_outlined,
                  critical: false,
                  enabled: false,
                ),
            ],
          ),
        ],
      ],
    );
  }

  // ── derived ───────────────────────────────────────────────────────────────

  Map<String, dynamic> get _booking => (_data?['booking'] ?? const {}) as Map<String, dynamic>;
  List<Map<String, dynamic>> get _travelers =>
      ((_data?['travelers'] as List?) ?? const []).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get _itinerary => ((_data?['items'] as List?) ?? const []).cast<Map<String, dynamic>>();

  String? get _ownerName {
    final id = _trip['operationsUserId']?.toString();
    if (id == null || id.isEmpty) return null;
    final members = ((_data?['members'] as List?) ?? const []).cast<Map<String, dynamic>>();
    final match = members.where((m) => m['id'] == id);
    return match.isEmpty ? 'Assigned' : (match.first['name'] ?? 'Assigned').toString();
  }

  String get _balanceText {
    final due = _booking['balanceDue'];
    final currency = (_booking['currency'] ?? '').toString();
    // A viewer without bookings:read is told THAT money is owed, not how much.
    return due == null ? 'Some balance is still owed' : '$currency $due';
  }

  int? get _daysToDeparture {
    final raw = _trip['startDate'];
    if (raw == null) return null;
    final start = DateTime.tryParse(raw.toString());
    if (start == null) return null;
    final now = DateTime.now();
    return DateTime.utc(
      start.year,
      start.month,
      start.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
  }

  String _headerSubtitle() {
    final guests = ((_trip['adults'] as num?)?.toInt() ?? 0) + ((_trip['children'] as num?)?.toInt() ?? 0);
    final days = _daysToDeparture;
    final when = days == null
        ? 'No dates yet'
        : days < 0
        ? 'Under way'
        : days == 0
        ? 'Departs today'
        : days == 1
        ? 'Departs tomorrow'
        : 'Departs in $days days';
    return '$when · $guests guest${guests == 1 ? '' : 's'}';
  }

  static String _travelerLine(Map<String, dynamic> t) {
    final bits = <String>[
      if ((t['nationality'] ?? '').toString().isNotEmpty) t['nationality'].toString(),
      t['hasPassport'] == true ? 'passport on file' : 'no passport yet',
      if ((t['dietaryRequirements'] ?? '').toString().isNotEmpty) t['dietaryRequirements'].toString(),
    ];
    return bits.join(' · ');
  }

  List<({String field, String label, String? value, IconData icon, String hint, bool critical})> get _setupRows => [
    (
      field: 'accommodation',
      label: 'Accommodation',
      value: _trip['accommodation'] as String?,
      icon: Icons.hotel_outlined,
      hint: 'Which lodge or hotel',
      critical: true,
    ),
    (
      field: 'vehicle',
      label: 'Vehicle',
      value: _trip['vehicle'] as String?,
      icon: Icons.directions_car_outlined,
      hint: 'e.g. T 123 ABC — Land Cruiser',
      critical: true,
    ),
    (
      field: 'driver',
      label: 'Driver',
      value: _trip['driver'] as String?,
      icon: Icons.person_outline_rounded,
      hint: 'Who is driving',
      critical: true,
    ),
    (
      field: 'guide',
      label: 'Guide',
      value: _trip['guide'] as String?,
      icon: Icons.explore_outlined,
      hint: 'Who is guiding',
      critical: false,
    ),
  ];
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.title,
    required this.body,
    required this.actionLabel,
    required this.enabled,
    required this.busy,
    required this.onAction,
  });

  final String title;
  final String body;
  final String actionLabel;
  final bool enabled;
  final bool busy;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Tone.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Tone.line(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(body, style: TextStyle(fontSize: 13, height: 1.35, color: Tone.muted(context))),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled && !busy ? onAction : null,
              style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
              child: busy
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      // The button's own foreground, not a white literal: in dark
                      // the fill is light blue with a DARK label, so a white
                      // spinner all but disappears on it.
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Theme.of(context).colorScheme.onPrimary,
                      ),
                    )
                  : Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}
