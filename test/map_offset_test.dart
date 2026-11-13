import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:tabang/widgets/digos_vector_map.dart';

void main() {
  group('base map offset', () {
    test('matches the hand-tuned offset at the calibration zoom', () {
      expect(
        DigosVectorMap.baseMapOffsetFor(DigosVectorMap.baseMapOffsetZoom),
        DigosVectorMap.baseMapOffset,
      );
    });

    test('shrinks with the ground when zooming out', () {
      // The bug report compared a hand-tuned view with one half a zoom level
      // further out: the raster base must move by 2^-0.5 on screen, not stay
      // pinned to the same pixel offset.
      final half = DigosVectorMap.baseMapOffsetFor(
        DigosVectorMap.baseMapOffsetZoom - 0.5,
      );
      expect(half.dx, closeTo(DigosVectorMap.baseMapOffset.dx * 0.7071, 0.01));
      expect(half.dy, closeTo(DigosVectorMap.baseMapOffset.dy * 0.7071, 0.01));
    });

    test('keeps growing past the calibration zoom', () {
      // Street-level views below 200 m need a larger screen offset, not the
      // calibration offset frozen in place.
      final at18 = DigosVectorMap.baseMapOffsetFor(18);
      final scale = math
          .pow(2, 18 - DigosVectorMap.baseMapOffsetZoom)
          .toDouble();
      expect(at18.dx, closeTo(DigosVectorMap.baseMapOffset.dx * scale, 0.01));
      expect(at18.dy, closeTo(DigosVectorMap.baseMapOffset.dy * scale, 0.01));
      expect(at18.dy, greaterThan(DigosVectorMap.baseMapOffset.dy * 4));
    });

    test('whole-tile shift follows the raster grid', () {
      expect(DigosVectorMap.baseMapTileShift(16), const math.Point<int>(0, 1));
      expect(DigosVectorMap.baseMapTileShift(18), const math.Point<int>(1, 4));
      // The shift must keep growing with zoom instead of clamping at one tile.
      expect(DigosVectorMap.baseMapTileShift(22).y, greaterThan(4));
    });

    test('residual stays small enough for the canvas margin', () {
      // The provider fetches whole tiles, so only half a tile per axis is left
      // over. At the edges of a zoom step that half tile is scaled by up to
      // sqrt(2), which bounds it at 128*sqrt(2) screen pixels.
      for (var zoom = 10.5; zoom <= 18.0; zoom += 0.05) {
        final tileZoom = zoom.round();
        final residual = DigosVectorMap.baseMapResidualFor(zoom, tileZoom);
        expect(
          residual.dx.abs(),
          lessThanOrEqualTo(128 * math.sqrt2 + 0.01),
          reason: 'x residual at zoom $zoom',
        );
        expect(
          residual.dy.abs(),
          lessThanOrEqualTo(128 * math.sqrt2 + 0.01),
          reason: 'y residual at zoom $zoom',
        );
      }
    });

    test('tile shift plus residual reconstructs the full offset', () {
      for (final zoom in [10.5, 13.0, 15.0, 15.82, 16.4, 17.0, 17.75, 18.0]) {
        final tileZoom = zoom.round();
        final shift = DigosVectorMap.baseMapTileShift(tileZoom);
        final scale = math.pow(2, zoom - tileZoom).toDouble();
        final residual = DigosVectorMap.baseMapResidualFor(zoom, tileZoom);
        final total = DigosVectorMap.baseMapOffsetFor(zoom);
        expect(
          residual.dx + shift.x * DigosVectorMap.baseMapTileSize * scale,
          closeTo(total.dx, 1e-9),
        );
        expect(
          residual.dy + shift.y * DigosVectorMap.baseMapTileSize * scale,
          closeTo(total.dy, 1e-9),
        );
      }
    });
  });

  group('drive marker stability', () {
    test('returns the same point regardless of camera zoom', () {
      // The old collision nudge compared pins in screen space, so a drive
      // could move between zooms. The helper is pure: one input, one output.
      const drive = LatLng(6.74378, 125.35629); // Digos City Gymnasium.
      final first = DigosVectorMap.driveMarkerPoint(drive);
      final second = DigosVectorMap.driveMarkerPoint(drive);
      expect(first.latitude, closeTo(second.latitude, 1e-12));
      expect(first.longitude, closeTo(second.longitude, 1e-12));
      // The gym is not at a facility venue, so it keeps its exact position.
      expect(first.latitude, drive.latitude);
      expect(first.longitude, drive.longitude);
    });

    test('steps a shared-venue drive off the facility pin', () {
      final facility = DigosVectorMap.toMapFrame(digosFacilityPins.first.point);
      final marker = DigosVectorMap.driveMarkerPoint(facility);
      expect(marker.latitude, lessThan(facility.latitude));
      expect(marker.longitude, greaterThan(facility.longitude));
      // Repeating the call is stable as well.
      final again = DigosVectorMap.driveMarkerPoint(facility);
      expect(again.latitude, closeTo(marker.latitude, 1e-12));
      expect(again.longitude, closeTo(marker.longitude, 1e-12));
    });
  });

  group('metric scale bar', () {
    // Metres covered by one logical pixel at Digos latitude.
    double metresPerPixel(double zoom, double latitude) =>
        156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);

    test('street-level zoom labels the distance it actually draws', () {
      // Regression: at phone zoom the old bar ran out of candidate distances,
      // drew a clamped 24 px line and still called it "50 m".
      final scale = mapScaleBarScale(zoom: 18, latitude: 6.84);
      expect(scale.label, '50 m');
      expect(scale.distanceMetres, 50);
      expect(scale.width, greaterThanOrEqualTo(30));
      expect(scale.width, lessThanOrEqualTo(96));
      expect(
        scale.width,
        closeTo(50 / metresPerPixel(18, 6.84), 0.01),
        reason: 'the drawn line must match the stated distance',
      );
    });

    test('every zoom keeps the label and line length consistent', () {
      for (var zoom = 10.5; zoom <= 18.0; zoom += 0.1) {
        final scale = mapScaleBarScale(zoom: zoom, latitude: 6.84);
        expect(scale.width, inInclusiveRange(30, 96), reason: 'zoom $zoom');
        expect(
          scale.width,
          closeTo(scale.distanceMetres / metresPerPixel(zoom, 6.84), 1e-9),
          reason: 'zoom $zoom',
        );
        expect(
          scale.label,
          scale.distanceMetres >= 1000
              ? '${(scale.distanceMetres / 1000).toStringAsFixed(scale.distanceMetres % 1000 == 0 ? 0 : 1)} km'
              : '${scale.distanceMetres.toInt()} m',
          reason: 'zoom $zoom',
        );
      }
    });

    test('zooming in shrinks the labelled distance', () {
      final city = mapScaleBarScale(zoom: 12, latitude: 6.84);
      final street = mapScaleBarScale(zoom: 18, latitude: 6.84);
      expect(city.distanceMetres, greaterThan(street.distanceMetres));
      expect(street.distanceMetres, lessThanOrEqualTo(50));
    });
  });

  group('map frame rebase', () {
    const metresPerDegree = 111319.49;

    test('moves an OSM point by the same ground offset as the raster', () {
      const pin = LatLng(6.757051, 125.352800); // PRC chapter, true OSM.
      final rebased = DigosVectorMap.toMapFrame(pin);

      final cosLat = math.cos(pin.latitude * math.pi / 180);
      final metresPerPixel =
          156543.03392 * cosLat / math.pow(2, DigosVectorMap.baseMapOffsetZoom);
      final southMetres = (pin.latitude - rebased.latitude) * metresPerDegree;
      final eastMetres =
          (rebased.longitude - pin.longitude) * metresPerDegree * cosLat;

      expect(
        southMetres,
        closeTo(DigosVectorMap.baseMapOffset.dy * metresPerPixel, 1),
      );
      expect(
        eastMetres,
        closeTo(DigosVectorMap.baseMapOffset.dx * metresPerPixel, 1),
      );
      // Same direction as the raster nudge: south and east.
      expect(rebased.latitude, lessThan(pin.latitude));
      expect(rebased.longitude, greaterThan(pin.longitude));
    });

    test('fromMapFrame is the inverse of toMapFrame', () {
      const point = LatLng(6.8123, 125.3567);
      final back = DigosVectorMap.fromMapFrame(
        DigosVectorMap.toMapFrame(point),
      );
      // Sub-metre: the inverse recomputes the metres-per-pixel from the
      // rebased latitude, so the two are not bit-identical.
      expect(back.latitude, closeTo(point.latitude, 1e-6));
      expect(back.longitude, closeTo(point.longitude, 1e-6));
    });

    test('barangayAt detects the barangay under a centroid', () {
      final zone = DigosVectorMap.centroidOf('Zone 1');
      expect(zone, isNotNull);
      expect(DigosVectorMap.barangayAt(zone!), 'Zone 1');

      // A point outside the city resolves to nothing.
      expect(DigosVectorMap.barangayAt(const LatLng(0, 0)), isNull);
    });
  });
}
