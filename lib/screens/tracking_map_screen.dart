import 'dart:async';

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/api.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../core/motion.dart';
import '../core/theme.dart';
import '../core/tracking_math.dart';
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

/// A tile request that gives up instead of hanging.
///
/// dart:io's default connection timeout is long enough that a blocked or
/// silently-dropping network produces no error for over a minute — during which
/// flutter_map has nothing to report and the map is simply a grey rectangle with
/// no explanation. On a phone in the field that is indistinguishable from a
/// broken app. Eight seconds is well past a slow-but-working 3G tile and well
/// short of a person's patience.
class _TimeoutTileClient extends http.BaseClient {
  _TimeoutTileClient() : _inner = http.Client();
  final http.Client _inner;
  static const _limit = Duration(seconds: 8);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(_limit);

  @override
  void close() {
    _inner.close();
    super.close();
  }
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
  _Basemap(
    'standard',
    'Standard',
    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    19,
    '© OpenStreetMap contributors',
  ),
  _Basemap(
    'satellite',
    'Satellite',
    'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
    19,
    'Imagery © Esri',
  ),
  _Basemap('terrain', 'Terrain', 'https://tile.opentopomap.org/{z}/{x}/{y}.png', 17, '© OpenTopoMap (CC-BY-SA)'),
];

/// One phrase per state, and they are mutually exclusive.
const _labels = <String, String>{
  'LIVE': 'Live',
  'RECENT': 'Recently updated',
  'STALE': 'Location may be outdated',
  'OFFLINE': 'No recent GPS signal',
  'NOT_CONFIGURED': 'Tracking not configured',
  // The SERVICE, never the vehicle: this must never read as offline.
  'UNAVAILABLE': 'Tracking service temporarily unavailable',
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

class _TrackingMapScreenState extends State<TrackingMapScreen> with WidgetsBindingObserver {
  final MapController _map = MapController();
  final DraggableScrollableController _sheet = DraggableScrollableController();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  Timer? _poll;
  bool _followed = false;
  bool _markerCardOpen = false;
  /// Set when the basemap will not load, so the grey is explained rather than mute.
  bool _tilesFailed = false;
  final _tileClient = _TimeoutTileClient();
  /// The provider's own words for why, shown in debug builds only.
  String? _tileError;
  _Basemap _base = _basemaps.first;

  /// The route window, and the state of the one request that fetches it.
  ///
  /// History is fetched ONCE per change of preset and never on the poll: the
  /// poll carries the position alone, and the route is kept from the last
  /// answer that carried one. [_historyRequest] is a ticket — an answer for a
  /// preset the operator has since moved off is dropped, not drawn.
  String _preset = routePresets.first;
  bool _historyLoading = true;
  String? _historyError;
  int? _historyHours;
  int _historyRequest = 0;

  /// The fleet, and which of it we are watching. Null vehicle = the trip's own,
  /// which is how the screen opens.
  List<Map<String, dynamic>> _fleet = const [];
  String? _vehicleId;
  String? _vehicleName;

  /// Slow on purpose. This is somebody's data bundle and somebody's battery, and
  /// a safari vehicle does not need second-by-second truth.
  static const _interval = Duration(seconds: 25);

  /// Whole-country framing for a tracker that is linked but has never sent a
  /// fix. A map of Tanzania with no pin says "nothing yet"; a blank grey square
  /// says "broken".
  static const _tanzania = LatLng(-6.37, 34.89);
  static const _tanzaniaZoom = 5.4;

  static const _collapsed = 0.18;
  static const _medium = 0.42;
  static const _expanded = 0.88;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load(withHistory: true);
    _loadFleet();
    _startPolling();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    _tileClient.close();
    super.dispose();
  }

  /// Polling follows the app, not the clock.
  ///
  /// A screen in the background is not being looked at, and a fetch every
  /// twenty-five seconds that nobody sees is pure bundle and battery. On the
  /// way back the first thing an operator wants is the truth NOW, not in up to
  /// twenty-five seconds — hence the immediate load before the timer restarts.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused || AppLifecycleState.inactive || AppLifecycleState.hidden:
        _stopPolling();
      case AppLifecycleState.resumed:
        _startPolling();
        _load();
      case AppLifecycleState.detached:
        break;
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(_interval, (_) => _load());
  }

  void _stopPolling() {
    _poll?.cancel();
    _poll = null;
  }

  Future<void> _load({bool withHistory = false}) async {
    // Which vehicle, and which route request, this answer will belong to. An
    // answer that arrives after the operator has switched vehicle or preset is
    // for a question nobody is asking any more.
    final vehicle = _vehicleId;
    final request = withHistory ? ++_historyRequest : _historyRequest;
    final hours = withHistory ? hoursForPreset(_preset, DateTime.now()) : null;
    bool stale() => !mounted || vehicle != _vehicleId || (withHistory && request != _historyRequest);
    try {
      // Whichever vehicle is selected. The server resolves ownership either way;
      // the app never sends a tracker identifier.
      final data = vehicle == null
          ? await Api.instance.tripTracking(widget.tripId, history: withHistory, hours: hours)
          : await Api.instance.vehicleTracking(vehicle, history: withHistory, hours: hours);
      if (stale()) return;
      setState(() {
        // History arrives once. Refetching a day of fixes every twenty-five
        // seconds would cost the operator's bundle for nothing.
        _data = (withHistory || data['history'] != null) ? data : {...data, 'history': _data?['history']};
        _error = null;
        _loading = false;
        if (withHistory) {
          _historyLoading = false;
          _historyError = null;
          _historyHours = hours;
        }
      });
      _fitOnce();
    } catch (error) {
      if (stale()) return;
      setState(() {
        _error = error is ApiException ? error.message : 'Could not reach tracking.';
        _loading = false;
        if (withHistory) {
          _historyLoading = false;
          _historyError = _error;
        }
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
      _error = null;
      _historyLoading = true;
      _historyError = null;
    });
    _load(withHistory: true);
  }

  /// Fetch the route for the current preset — once, now.
  void _reloadHistory() {
    setState(() {
      _historyLoading = true;
      _historyError = null;
    });
    _load(withHistory: true);
  }

  void _choosePreset(String preset) {
    if (preset == _preset) return;
    _preset = preset;
    _reloadHistory();
  }

  /// Start over: position and route both.
  void _retry() {
    setState(() {
      _loading = true;
      _data = null;
      _error = null;
      _historyLoading = true;
      _historyError = null;
    });
    _load(withHistory: true);
  }

  String get _title => _vehicleName ?? widget.vehicleLabel ?? 'Vehicle';

  /// The plate, from the tracking answer or — before it arrives — the fleet
  /// list. Blank is null: an empty chip is worse than no chip.
  String? get _registration {
    final own = (_data?['registration'] as String?)?.trim();
    if (own != null && own.isNotEmpty) return own;
    for (final v in _fleet) {
      if (v['id'] == _vehicleId) {
        final plate = (v['registration'] as String?)?.trim();
        return (plate == null || plate.isEmpty) ? null : plate;
      }
    }
    return null;
  }

  Map<String, dynamic>? get _position => _data?['position'] as Map<String, dynamic>?;
  String get _state => (_data?['state'] as String?) ?? 'UNAVAILABLE';

  /// Nothing has answered yet. Not a state the server has — it is ours, and it
  /// must not be dressed as one of theirs (an unanswered request is not the
  /// service being unavailable, let alone the vehicle being offline).
  bool get _checking => _loading && _data == null;

  /// Linked to a tracker that has never sent a fix: a state of its own, and
  /// the one case where an empty map is the truthful picture.
  bool get _noFixYet =>
      _data != null &&
      _data!['linked'] == true &&
      _position == null &&
      _state != 'NOT_CONFIGURED' &&
      _state != 'UNAVAILABLE';

  LatLng? get _here {
    final p = _position;
    final lat = (p?['latitude'] as num?)?.toDouble();
    final lng = (p?['longitude'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;
    return LatLng(lat, lng);
  }

  Map<String, dynamic>? get _history => _data?['history'] as Map<String, dynamic>?;
  List<GeoPoint> get _trackPoints => trackPoints(_history?['points']);
  List<LatLng> get _track => [for (final p in _trackPoints) LatLng(p.lat, p.lng)];
  bool get _historyTruncated => _history?['truncated'] == true;

  /// A route section makes sense once there is a tracker to have recorded one.
  /// While the service is down and nothing was drawn, "no route in this range"
  /// would be a claim we cannot make.
  bool get _showsRoute =>
      _data != null && _state != 'NOT_CONFIGURED' && (_state != 'UNAVAILABLE' || _trackPoints.isNotEmpty);

  DateTime? get _fixAt => DateTime.tryParse(_position?['recordedAt'] as String? ?? '');
  DateTime? get _checkedAt => DateTime.tryParse(_data?['checkedAt'] as String? ?? '');
  int? get _speed => (_position?['speedKph'] as num?)?.round();

  String get _stateText => _checking ? 'Checking…' : (_labels[_state] ?? _state);
  IconData get _stateIcon => _checking ? Icons.gps_not_fixed_rounded : (_icons[_state] ?? Icons.gps_not_fixed_rounded);

  /// One calm sentence for the states that need explaining. Live needs none,
  /// and a tracker with no fix yet has already been explained.
  String? get _explanation {
    if (_checking || _noFixYet) return null;
    return switch (_state) {
      'STALE' => 'The vehicle may have moved since this fix.',
      'OFFLINE' => 'This tracker has not reported recently.',
      'NOT_CONFIGURED' => 'Connect a phone or GPS tracker to see this vehicle on the map.',
      'UNAVAILABLE' => "We couldn't reach the tracking service. This says nothing about where the vehicle is.",
      _ => null,
    };
  }

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

  Color _tone(BuildContext c) {
    if (_checking) return Tone.muted(c);
    return switch (_state) {
      'LIVE' || 'RECENT' => Tone.success(c),
      'STALE' || 'UNAVAILABLE' => Tone.warning(c),
      _ => Tone.muted(c),
    };
  }

  void _choose(_Basemap b) {
    setState(() {
      _base = b;
      // A different provider may well be reachable when this one is not.
      _tilesFailed = false;
    });
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
    _sheet.animateTo(size > _collapsed + 0.05 ? _collapsed : _medium, duration: Motion.enter, curve: Motion.curve);
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
                  // Screen-anchored, so neither zoom nor rotation touches them.
                  Positioned(
                    left: 14,
                    right: 14,
                    top: 68,
                    child: Column(
                      children: [
                        if (_tilesFailed) _tileNotice(context),
                        if (_markerCardOpen && _here != null) ...[
                          if (_tilesFailed) const SizedBox(height: 8),
                          _vehicleCard(context, _tone(context)),
                        ],
                      ],
                    ),
                  ),

                  _bottomSheet(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Says the imagery is missing — never that the vehicle is.
  Widget _tileNotice(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.94),
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 10)],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.layers_clear_outlined, size: 16, color: Tone.muted(context)),
              const SizedBox(width: 7),
              Flexible(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      // Naming the basemap matters: the three come from three
                      // different hosts, so one being unreachable says nothing
                      // about the others, and switching is the fix a person can
                      // actually apply.
                      '${_base.label} imagery could not load — try another basemap above. '
                      'The vehicle position is still current.',
                      style: TextStyle(fontSize: 12, color: Tone.muted(context)),
                    ),
                    // The provider's own reason, in debug builds only: a grey map
                    // on a handset cannot be diagnosed from a desk, and this is
                    // faster than attaching to the device's log stream.
                    if (kDebugMode && _tileError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          _tileError!,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 10.5, color: Tone.danger(context)),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );

  // ---------------------------------------------------------------- header --

  /// The chrome, and only the chrome: a way back, what this screen is, and the
  /// switcher when there is a fleet to switch between. The vehicle itself
  /// lives in the sheet, where its state sits beside its clocks.
  Widget _header(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(4, 4, 8, 6),
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
            const SizedBox(width: 2),
            Expanded(
              child: Text(
                'Live tracking',
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  height: 1.15,
                  color: Tone.ink(context),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                  Text(
                    'Which vehicle?',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Tone.ink(sheetContext)),
                  ),
                  const Spacer(),
                  Text('${_fleet.length} vehicles', style: TextStyle(fontSize: 13.5, color: Tone.muted(sheetContext))),
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
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: Tone.ink(listContext),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  // State first, then how old — never a place name
                                  // first, which reads as reassurance.
                                  [
                                    (v['stateLabel'] as String?) ?? '',
                                    if (v['recordedAt'] != null) relativeTime(v['recordedAt']),
                                  ].where((x) => x.isNotEmpty).join(' · '),
                                  style: TextStyle(fontSize: 13.5, color: tone),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          if (selected) Icon(Icons.check_rounded, size: 20, color: Tone.accent(listContext)),
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
    if (_checking) {
      return Center(child: CircularProgressIndicator(color: Tone.accent(context), strokeWidth: 2.5));
    }
    final here = _here;
    // A linked tracker with no fix yet gets the country, not a placeholder:
    // the map is the truthful picture, and the sheet says why it is empty.
    if (here == null && !_noFixYet) return _noPosition(context);
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
                  ? (_error ??
                        "We couldn't refresh the vehicle location. This says nothing about where the vehicle is.")
                  : 'This tracker has not reported recently.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 15, height: 1.4, color: Tone.muted(context)),
            ),
            const SizedBox(height: 18),
            SizedBox(
              height: 46,
              child: FilledButton.icon(
                onPressed: _retry,
                icon: const Icon(Icons.refresh_rounded, size: 19),
                label: const Text('Try again', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _mapView(BuildContext context, LatLng? here, List<LatLng> track, Color tone) {
    final end = track.length > 1 ? track.last : null;
    // The end of the recording — unless the vehicle is already standing on it.
    final showEnd = end != null && (here == null || !_same(end, here));
    return FlutterMap(
      mapController: _map,
      options: MapOptions(
        initialCenter: here ?? _tanzania,
        initialZoom: here == null ? _tanzaniaZoom : 14,
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
          /*
           * A basemap that fails to load is a flat grey rectangle and nothing
           * else — indistinguishable from a map of empty ground, which is a real
           * thing to see in the Serengeti. Say which it is: the notice tells the
           * operator the imagery is missing rather than the vehicle, and the log
           * line names the reason so it can be diagnosed without the handset.
           */
          tileProvider: NetworkTileProvider(httpClient: _tileClient),
          errorTileCallback: (tile, error, _) {
            debugPrint('[tracking] ${_base.key} tile ${tile.coordinates} failed: $error');
            if (mounted && !_tilesFailed) {
              setState(() {
                _tilesFailed = true;
                _tileError = error.toString();
              });
            }
          },
          /*
           * One tile arriving is proof the basemap works, and it clears the
           * notice. Without this the warning could only be dismissed by changing
           * basemap — so a network that recovered still showed an app insisting
           * the imagery was missing while it was plainly drawing.
           */
          tileBuilder: (context, tileWidget, tile) {
            if (_tilesFailed && mounted) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && _tilesFailed) setState(() => _tilesFailed = false);
              });
            }
            return tileWidget;
          },
        ),
        if (track.length > 1)
          PolylineLayer(
            polylines: [
              // Drawn from the fixes verbatim. A prettier curve would be a road
              // the vehicle never took.
              Polyline(points: track, strokeWidth: 4, color: tone.withValues(alpha: 0.55)),
            ],
          ),
        // Both ends of the drive, so the line has a direction the eye can read:
        // a hollow ring where the recording began, a solid dot where it stops.
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
              if (showEnd)
                Marker(
                  point: end,
                  width: 16,
                  height: 16,
                  child: Container(
                    decoration: BoxDecoration(
                      color: tone,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6)],
                    ),
                  ),
                ),
            ],
          ),
        if (here != null)
          MarkerLayer(
            markers: [
              Marker(
                point: here,
                width: 56,
                height: 56,
                /*
                 * The ICON only. The card that opens on tap is no longer here.
                 *
                 * A marker's child is drawn inside the map, and the map is
                 * transformed as a whole while a pinch is in progress — so a card
                 * of text grew and shrank with the gesture, which reads as the
                 * interface stretching rather than the map zooming. rotate: true
                 * fixed the same problem for rotation but cannot fix scale,
                 * because scale is applied to the layer, not to the marker.
                 *
                 * Geography belongs on the map; a panel of text belongs on the
                 * screen. The card now lives in the screen's own Stack, anchored
                 * beneath the controls, where no map transform reaches it.
                 */
                rotate: true,
                child: GestureDetector(
                  onTap: () => setState(() => _markerCardOpen = !_markerCardOpen),
                  child: Center(
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
                ),
              ),
            ],
          ),
      ],
    );
  }

  /// Two fixes at the same spot, to within a tenth of a metre.
  static bool _same(LatLng a, LatLng b) =>
      (a.latitude - b.latitude).abs() < 1e-6 && (a.longitude - b.longitude).abs() < 1e-6;

  // -------------------------------------------------------------- controls --

  Widget _controls(BuildContext context) {
    /*
     * spaceBetween, NOT Flexible + Spacer.
     *
     * Flexible defaults to flex 1 and so does Spacer, so the two of them split
     * the free width evenly: the picker was allotted about 175pt when its three
     * segments need about 218, and Flutter drew a "RIGHT OVERFLOWED BY 58
     * PIXELS" stripe across the map. In release the stripe is hidden and the
     * label is simply clipped, so it was a real defect, not a debug artefact.
     *
     * Now the picker takes its natural width and spaceBetween pushes the zoom
     * column to the far edge. Flexible stays, with the whole remaining width to
     * draw on, so a narrower phone shrinks the picker instead of overflowing.
     */
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(child: _basemapPicker(context)),
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
  /// The tapped vehicle, drawn on the SCREEN rather than on the map.
  ///
  /// It used to be a marker's child, which put it inside the map's transform:
  /// a pinch scaled the text along with the ground. Here nothing the map does
  /// reaches it, and it can be dismissed by tapping the map or the marker again.
  Widget _vehicleCard(BuildContext context, Color tone) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
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
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 26, offset: const Offset(0, -4)),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          /*
           * The list scrolls; it just did not look like it.
           *
           * At the medium stop the content is clipped mid-element by a hard
           * edge, which reads as a cropped panel rather than a scrollable one —
           * reported as "looks cropped, need scroll" when scrolling already
           * worked. A short fade to the sheet's own surface colour is the whole
           * fix: a fading edge says there is more below, a hard edge says the
           * panel ends here. IgnorePointer so it never eats a drag.
           */
          child: Stack(
            children: [
              ListView(
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
                  _vehicleRow(context, tone),
                  const SizedBox(height: 16),
                  _statusBlock(context, tone),
                  if (_position != null) ...[
                    const SizedBox(height: 18),
                    _metrics(context),
                    const SizedBox(height: 14),
                    _actions(context),
                  ],
                  if (_showsRoute) ...[
                    const SizedBox(height: 22),
                    _routeBlock(context, tone),
                  ],
                  if (widget.tripTitle != null && _vehicleId == null) ...[
                    const SizedBox(height: 22),
                    _tripBlock(context),
                  ],
                  const SizedBox(height: 16),
                  _trackingDetails(context),
                ],
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 26,
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Tone.surface(context).withValues(alpha: 0), Tone.surface(context)],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// WHO this is, and WHAT state — the row the eye lands on when the sheet is
  /// at its lowest, and the one thing on it that is always readable.
  ///
  /// The whole row is the switcher's target: an operator with a fleet taps the
  /// vehicle to change vehicle, which is where a finger goes anyway. With one
  /// vehicle the tap does nothing but acknowledge itself, and the chevron that
  /// would promise a switch is not drawn — this app has no vehicle-detail
  /// screen, and a chevron that goes nowhere is worse than none.
  Widget _vehicleRow(BuildContext context, Color tone) {
    final switchable = _fleet.length > 1;
    final plate = _registration;
    return Semantics(
      button: switchable,
      label: switchable ? 'Switch vehicle' : null,
      child: PressableRow(
        onTap: () {
          if (switchable) _openFleetSheet(context);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(color: Tone.wash(context, tone), borderRadius: BorderRadius.circular(13)),
                child: Icon(Icons.directions_car_rounded, size: 24, color: tone),
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
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        height: 1.15,
                        letterSpacing: -0.2,
                        color: Tone.ink(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (plate != null) ...[
                      const SizedBox(height: 4),
                      // A plate is read letter by letter, so it is set like one:
                      // fixed-pitch where the platform has it, spaced where not.
                      Text(
                        plate,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                          fontFamily: 'Menlo',
                          fontFamilyFallback: const ['Roboto Mono', 'monospace'],
                          fontFeatures: const [FontFeature.tabularFigures()],
                          color: Tone.muted(context),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Capped so a long state ("Location may be outdated") wraps to
              // two lines instead of squeezing the name out of the row.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 148),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(_stateIcon, size: 16, color: tone),
                    const SizedBox(width: 5),
                    Flexible(
                      child: Text(
                        _stateText,
                        textAlign: TextAlign.end,
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.2, color: tone),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              if (switchable) ...[
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 24, color: Tone.muted(context)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// THE TWO CLOCKS — and, when the state needs one, a sentence.
  ///
  /// The age of the fix is the big number; the age of our knowledge is the
  /// small line under it. Conflating them is how a screen claims to be live
  /// while nothing has been fetched for ten minutes.
  Widget _statusBlock(BuildContext context, Color tone) {
    final small = TextStyle(fontSize: 13.5, color: Tone.muted(context));
    final sentence = TextStyle(fontSize: 14, height: 1.35, color: Tone.muted(context));
    final explanation = _explanation;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_checking)
          Text('Checking the tracker…', style: TextStyle(fontSize: 15, color: Tone.muted(context)))
        else if (_noFixYet) ...[
          Text('No GPS fix yet', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: Tone.ink(context))),
          const SizedBox(height: 4),
          Text('The tracker is linked but has not sent a position yet.', style: sentence),
        ] else if (_fixAt != null) ...[
          Text('Last GPS update', style: small),
          const SizedBox(height: 2),
          Text(
            relativeTime(_fixAt),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: Tone.ink(context)),
          ),
        ],
        if (explanation != null) ...[
          const SizedBox(height: 6),
          Text(explanation, style: sentence),
        ],
        if (_checkedAt != null) ...[
          const SizedBox(height: 6),
          // THE SECOND CLOCK.
          Text('Checked ${relativeTime(_checkedAt)}', style: small),
        ],
      ],
    );
  }

  Widget _metrics(BuildContext context) {
    Widget tile(String value, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
        decoration: BoxDecoration(color: Tone.panel(context), borderRadius: BorderRadius.circular(14)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(fontSize: 21, fontWeight: FontWeight.w700, color: Tone.ink(context)),
            ),
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
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: FilledButton.icon(
        onPressed: _recentre,
        icon: const Icon(Icons.my_location_rounded, size: 19),
        label: const Text('Recentre', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
      ),
    );
  }

  // ----------------------------------------------------------------- route --

  /// The route, and how much of it there is.
  ///
  /// Three windows, each fetched once. The count and the distance are shown
  /// because they are the honesty check on the line: 2,000 points and 400 km
  /// under a "cut off" notice is a different fact from 40 points and 3 km.
  Widget _routeBlock(BuildContext context, Color tone) {
    final points = _trackPoints;
    final hasRoute = points.length > 1;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'ROUTE HISTORY',
              style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: Tone.muted(context)),
            ),
            const Spacer(),
            if (hasRoute && !_historyLoading && _historyError == null)
              Text(
                '${points.length} points · ${formatKm(routeDistanceKm(points))}',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: Tone.ink(context)),
              ),
          ],
        ),
        const SizedBox(height: 10),
        _presetRow(context),
        const SizedBox(height: 10),
        _routeStatus(context, points, hasRoute),
      ],
    );
  }

  /// Today · 6h · 24h. A segmented control, 48pt tall so a thumb finds it.
  Widget _presetRow(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: Tone.panel(context), borderRadius: BorderRadius.circular(13)),
      child: Row(
        children: [
          for (final preset in routePresets)
            Expanded(
              child: Semantics(
                button: true,
                selected: preset == _preset,
                child: GestureDetector(
                  onTap: () => _choosePreset(preset),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedContainer(
                    duration: Motion.quick,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: preset == _preset ? Tone.accent(context) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      presetLabel(preset),
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: preset == _preset ? Colors.white : Tone.muted(context),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// One line under the presets, and it always says something: loading, failed
  /// (with the way to try again), empty, cut off — or nothing at all when the
  /// route is simply there, which the summary above already says.
  Widget _routeStatus(BuildContext context, List<GeoPoint> points, bool hasRoute) {
    final sentence = TextStyle(fontSize: 14, height: 1.35, color: Tone.muted(context));
    if (_historyLoading) {
      return Row(
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: Tone.accent(context)),
          ),
          const SizedBox(width: 10),
          Text('Loading route…', style: sentence),
        ],
      );
    }
    if (_historyError != null) {
      return Row(
        children: [
          Icon(Icons.error_outline_rounded, size: 18, color: Tone.warning(context)),
          const SizedBox(width: 8),
          Expanded(
            child: Text("Couldn't load the route.", style: TextStyle(fontSize: 14, color: Tone.ink(context))),
          ),
          SizedBox(
            height: 40,
            child: TextButton(
              onPressed: _reloadHistory,
              child: const Text('Retry', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      );
    }
    if (!hasRoute) return Text('No route recorded in this range', style: sentence);
    if (_historyTruncated) {
      // N is what actually came back, never the server's ceiling: the number
      // on the screen must be the number on the map.
      return Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: Tone.wash(context, Tone.warning(context)),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.content_cut_rounded, size: 17, color: Tone.warning(context)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Showing the most recent ${points.length} recorded points — the route is cut off',
                style: TextStyle(fontSize: 13.5, height: 1.35, color: Tone.ink(context)),
              ),
            ),
          ],
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _tripBlock(BuildContext context) {
    final parts = [
      if (widget.guests != null && widget.guests! > 0) '${widget.guests} guests',
      if (widget.tripStatus != null) _tripStatusLabel(widget.tripStatus!),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CURRENT TRIP',
          style: TextStyle(fontSize: 12, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: Tone.muted(context)),
        ),
        const SizedBox(height: 8),
        PressableRow(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
            decoration: BoxDecoration(color: Tone.panel(context), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tripTitle!,
                        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: Tone.ink(context)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
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
        title: Text(
          'Tracking details',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Tone.ink(context)),
        ),
        iconColor: Tone.muted(context),
        collapsedIconColor: Tone.muted(context),
        children: [
          if (here != null)
            _detail(
              context,
              'Coordinates',
              '${here.latitude.toStringAsFixed(5)}, ${here.longitude.toStringAsFixed(5)}',
            ),
          if (_fixAt != null) _detail(context, 'GPS fix time', _fixAt!.toLocal().toString().substring(0, 16)),
          if (_checkedAt != null) _detail(context, 'Last checked', _checkedAt!.toLocal().toString().substring(0, 16)),
          if (track.length > 1) ...[
            _detail(context, 'Route points', '${track.length} in ${hoursPhrase(_historyHours ?? 24)}'),
            _detail(context, 'Route distance', formatKm(routeDistanceKm(_trackPoints))),
          ],
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
