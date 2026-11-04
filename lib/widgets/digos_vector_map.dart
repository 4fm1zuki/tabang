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
  /// street template so roads, water and buildings stay visible under the
  /// barangay fills. (The previous matrix brightened the tiles into near-white,
  /// which is why the base looked like a plain outline.)
  static const List<double> lightTileFilter = <double>[
    0.575, 0.422, 0.043, 0, -6,
    0.125, 0.872, 0.043, 0, -4,
    0.125, 0.422, 0.493, 0, -8,
    0.000, 0.000, 0.000, 1, 0,
  ];

  /// Inverted, dimmed tiles for the dark map style.
  static const List<double> darkTileFilter = <double>[
    -0.300, -0.300, -0.300, 0, 96,
    -0.300, -0.300, -0.300, 0, 90,
    -0.300, -0.300, -0.300, 0, 82,
    0.000, 0.000, 0.000, 1, 0,
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
const List<DigosFacilityPin> digosFacilityPins = [
  DigosFacilityPin(
    name: 'Philippine Red Cross — Davao del Sur Chapter',
    kind: 'chapter',
    point: LatLng(6.7508, 125.3527),
    note: 'Blood bank and donation site · walk-ins welcome',
  ),
  DigosFacilityPin(
    name: 'Digos Provincial Hospital',
    kind: 'hospital',
    point: LatLng(6.7552, 125.3492),
    note: 'Participating hospital · accepts blood-bank releases',
  ),
  DigosFacilityPin(
    name: 'Digos Doctors Hospital',
    kind: 'hospital',
    point: LatLng(6.7459, 125.3568),
    note: 'Participating hospital · accepts blood-bank releases',
  ),
  DigosFacilityPin(
    name: 'Cor Jesu College Infirmary',
    kind: 'hospital',
    point: LatLng(6.7446, 125.3602),
    note: 'Participating infirmary · student and community referrals',
  ),
];

/// How much of the base map each density band lets through.
///
/// The fills used to be fully opaque, which hid the OpenStreetMap layer
/// completely: the base map was there but no street ever showed. Empty
/// barangays are almost transparent (like the standalone map project's 5.5%
/// fill) and the fills build up as donor density rises.
double digosHeatOpacity(int count) {
  if (count == 0) return 0.10;
  if (count <= 2) return 0.45;
  if (count <= 5) return 0.62;
  if (count <= 9) return 0.78;
  return 0.88;
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
    required this.driveCounts,
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

  /// Canonical barangay name → active drives.
  final Map<String, int> driveCounts;

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

  /// The camera fit that frames the whole city.
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
List<LatLng>? _cityRingCache;

List<BarangayFeature> _barangayFeatures() =>
    _barangayFeaturesCache ??= DigosGeoData.buildBarangays();

/// Douglas–Peucker simplification for the city outline.
///
/// The stitched ring carries ~1000 points, and the mask polygon (a huge
/// rectangle with that ring as a hole) is re-tessellated whenever the camera
/// moves. Simplifying to a sub-pixel tolerance at the city-wide zoom cuts the
/// work dramatically while keeping the outline visually identical.
List<LatLng> _simplifyRing(List<LatLng> points, double epsilon) {
  if (points.length < 4) return points;

  double perpendicularDistance(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final norm = math.sqrt(dx * dx + dy * dy);
    if (norm == 0) {
      return math.sqrt(
        math.pow(p.longitude - a.longitude, 2) +
            math.pow(p.latitude - a.latitude, 2),
      );
    }
    return ((p.longitude - a.longitude) * dy -
                (p.latitude - a.latitude) * dx)
            .abs() /
        norm;
  }

  final keep = List<bool>.filled(points.length, false);
  keep[0] = true;
  keep[points.length - 1] = true;

  final stack = <List<int>>[
    [0, points.length - 1],
  ];
  while (stack.isNotEmpty) {
    final range = stack.removeLast();
    final first = range[0];
    final last = range[1];
    var maxDistance = 0.0;
    var index = -1;
    for (var i = first + 1; i < last; i++) {
      final distance = perpendicularDistance(
        points[i],
        points[first],
        points[last],
      );
      if (distance > maxDistance) {
        maxDistance = distance;
        index = i;
      }
    }
    if (index != -1 && maxDistance > epsilon) {
      keep[index] = true;
      stack
        ..add([first, index])
        ..add([index, last]);
    }
  }

  final simplified = <LatLng>[
    for (var i = 0; i < points.length; i++)
      if (keep[i]) points[i],
  ];
  if (simplified.length < 3) return points;
  return simplified;
}

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
    _cityRingCache ??= _simplifyRing(
      DigosGeoData.stitchRing(DigosGeoData.cityArcs),
      0.00035,
    );
    _features = _barangayFeatures();
    _internalBorders = _internalBordersCache!;
    _cityRing = _cityRingCache!;
    _canonicalNames = {
      for (final feature in _features)
        feature.name:
            DigosBarangays.canonical(feature.name) ?? feature.name,
    };
  }

  double _lerp(double minZoom, double minValue, double maxZoom, double maxValue) {
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
    final internalWidth = _lerp(9, 1.2, 14, 2.2);
    final outerWidth = _lerp(9, 2.2, 14, 3.4);
    final labelSize = _lerp(10, 9.5, 13, 11.5);

    return LayoutBuilder(
      builder: (context, constraints) {
        _mapSize = constraints.biggest;
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            FlutterMap(
              mapController: widget.controller,
      options: MapOptions(
        initialCenter: const LatLng(6.84, 125.33),
        initialZoom: 11,
        // Proper zoom limit: stay within useful tile detail, and never lose
        // the city in the masked paper around it.
        minZoom: 10,
        maxZoom: 16,
        cameraConstraint: CameraConstraint.containCenter(
          bounds: LatLngBounds(
            const LatLng(6.68, 125.20),
            const LatLng(7.03, 125.44),
          ),
        ),
        backgroundColor: dark ? DigosMapColors.paperDark : DigosMapColors.paper,
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
          // Base template exactly as the standalone map project renders it:
          // the warm, low-contrast matrix keeps roads, water and buildings
          // visible underneath the barangay fills.
          ColorFiltered(
            colorFilter: ColorFilter.matrix(
              dark
                  ? DigosMapColors.darkTileFilter
                  : DigosMapColors.lightTileFilter,
            ),
            child: TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
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

        // Inverse mask: hide every tile outside Digos City. Alternative
        // rendering is markedly faster for a polygon with a hole on web.
        PolygonLayer(
          useAltRendering: true,
          polygons: [
            Polygon(
              points: const [
                LatLng(5.0, 123.0),
                LatLng(5.0, 127.0),
                LatLng(9.0, 127.0),
                LatLng(9.0, 123.0),
              ],
              holePointsList: [_cityRing],
              color: dark ? DigosMapColors.paperDark : DigosMapColors.paper,
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

        // Internal boundaries, drawn once per shared edge.
        PolylineLayer(
          polylines: [
            for (final arc in _internalBorders)
              Polyline(
                points: arc,
                color: (dark
                        ? DigosMapColors.internalBorderDark
                        : DigosMapColors.internalBorder)
                    .withValues(alpha: 0.85),
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

        // Drive pins above the fills, below the labels.
        if (widget.driveCounts.isNotEmpty)
          MarkerLayer(
            markers: [
              for (final feature in _features)
                if ((widget.driveCounts[_canonicalNames[feature.name]] ?? 0) > 0)
                  Marker(
                    point: feature.centroid,
                    width: 34,
                    height: 42,
                    alignment: Alignment.topCenter,
                    child: _DrivePin(
                      count: widget.driveCounts[_canonicalNames[feature.name]]!,
                      dark: dark,
                      onTap: () =>
                          widget.onDriveTap(_canonicalNames[feature.name]!),
                    ),
                  ),
            ],
          ),

        // Hospitals and the PRC chapter, above the fills.
        MarkerLayer(
          markers: [
            for (final pin in digosFacilityPins)
              Marker(
                point: pin.point,
                width: 30,
                height: 30,
                child: _FacilityPin(
                  pin: pin,
                  dark: dark,
                  onTap: () => widget.onFacilityTap(pin),
                ),
              ),
          ],
        ),

        // Barangay labels, collision-checked: small barangays only appear as
        // the user zooms in and a name is dropped rather than stacked on top
        // of a neighbour.
                MarkerLayer(markers: _labelMarkers(labelSize)),
              ],
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
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
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

  // Label placement is memoised: hovering a barangay must not re-measure all
  // 26 labels, and panning must not rebuild them at all.
  List<Marker>? _labelCache;
  double _labelCacheZoom = -1;
  String? _labelCacheSelected;
  bool? _labelCacheDark;
  Map<String, int>? _labelCacheDonors;
  Map<String, int>? _labelCacheDrives;
  Size? _labelCacheSize;
  String? _labelCacheCenter;

  /// Barangay label markers with greedy collision rejection in screen space.
  ///
  /// The old layer drew every candidate at its centroid, which piled "Zone 1
  /// (Pob.) / Zone 2 (Pob.) / Sinawilan / Aplaya" on top of each other in the
  /// city proper. Labels are sorted by area (biggest first), so the large
  /// barangays always win a slot.
  List<Marker> _labelMarkers(double labelSize) {
    final camera = _cameraOrNull();
    // Panning only invalidates the cache every ~1 km, so a drag does not
    // re-measure 26 labels on every frame.
    final centerKey = camera == null
        ? ''
        : '${camera.center.latitude.toStringAsFixed(2)},'
            '${camera.center.longitude.toStringAsFixed(2)}';

    final cached = _labelCache;
    if (cached != null &&
        _labelCacheZoom == _zoom &&
        _labelCacheSelected == widget.selectedBarangay &&
        _labelCacheDark == widget.mapDark &&
        identical(_labelCacheDonors, widget.donorCounts) &&
        identical(_labelCacheDrives, widget.driveCounts) &&
        _labelCacheSize == _mapSize &&
        _labelCacheCenter == centerKey) {
      return cached;
    }
    _labelCacheZoom = _zoom;
    _labelCacheSelected = widget.selectedBarangay;
    _labelCacheDark = widget.mapDark;
    _labelCacheDonors = widget.donorCounts;
    _labelCacheDrives = widget.driveCounts;
    _labelCacheSize = _mapSize;
    _labelCacheCenter = centerKey;
    final placed = <Rect>[];
    final markers = <Marker>[];

    // Reserve the pin footprints so a name never lands under a pin.
    if (camera != null) {
      for (final pin in digosFacilityPins) {
        placed.add(_screenRect(camera, pin.point, 30, 30));
      }
      for (final feature in _features) {
        if ((widget.driveCounts[_canonicalNames[feature.name]] ?? 0) > 0) {
          placed.add(_screenRect(camera, feature.centroid, 34, 46));
        }
      }
    }

    // Selected barangay first, then biggest area first, so the names that
    // matter most always win a slot.
    final selectedName = widget.selectedBarangay;
    final ordered = [..._features]
      ..sort((a, b) {
        final aSelected = _canonicalNames[a.name] == selectedName;
        final bSelected = _canonicalNames[b.name] == selectedName;
        if (aSelected != bSelected) return aSelected ? -1 : 1;
        return _ringArea(b).compareTo(_ringArea(a));
      });

    final bounds = _mapSize;
    for (final feature in ordered) {
      final text = _shortName(feature.name);
      // Try the full size first, then a smaller one, so names in the crowded
      // city proper still appear instead of being dropped outright.
      for (final size in <double>[labelSize, labelSize * 0.8]) {
        final width = text.length * size * 0.62 + 14;
        final height = size * 1.9;

        if (camera != null && bounds != null) {
          final rect = _screenRect(camera, feature.centroid, width, height);
          final canvasRect = Offset.zero & bounds;
          if (!canvasRect.deflate(4).overlaps(rect)) break;
          if (placed.any((other) => other.overlaps(rect))) continue;
          placed.add(rect);
        }

        markers.add(
          Marker(
            point: feature.centroid,
            width: width + 12,
            height: height,
            child: IgnorePointer(
              child: _HaloLabel(
                text: text,
                fontSize: size,
                dark: widget.mapDark,
              ),
            ),
          ),
        );
        break;
      }
    }
    _labelCache = markers;
    return markers;
  }

  Rect _screenRect(MapCamera camera, LatLng point, double width, double height) {
    final projected = camera.project(point);
    final origin = camera.pixelOrigin;
    return Rect.fromCenter(
      center: Offset(projected.x - origin.x, projected.y - origin.y),
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

  final Map<int, double> _areaCache = {};

  double _ringArea(BarangayFeature feature) {
    return _areaCache.putIfAbsent(feature.id, () {
      var minLat = double.infinity, maxLat = -double.infinity;
      var minLng = double.infinity, maxLng = -double.infinity;
      for (final point in feature.ring) {
        minLat = math.min(minLat, point.latitude);
        maxLat = math.max(maxLat, point.latitude);
        minLng = math.min(minLng, point.longitude);
        maxLng = math.max(maxLng, point.longitude);
      }
      return (maxLat - minLat) * (maxLng - minLng);
    });
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
        color: (dark
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
  String _shortName(String name) =>
      DigosBarangays.canonical(name) ?? name;
}

/// A map pin with the active-drive count, tappable to open the drives sheet.
class _DrivePin extends StatelessWidget {
  const _DrivePin({
    required this.count,
    required this.dark,
    required this.onTap,
  });

  final int count;
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = dark ? DigosMapColors.driveDark : DigosMapColors.drive;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Tooltip(
        message: '$count active drive${count == 1 ? '' : 's'} · tap for '
            'details',
        child: Center(
          child: SizedBox(
            width: 30,
            height: 36,
            child: CustomPaint(
              painter: _DrivePinPainter(color: color, count: count, dark: dark),
            ),
          ),
        ),
      ),
    );
  }
}

class _DrivePinPainter extends CustomPainter {
  const _DrivePinPainter({
    required this.color,
    required this.count,
    required this.dark,
  });

  final Color color;
  final int count;
  final bool dark;

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
    canvas.drawCircle(
      center,
      radius * 0.62,
      Paint()
        ..color = dark ? const Color(0xFF2A1512) : Colors.white,
    );

    final painter = TextPainter(
      text: TextSpan(
        text: '$count',
        style: TextStyle(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w800,
          color: dark ? const Color(0xFFFFDAD4) : DigosMapColors.drive,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center.translate(-painter.width / 2, -painter.height / 2),
    );
  }

  @override
  bool shouldRepaint(_DrivePinPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.count != count ||
      oldDelegate.dark != dark;
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
  });

  final DigosFacilityPin pin;
  final bool dark;
  final VoidCallback onTap;

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
            width: 25,
            height: 25,
            decoration: BoxDecoration(
              color: dark ? const Color(0xFF241C1A) : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 2),
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
              size: 13,
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
      50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000,
    ];
    // Web-mercator metres per logical pixel at this latitude and zoom.
    final metresPerPixel = 156543.03392 *
        math.cos(latitude * math.pi / 180) /
        math.pow(2, zoom);

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
        color: (dark
                ? const Color(0xFF241C1A)
                : const Color(0xFFFFFFFF))
            .withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: (dark
                  ? const Color(0xFF4A3B36)
                  : const Color(0xFFE0D5CE)),
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

/// Attribution required by the OpenStreetMap tile usage policy.
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
        style: TextStyle(
          fontSize: 8.5,
          height: 1.1,
          color: context.textMuted,
        ),
      ),
    );
  }
}
