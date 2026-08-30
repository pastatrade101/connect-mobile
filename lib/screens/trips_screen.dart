import 'package:flutter/material.dart';

import '../core/api.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../widgets/primitives.dart';
import '../widgets/skeleton.dart';
import '../widgets/trip_readiness.dart';

/// Trips, as the person getting them out of the door reads them.
///
/// Grouped by WHEN they leave, because that is how an operations day is ordered —
/// not by when a trip happened to be created. Every judgement on this screen
/// (the grouping, the readiness verdict, the blockers, the next action) is made
/// by the server, so the phone and the portal cannot disagree about whether a
/// trip can depart. A rule reimplemented here is a rule that drifts until the
/// next app-store release.
class TripsScreen extends StatefulWidget {
  const TripsScreen({super.key, required this.onOpenTrip});

  final void Function(String tripId) onOpenTrip;

  @override
  State<TripsScreen> createState() => TripsScreenState();
}

class TripsScreenState extends State<TripsScreen> {
  static const _tabs = [
    (key: 'upcoming', label: 'Upcoming'),
    (key: 'in_progress', label: 'Under way'),
    (key: 'completed', label: 'Done'),
  ];

  bool _loading = true;
  String _tab = 'upcoming';
  bool _mine = false;
  String? _error;
  List<Map<String, dynamic>> _groups = const [];
  int _blocked = 0;
  int _leavingSoon = 0;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      final data = await Api.instance.trips(tab: _tab, mine: _mine);
      if (!mounted) return;
      setState(() {
        _groups = (data['groups'] as List? ?? const []).cast<Map<String, dynamic>>();
        _blocked = (data['blocked'] as num? ?? 0).toInt();
        _leavingSoon = (data['leavingSoon'] as num? ?? 0).toInt();
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException ? error.message : 'Could not load trips.';
        _loading = false;
      });
    }
  }

  void _switch({String? tab, bool? mine}) {
    setState(() {
      if (tab != null) _tab = tab;
      if (mine != null) _mine = mine;
      _loading = true;
    });
    load();
  }

  /// The one line worth reading on arrival. A row of counters is what a screen
  /// shows when nobody has decided what it is for.
  String get _summary {
    if (_blocked > 0) {
      final s = '$_blocked cannot leave yet';
      return _leavingSoon > 0 ? '$s · $_leavingSoon leaving this week' : s;
    }
    if (_leavingSoon > 0) return '$_leavingSoon leaving this week — all on track';
    return _groups.isEmpty ? 'Confirmed bookings, getting out of the door' : 'Everything on track';
  }

  @override
  Widget build(BuildContext context) {
    final session = Api.instance.session;
    if (session == null) return const SizedBox.shrink();

    return Column(
      children: [
        MobileHeader(
          title: 'Trips',
          subtitle: _summary,
          subtitleTone: _blocked > 0 ? Tone.danger(context) : null,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(
            children: [
              Expanded(
                child: _Segmented(
                  options: _tabs,
                  selected: _tab,
                  onChanged: (v) => _switch(tab: v),
                ),
              ),
              const SizedBox(width: 8),
              // "Mine" is an operations person's whole day; it deserves to be one
              // tap from anywhere on this screen.
              _MineToggle(on: _mine, onTap: () => _switch(mine: !_mine)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const SkeletonRows(rows: 4)
              : _error != null
              ? TeachingEmptyState(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not load trips',
                  body: _error!,
                  actionLabel: 'Try again',
                  onAction: () => _switch(),
                )
              : _groups.isEmpty
              ? TeachingEmptyState(
                  icon: Icons.map_outlined,
                  title: _mine ? 'Nothing assigned to you' : 'No trips here',
                  body:
                      'A trip appears when a confirmed booking is handed over to '
                      'operations. The traveller, the dates and what they bought all come across.',
                )
              : RefreshIndicator(
                  onRefresh: load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: NavBar.clearance),
                    children: [
                      for (var g = 0; g < _groups.length; g++) ...[
                        GroupLabel(
                          text:
                              '${_groups[g]['label']} · ${(_groups[g]['items'] as List?)?.length ?? 0}',
                        ).entrance(index: g),
                        GroupedList(
                          children: [
                            for (final item in (_groups[g]['items'] as List? ?? const []))
                              TripRow(
                                trip: item as Map<String, dynamic>,
                                onTap: () => widget.onOpenTrip((item['id'] ?? '').toString()),
                              ),
                          ],
                        ),
                        const SizedBox(height: 14),
                      ],
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}

class _MineToggle extends StatelessWidget {
  const _MineToggle({required this.on, required this.onTap});

  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Tone.blue(context);
    return PressableRow(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: on ? Tone.wash(context, accent) : Tone.panel(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: on ? accent.withValues(alpha: 0.4) : Tone.line(context)),
        ),
        child: Text(
          'Mine',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: on ? accent : Tone.muted(context),
          ),
        ),
      ),
    );
  }
}

/// A compact three-way switch. Local to this screen: the portal's tabs are a nav
/// pattern, and lifting one into the shared widgets before a second screen wants
/// it is how a widget library fills with single-use components.
class _Segmented extends StatelessWidget {
  const _Segmented({required this.options, required this.selected, required this.onChanged});

  final List<({String key, String label})> options;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Tone.panel(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          for (final option in options)
            Expanded(
              child: PressableRow(
                onTap: () => onChanged(option.key),
                child: AnimatedContainer(
                  duration: Motion.quick,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: selected == option.key ? Tone.surface(context) : Colors.transparent,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Text(
                    option.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: selected == option.key ? Tone.ink(context) : Tone.muted(context),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
