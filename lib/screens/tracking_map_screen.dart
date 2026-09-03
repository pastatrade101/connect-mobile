import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/api.dart';
import '../core/motion.dart';
import '../core/theme.dart';
import '../widgets/primitives.dart';

/// Where the vehicle is, on a map.
///
/// The rule this screen exists to obey: a position is NEVER shown without its
/// age beside it. A four-hour-old fix drawn as a confident pin is the one
/// failure that makes tracking worse than having none — it invites somebody to
/// stop worrying about a vehicle they should be phoning about.
///
/// So the marker's colour and the sentence under it come from the SERVER's
/// state, never from a guess made here, and the track is drawn from the fixes
/// verbatim — no smoothing, no interpolation, no line the vehicle never drove.
class TrackingMapScreen extends StatefulWidget {
  const TrackingMapScreen({super.key, required this.tripId, required this.vehicleLabel});

  final String tripId;
  final String? vehicleLabel;

  @override
  State<TrackingMapScreen> createState() => _TrackingMapScreenState();
}

/// A basemap the operator can choose between.
///
/// Satellite is not decoration here: a Land Cruiser in the Serengeti is usually
/// on a track no street map has drawn, so on Standard it floats in empty beige.
/// Imagery is the only view where a riverbed and a road look different.
///
/// None of these needs an API key. Each carries the attribution its licence
/// demands, and its own maxZoom — OpenTopoMap stops at 17 and serves grey above
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

class _TrackingMapScreenState extends State<TrackingMapScreen> {
  final MapController _map = MapController();

  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _data;
  Timer? _poll;
  bool _followed = false;
  _Basemap _base = _basemaps.first;

  /// Slow on purpose. This is somebody's data bundle and somebody's battery, and
  /// a safari vehicle does not need second-by-second truth.
  static const _interval = Duration(seconds: 25);

  @override
  void initState() {
    super.initState();
    _load(withHistory: true);
    _poll = Timer.periodic(_interval, (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool withHistory = false}) async {
    try {
      final data = await Api.instance.tripTracking(widget.tripId, history: withHistory);
      if (!mounted) return;
      setState(() {
        // History is only in the first response; keep it across polls rather than
        // refetching a day of fixes every twenty-five seconds.
        if (withHistory || data['history'] != null) {
          _data = data;
        } else {
          _data = {...data, 'history': _data?['history']};
        }
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

  Map<String, dynamic>? get _position => _data?['position'] as Map<String, dynamic>?;

  LatLng? get _here {
    final p = _position;
    if (p == null) return null;
    final lat = (p['latitude'] as num?)?.toDouble();
    final lng = (p['longitude'] as num?)?.toDouble();
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

  /// Centre once, on the first fix. After that the operator owns the camera —
  /// yanking the map back mid-pinch is how a map stops being usable.
  void _fitOnce() {
    if (_followed) return;
    final here = _here;
    if (here == null) return;
    _followed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _map.move(here, 13);
    });
  }

  void _choose(_Basemap b) {
    setState(() => _base = b);
    // A view with a lower ceiling must not leave the operator staring at grey.
    if (_map.camera.zoom > b.maxZoom) _map.move(_map.camera.center, b.maxZoom);
  }

  void _zoom(double by) {
    final next = (_map.camera.zoom + by).clamp(3.0, _base.maxZoom);
    _map.move(_map.camera.center, next);
  }

  /// Back to the vehicle, for when panning has lost it.
  void _recentre() {
    final here = _here;
    if (here != null) _map.move(here, _map.camera.zoom < 13 ? 13 : _map.camera.zoom);
  }

  Color _tone(BuildContext context) {
    switch (_data?['state']) {
      case 'LIVE':
      case 'RECENT':
        return Tone.success(context);
      case 'STALE':
      case 'UNAVAILABLE':
        return Tone.warning(context);
      default:
        return Tone.muted(context);
    }
  }

  /// One sentence, and it always begins with WHEN, never with where.
  ///
  /// An operator reads left to right and stops at the first reassuring noun, so
  /// "Near Mto wa Mbu, four hours ago" is read as "near Mto wa Mbu".
  String _sentence() {
    final state = _data?['state'] as String?;
    final p = _position;
    if (state == 'NOT_CONFIGURED') return 'This vehicle has no tracker fitted.';
    if (state == 'UNAVAILABLE') {
      return 'We could not reach the tracking service. This says nothing about where the vehicle is.';
    }
    if (state == 'OFFLINE' || p == null) return 'This tracker is not reporting.';

    final when = relativeTime(DateTime.tryParse(p['recordedAt'] as String? ?? ''));
    final speed = (p['speedKph'] as num?)?.round() ?? 0;
    if (state == 'LIVE') {
      return speed > 3 ? 'Moving now, $speed km/h.' : 'Stopped, reporting normally.';
    }
    if (state == 'RECENT') return 'Last reported $when.';
    return 'Last reported $when — treat this position as old.';
  }

  @override
  Widget build(BuildContext context) {
    final here = _here;
    final track = _track;
    final tone = _tone(context);

    return DecoratedBox(
      decoration: appBackground(context),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              MobileHeader(
                title: widget.vehicleLabel ?? 'Vehicle',
                subtitle: _loading ? 'Checking…' : (_data?['label'] as String? ?? ''),
                subtitleTone: _loading ? null : tone,
                onBack: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: _loading
                    ? Center(child: CircularProgressIndicator(color: Tone.accent(context), strokeWidth: 2))
                    : here == null
                    ? _noPosition(context)
                    : _map3(context, here, track, tone),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// No position is a real answer, not an empty screen. A grey map with no pin
  /// looks like a bug; this says which of the several different nothings it is.
  Widget _noPosition(BuildContext context) => TeachingEmptyState(
    icon: _data?['state'] == 'UNAVAILABLE' ? Icons.cloud_off_rounded : Icons.location_off_outlined,
    title: _data?['label'] as String? ?? 'No position',
    body: _error ?? _sentence(),
    actionLabel: 'Try again',
    onAction: () {
      setState(() => _loading = true);
      _load(withHistory: true);
    },
  );

  Widget _map3(BuildContext context, LatLng here, List<LatLng> track, Color tone) {
    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(initialCenter: here, initialZoom: 13, maxZoom: _base.maxZoom),
          children: [
            TileLayer(
              key: ValueKey(_base.key),
              urlTemplate: _base.url,
              // OpenStreetMap asks that every client identify itself.
              userAgentPackageName: 'tz.co.makutano.makutanoConnect',
              maxZoom: _base.maxZoom,
            ),
            if (track.length > 1)
              PolylineLayer(
                polylines: [
                  // Drawn from the fixes verbatim. No smoothing: a prettier curve
                  // would be a road the vehicle never took.
                  Polyline(points: track, strokeWidth: 3.5, color: tone.withValues(alpha: 0.7)),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: here,
                  width: 34,
                  height: 34,
                  child: Container(
                    decoration: BoxDecoration(
                      color: tone,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 6)],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        // Basemap picker and controls, clear of the notch and of the sheet.
        Positioned(left: 12, right: 12, top: 12, child: _controls(context)),

        // The readout is anchored to the PHYSICAL bottom of the phone rather than
        // floating above it: a card with a gap under it fights the home indicator
        // for the same strip of screen, and on a tall phone that strip is exactly
        // where the thumb rests.
        Positioned(left: 0, right: 0, bottom: 0, child: _readout(context, here, track, tone)),
      ],
    );
  }


  /// The basemap picker, and the two controls a thumb actually reaches for.
  ///
  /// Kept at the TOP because the bottom of the screen belongs to the readout and
  /// to the home indicator, and a control stacked over either is a control that
  /// gets pressed by accident.
  Widget _controls(BuildContext context) {
    final surface = Tone.surface(context).withValues(alpha: 0.94);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: Tone.line(context)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8)],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final b in _basemaps)
                GestureDetector(
                  onTap: () => _choose(b),
                  child: AnimatedContainer(
                    duration: Motion.quick,
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                    decoration: BoxDecoration(
                      color: _base.key == b.key ? Tone.accent(context) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      b.label,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: _base.key == b.key ? Colors.white : Tone.muted(context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Spacer(),
        Column(
          children: [
            _roundButton(context, Icons.add_rounded, () => _zoom(1)),
            const SizedBox(height: 7),
            _roundButton(context, Icons.remove_rounded, () => _zoom(-1)),
            const SizedBox(height: 7),
            // Only offered when there is something to centre ON.
            if (_here != null) _roundButton(context, Icons.my_location_rounded, _recentre),
          ],
        ),
      ],
    );
  }

  Widget _roundButton(BuildContext context, IconData icon, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: Tone.surface(context).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Tone.line(context)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.10), blurRadius: 8)],
      ),
      child: Icon(icon, size: 19, color: Tone.ink(context)),
    ),
  );

  Widget _readout(BuildContext context, LatLng here, List<LatLng> track, Color tone) {
    final checked = DateTime.tryParse(_data?['checkedAt'] as String? ?? '');
    // Whatever the phone reserves for the home indicator, plus a little, so the
    // last line of text is never under the swipe strip.
    final inset = MediaQuery.of(context).padding.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 14, 16, 14 + inset),
      decoration: BoxDecoration(
        color: Tone.surface(context),
        // Rounded at the top only. The bottom corners are the phone's corners.
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        border: Border(top: BorderSide(color: Tone.line(context))),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 18, offset: const Offset(0, -4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 38,
              height: 4,
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: Tone.muted(context).withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              Container(width: 8, height: 8, decoration: BoxDecoration(color: tone, shape: BoxShape.circle)),
              const SizedBox(width: 7),
              Text(
                _data?['label'] as String? ?? '',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: tone, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              // The SECOND clock. The age of the fix is in the sentence below;
              // this is the age of our knowledge, and they are different numbers.
              if (checked != null)
                Text(
                  'checked ${relativeTime(checked)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Tone.muted(context)),
                ),
            ],
          ),
          const SizedBox(height: 5),
          Text(_sentence(), style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                '${here.latitude.toStringAsFixed(5)}, ${here.longitude.toStringAsFixed(5)}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Tone.muted(context),
                  fontFeatures: const [],
                ),
              ),
              const Spacer(),
              if (track.length > 1)
                Text(
                  '${track.length} points, last 24 h',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Tone.muted(context)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          // Required by every one of these tile licences, so it is part of the
          // card rather than something a layout change can quietly drop.
          Row(
            children: [
              Expanded(
                child: Text(
                  _base.attribution,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Tone.muted(context).withValues(alpha: 0.75),
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
