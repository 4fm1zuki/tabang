import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
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
}
