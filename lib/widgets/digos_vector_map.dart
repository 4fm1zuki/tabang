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
class DigosMapColors {
  const DigosMapColors._();

  /// Paper matches the standalone map project exactly, so the inverse mask is
  /// invisible against the surrounding surface.
  static const Color paper = Color(0xFFF6F7F3);
  static const Color paperDark = Color(0xFF171312);
  static const Color internalBorder = Color(0xFFD08A76);
  static const Color internalBorderDark = Color(0xFF8E5A4B);
  static const Color cityBorder = Color(0xFF5A1512);
  static const Color cityBorderDark = Color(0xFFFFDAD4);
  static const Color label = Color(0xFF2B211E);
  static const Color labelDark = Color(0xFFFBF5F2);
  static const Color halo = Color(0xFFFBF7F4);
  static const Color haloDark = Color(0xFF171312);

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

  /// Base-map tint from the standalone map project: a warm, low-contrast
  /// street template so roads, water, buildings and land use stay visible
  /// under the barangay fills.
  static const List<double> lightTileFilter = <double>[
    0.575,
    0.422,
    0.043,
    0,
    -6,
    0.125,
    0.872,
    0.043,
    0,
    -4,
    0.125,
    0.422,
    0.493,
    0,
    -8,
    0.000,
    0.000,
    0.000,
    1,
    0,
  ];

  /// Inverted, dimmed tiles for the dark map style.
  static const List<double> darkTileFilter = <double>[
    -0.300,
    -0.300,
    -0.300,
    0,
    96,
    -0.300,
    -0.300,
    -0.300,
    0,
    90,
    -0.300,
    -0.300,
    -0.300,
    0,
    82,
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
    this.onInteractionStart,
    this.onInteractionEnd,
  });

  /// Owned by the page so its zoom/compass buttons can drive the camera.
  final MapController controller;

  /// Canonical barangay name → eligible donors.
  final Map<String, int> donorCounts;

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

  /// The camera fit that frames the whole city, using the same bounds as the
  /// standalone `map/` project so the framing matches the previous map.
  static final LatLngBounds cityBounds = LatLngBounds(
    const LatLng(6.71695, 125.2524),
    const LatLng(6.9874, 125.3930),
  );

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
        padding: const EdgeInsets.all(40),
        // Same cap as the standalone map. The one-time re-fit after the first
        // real layout (@see _fitOnceMeasured) means an early zero-sized
        // layout can no longer leave the city framed at street level.
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

  int? _hoveredId;
  double _zoom = 11;

  /// Tile loading state, used only to explain a blank base map.
  int _tileFailures = 0;
  bool _tileWarned = false;

  /// Map widget size, used to reject labels that would fall off the canvas.
  Size? _mapSize;
  bool _firstFrameDone = false;

  /// `initialCameraFit` is computed before the map has a real size when the
  /// page is restored straight into Find Donor, which used to leave the city
  /// framed too small. Once a valid layout size exists, re-fit exactly once.
  bool _didInitialFit = false;

  void _fitOnceMeasured() {
    if (_didInitialFit) return;
    final size = _mapSize;
    if (size == null || size.width < 50 || size.height < 50) return;
    _didInitialFit = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        DigosVectorMap.fitCity(widget.controller);
      } catch (_) {
        // The camera may not exist on the very first frame; the next layout
        // will schedule another attempt.
        _didInitialFit = false;
      }
    });
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
    final internalWidth = _lerp(9, 1.2, 18, 2.6);
    final outerWidth = _lerp(9, 2.2, 18, 4.0);
    final labelSize = _lerp(10.5, 9.5, 18, 15);
    // Pins shrink with the map so a city-wide view does not drown in markers,
    // and grow back to full size once the user is at street level.
    final pinScale = _lerp(10.5, 0.62, 14, 1.0);

    return LayoutBuilder(
      builder: (context, constraints) {
        _mapSize = constraints.biggest;
        _fitOnceMeasured();
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            // A pointing-hand cursor while a barangay is under the mouse makes
            // "click to select a region" discoverable; elsewhere the map shows
            // the grab cursor that matches dragging.
            MouseRegion(
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
                  backgroundColor: dark
                      ? DigosMapColors.paperDark
                      : DigosMapColors.paper,
                  initialCameraFit: CameraFit.bounds(
                    // Same framing as the standalone map project.
                    bounds: DigosVectorMap.cityBounds,
                    padding: const EdgeInsets.all(40),
                    maxZoom: 13,
                  ),
                  interactionOptions: const InteractionOptions(
                    flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                  ),
                  onPositionChanged: (camera, hasGesture) {
                    if ((camera.zoom - _zoom).abs() > 0.05) {
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
                    // Street base exactly as the standalone map project renders
                    // it. The warm, low-contrast matrix keeps roads, water,
                    // buildings and land use visible underneath the barangay
                    // fills while muting the Carto style's farmland hatching and
                    // baked-in place names, so TABANG's labels stay the names
                    // that stand out.
                    ColorFiltered(
                      colorFilter: ColorFilter.matrix(
                        dark
                            ? DigosMapColors.darkTileFilter
                            : DigosMapColors.lightTileFilter,
                      ),
                      child: TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.digos.barangay_map',
                        maxNativeZoom: 19,
                        // No per-tile fade animation: with many tiles loading during a
                        // drag the animation pass was visible as stutter.
                        tileDisplay: const TileDisplay.instantaneous(),
                        // Offline or rate-limited tiles must never break the map: the
                        // local vector layers keep rendering over the paper background.
                        // A few failures in a row also raise a small "base map offline"
                        // note so a blank base is explained rather than mysterious.
                        errorTileCallback: (tile, error, stackTrace) {
                          _tileFailures++;
                          if (!_tileWarned && _tileFailures >= 4 && mounted) {
                            setState(() => _tileWarned = true);
                          }
                        },
                      ),
                    ),

                  // Inverse mask: hide every tile outside Digos City. (Alt rendering
                  // triangulates the polygon and showed visible seams across the city,
                  // so the simplified ring does the heavy lifting instead.)
                  PolygonLayer(
                    polygons: [
                      Polygon(
                        points: const [
                          LatLng(5.0, 123.0),
                          LatLng(5.0, 127.0),
                          LatLng(9.0, 127.0),
                          LatLng(9.0, 123.0),
                        ],
                        holePointsList: [_cityRing],
                        color: dark
                            ? DigosMapColors.paperDark
                            : DigosMapColors.paper,
                        borderStrokeWidth: 0,
                      ),
                    ],
                  ),

                  // Barangay fills: donor density, with hover and selection states.
                  PolygonLayer(
                    polygons: [
                      for (final feature in _features)
                        _barangayPolygon(feature, dark),
                    ],
                  ),

                  // Internal boundaries. Each ring is drawn once, so a shared
                  // edge doubles up; the half-opacity stroke keeps the result a
                  // soft hairline instead of a heavy wall between barangays.
                  PolylineLayer(
                    polylines: [
                      for (final arc in _internalBorders)
                        Polyline(
                          points: arc,
                          color:
                              (dark
                                      ? DigosMapColors.internalBorderDark
                                      : DigosMapColors.internalBorder)
                                  .withValues(alpha: 0.55),
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

                  // Hospitals and the PRC chapter, above the fills.
                  MarkerLayer(
                    markers: [
                      for (final pin in digosFacilityPins)
                        Marker(
                          point: pin.point,
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
            // Distance scale (metric). On a short map pane the compact legend
            // and the attribution stack along the bottom, so the bar sits
            // above both instead of on top of them.
            Positioned(
              right: 10,
              bottom: (_mapSize?.height ?? 500) < 430 ? 96 : 34,
              child: _ScaleBar(
                zoom: _zoom,
                latitude: _cameraOrNull()?.center.latitude ?? 6.84,
                dark: dark,
              ),
            ),
            if (_tileWarned && DigosVectorMap.tilesEnabled)
              Positioned(
                right: 10,
                bottom: (_mapSize?.height ?? 500) < 430 ? 128 : 66,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: dark
                        ? const Color(0xFF241C1A)
                        : const Color(0xFFFFFFFF).withValues(alpha: 0.92),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: dark
                          ? const Color(0xFF4A3B36)
                          : const Color(0xFFE0D5CE),
                    ),
                  ),
                  child: Text(
                    'Base map offline — showing vector layers',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: dark
                          ? const Color(0xFFD9CFC9)
                          : const Color(0xFF5A4F4B),
                    ),
                  ),
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

  /// Venue-accurate drive pins, separated when a barangay hosts several or
  /// when a hospital/PRC pin already occupies the same spot. The glyph scales
  /// with the zoom so wide views stay readable.
  List<Marker> _driveMarkers(bool dark, double pinScale) {
    final camera = _cameraOrNull();
    final driveWidth = 30 * pinScale;
    final driveHeight = 38 * pinScale;
    final driveHitHeight = 42 * pinScale;
    final facilityRects = camera == null
        ? const <Rect>[]
        : [
            for (final pin in digosFacilityPins)
              _screenRect(camera, pin.point, 30 * pinScale, 30 * pinScale),
          ];
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
          if (camera != null && facilityRects.isNotEmpty) {
            final base = _screenCenter(camera, point);
            final rect = Rect.fromCenter(
              center: base,
              width: driveWidth,
              height: driveHitHeight,
            );
            if (facilityRects.any((facility) => facility.overlaps(rect))) {
              // Step off the facility pin in the first direction that clears
              // it. The drive stays inside its barangay; only the pin glyph
              // moves, so both venues remain tappable.
              for (final nudge in const [
                Offset(0, -40),
                Offset(20, -30),
                Offset(-20, -30),
                Offset(0, 44),
                Offset(24, 0),
                Offset(-24, 0),
              ]) {
                final scaled = nudge * pinScale;
                point = camera.pointToLatLng(
                  math.Point(base.dx + scaled.dx, base.dy + scaled.dy),
                );
                final nudgedRect = Rect.fromCenter(
                  center: base + scaled,
                  width: driveWidth,
                  height: driveHitHeight,
                );
                if (!facilityRects.any(
                  (facility) => facility.overlaps(nudgedRect),
                )) {
                  break;
                }
              }
            }
          }
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

  /// Screen position of [point] in the map's local coordinate space.
  Offset _screenCenter(MapCamera camera, LatLng point) {
    final projected = camera.project(point);
    final origin = camera.pixelOrigin;
    return Offset(projected.x - origin.x, projected.y - origin.y);
  }

  Rect _screenRect(
    MapCamera camera,
    LatLng point,
    double width,
    double height,
  ) {
    return Rect.fromCenter(
      center: _screenCenter(camera, point),
      width: width,
      height: height,
    );
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

    final count = widget.donorCounts[canonical] ?? 0;
    final base = digosHeatColor(count, dark: dark);
    final fill = hovered
        ? Color.alphaBlend(
            (dark ? Colors.white : Colors.black).withValues(alpha: 0.08),
            base,
          )
        : base;

    return Polygon(
      points: feature.ring,
      // Translucent so the street map stays visible underneath.
      color: fill.withValues(alpha: digosHeatOpacity(count)),
      borderStrokeWidth: 0,
    );
  }

  /// "Zone 2 (Pob.)" → "Zone 2", "Kapatagan (Rizal)" → "Kapatagan".
  String _shortName(String name) => DigosBarangays.canonical(name) ?? name;
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
    final halo = dark ? DigosMapColors.haloDark : DigosMapColors.halo;
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
              color: dark ? const Color(0xFF241C1A) : Colors.white,
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

/// Metric scale bar: the distance that the drawn line covers on screen.
class _ScaleBar extends StatelessWidget {
  const _ScaleBar({
    required this.zoom,
    required this.latitude,
    required this.dark,
  });

  final double zoom;
  final double latitude;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    const candidates = <double>[
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
      if (candidate / metresPerPixel <= 96) distance = candidate;
    }
    final barWidth = (distance / metresPerPixel).clamp(24.0, 120.0);
    final label = distance >= 1000
        ? '${(distance / 1000).toStringAsFixed(distance % 1000 == 0 ? 0 : 1)} km'
        : '${distance.toInt()} m';

    final color = dark ? const Color(0xFFD9CFC9) : const Color(0xFF3A2C28);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: (dark ? const Color(0xFF241C1A) : const Color(0xFFFFFFFF))
            .withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (dark ? const Color(0xFF4A3B36) : const Color(0xFFE0D5CE)),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Container(
            width: barWidth,
            height: 6,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: color, width: 1.6),
                right: BorderSide(color: color, width: 1.6),
                bottom: BorderSide(color: color, width: 1.6),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(TabangRadius.xs),
        border: Border.all(color: context.border),
      ),
      child: Text(
        '© OpenStreetMap contributors',
        style: TextStyle(fontSize: 8.5, height: 1.1, color: context.textMuted),
      ),
    );
  }
}
