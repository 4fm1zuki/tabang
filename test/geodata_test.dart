import 'package:flutter_test/flutter_test.dart';
import 'package:tabang/core/digos_geodata.dart';

void main() {
  test('Digos topology keeps all shared arcs and barangay rings', () {
    final features = DigosGeoData.buildBarangays();

    // 26 barangays, each stitched from the 75 shared arcs. The map's
    // internal-border layer starts at arc 15, so a truncated arc table used to
    // crash the whole map with "Index out of range: 15".
    expect(features, hasLength(26));
    for (final feature in features) {
      expect(feature.ring.length, greaterThan(3), reason: feature.name);
    }
    expect(DigosGeoData.buildInternalBorders(), hasLength(60));
    expect(DigosGeoData.cityRing.length, greaterThan(3));
  });
}
