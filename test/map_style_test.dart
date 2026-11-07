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
}
