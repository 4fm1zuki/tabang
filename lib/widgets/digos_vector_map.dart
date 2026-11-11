import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../core/digos_geodata.dart';
import '../core/repository.dart';
import '../theme.dart';

/// TABANG's palette for the Digos vector map.
///
/// The standalone `map/` project used a green/teal scheme. Here the same
/// layered structure — paper base, internal boundaries, a heavy outer city
/// border, halo labels — is re-coloured to the app's warm crimson, maroon,
/// charcoal and gold set, with the donor heat ramp kept for density.
///
/// Where to edit the map's colours:
/// - canvas under the raster: [paperGradient] / [paperGradientDark] and
///   [outsideGradient] / [outsideGradientDark];
/// - the raster street base itself: [lightTileFilter] / [darkTileFilter];
/// - barangay data fills: [digosHeatColor], [digosRequestColor] and
///   [digosHeatOpacity] in this same file;
/// - borders, selection, pins and labels: [internalBorder], [cityBorder],
///   [selectionFill], [selectionBorder], [drive], [hospital], [chapter],
///   [label] and their `…Dark` variants below.
class DigosMapColors {
  const DigosMapColors._();

  /// The canvas under the raster tiles. Plain white: the earlier warm
  /// off-white read as dirty and the sky-blue gradient that replaced it tinted
  /// the whole base map blue, so the light canvas is deliberately neutral now.
  static const LinearGradient paperGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
  );
  /// The dark canvas mirrors the app's warm charcoal surfaces (see
  /// [TabangColors.darkBg]); the earlier blue-navy gradient tinted the whole
  /// dark map blue and read as a different product next to the shell.
  static const LinearGradient paperGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ui.Color.fromARGB(255, 41, 41, 41), Color(0xFF161110)],
  );

  /// Everything outside the city cutout. Also plain white; the heavy city
  /// border and the barangay lines carry the silhouette without a coloured
  /// band around Digos.
  static const LinearGradient outsideGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFFFFF)],
  );
  static const LinearGradient outsideGradientDark = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [ui.Color.fromARGB(255, 59, 59, 58), ui.Color.fromARGB(255, 24, 23, 23)],
  );

  /// Barangay borders. A deeper terracotta than the old pale rose so the
  /// internal outlines stay legible over both the raster base and the heat
  /// fills instead of washing out. The dark tone is much lighter and is stroked
  /// at near-full opacity, because a faint terracotta line on a near-black
  /// raster made the barangay cutouts disappear in dark mode.
  static const Color internalBorder = Color(0xFFB85C42);
  static const Color internalBorderDark = Color(0xFFDE9377);
  static const Color cityBorder = Color(0xFF5A1512);
  static const Color cityBorderDark = Color(0xFFFFDAD4);
  static const Color label = ui.Color.fromARGB(255, 43, 40, 39);
  static const Color labelDark = Color(0xFFFBF5F2);
  static const Color halo = Color(0xFFF8FAFC);
  static const Color haloDark = ui.Color.fromARGB(255, 31, 30, 30);

  /// Selected barangay: a subtle teal wash with a brand-teal outline, so it
  /// no longer competes with the warm donor ramp. (Polygon fills cannot take a
  /// gradient in flutter_map, so this is the flat two-tone treatment.)
  static const Color selectionFill = Color(0xFFD3E8E2);
  static const Color selectionFillDark = Color(0xFF1E4A42);
  static const Color selectionBorder = Color(0xFF23695E);
  static const Color selectionBorderDark = Color(0xFF9CD5CA);
  static const Color selectionStroke = Color(0xFFFFFFFF);
  static const Color drive = Color(0xFFB3261E);
  static const Color driveDark = Color(0xFFFFA694);
  static const Color hospital = Color(0xFF1F5FA8);
  static const Color hospitalDark = Color(0xFF9CC4F0);
  static const Color chapter = Color(0xFFB3261E);
  static const Color chapterDark = Color(0xFFFFB4A8);
  static const Color attribution = Color(0xFF5A4F4B);

  /// Light tiles are the OSM-France style, whose trunk roads are drawn in
  /// yellow. That yellow clashed with the app's crimson palette, so this matrix
  /// halves the saturation (a luminance-preserving mix towards grey, weights
  /// 0.213/0.715/0.072) and lifts the range by 6. A yellow road lands on a pale
  /// sand tone — measured on the real pane, nothing is yellow any more —
  /// while vegetation keeps a soft green and water a faint blue, so the base
  /// reads pale without a dim grey cast. Edit these 20 numbers to retune the
  /// light base (the first three rows are R/G/B; the fifth column is the
  /// 0–255 offset).
  static const List<double> lightTileFilter = <double>[
    0.6065,
    0.3575,
    0.0360,
    0,
    6,
    0.1065,
    0.8575,
    0.0360,
    0,
    6,
    0.1065,
    0.3575,
    0.5360,
    0,
    6,
    0.000,
    0.000,
    0.000,
    1,
    0,
  ];

  /// Inverted, hue-rotated tiles for the dark map style.
  ///
  /// This is the classic `invert(1) hue-rotate(180deg)` recipe folded into one
  /// matrix, then compressed and lifted so the dark map still reads as a map:
  /// pale OSM land becomes a warm charcoal just above the canvas gradient
  /// (rather than the near-black it used to be, which made the city interior
  /// look empty), water stays blue, parks stay green and roads read as lighter
  /// grey lines. OSM place names land in the mid greys instead of glowing
  /// white, so TABANG's own halo labels stay the brightest text.
  static const List<double> darkTileFilter = <double>[
    0.360,
    -0.897,
    -0.090,
    0,
    203,
    -0.267,
    -0.270,
    -0.090,
    0,
    202,
    -0.267,
    -0.897,
    0.537,
    0,
    200,
    0.000,
    0.000,
    0.000,
    1,
    0,
  ];
}

/// A fixed point of interest drawn on the Digos map: the PRC chapter plus the
/// participating hospitals from the facility directory.
class DigosFacilityPin {
  const DigosFacilityPin({
    required this.name,
    required this.kind,
    required this.point,
    required this.note,
  });

  final String name;

  /// `chapter` (blood bank) or `hospital`.
  final String kind;
  final LatLng point;
  final String note;
}

/// Coordinates are approximate in this prototype — they place each facility
/// inside the correct barangay for wayfinding, not for navigation.
/// One active blood drive, pinned at its venue rather than the barangay
/// centroid.
class DigosDriveMarker {
  const DigosDriveMarker({
    required this.title,
    required this.barangay,
    required this.point,
  });

  final String title;
  final String barangay;
  final LatLng point;
}

///
/// Coordinates come from the OpenStreetMap features for each facility, not
/// barangay centroids: the PRC chapter sits on Quezon Avenue, Digos Doctors on
/// MacArthur Highway and the provincial hospital on Malvar Street. A pin that
/// is half a kilometre off is worse than no pin on a blood-donation map.
const List<DigosFacilityPin> digosFacilityPins = [
  DigosFacilityPin(
    name: 'Philippine Red Cross — Davao del Sur Chapter',
    kind: 'chapter',
    point: LatLng(6.757051, 125.352800),
    note: 'Blood bank and donation site · Quezon Avenue · walk-ins welcome',
  ),
  DigosFacilityPin(
    name: 'Digos Provincial Hospital',
    kind: 'hospital',
    point: LatLng(6.743810, 125.361265),
    note:
        'Participating hospital · Malvar Street · accepts blood-bank releases',
  ),
  DigosFacilityPin(
    name: 'Digos Doctors Hospital',
    kind: 'hospital',
    point: LatLng(6.764423, 125.355069),
    note: 'Participating hospital · MacArthur Highway · accepts blood-bank releases',
  ),
];

/// How much of the base map each density band lets through.
///
/// The fills used to be fully opaque, which hid the street layer completely:
/// the base map was there but no road ever showed. Empty barangays are almost
/// transparent and every band stays below 0.8 so the streets remain readable
/// even in the densest part of the city proper.
double digosHeatOpacity(int count) {
  if (count == 0) return 0.04;
  if (count <= 2) return 0.30;
  if (count <= 5) return 0.48;
  if (count <= 9) return 0.64;
  return 0.78;
}

/// Sequential donor-density ramp, re-tuned to sit on the warm paper base.
Color digosHeatColor(int count, {required bool dark}) {
  if (dark) {
    if (count == 0) return const Color(0xFF241C1A);
    if (count <= 2) return const Color(0xFF5B2D26);
    if (count <= 5) return const Color(0xFF8E3A2E);
    if (count <= 9) return const Color(0xFFC24C3B);
    return const Color(0xFFE76B56);
  }
  if (count == 0) return const Color(0xFFEDE4DF);
  if (count <= 2) return const Color(0xFFF2C0A6);
  if (count <= 5) return const Color(0xFFDF8266);
  if (count <= 9) return const Color(0xFFC24934);
  return const Color(0xFF961D13);
}

/// Staff operations ramp for the open-request layer. Amber → deep red so it
/// reads as workload rather than donor density.
Color digosRequestColor(int count, {required bool dark}) {
  if (dark) {
    if (count == 0) return const Color(0xFF241C1A);
    if (count <= 1) return const Color(0xFF5B4316);
    if (count <= 3) return const Color(0xFF8E6420);
    if (count <= 6) return const Color(0xFFC0842E);
    return const Color(0xFFE5A94B);
  }
  if (count == 0) return const Color(0xFFEDE4DF);
  if (count <= 1) return const Color(0xFFF7DFA8);
  if (count <= 3) return const Color(0xFFEDB55B);
  if (count <= 6) return const Color(0xFFD97F2B);
  return const Color(0xFFA33F16);
}

/// The Digos City vector map used by Find Donor.
///
/// Adopted from the standalone `digos_barangay_map` project: OpenStreetMap
/// tiles form the base, an inverse mask hides everything outside the city, and
/// the barangay topology ships locally in [DigosGeoData]. On top of that,
/// TABANG draws its own layers — donor-density fills, selection, drive pins
/// and labels — so the map still reads when tiles are unavailable.
class DigosVectorMap extends StatefulWidget {
  const DigosVectorMap({
    super.key,
    required this.controller,
    required this.donorCounts,
    required this.drives,
    required this.selectedBarangay,
    required this.mapDark,
    required this.onSelectBarangay,
    required this.onDriveTap,
    required this.onFacilityTap,
    this.requestCounts,
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  /// Owned by the page so its zoom/compass buttons can drive the camera.
  final MapController controller;

  /// Canonical barangay name → eligible donors.
  final Map<String, int> donorCounts;

  /// Canonical barangay name → open requests. When supplied, the fill layer
  /// switches from the donor-density ramp to the staff request ramp; the
  /// caller is responsible for the matching legend.
  final Map<String, int>? requestCounts;

  /// Active drives with their venue coordinates.
  final List<DigosDriveMarker> drives;

  final String? selectedBarangay;

  /// Light or dark *map* style, independent of the app theme.
  final bool mapDark;

  final ValueChanged<String?> onSelectBarangay;
  final ValueChanged<String> onDriveTap;

  /// Fired when a hospital or the PRC chapter pin is tapped.
  final ValueChanged<DigosFacilityPin> onFacilityTap;

  /// Fired when a pan or zoom gesture starts, so the page can fade its map
  /// overlays while the map itself is being used.
  final VoidCallback? onInteractionStart;

  /// Fired when the gesture ends (or a fling settles).
  final VoidCallback? onInteractionEnd;

  /// Widget tests disable network tiles so no HTTP is attempted.
  static bool tilesEnabled = true;

  /// The OSM base is a decorative street template behind hand-traced barangay
  /// geometry. Its streets sit a touch up and to the left of the cutouts, so
  /// only the raster layer is nudged down-right; every vector layer, pin and
  /// label keeps its exact position.
  ///
  /// This is the screen offset at [baseMapOffsetZoom]. The applied offset is
  /// scaled by the map's zoom so it represents a fixed displacement on the
  /// ground: zooming out shrinks it in step with the cutouts, and zooming in
  /// keeps growing it, instead of freezing at the calibration size.
  static const Offset baseMapOffset = Offset(33, 205);

  /// Zoom level at which [baseMapOffset] was calibrated by hand.
  static const double baseMapOffsetZoom = 15.82;

  /// Logical size of one OSM raster tile. [TileLayer] is left at its default.
  static const double baseMapTileSize = 256;

  /// Total screen offset the raster base needs at [zoom].
  ///
  /// The underlying ground displacement is fixed, so the screen offset follows
  /// the same `2^zoom` growth as the vector geometry. Unlike a clamped offset,
  /// this keeps the streets aligned at street-level zooms, where the required
  /// shift is several tiles wide.
  static Offset baseMapOffsetFor(double zoom) =>
      baseMapOffset * math.pow(2, zoom - baseMapOffsetZoom).toDouble();

  /// Whole tiles the requested OSM grid is shifted at [tileZoom].
  ///
  /// [baseMapOffsetFor] grows far past one tile at high zoom, so requesting it
  /// as a per-tile pixel translation would need an enormous canvas. Instead the
  /// provider asks for source tile `(x - dx, y - dy)` and only the sub-tile
  /// remainder is applied as a translation.
  static math.Point<int> baseMapTileShift(int tileZoom) {
    final ground = baseMapOffsetFor(tileZoom.toDouble());
    return math.Point<int>(
      (ground.dx / baseMapTileSize).round(),
      (ground.dy / baseMapTileSize).round(),
    );
  }

  /// Screen translation left after [baseMapTileShift] whole tiles at
  /// [tileZoom], for a tile displayed at [zoom] (scaled by `2^(zoom-tileZoom)`
  /// during zoom animations).
  ///
  /// The whole-tile part is exact, so this never exceeds half a tile per axis
  /// at the tile's own zoom — at most `128·√2` screen pixels at the extremes
  /// of a zoom step. That bound is what keeps [baseMapMargin] small.
  static Offset baseMapResidualFor(double zoom, int tileZoom) {
    final tileScale = math.pow(2, zoom - tileZoom).toDouble();
    final shift = baseMapTileShift(tileZoom);
    final total = baseMapOffsetFor(zoom);
    return Offset(
      total.dx - shift.x * baseMapTileSize * tileScale,
      total.dy - shift.y * baseMapTileSize * tileScale,
    );
  }

  /// How far the map canvas is grown behind the visible pane. The tile grid is
  /// shifted by up to half a tile per axis (plus scaling during zoom
  /// animations), so its uncovered strips must fall outside the pane; this also
  /// keeps tap coordinates and vector framing unchanged when the canvas is
  /// offset by the same amount on every side.
  static const double baseMapMargin = 128 * math.sqrt2 + 16;

  /// The inverse city mask: the whole canvas rectangle with [cityRing]
  /// (already projected to canvas coordinates) punched out as a hole.
  ///
  /// Uses the even-odd fill rule rather than
  /// `Path.combine(PathOperation.difference, ...)`. On the web renderer the
  /// combined path lost the hole for city-wide cameras — painting the mask
  /// over the entire viewport and hiding the raster base behind it — and
  /// collapsed to nothing at street level. Exposed as a pure function so tests
  /// can assert the hole directly ([Path.contains] respects the fill rule).
  static ui.Path outsideCityMaskPath(Size size, List<Offset> cityRing) {
    final city = ui.Path();
    for (var i = 0; i < cityRing.length; i++) {
      final point = cityRing[i];
      if (i == 0) {
        city.moveTo(point.dx, point.dy);
      } else {
        city.lineTo(point.dx, point.dy);
      }
    }
    city.close();
    return ui.Path()
      ..fillType = ui.PathFillType.evenOdd
      ..addRect(Offset.zero & size)
      ..addPath(city, Offset.zero);
  }

  /// The camera fit that frames the whole city, using the same bounds as the
  /// standalone `map/` project so the framing matches the previous map.
  static final LatLngBounds cityBounds = LatLngBounds(
    const LatLng(6.71695, 125.2524),
    const LatLng(6.9874, 125.3930),
  );

  /// Moves a true OpenStreetMap coordinate into the hand-traced map frame.
  ///
  /// Facility pins and drive venues are stored at their real coordinates, but
  /// the raster base — and therefore the whole bundled map — is nudged
  /// [baseMapOffset] down-right of real geography: a fixed ground
  /// displacement of roughly 89 m east and 551 m south at
  /// [baseMapOffsetZoom]. This applies that same displacement to a point, so
  /// OSM-derived pins sit on their buildings under the nudged raster instead
  /// of roughly half a kilometre away. Hand-traced coordinates
  /// ([centroidOf], barangay rings) are already in this frame and must not be
  /// passed through it.
  static LatLng toMapFrame(LatLng point) {
    const metresPerDegree = 111319.49;
    final cosLat = math.cos(point.latitude * math.pi / 180);
    final metresPerPixel =
        156543.03392 * cosLat / math.pow(2, baseMapOffsetZoom);
    return LatLng(
      point.latitude - baseMapOffset.dy * metresPerPixel / metresPerDegree,
      point.longitude +
          baseMapOffset.dx * metresPerPixel / (metresPerDegree * cosLat),
    );
  }

  /// Distance, in degrees, within which a drive and a facility count as the
  /// same venue. Roughly 45 m at Digos latitudes.
  static const double _sameVenueDegrees = 0.0004;

  /// Fixed south-east step for a drive pin sharing a facility's venue.
  static const LatLng _venueStep = LatLng(-0.0008, 0.0011);

  /// Applies the zoom-independent venue separation used by drive pins.
  ///
  /// Pure and deterministic: the same input always returns the same point, so
  /// a pin does not move while the camera zooms. Facility pins are rebased
  /// first, matching how the marker layer draws them.
  static LatLng driveMarkerPoint(LatLng point) {
    for (final pin in digosFacilityPins) {
      final facility = toMapFrame(pin.point);
      final cosLat = math.cos(point.latitude * math.pi / 180);
      final dLat = point.latitude - facility.latitude;
      final dLng = (point.longitude - facility.longitude) * cosLat;
      if (dLat.abs() < _sameVenueDegrees && dLng.abs() < _sameVenueDegrees) {
        return LatLng(
          point.latitude + _venueStep.latitude,
          point.longitude + _venueStep.longitude,
        );
      }
    }
    return point;
  }

  /// Centroid of a barangay by repository name ("Zone 1"), used by the donor
  /// pane's "show on map" actions.
  static LatLng? centroidOf(String canonical) {
    for (final feature in _barangayFeatures()) {
      final name = DigosBarangays.canonical(feature.name) ?? feature.name;
      if (name == canonical) return feature.centroid;
    }
    return null;
  }

  /// Frames the whole city again; used by the page's compass button.
  static void fitCity(MapController controller) {
    controller.fitCamera(
      CameraFit.bounds(
        bounds: cityBounds,
        // The map canvas is grown by [baseMapMargin] on every side, so the
        // padding grows with it to keep the visible framing identical to a
        // plain 40 px inset.
        padding: const EdgeInsets.all(40 + baseMapMargin),
        // Same cap as the standalone map, and as the initial fit below, so the
        // compass button cannot zoom past the city-wide framing.
        maxZoom: 13,
      ),
    );
  }

  @override
  State<DigosVectorMap> createState() => _DigosVectorMapState();
}

/// Stitched parameters are expensive to rebuild and never change, so they are
/// cached once per process.
List<BarangayFeature>? _barangayFeaturesCache;
List<List<LatLng>>? _internalBordersCache;

List<BarangayFeature> _barangayFeatures() =>
    _barangayFeaturesCache ??= DigosGeoData.buildBarangays();

class _DigosVectorMapState extends State<DigosVectorMap> {
  late final List<BarangayFeature> _features;
  late final List<List<LatLng>> _internalBorders;
  late final List<LatLng> _cityRing;

  /// Geodata names ("Zone 1 (Pob.)") → repository names ("Zone 1").
  late final Map<String, String> _canonicalNames;

  /// One tile provider for the life of this map: it rewrites requested tile
  /// coordinates so the raster grid can be shifted by whole tiles. It is
  /// disposed by the [TileLayer].
  late final _ShiftedTileProvider _tileProvider = _ShiftedTileProvider();

  int? _hoveredId;
  double _zoom = 11;

  /// The distance bar follows the live camera, not the coarser [_zoom] value
  /// used for label and pin sizing. It is a notifier so a pinch or scroll
  /// repaints only the small bar instead of rebuilding every map layer.
  final ValueNotifier<MapScaleBarScale> _scaleNotifier = ValueNotifier(
    mapScaleBarScale(zoom: 11, latitude: 6.84),
  );

  bool _firstFrameDone = false;

  void _syncScale(MapCamera camera) {
    _scaleNotifier.value = mapScaleBarScale(
      zoom: camera.zoom,
      latitude: camera.center.latitude,
    );
  }

  @override
  void initState() {
    super.initState();
    // One extra frame once the camera exists, so label collision applies to
    // the very first paint instead of waiting for the next zoom change.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _firstFrameDone) return;
      _firstFrameDone = true;
      setState(() {});
    });
    _internalBordersCache ??= DigosGeoData.buildInternalBorders();
    _features = _barangayFeatures();
    _internalBorders = _internalBordersCache!;
    _cityRing = DigosGeoData.cityRing;
    _canonicalNames = {
      for (final feature in _features)
        feature.name: DigosBarangays.canonical(feature.name) ?? feature.name,
    };
  }

  @override
  void dispose() {
    _scaleNotifier.dispose();
    super.dispose();
  }

  double _lerp(
    double minZoom,
    double minValue,
    double maxZoom,
    double maxValue,
  ) {
    final t = ((_zoom - minZoom) / (maxZoom - minZoom)).clamp(0.0, 1.0);
    return minValue + (maxValue - minValue) * t;
  }

  String? _canonicalAt(LatLng point) {
    for (final feature in _features) {
      if (DigosGeoData.isPointInPolygon(point, feature.ring)) {
        return _canonicalNames[feature.name];
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.mapDark;
    final internalWidth = _lerp(9, 1.5, 18, 3.0);
    final outerWidth = _lerp(9, 2.6, 18, 4.6);
    final labelSize = _lerp(10.5, 9.5, 18, 15);
    // Pins shrink with the map so a city-wide view does not drown in markers,
    // and grow back to full size once the user is at street level.
    final pinScale = _lerp(10.5, 0.62, 14, 1.0);

    return LayoutBuilder(
      builder: (context, _) {
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // The map canvas extends behind the pane by [baseMapMargin] on
            // every side. The raster tiles are nudged down-right, so their
            // uncovered top/left strip falls outside this clipped pane; the
            // symmetric growth keeps the camera centre, taps and vector layers
            // exactly where they were in the visible pane.
            Positioned(
              left: -DigosVectorMap.baseMapMargin,
              top: -DigosVectorMap.baseMapMargin,
              right: -DigosVectorMap.baseMapMargin,
              bottom: -DigosVectorMap.baseMapMargin,
              // A pointing-hand cursor while a barangay is under the mouse makes
              // "click to select a region" discoverable; elsewhere the map shows
              // the grab cursor that matches dragging. The plain white canvas
              // sits under the transparent FlutterMap raster, so a tile gap
              // reads as clean white instead of a tinted band.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: dark
                      ? DigosMapColors.paperGradientDark
                      : DigosMapColors.paperGradient,
                ),
                child: MouseRegion(
                  cursor: _hoveredId != null
                      ? SystemMouseCursors.click
                      : SystemMouseCursors.grab,
                  child: FlutterMap(
                    mapController: widget.controller,
                    options: MapOptions(
                      initialCenter: const LatLng(6.80, 125.34),
                      initialZoom: 11,
                      // Below 10.5 the whole city is barely a hundred pixels wide;
                      // above 18 the raster base has no more detail to show. Both
                      // zoom buttons use the same clamp.
                      minZoom: 10.5,
                      maxZoom: 18,
                      cameraConstraint: CameraConstraint.containCenter(
                        bounds: LatLngBounds(
                          const LatLng(6.70, 125.23),
                          const LatLng(7.01, 125.42),
                        ),
                      ),
                      backgroundColor: Colors.transparent,
                      // The one and only initial framing. flutter_map 8 applies
                      // this once real constraints exist, so it must not be
                      // followed by a post-frame `fitCamera` re-fit: a camera
                      // jump while the first tiles are in flight aborts every
                      // request and the layer never retries, leaving the base
                      // blank until the user pans (the old v7 re-fit did
                      // exactly that).
                      initialCameraFit: CameraFit.bounds(
                        // Same framing as the standalone map project, with the
                        // canvas margin added so the visible inset stays 40 px.
                        bounds: DigosVectorMap.cityBounds,
                        padding: const EdgeInsets.all(
                          40 + DigosVectorMap.baseMapMargin,
                        ),
                        maxZoom: 13,
                      ),
                      interactionOptions: const InteractionOptions(
                        // No double-tap zoom: its recognizer holds every single
                        // tap in the gesture arena for ~300 ms, which made
                        // selecting a barangay feel unresponsive. Pinch, the
                        // wheel and the ± buttons still zoom; one-finger drag
                        // still pans.
                        flags:
                            InteractiveFlag.all &
                            ~(InteractiveFlag.rotate |
                                InteractiveFlag.doubleTapZoom |
                                InteractiveFlag.doubleTapDragZoom),
                      ),
                      onPositionChanged: (camera, hasGesture) {
                        // The bar uses the exact camera zoom on every frame;
                        // the coarser value below still drives label and pin
                        // scaling. A 0.12 threshold keeps a pinch from
                        // rebuilding the whole layer stack dozens of times a
                        // second for sub-pixel size changes.
                        _syncScale(camera);
                        if ((camera.zoom - _zoom).abs() > 0.12) {
                          setState(() => _zoom = camera.zoom);
                        }
                      },
                      // Gesture-start / gesture-end drive the panel fade, so the panels come
                      // back as soon as the user stops moving the map instead of on a long
                      // timer.
                      onMapEvent: (event) {
                        switch (event) {
                          case MapEventMoveStart():
                          case MapEventFlingAnimationStart():
                            widget.onInteractionStart?.call();
                          case MapEventMoveEnd():
                          case MapEventFlingAnimationEnd():
                          case MapEventDoubleTapZoomEnd():
                            widget.onInteractionEnd?.call();
                          default:
                            break;
                        }
                      },
                      onTap: (tapPosition, point) {
                        widget.onInteractionStart?.call();
                        widget.onInteractionEnd?.call();
                        widget.onSelectBarangay(_canonicalAt(point));
                      },
                      onPointerHover: (event, point) {
                        if (event.kind != PointerDeviceKind.mouse) return;
                        final feature = _featureAt(point);
                        final id = feature?.id;
                        if (id != _hoveredId) setState(() => _hoveredId = id);
                      },
                    ),
                    children: [
                      if (DigosVectorMap.tilesEnabled)
                        // The raster is only lightly tinted in light mode (see
                        // [DigosMapColors.lightTileFilter]); the dark theme
                        // transforms it into the inverted night base. Retune
                        // both matrices in that class to change the map's base
                        // colours.
                        ColorFiltered(
                          colorFilter: ColorFilter.matrix(
                            dark
                                ? DigosMapColors.darkTileFilter
                                : DigosMapColors.lightTileFilter,
                          ),
                          child: TileLayer(
                            // OSM-France's world-wide style, served from the
                            // keyless mirror. Unlike the Bretagne mirror used
                            // before, it carries street and place labels outside
                            // France, so Digos' road names, rivers and barangay
                            // surroundings are readable. It needs no API key and
                            // no Referer, so the same URL works on localhost, in
                            // a deployed build and from a phone.
                            //
                            // Its trunk roads are drawn in yellow, which clashed
                            // with the app's crimson palette; the colour matrix
                            // in [DigosMapColors.lightTileFilter] removes that
                            // (measured: no pixel in the pane is yellow after the
                            // filter) while keeping vegetation green and water
                            // faintly blue.
                            //
                            // Esri's World Topographic basemap was the other
                            // keyless candidate with no yellow, but at mid zooms
                            // it renders contour lines and shaded relief over the
                            // Digos highlands, which read as grey and swamped the
                            // barangay fills. Carto's Positron style would also
                            // fit, but its CDN now serves an "API KEY REQUIRED"
                            // watermark without a key, and openstreetmap.org
                            // tiles are Referer-gated.
                            urlTemplate:
                                'https://a.tile.openstreetmap.fr/osmfr/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.digos.barangay_map',
                            maxNativeZoom: 19,
                            // The offset is re-evaluated inside the tile builder so
                            // it tracks the live camera during zoom animations.
                            // Whole-tile shifts are fetched by the provider; only
                            // the sub-tile remainder is translated here, which
                            // keeps the oversized canvas above small even at
                            // zoom 18. The tile buffers stay at FlutterMap's
                            // defaults: the widened ring cost ~4x the tiles at
                            // zoom 18 on a slow mirror, which is what made
                            // zooming laggy and blank-prone.
                            tileProvider: _tileProvider,
                            tileBuilder: (context, tileWidget, tile) =>
                                Transform.translate(
                                  offset: DigosVectorMap.baseMapResidualFor(
                                    MapCamera.of(context).zoom,
                                    tile.coordinates.z,
                                  ),
                                  child: tileWidget,
                                ),
                            // No per-tile fade animation: with many tiles loading during a
                            // drag the animation pass was visible as stutter.
                            tileDisplay: const TileDisplay.instantaneous(),
                            // Offline or rate-limited tiles must never break the map: the
                            // local vector layers keep rendering over the paper background.
                            // No floating offline banner: it covered the legend on
                            // phones and said nothing the map itself did not.
                          ),
                        ),

                      // Inverse mask: hide every tile outside Digos City and
                      // paint the surrounding canvas with the clean gradient.
                      // `PolygonLayer` only fills with a solid colour, so the
                      // inverse ring is drawn by a small custom map layer.
                      _OutsideCityMask(cityRing: _cityRing, dark: dark),

                      // Barangay fills: donor density, with hover and selection states.
                      PolygonLayer(
                        polygons: [
                          for (final feature in _features)
                            _barangayPolygon(feature, dark),
                        ],
                      ),

                      // Internal boundaries. Each ring is drawn once, so a shared
                      // edge doubles up. The light map can afford a soft
                      // hairline, but the dark map needs the cutouts to read, so
                      // the stroke is near-opaque against the dark raster.
                      PolylineLayer(
                        polylines: [
                          for (final arc in _internalBorders)
                            Polyline(
                              points: arc,
                              color:
                                  (dark
                                          ? DigosMapColors.internalBorderDark
                                          : DigosMapColors.internalBorder)
                                      .withValues(alpha: dark ? 0.92 : 0.55),
                              strokeWidth: internalWidth,
                              strokeCap: StrokeCap.round,
                              strokeJoin: StrokeJoin.round,
                            ),
                        ],
                      ),

                      // Heavy outer city border.
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _cityRing,
                            color: dark
                                ? DigosMapColors.cityBorderDark
                                : DigosMapColors.cityBorder,
                            strokeWidth: outerWidth,
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                        ],
                      ),

                      // Drive pins at their venues, above the fills and below the labels.
                      // Two drives in the same barangay are nudged apart so both are
                      // reachable.
                      if (widget.drives.isNotEmpty)
                        MarkerLayer(markers: _driveMarkers(dark, pinScale)),

                      // Hospitals and the PRC chapter, above the fills. The
                      // stored points are true OSM coordinates, so they are
                      // rebased into the nudged map frame first.
                      MarkerLayer(
                        markers: [
                          for (final pin in digosFacilityPins)
                            Marker(
                              point: DigosVectorMap.toMapFrame(pin.point),
                              width: 30 * pinScale,
                              height: 30 * pinScale,
                              child: _FacilityPin(
                                pin: pin,
                                dark: dark,
                                onTap: () => widget.onFacilityTap(pin),
                                scale: pinScale,
                              ),
                            ),
                        ],
                      ),

                      // Barangay names at their representative points; all 26 stay
                      // on the map at every zoom, exactly like the standalone map.
                      MarkerLayer(markers: _labelMarkers(labelSize)),
                    ],
                  ),
                ),
              ),
            ),
            // Distance scale (metric). Pinned low in the bottom-right corner so
            // it stops competing with the map; the tile credit sits directly
            // underneath it. The notifier keeps the label and the drawn line
            // locked to the live camera zoom.
            Positioned(
              right: 8,
              bottom: 22,
              child: ValueListenableBuilder<MapScaleBarScale>(
                valueListenable: _scaleNotifier,
                builder: (context, scale, _) =>
                    _ScaleBar(scale: scale, dark: dark),
              ),
            ),
          ],
        );
      },
    );
  }

  BarangayFeature? _featureAt(LatLng point) {
    for (final feature in _features) {
      if (DigosGeoData.isPointInPolygon(point, feature.ring)) return feature;
    }
    return null;
  }

  /// Barangay name labels.
  ///
  /// The standalone `map/` project draws every barangay name at its
  /// representative point with no collision filtering; this keeps that exact
  /// behaviour so a name never disappears when the user zooms out. The font
  /// grows as the user zooms in, which is what separates the crowded
  /// Poblacion names.
  List<Marker> _labelMarkers(double labelSize) {
    final camera = _cameraOrNull();
    if (camera == null) return const [];
    return [
      for (final feature in _features)
        Marker(
          point: feature.centroid,
          width: 110,
          height: 34,
          child: IgnorePointer(
            child: Center(
              child: _HaloLabel(
                text: _shortName(feature.name),
                fontSize: labelSize,
                dark: widget.mapDark,
              ),
            ),
          ),
        ),
    ];
  }

  /// Venue-accurate drive pins.
  ///
  /// Position is deliberately zoom-independent. The old build compared each
  /// drive against the facility pins in screen space and nudged it until the
  /// glyphs no longer overlapped, so a pin could jump to a different spot on
  /// every zoom level. Separation is now a fixed geographic offset applied
  /// only when a drive and a facility share the same venue, and drives that
  /// share a barangay get a fixed stagger instead.
  List<Marker> _driveMarkers(bool dark, double pinScale) {
    final driveWidth = 30 * pinScale;
    final driveHeight = 38 * pinScale;
    final seenPerBarangay = <String, int>{};
    return [
      for (final drive in widget.drives)
        () {
          final index = seenPerBarangay.update(
            drive.barangay,
            (value) => value + 1,
            ifAbsent: () => 0,
          );
          var point = index == 0
              ? drive.point
              : LatLng(
                  drive.point.latitude + 0.0018 * index,
                  drive.point.longitude + 0.0018 * index,
                );
          point = DigosVectorMap.driveMarkerPoint(point);
          return Marker(
            point: point,
            width: driveWidth,
            height: driveHeight,
            alignment: Alignment.topCenter,
            child: _DrivePin(
              dark: dark,
              tooltip: '${drive.title} · tap for details',
              onTap: () => widget.onDriveTap(drive.barangay),
              scale: pinScale,
            ),
          );
        }(),
    ];
  }

  MapCamera? _cameraOrNull() {
    try {
      return widget.controller.camera;
    } catch (_) {
      // The camera only exists after the map's first build.
      return null;
    }
  }

  Polygon _barangayPolygon(BarangayFeature feature, bool dark) {
    final canonical = _canonicalNames[feature.name];
    final selected = widget.selectedBarangay == canonical;
    final hovered = !selected && _hoveredId == feature.id;

    if (selected) {
      // Subtle teal wash + outline, deliberately distinct from the warm heat
      // ramp and from the old gold/brown treatment.
      return Polygon(
        points: feature.ring,
        color:
            (dark
                    ? DigosMapColors.selectionFillDark
                    : DigosMapColors.selectionFill)
                .withValues(alpha: 0.55),
        borderColor: dark
            ? DigosMapColors.selectionBorderDark
            : DigosMapColors.selectionBorder,
        borderStrokeWidth: 2.4,
      );
    }

    // Staff maps pass requestCounts for the amber request-workload ramp; when
    // they do not (or the legend switch selects donors) the same fill uses the
    // community donor-density ramp.
    final requestCounts = widget.requestCounts;
    final count = requestCounts != null
        ? (requestCounts[canonical] ?? 0)
        : (widget.donorCounts[canonical] ?? 0);
    final base = requestCounts != null
        ? digosRequestColor(count, dark: dark)
        : digosHeatColor(count, dark: dark);
    // Hover is a deliberate preview of a possible selection, not a faint
    // tint. The ring and wash make the barangay under the pointer obvious
    // even over the darkest part of the heat ramp.
    final fill = hovered
        ? Color.alphaBlend(
            (dark ? Colors.white : Colors.black).withValues(
              alpha: dark ? 0.22 : 0.14,
            ),
            base,
          )
        : base;

    return Polygon(
      points: feature.ring,
      // Request fills keep a faint wash even at zero so the amber workload
      // layer reads as "nothing open here" at a glance; the donor ramp lets
      // empty barangays fall back to the streets.
      color: fill.withValues(
        alpha: requestCounts != null
            ? (count == 0 ? 0.10 : digosHeatOpacity(count) + 0.08)
            : digosHeatOpacity(count) + (hovered ? 0.10 : 0),
      ),
      borderColor: hovered
          ? (dark
                ? Colors.white.withValues(alpha: 0.9)
                : TabangColors.crimsonDark)
          : Colors.transparent,
      borderStrokeWidth: hovered ? 2 : 0,
    );
  }

  /// "Zone 2 (Pob.)" → "Zone 2", "Kapatagan (Rizal)" → "Kapatagan".
  String _shortName(String name) => DigosBarangays.canonical(name) ?? name;
}

/// Inverse city mask painted as a clean two-stop gradient.
///
/// `PolygonLayer` only supports a solid fill. The old flat beige mask was the
/// "dirty" band around the city on tall phone maps, so the mask is drawn here
/// with the same camera projection as the vector layers instead.
class _OutsideCityMask extends StatelessWidget {
  const _OutsideCityMask({required this.cityRing, required this.dark});

  final List<LatLng> cityRing;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final camera = MapCamera.of(context);
    return IgnorePointer(
      child: CustomPaint(
        size: Size.infinite,
        painter: _OutsideCityMaskPainter(
          camera: camera,
          cityRing: cityRing,
          gradient: dark
              ? DigosMapColors.outsideGradientDark
              : DigosMapColors.outsideGradient,
        ),
      ),
    );
  }
}

class _OutsideCityMaskPainter extends CustomPainter {
  const _OutsideCityMaskPainter({
    required this.camera,
    required this.cityRing,
    required this.gradient,
  });

  final MapCamera camera;
  final List<LatLng> cityRing;
  final LinearGradient gradient;

  @override
  void paint(Canvas canvas, Size size) {
    final viewport = Offset.zero & size;
    // Everything in the visible canvas except the city ring; see
    // [DigosVectorMap.outsideCityMaskPath] for why the hole is built with the
    // even-odd fill rule instead of `Path.combine`.
    canvas.drawPath(
      DigosVectorMap.outsideCityMaskPath(
        size,
        [for (final point in cityRing) camera.latLngToScreenOffset(point)],
      ),
      Paint()..shader = gradient.createShader(viewport),
    );
  }

  @override
  bool shouldRepaint(_OutsideCityMaskPainter oldDelegate) {
    return oldDelegate.camera != camera ||
        oldDelegate.cityRing != cityRing ||
        oldDelegate.gradient != gradient;
  }
}

/// Raster tile provider that fetches the tile grid shifted by whole tiles.
///
/// Only the URL-facing coordinates change, so [NetworkTileProvider]'s retry,
/// header and progress handling stay intact. The matching sub-tile residual is
/// applied by the tile layer's `tileBuilder`.
class _ShiftedTileProvider extends NetworkTileProvider {
  /// Tiles that are pruned during a fast zoom are allowed to finish loading
  /// instead of being aborted: flutter_map 8.2+ cancels them by default, and a
  /// cancelled load can leave Flutter's image cache holding a dead entry, which
  /// renders as a permanently blank tile until the map is touched again
  /// (fleaflet/flutter_map #2290). The cost is a few wasted requests.
  ///
  /// The flag is a no-op on web (Dart cannot abort in-flight `HttpClient`
  /// requests there) and matters on the Android/iOS builds.
  _ShiftedTileProvider() : super(abortObsoleteRequests: false);

  @override
  String getTileUrl(TileCoordinates coordinates, TileLayer options) {
    final shift = DigosVectorMap.baseMapTileShift(coordinates.z);
    return super.getTileUrl(
      TileCoordinates(
        coordinates.x - shift.x,
        coordinates.y - shift.y,
        coordinates.z,
      ),
      options,
    );
  }

  @override
  String? getTileFallbackUrl(TileCoordinates coordinates, TileLayer options) {
    final shift = DigosVectorMap.baseMapTileShift(coordinates.z);
    return super.getTileFallbackUrl(
      TileCoordinates(
        coordinates.x - shift.x,
        coordinates.y - shift.y,
        coordinates.z,
      ),
      options,
    );
  }
}

/// A drop-shaped drive pin sitting on the venue, tappable for details.
class _DrivePin extends StatelessWidget {
  const _DrivePin({
    required this.dark,
    required this.tooltip,
    required this.onTap,
    this.scale = 1,
  });

  final bool dark;
  final String tooltip;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final color = dark ? DigosMapColors.driveDark : DigosMapColors.drive;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: tooltip,
        child: Center(
          child: SizedBox(
            width: 28 * scale,
            height: 34 * scale,
            child: CustomPaint(painter: _DrivePinPainter(color: color)),
          ),
        ),
      ),
    );
  }
}

/// The pin silhouette with a blood drop under it.
class _DrivePinPainter extends CustomPainter {
  const _DrivePinPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.36);
    final radius = size.width * 0.42;

    canvas.drawCircle(
      center.translate(0, 1.2),
      radius,
      Paint()..color = Colors.black.withValues(alpha: 0.16),
    );
    // `Path` is shadowed by flutter_map's generic Path, so the pin uses
    // dart:ui's Path explicitly.
    final tip = ui.Path()
      ..moveTo(center.dx - radius * 0.55, center.dy + radius * 0.55)
      ..lineTo(center.dx + radius * 0.55, center.dy + radius * 0.55)
      ..lineTo(center.dx, center.dy + radius * 1.6)
      ..close();
    canvas.drawPath(tip, Paint()..color = color);
    canvas.drawCircle(center, radius, Paint()..color = color);

    // Blood drop glyph, drawn rather than fonted so the pin stays crisp at
    // any size.
    final drop = ui.Path()
      ..moveTo(center.dx, center.dy - radius * 0.62)
      ..cubicTo(
        center.dx + radius * 0.5,
        center.dy - radius * 0.05,
        center.dx + radius * 0.42,
        center.dy + radius * 0.45,
        center.dx,
        center.dy + radius * 0.45,
      )
      ..cubicTo(
        center.dx - radius * 0.42,
        center.dy + radius * 0.45,
        center.dx - radius * 0.5,
        center.dy - radius * 0.05,
        center.dx,
        center.dy - radius * 0.62,
      )
      ..close();
    canvas.drawPath(drop, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(_DrivePinPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Haloed barangay label, mirroring the vector map's text-halo treatment.
class _HaloLabel extends StatelessWidget {
  const _HaloLabel({
    required this.text,
    required this.fontSize,
    required this.dark,
  });

  final String text;
  final double fontSize;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final halo = dark ? const ui.Color.fromARGB(255, 48, 47, 47) : DigosMapColors.halo;
    return Stack(
      alignment: Alignment.center,
      children: [
        Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.15,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3
              ..color = halo,
          ),
        ),
        Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.15,
            color: dark ? DigosMapColors.labelDark : DigosMapColors.label,
          ),
        ),
      ],
    );
  }
}

/// Hospital / blood-bank pin: a small white badge with a coloured glyph so it
/// reads as a facility rather than a donor marker.
class _FacilityPin extends StatelessWidget {
  const _FacilityPin({
    required this.pin,
    required this.dark,
    required this.onTap,
    this.scale = 1,
  });

  final DigosFacilityPin pin;
  final bool dark;
  final VoidCallback onTap;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final isChapter = pin.kind == 'chapter';
    final color = dark
        ? (isChapter ? DigosMapColors.chapterDark : DigosMapColors.hospitalDark)
        : (isChapter ? DigosMapColors.chapter : DigosMapColors.hospital);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: pin.name,
        child: Center(
          child: Container(
            width: 25 * scale,
            height: 25 * scale,
            decoration: BoxDecoration(
              color: dark ? const ui.Color.fromARGB(255, 53, 52, 52) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: color,
                width: (2 * scale).clamp(1.0, 2.6),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 4,
                  offset: const Offset(0, 1.5),
                ),
              ],
            ),
            child: Icon(
              isChapter ? Icons.bloodtype : Icons.local_hospital,
              size: 13 * scale,
              color: color,
            ),
          ),
        ),
      ),
    );
  }
}

/// A round distance chosen for the metric scale bar and its on-screen width.
class MapScaleBarScale {
  const MapScaleBarScale({
    required this.distanceMetres,
    required this.width,
    required this.label,
  });

  final double distanceMetres;
  final double width;
  final String label;
}

/// Picks the largest round distance that still fits inside 96 logical pixels.
///
/// Kept public so a widget test can prove the bar never claims one distance
/// while drawing another. The width is *not* clamped after choosing the
/// distance: clamping was what previously let the label and line disagree.
MapScaleBarScale mapScaleBarScale({
  required double zoom,
  required double latitude,
}) {
  // Fine-grained low-end candidates keep the bar honest at street-level zoom.
  const candidates = <double>[
    10,
    20,
    25,
    50,
    100,
    200,
    500,
    1000,
    2000,
    5000,
    10000,
    20000,
  ];
  // Web-mercator metres per logical pixel at this latitude and zoom.
  final metresPerPixel =
      156543.03392 * math.cos(latitude * math.pi / 180) / math.pow(2, zoom);

  var distance = candidates.first;
  for (final candidate in candidates) {
    if (candidate / metresPerPixel <= 96) {
      distance = candidate;
    } else {
      break;
    }
  }
  final width = distance / metresPerPixel;
  final label = distance >= 1000
      ? '${(distance / 1000).toStringAsFixed(distance % 1000 == 0 ? 0 : 1)} km'
      : '${distance.toInt()} m';
  return MapScaleBarScale(distanceMetres: distance, width: width, label: label);
}

/// Metric scale bar: the distance that the drawn line covers on screen.
class _ScaleBar extends StatelessWidget {
  const _ScaleBar({required this.scale, required this.dark});

  final MapScaleBarScale scale;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final color = dark ? const Color(0xFFD9CFC9) : const Color(0xFF3A2C28);
    return Container(
      key: const ValueKey('mapScaleBar'),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: (dark ? const ui.Color.fromARGB(255, 54, 54, 54) : const Color(0xFFFFFFFF))
            .withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Centred above the ruler, the way a printed map-scale label reads.
          // The old inline label made the line look like a separate rule.
          Text(
            scale.label,
            key: const ValueKey('mapScaleBarLabel'),
            style: TextStyle(
              fontSize: 8.5,
              height: 1.1,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            key: const ValueKey('mapScaleBarLine'),
            width: scale.width,
            height: 4,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: color, width: 1.2),
                right: BorderSide(color: color, width: 1.2),
                bottom: BorderSide(color: color, width: 1.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Attribution required by the base-map and OpenStreetMap data licences.
class DigosMapAttribution extends StatelessWidget {
  const DigosMapAttribution({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        '© OpenStreetMap contributors',
        style: TextStyle(fontSize: 7.5, height: 1, color: context.textMuted),
      ),
    );
  }
}
