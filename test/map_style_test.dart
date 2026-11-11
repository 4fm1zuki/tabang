import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tabang/widgets/digos_vector_map.dart';

/// Applies a Flutter [ColorFilter.matrix] (3x5, 0–255 offsets) to an RGB
/// triple and clamps the result, mirroring what the raster layer renders.
List<double> _apply(List<double> matrix, List<double> rgb) {
  return [
    for (var row = 0; row < 3; row++)
      (matrix[row * 5] * rgb[0] +
              matrix[row * 5 + 1] * rgb[1] +
              matrix[row * 5 + 2] * rgb[2] +
              matrix[row * 5 + 4])
          .clamp(0.0, 255.0),
  ];
}

void main() {
  group('dark tile filter', () {
    const filter = DigosMapColors.darkTileFilter;

    test('keeps the dark map from collapsing to pure black', () {
      // The previous dark matrix turned every OSM land, water and road colour
      // into black, which is why the dark map looked like an empty pane.
      final midGray = _apply(filter, [128, 128, 128]);
      expect(
        midGray.reduce((a, b) => a > b ? a : b),
        greaterThan(60),
        reason: 'mid-tones must survive the dark filter',
      );
    });

    test('maps pale OSM land to a near-paperDark dark surface', () {
      final land = _apply(filter, [242, 239, 233]);
      expect(land.reduce((a, b) => a > b ? a : b), lessThan(50));
      // Warm, not green or blue: no channel should dominate the others.
      expect((land[0] - land[2]).abs(), lessThan(15));
    });

    test('keeps water blue and parks green', () {
      final water = _apply(filter, [170, 211, 223]);
      expect(water[2], greaterThan(water[0]));
      expect(water[2], greaterThan(water[1]));

      final forest = _apply(filter, [173, 209, 158]);
      expect(forest[1], greaterThan(forest[0]));
      expect(forest[1], greaterThan(forest[2]));
    });

    test('turns white roads dark and keeps baked-in labels muted', () {
      // OSM roads are white; after inversion they become near-black lines.
      final road = _apply(filter, [255, 255, 255]);
      expect(road.reduce((a, b) => a > b ? a : b), lessThan(40));

      // OSM place names are dark text; the filter must not turn them into
      // glowing white that competes with TABANG's own halo labels.
      final label = _apply(filter, [51, 51, 51]); // #333 Carto text
      final labelMax = label.reduce((a, b) => a > b ? a : b);
      expect(labelMax, greaterThan(120));
      expect(labelMax, lessThan(220));
    });
  });

  group('light map canvas', () {
    test('the canvas and the outside mask are plain white', () {
      // The base map must not pick up an off-white, beige or blue cast; both
      // stops of each light gradient are pure white.
      const white = Color(0xFFFFFFFF);
      expect(DigosMapColors.paperGradient.colors, [white, white]);
      expect(DigosMapColors.outsideGradient.colors, [white, white]);
    });

    test('light tiles keep rivers blue and parks green while staying pale', () {
      const filter = DigosMapColors.lightTileFilter;

      // The base is the familiar coloured street map again, only softened.
      // Carto's water tile colour must stay blue: B > G > R.
      final water = _apply(filter, [125, 168, 215]);
      expect(water[2], greaterThan(water[1]));
      expect(water[1], greaterThan(water[0]));

      // Parks stay green: G is the strongest channel.
      final forest = _apply(filter, [173, 209, 158]);
      expect(forest[1], greaterThan(forest[0]));
      expect(forest[1], greaterThan(forest[2]));

      // Main roads keep their warm tint: R > G > B.
      final road = _apply(filter, [230, 138, 92]);
      expect(road[0], greaterThan(road[1]));
      expect(road[1], greaterThan(road[2]));

      // Nothing is allowed to get darker than a light base map; the tint only
      // softens the palette instead of draining it to grey.
      for (final colour in [water, forest, road]) {
        for (final channel in colour) {
          expect(channel, greaterThan(100), reason: 'base must read pale');
        }
      }

      // White land stays essentially white.
      final white = _apply(filter, [255, 255, 255]);
      for (final channel in white) {
        expect(channel, greaterThanOrEqualTo(235));
      }
    });

    test('barangay outlines use the deeper opaque terracotta', () {
      expect(DigosMapColors.internalBorder, const Color(0xFFB85C42));
      expect(DigosMapColors.cityBorder, const Color(0xFF5A1512));
    });
  });

  group('outside city mask', () {
    test('punches the city ring out of the canvas rectangle', () {
      // Regression: the mask used to be built with
      // `Path.combine(PathOperation.difference, ...)`, which lost the hole on
      // the web renderer at city-wide zoom — the mask covered the whole
      // viewport and hid the raster base. The even-odd path must keep the hole.
      const size = Size(400, 400);
      const ring = [
        Offset(100, 100),
        Offset(300, 100),
        Offset(300, 300),
        Offset(100, 300),
      ];

      final mask = DigosVectorMap.outsideCityMaskPath(size, ring);

      // The ring interior is a hole: the mask must not cover it.
      expect(mask.contains(const Offset(200, 200)), isFalse);
      // Everything outside the ring is masked.
      expect(mask.contains(const Offset(50, 200)), isTrue);
      expect(mask.contains(const Offset(350, 350)), isTrue);
      // The path still spans the canvas so the margins can be hidden.
      expect(mask.getBounds(), const Rect.fromLTRB(0, 0, 400, 400));
    });

    test('keeps the hole for a city-wide camera', () {
      // At the desktop fit (~2 km) the ring is only a fraction of the canvas;
      // this is the exact case that turned into a full-viewport cover.
      const size = Size(1234, 1199);
      const ring = [
        Offset(430, 237),
        Offset(804, 237),
        Offset(804, 962),
        Offset(430, 962),
      ];

      final mask = DigosVectorMap.outsideCityMaskPath(size, ring);

      expect(mask.contains(const Offset(617, 600)), isFalse);
      expect(mask.contains(const Offset(10, 10)), isTrue);
      expect(mask.contains(const Offset(1200, 1180)), isTrue);
    });
  });
}
