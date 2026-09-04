import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/api.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/motion.dart';
import '../core/theme.dart';
import '../widgets/primitives.dart';

/// Where the vehicle is, on a map an operator can actually work from.
///
/// The rule this screen exists to obey: a position is NEVER shown without its
/// age beside it. A four-hour-old fix drawn as a confident pin is the one
/// failure that makes tracking worse than having none — it invites somebody to
/// stop worrying about a vehicle they should be phoning about.
///
/// So the marker's colour and every sentence come from the SERVER's state,
/// never from a guess made here, and the track is drawn from the fixes verbatim
/// — no smoothing, no road snapping, no line the vehicle never drove.
class TrackingMapScreen extends StatefulWidget {
  const TrackingMapScreen({
    super.key,
    required this.tripId,
    required this.vehicleLabel,
    this.tripTitle,
    this.tripStatus,
    this.guests,
  });

  /// The trip this screen was opened from. Tracking follows the SELECTED
  /// vehicle, which starts as this trip's and can then be switched — an
  /// operator runs a fleet, not one journey.
  final String tripId;
  final String? vehicleLabel;
  final String? tripTitle;
  final String? tripStatus;
  final int? guests;

  @override
  State<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

/// A basemap the operator can choose between.
///
/// Satellite is not decoration here: a Land Cruiser in the Serengeti is usually
/// on a track no street map has drawn, so on Standard it floats in empty beige.
/// None of these needs an API key. Each carries the attribution its licence
/// demands and its own maxZoom — OpenTopoMap stops at 17 and serves grey above
/// it, which reads as a broken map rather than a zoom limit.
class _Basemap {
  const _Basemap(this.key, this.label, this.url, this.maxZoom, this.attribution);
  final String key;
  final String label;
  final String url;
  final double maxZoom;
  final String attribution;
}

const _basemaps = <_Basemap>[
  _Basemap('standard', 'Standard', 'https://tile.openstreetmap.org/{z}/{x}/{y}.png', 19,
      '© OpenStreetMap contributors'),
  _Basemap('satellite', 'Satellite',
      'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}', 19,
      'Imagery © Esri'),
  _Basemap('terrain', 'Terrain', 'https://tile.opentopomap.org/{z}/{x}/{y}.png', 17,
      '© OpenTopoMap (CC-BY-SA)'),
];

/// One phrase per state, and they are mutually exclusive.
const _labels = <String, String>{
  'LIVE': 'Live',
  'RECENT': 'Recently updated',
  'STALE': 'Location may be outdated',
  'OFFLINE': 'No recent GPS signal',
  'NOT_CONFIGURED': 'Tracking not configured',
  'UNAVAILABLE': 'Tracking temporarily unavailable',
};

/// Never colour alone: an icon carries the same meaning for anyone who cannot
/// separate the greens from the ambers, and in direct sunlight.
const _icons = <String, IconData>{
  'LIVE': Icons.gps_fixed_rounded,
  'RECENT': Icons.gps_fixed_rounded,
  'STALE': Icons.history_rounded,
  'OFFLINE': Icons.gps_off_rounded,
  'NOT_CONFIGURED': Icons.location_disabled_rounded,
  'UNAVAILABLE': Icons.cloud_off_rounded,
};

class _TrackingMapScreenState extends State<TrackingMapScreen> {
  final MapController _map = MapController();
  final DraggableScrollableController _sheet = DraggableScrollableController();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  Timer? _poll;
  bool _followed = false;
  bool _markerCardOpen = false;
  _Basemap _base = _basemaps.first;

  /// The fleet, and which of it we are watching. Null vehicle = the trip's own,
  /// which is how the screen opens.
  List<Map<String, dynamic>> _fleet = const [];
  String? _vehicleId;
  String? _vehicleName;

  /// Slow on purpose. This is somebody's data bundle and somebody's battery, and
  /// a safari vehicle does not need second-by-second truth.
  static const _interval = Duration(seconds: 25);

  static const _collapsed = 0.18;
  static const _medium = 0.42;
  static const _expanded = 0.88;

  @override
  void initState() {
    super.initState();
    _load(withHistory: true);
    _loadFleet();
    _poll = Timer.periodic(_interval, (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool withHistory = false}) async {
    try {
      // Whichever vehicle is selected. The server resolves ownership either way;
      // the app never sends a tracker identifier.
      final data = _vehicleId == null
          ? await Api.instance.tripTracking(widget.tripId, history: withHistory)
          : await Api.instance.vehicleTracking(_vehicleId!, history: withHistory);
      if (!mounted) return;
      setState(() {
        // History arrives once. Refetching a day of fixes every twenty-five
        // seconds would cost the operator's bundle for nothing.
        _data = (withHistory || data['history'] != null) ? data : {...data, 'history': _data?['history']};
        _error = null;
        _loading = false;
      });
      _fitOnce();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error is ApiException ? error.message : 'Could not reach tracking.';
        _loading = false;
      });
    }
  }

  Future<void> _loadFleet() async {
    try {
      final data = await Api.instance.vehicles();
      if (!mounted) return;
      setState(() => _fleet = ((data['vehicles'] as List?) ?? const []).cast<Map<String, dynamic>>());
    } catch (_) {
      // The switcher simply does not appear. Failing to list the fleet must
      // never stop the operator seeing the vehicle they came here for.
    }
  }

  /// Switch which vehicle the map is following.
  void _selectVehicle(Map<String, dynamic>? v) {
    setState(() {
      _vehicleId = v?['id'] as String?;
      _vehicleName = v == null ? null : (v['name'] as String? ?? v['label'] as String?);
      _loading = true;
      _followed = false;
      _markerCardOpen = false;
      _data = null;
    });
    _load(withHistory: true);
  }

  String get _title => _vehicleName ?? widget.vehicleLabel ?? 'Vehicle';

  Map<String, dynamic>? get _position => _data?['position'] as Map<String, dynamic>?;
  String get _state => (_data?['state'] as String?) ?? 'UNAVAILABLE';

  LatLng? get _here {
    final p = _position;
    final lat = (p?['latitude'] as num?)?.toDouble();
    final lng = (p?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  List<LatLng> get _track {
    final raw = (_data?['history'] as Map<String, dynamic>?)?['points'] as List?;
    if (raw == null) return const [];
    return raw
        .whereType<List>()
        .map((t) => LatLng((t[0] as num).toDouble(), (t[1] as num).toDouble()))
        .toList(growable: false);
  }

  DateTime? get _fixAt => DateTime.tryParse(_position?['recordedAt'] as String? ?? '');
  DateTime? get _checkedAt => DateTime.tryParse(_data?['checkedAt'] as String? ?? '');
  int? get _speed => (_position?['speedKph'] as num?)?.round();

  /// Centre once, on the first fix. After that the operator owns the camera —
  /// yanking the map back mid-pinch is how a map stops being usable.
  void _fitOnce() {
    if (_followed) return;
    final here = _here;
    if (here == null) return;
    _followed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _map.move(here, 14);
    });
  }

  Color _tone(BuildContext c) => switch (_state) {
        'LIVE' || 'RECENT' => Tone.success(c),
        'STALE' || 'UNAVAILABLE' => Tone.warning(c),
        _ => Tone.muted(c),
      };

  void _choose(_Basemap b) {
    setState(() => _base = b);
    // A view with a lower ceiling must not leave the operator staring at grey.
    if (_map.camera.zoom > b.maxZoom) _map.move(_map.camera.center, b.maxZoom);
  }

  void _zoom(double by) => _map.move(_map.camera.center, (_map.camera.zoom + by).clamp(3.0, _base.maxZoom));

  void _recentre() {
    final here = _here;
    if (here != null) _map.move(here, _map.camera.zoom < 14 ? 14 : _map.camera.zoom);
  }

  /// Get the sheet out of the way, without fighting the operator if it is
  /// already down.
  void _collapseSheet() {
    if (!_sheet.isAttached || _sheet.size <= _collapsed + 0.02) return;
    _sheet.animateTo(_collapsed, duration: Motion.quick, curve: Motion.curve);
  }

  void _toggleSheet() {
    final size = _sheet.isAttached ? _sheet.size : _medium;
    _sheet.animateTo(size > _collapsed + 0.05 ? _collapsed : _medium,
        duration: Motion.enter, curve: Motion.curve);
  }

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: appBackground(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: Column(
          children: [
            _header(context),
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(child: _mapOrState(context)),
                  Positioned(left: 14, right: 14, top: 12, child: _controls(context)),

                  _bottomSheet(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- header --

  /// WHAT vehicle, and WHAT state, readable at a glance.
  ///
  /// Deliberately not dressed as a link. This app has no vehicle-detail screen
  /// to open, and a chevron that goes nowhere is worse than no chevron — the
  /// route out of here is Trip details, which is real.
  Widget _header(BuildContext context) {
    final tone = _tone(context);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 16, 10),
        child: Row(
          children: [
            // 48px target, not a 20px icon.
            SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded, size: 24),
                color: Tone.ink(context),
                tooltip: 'Back',
              ),
            ),
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: Tone.wash(context, tone),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.directions_car_rounded, size: 22, color: tone),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                      color: Tone.ink(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(_icons[_state] ?? Icons.gps_not_fixed_rounded, size: 15, color: tone),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _loading ? 'Checking…' : (_labels[_state] ?? _state),
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: tone),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Only offered when the tenant actually has more than one vehicle:
            // a switcher over a fleet of one is a control that does nothing.
            if (_fleet.length > 1)
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton(
                  onPressed: () => _openFleetSheet(context),
                  icon: const Icon(Icons.swap_horiz_rounded, size: 24),
                  color: Tone.accent(context),
                  tooltip: 'Switch vehicle',
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// The fleet, as a sheet. Tap a vehicle and the map follows it.
  void _openFleetSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(sheetContext).size.height * 0.75),
        decoration: BoxDecoration(
          color: Tone.surface(sheetContext),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).padding.bottom + 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Tone.muted(sheetContext).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text('Which vehicle?',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Tone.ink(sheetContext))),
                  const Spacer(),
                  Text('${_fleet.length} vehicles',
                      style: TextStyle(fontSize: 13.5, color: Tone.muted(sheetContext))),
                ],
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: _fleet.length,
                itemBuilder: (listContext, i) {
                  final v = _fleet[i];
                  final st = (v['state'] as String?) ?? 'NOT_CONFIGURED';
                  final tone = switch (st) {
                    'LIVE' || 'RECENT' => Tone.success(listContext),
                    'STALE' || 'UNAVAILABLE' => Tone.warning(listContext),
                    _ => Tone.muted(listContext),
                  };
                  final selected = v['id'] == _vehicleId;
                  return PressableRow(
                    onTap: () {
                      Navigator.of(sheetContext).pop();
                      _selectVehicle(v);
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                      decoration: BoxDecoration(
                        color: selected ? Tone.wash(listContext, Tone.accent(listContext)) : Tone.panel(listContext),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Icon(_icons[st] ?? Icons.gps_not_fixed_rounded, size: 20, color: tone),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (v['name'] as String?) ?? 'Vehicle',
                                  style: TextStyle(
                                      fontSize: 16, fontWeight: FontWeight.w600, color: Tone.ink(listContext)),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  // State first, then how old — never a place name
                                  // first, which reads as reassurance.
                                  [
                                    (v['stateLabel'] as String?) ?? '',
                                    if (v['recordedAt'] != null) relativeTime(v['recordedAt'])
                                  ].where((x) => x.isNotEmpty).join(' · '),
                                  style: TextStyle(fontSize: 13.5, color: tone),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_rounded, size: 20, color: Tone.accent(listContext)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------- map --

  Widget _mapOrState(BuildContext context) {
    if (_loading) {
      return Center(child: CircularProgressIndicator(color: Tone.accent(context), strokeWidth: 2.5));
    }
    final here = _here;
    if (here == null) return _noPosition(context);
    return _mapView(context, here, _track, _tone(context));
  }

  /// No position is a real answer, not an empty screen. A grey map with no pin
  /// looks like a bug; this says which of the several different nothings it is.
  Widget _noPosition(BuildContext context) {
    final notConfigured = _state == 'NOT_CONFIGURED';
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(_icons[_state] ?? Icons.location_off_rounded, size: 42, color: Tone.muted(context)),
            const SizedBox(height: 14),
            Text(
              _labels[_state] ?? 'No position',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Tone.ink(context)),
            ),
            const SizedBox(height: 8),
            Text(
              notConfigured
                  ? 'Connect a phone or GPS tracker to see this vehicle on the map.'
                  : _state == 'UNAVAILABLE'
                      // The server's own words when it has them: "temporarily
                      // unavailable" is true but says nothing an operator can act on.
                      ? (_error ?? "We couldn't refresh the vehicle location. This says nothing about where the vehicle is.")
                      : 'This tracker has not reported recently.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4, color: Tone.muted(context)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: () {
                  setState(() => _loading = true);
                  _load(withHistory: true);
                },
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: const Text('Try again', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapView(BuildContext context, LatLng here, List<LatLng> track, Color tone) {
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: here,
        initialZoom: 14,
        maxZoom: _base.maxZoom,
        // Tapping the map dismisses the tooltip, the way a map should.
        onTap: (_, __) => setState(() => _markerCardOpen = false),
        /*
         * Touching the map gets the sheet out of the way.
         *
         * An operator who starts panning is looking at the map, and a panel
         * covering the bottom third of it at that moment is the thing they were
         * about to move. hasGesture distinguishes a real touch from our own
         * programmatic recentre, which must NOT collapse anything.
         */
        onPositionChanged: (_, hasGesture) {
          if (hasGesture) _collapseSheet();
        },
      ),
      children: [
        TileLayer(
          key: ValueKey(_base.key),
          urlTemplate: _base.url,
          userAgentPackageName: 'tz.co.makutano.makutanoConnect',
          maxZoom: _base.maxZoom,
        ),
        if (track.length > 1)
          PolylineLayer(
            polylines: [
              // Drawn from the fixes verbatim. A prettier curve would be a road
              // the vehicle never took.
              Polyline(points: track, strokeWidth: 4, color: tone.withValues(alpha: 0.55)),
            ],
          ),
        // Where the drive began, so the line has a direction the eye can read.
        if (track.length > 1)
          MarkerLayer(
            markers: [
              Marker(
                point: track.first,
                width: 18,
                height: 18,
                child: Container(
                  decoration: BoxDecoration(
                    color: Tone.surface(context),
                    shape: BoxShape.circle,
                    border: Border.all(color: tone, width: 3),
                  ),
                ),
              ),
            ],
          ),
        MarkerLayer(
          markers: [
            Marker(
              point: here,
              // Tall enough to hold the tooltip ABOVE the vehicle, so the popup
              // belongs to the thing that was tapped rather than appearing at the
              // other end of the screen.
              width: 250,
              height: _markerCardOpen ? 170 : 56,
              alignment: Alignment.bottomCenter,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_markerCardOpen) _tooltip(context, tone),
                  GestureDetector(
                    onTap: () => setState(() => _markerCardOpen = !_markerCardOpen),
                    child: Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: tone,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3.5),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 10)],
                      ),
                      child: const Icon(Icons.directions_car_rounded, size: 23, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // -------------------------------------------------------------- controls --

  Widget _controls(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Flexible(child: _basemapPicker(context)),
        const Spacer(),
        Column(
          children: [
            _roundButton(context, Icons.add_rounded, () => _zoom(1), 'Zoom in'),
            const SizedBox(height: 7),
            _roundButton(context, Icons.remove_rounded, () => _zoom(-1), 'Zoom out'),
            const SizedBox(height: 7),
            if (_here != null) _roundButton(context, Icons.my_location_rounded, _recentre, 'Recentre'),
            const SizedBox(height: 7),
            _roundButton(context, Icons.open_in_full_rounded, _toggleSheet, 'Full map'),
          ],
        ),
      ],
    );
  }

  Widget _basemapPicker(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Tone.surface(context).withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Tone.line(context)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
      ),
      padding: const EdgeInsets.all(2.5),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final b in _basemaps)
            GestureDetector(
              onTap: () => _choose(b),
              behavior: HitTestBehavior.opaque,
              child: AnimatedContainer(
                duration: Motion.quick,
                // Compact. This is chosen once and then ignored — it should not
                // occupy the map like a primary action.
                constraints: const BoxConstraints(minHeight: 32),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 11),
                decoration: BoxDecoration(
                  color: _base.key == b.key ? Tone.accent(context) : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  b.label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: _base.key == b.key ? Colors.white : Tone.muted(context),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _roundButton(BuildContext context, IconData icon, VoidCallback onTap, String tip) => Semantics(
        button: true,
        label: tip,
        child: GestureDetector(
          onTap: onTap,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Tone.surface(context).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: Tone.line(context)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
            ),
            child: Icon(icon, size: 22, color: Tone.ink(context)),
          ),
        ),
      );

  // ------------------------------------------------------------ marker card --

  /// What tapping the vehicle opens — anchored to the vehicle itself.
  ///
  /// A card at the bottom of the screen makes the operator work out which pin it
  /// belongs to. Above the marker there is nothing to work out.
  Widget _tooltip(BuildContext context, Color tone) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 11),
      decoration: BoxDecoration(
        color: Tone.surface(context),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Tone.line(context)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.22), blurRadius: 16)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _title,
            style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w700, color: Tone.ink(context)),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_icons[_state] ?? Icons.gps_not_fixed_rounded, size: 14, color: tone),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  _labels[_state] ?? _state,
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: tone),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            // Time first, never place: an operator reads left to right and stops
            // at the first reassuring word.
            'Last GPS update ${relativeTime(_fixAt)}'
            '${_speed != null && _speed! > 3 ? ' · $_speed km/h' : ''}',
            style: TextStyle(fontSize: 13, color: Tone.muted(context)),
            maxLines: 2,
          ),
        ],
      ),
    ).animate().fadeIn(duration: Motion.quick).scaleXY(begin: 0.94, end: 1, duration: Motion.quick);
  }

  // ---------------------------------------------------------- bottom sheet --

  Widget _bottomSheet(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheet,
      initialChildSize: _medium,
      minChildSize: _collapsed,
      maxChildSize: _expanded,
      snap: true,
      snapSizes: const [_collapsed, _medium, _expanded],
      builder: (context, scrollController) {
        final tone = _tone(context);
        /*
         * A FLOATING panel, not a drawer welded to the bottom edge.
         *
         * Tied to the edge it reads as a wall the map ends at. Inset, with the
         * ground visible around it, it reads as something resting ON the map —
         * which is what it is, and it makes the map feel like the workspace
         * rather than the top half of the screen.
         */
        return Container(
          margin: EdgeInsets.fromLTRB(10, 0, 10, 10 + MediaQuery.of(context).padding.bottom),
          decoration: BoxDecoration(
            color: Tone.surface(context),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Tone.line(context)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 26, offset: const Offset(0, -4))],
          ),
          clipBehavior: Clip.antiAlias,
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 20),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Tone.muted(context).withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              _statusBlock(context, tone),
              if (_position != null) ...[
                const SizedBox(height: 18),
                _metrics(context),
                const SizedBox(height: 18),
                _actions(context),
              ],
              if (widget.tripTitle != null && _vehicleId == null) ...[
                const SizedBox(height: 20),
                _tripBlock(context),
              ],
              const SizedBox(height: 16),
              _trackingDetails(context),
            ],
          ),
        );
      },
    );
  }

  Widget _statusBlock(BuildContext context, Color tone) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(_icons[_state] ?? Icons.gps_not_fixed_rounded, size: 20, color: tone),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _labels[_state] ?? _state,
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: tone),
              ),
            ),
          ],
        ),
        if (_fixAt != null) ...[
          const SizedBox(height: 10),
          Text('Last GPS update', style: TextStyle(fontSize: 13.5, color: Tone.muted(context))),
          const SizedBox(height: 2),
          Text(
            relativeTime(_fixAt),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Tone.ink(context)),
          ),
        ],
        if (_checkedAt != null) ...[
          const SizedBox(height: 6),
          // THE SECOND CLOCK. The age of the fix is above; this is the age of our
          // knowledge. Conflating them is how a screen claims to be live while
          // nothing has been fetched for ten minutes.
          Text('Checked ${relativeTime(_checkedAt)}',
              style: TextStyle(fontSize: 13.5, color: Tone.muted(context))),
        ],
      ],
    );
  }

  Widget _metrics(BuildContext context) {
    Widget tile(String value, String label) => Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: Tone.panel(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value,
                    style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Tone.ink(context))),
                const SizedBox(height: 3),
                Text(label, style: TextStyle(fontSize: 13.5, color: Tone.muted(context))),
              ],
            ),
          ),
        );

    return Row(
      children: [
        // Speed distinguishes driving from parked, which the state alone cannot.
        tile(_speed == null ? '—' : (_speed! > 3 ? '$_speed km/h' : 'Parked'), 'Movement'),
        const SizedBox(width: 12),
        tile(relativeTime(_fixAt), 'GPS update'),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 48,
            child: FilledButton.icon(
              onPressed: _recentre,
              icon: const Icon(Icons.my_location_rounded, size: 19),
              label: const Text('Recentre', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: SizedBox(
            height: 48,
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() => _loading = true);
                _load(withHistory: true);
              },
              icon: const Icon(Icons.route_rounded, size: 19),
              label: const Text('Route history', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _tripBlock(BuildContext context) {
    final parts = [
      if (widget.guests != null && widget.guests! > 0) '${widget.guests} guests',
      if (widget.tripStatus != null) _tripStatusLabel(widget.tripStatus!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CURRENT TRIP',
            style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: Tone.muted(context))),
        const SizedBox(height: 8),
        PressableRow(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(
              color: Tone.panel(context),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.tripTitle!,
                          style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: Tone.ink(context)),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      if (parts.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(parts.join(' · '), style: TextStyle(fontSize: 13.5, color: Tone.muted(context))),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 22, color: Tone.muted(context)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  String _tripStatusLabel(String s) => switch (s) {
        'PREPARING' => 'Preparing',
        'READY' => 'Ready to leave',
        'IN_PROGRESS' => 'Out now',
        'COMPLETED' => 'Completed',
        _ => s,
      };

  /// Coordinates and point counts live HERE, behind a tap.
  ///
  /// They are technical details. Given equal weight beside the status they read
  /// as diagnostics and push the things an operator actually acts on — is it
  /// reporting, how old, how fast — down the screen.
  Widget _trackingDetails(BuildContext context) {
    final here = _here;
    final track = _track;
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text('Tracking details',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Tone.ink(context))),
        iconColor: Tone.muted(context),
        collapsedIconColor: Tone.muted(context),
        children: [
          if (here != null)
            _detail(context, 'Coordinates',
                '${here.latitude.toStringAsFixed(5)}, ${here.longitude.toStringAsFixed(5)}'),
          if (_fixAt != null) _detail(context, 'GPS fix time', _fixAt!.toLocal().toString().substring(0, 16)),
          if (_checkedAt != null)
            _detail(context, 'Last checked', _checkedAt!.toLocal().toString().substring(0, 16)),
          if (track.length > 1) _detail(context, 'Route points', '${track.length} in the last 24 hours'),
          _detail(context, 'Map data', _base.attribution),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 118,
              child: Text(label, style: TextStyle(fontSize: 13.5, color: Tone.muted(context))),
            ),
            Expanded(
              child: Text(value, style: TextStyle(fontSize: 13.5, color: Tone.ink(context))),
            ),
          ],
        ),
      );
}
