/// Pure geometry and time helpers for the tracking screen.
///
/// No Flutter and no map library in here, on purpose: a distance is a number,
/// and a number can be checked in a plain Dart test without pumping a widget.
/// The screen maps these to its own types at the edge.
library;

import 'dart:math' as math;

/// A fix, as latitude and longitude in degrees.
typedef GeoPoint = ({double lat, double lng});

/// Mean Earth radius in kilometres (IUGG 1980).
const double earthRadiusKm = 6371.0088;

double _rad(double degrees) => degrees * math.pi / 180;

/// The great-circle distance between two points, in kilometres.
///
/// Haversine: it stays accurate for the short hops between consecutive fixes,
/// where the naive formula loses its digits.
double haversineKm(GeoPoint a, GeoPoint b) {
  final phi1 = _rad(a.lat);
  final phi2 = _rad(b.lat);
  final sinDPhi = math.sin(_rad(b.lat - a.lat) / 2);
  final sinDLambda = math.sin(_rad(b.lng - a.lng) / 2);
  final h = sinDPhi * sinDPhi + math.cos(phi1) * math.cos(phi2) * sinDLambda * sinDLambda;
  return 2 * earthRadiusKm * math.asin(math.sqrt(h.clamp(0.0, 1.0)));
}

/// Distance along [points] IN THE ORDER GIVEN, in kilometres.
///
/// Fewer than two points is not a route and measures 0. The order IS the route:
/// the same fixes shuffled measure a different — usually longer — line, which
/// is why the caller hands them over exactly as recorded.
double routeDistanceKm(List<GeoPoint> points) {
  var total = 0.0;
  for (var i = 1; i < points.length; i++) {
    total += haversineKm(points[i - 1], points[i]);
  }
  return total;
}

/// The wire shape `[[lat, lng, ms], ...]`, with anything malformed dropped.
List<GeoPoint> trackPoints(Object? raw) {
  if (raw is! List) return const [];
  return [
    for (final t in raw)
      if (t is List && t.length >= 2 && t[0] is num && t[1] is num)
        (lat: (t[0] as num).toDouble(), lng: (t[1] as num).toDouble()),
  ];
}

/// The route windows the sheet offers, in display order.
const routePresets = <String>['today', '6h', '24h'];

String presetLabel(String preset) => switch (preset) {
  'today' => 'Today',
  '6h' => '6h',
  '24h' => '24h',
  _ => preset,
};

/// How many hours of history a preset asks the server for, always 1..24.
///
/// `today` is the hours since LOCAL midnight, rounded UP so the first fix after
/// midnight is inside the window — never less than 1, which is the server's
/// minimum, and never more than 24, which is its ceiling (and the only value a
/// 25-hour clock-change day could otherwise produce).
int hoursForPreset(String preset, DateTime now) {
  switch (preset) {
    case '6h':
      return 6;
    case '24h':
      return 24;
    case 'today':
      final local = now.toLocal();
      final midnight = DateTime(local.year, local.month, local.day);
      final hours = (local.difference(midnight).inSeconds / 3600).ceil();
      return hours.clamp(1, 24);
    default:
      return 24;
  }
}

/// "the last hour" / "the last 6 hours" — for a sentence about a window.
String hoursPhrase(int hours) => hours == 1 ? 'the last hour' : 'the last $hours hours';

/// Kilometres with one decimal, the way a dashboard reads them: "48.3 km".
String formatKm(double km) => '${km.toStringAsFixed(1)} km';
