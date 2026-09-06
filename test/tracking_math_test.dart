// The numbers under the route sheet, checked as numbers.
//
// A distance drawn on a map is only as honest as the arithmetic behind it, and
// arithmetic is the one thing a widget test cannot see. So the haversine, the
// cumulative walk along the fixes and the preset-to-hours rule are plain Dart
// and are checked here against values worked out independently (R = 6371.0088).
import 'package:flutter_test/flutter_test.dart';
import 'package:makutano_connect/core/tracking_math.dart';

void main() {
  group('haversineKm', () {
    test('one degree of longitude on the equator is 111.195 km', () {
      expect(haversineKm((lat: 0, lng: 0), (lat: 0, lng: 1)), closeTo(111.195, 0.001));
    });

    test('one degree of latitude is the same distance anywhere', () {
      expect(haversineKm((lat: 0, lng: 0), (lat: 1, lng: 0)), closeTo(111.195, 0.001));
      expect(haversineKm((lat: -6, lng: 35), (lat: -5, lng: 35)), closeTo(111.195, 0.001));
    });

    test('Dar es Salaam to Arusha is about 471 km as the crow flies', () {
      final dar = (lat: -6.7924, lng: 39.2083);
      final arusha = (lat: -3.3869, lng: 36.6830);
      expect(haversineKm(dar, arusha), closeTo(470.74, 0.01));
      // Symmetric: the road back is the same length.
      expect(haversineKm(arusha, dar), closeTo(470.74, 0.01));
    });

    test('a point is no distance from itself', () {
      expect(haversineKm((lat: -2.3333, lng: 34.8333), (lat: -2.3333, lng: 34.8333)), 0);
    });

    test('a short hop between two fixes keeps its digits', () {
      // Two Serengeti fixes ~1 km apart — the size of gap the route is made of.
      expect(haversineKm((lat: -2.3333, lng: 34.8333), (lat: -2.34, lng: 34.84)), closeTo(1.0532, 0.0005));
    });
  });

  group('routeDistanceKm', () {
    test('empty and single-point lists measure 0', () {
      expect(routeDistanceKm(const []), 0);
      expect(routeDistanceKm(const [(lat: -6.8, lng: 39.2)]), 0);
    });

    test('adds up the hops along an ordered list', () {
      final points = <GeoPoint>[(lat: 0, lng: 0), (lat: 0, lng: 1), (lat: 0, lng: 2)];
      expect(routeDistanceKm(points), closeTo(222.390, 0.001));
    });

    test('the order is the route — the same points shuffled measure a different line', () {
      final inOrder = <GeoPoint>[(lat: 0, lng: 0), (lat: 0, lng: 1), (lat: 0, lng: 2)];
      final outOfOrder = <GeoPoint>[(lat: 0, lng: 0), (lat: 0, lng: 2), (lat: 0, lng: 1)];
      expect(routeDistanceKm(inOrder), closeTo(222.390, 0.001));
      expect(routeDistanceKm(outOfOrder), closeTo(333.585, 0.001));
      expect(routeDistanceKm(outOfOrder), greaterThan(routeDistanceKm(inOrder)));
    });

    test('a vehicle that sat still all day drove nowhere', () {
      final parked = List<GeoPoint>.filled(50, (lat: -3.3869, lng: 36.6830));
      expect(routeDistanceKm(parked), 0);
    });
  });

  group('trackPoints', () {
    test('reads the wire shape and drops anything malformed', () {
      final points = trackPoints([
        [-6.8, 39.2, 1700000000000],
        [-6.81, 39.21, 1700000060000],
        'junk',
        [null, 39.0],
        [-6.82],
      ]);
      expect(points, [(lat: -6.8, lng: 39.2), (lat: -6.81, lng: 39.21)]);
    });

    test('anything that is not a list is no route', () {
      expect(trackPoints(null), isEmpty);
      expect(trackPoints({'points': []}), isEmpty);
    });
  });

  group('hoursForPreset', () {
    test('the fixed windows are what they say', () {
      final now = DateTime(2026, 9, 6, 15, 30);
      expect(hoursForPreset('6h', now), 6);
      expect(hoursForPreset('24h', now), 24);
    });

    test('today is the hours since local midnight, rounded up', () {
      expect(hoursForPreset('today', DateTime(2026, 9, 6, 15, 30)), 16);
      expect(hoursForPreset('today', DateTime(2026, 9, 6, 1, 1)), 2);
      expect(hoursForPreset('today', DateTime(2026, 9, 6, 23, 59)), 24);
    });

    test('today never asks for less than one hour', () {
      expect(hoursForPreset('today', DateTime(2026, 9, 6, 0, 0)), 1);
      expect(hoursForPreset('today', DateTime(2026, 9, 6, 0, 10)), 1);
      // Exactly on the hour is not rounded past it.
      expect(hoursForPreset('today', DateTime(2026, 9, 6, 1, 0)), 1);
    });

    test('today never asks for more than a day', () {
      expect(hoursForPreset('today', DateTime(2026, 9, 6, 23, 59, 59)), 24);
    });

    test('an unknown preset falls back to the full day', () {
      expect(hoursForPreset('week', DateTime(2026, 9, 6, 9)), 24);
    });

    test('the presets are offered in a fixed order with readable labels', () {
      expect(routePresets, ['today', '6h', '24h']);
      expect(routePresets.map(presetLabel), ['Today', '6h', '24h']);
    });
  });

  group('formatting', () {
    test('kilometres carry one decimal', () {
      expect(formatKm(0), '0.0 km');
      expect(formatKm(48.26), '48.3 km');
      expect(formatKm(470.7436), '470.7 km');
    });

    test('a window reads as a phrase', () {
      expect(hoursPhrase(1), 'the last hour');
      expect(hoursPhrase(6), 'the last 6 hours');
    });
  });
}
