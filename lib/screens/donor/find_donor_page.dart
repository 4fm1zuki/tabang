import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';

/// Interactive offline map of Digos City.
///
/// The previous build depended on the Google Maps SDK for a barangay
/// choropleth. That required an API key, pulled tiles from the network, was
/// unavailable on Windows/Linux/macOS, and its web platform view was the
/// source of the tab-switch freeze. This version renders the bundled
/// `assets/maps/digos_barangays.geojson` directly with a [CustomPainter]:
///
///  * no API key, no network, works on every platform including desktop,
///  * all 26 barangays shaded by eligible-donor count and labelled by name,
///  * tap a barangay to filter the donor list, pinch or use the buttons to
///    zoom, and
///  * a light city overlay — the Digos River, the Davao–Cotabato road and a
///    few landmarks — so the map reads as a place rather than a diagram.
class FindDonorPage extends StatefulWidget {
  const FindDonorPage({super.key, required this.user});

  final AppUser user;

  @override
  State<FindDonorPage> createState() => _FindDonorPageState();
}

class _FindDonorPageState extends State<FindDonorPage> {
  final TabangRepository _repo = TabangRepository.instance;
  final TransformationController _viewController = TransformationController();

  Map<String, List<List<_LatLng>>> _boundaries = {};
  Map<String, int> _donorCounts = {};

  /// One label anchor per barangay, placed at the interior point furthest
  /// from any edge. A plain centroid falls outside concave barangays, which
  /// is why names looked like they belonged to a neighbour.
  Map<String, _LatLng> _labelAnchors = {};

  bool _loading = true;
  String? _loadError;

  BloodType? _bloodType;
  String? _selectedBarangay;
  String _query = '';
  bool _donorsCollapsed = false;

  Size _viewportSize = Size.zero;

  /// Raw pointer bookkeeping for map taps. A [Listener] is used instead of a
  /// tap recognizer so the zoom/pan gesture arena can never swallow a click.
  Offset? _pointerDownPosition;

  /// Parsed GeoJSON is immutable and shared by every page instance.
  static Map<String, List<List<_LatLng>>>? _boundaryCache;
  static Map<String, _LatLng>? _anchorCache;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
    _loadBoundaries();
    _refreshCounts();
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    _viewController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (!mounted) return;
    _refreshCounts();
    setState(() {});
  }

  void _refreshCounts() {
    _donorCounts = _repo.donorCountsByBarangay(bloodType: _bloodType);
  }

  Future<void> _loadBoundaries() async {
    final cached = _boundaryCache;
    if (cached != null) {
      _anchorsFor(cached);
      setState(() {
        _boundaries = cached;
        _labelAnchors = _anchorCache ?? {};
        _loading = false;
        _loadError = null;
      });
      return;
    }

    try {
      final raw = await rootBundle.loadString(
        'assets/maps/digos_barangays.geojson',
      );
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final features = (decoded['features'] as List<dynamic>?) ?? const [];

      final parsed = <String, List<List<_LatLng>>>{};

      for (final feature in features) {
        if (feature is! Map<String, dynamic>) continue;
        final props =
            (feature['properties'] as Map<String, dynamic>?) ?? const {};
        final rawName = props['NAME_3'] ?? props['name'] ?? props['NAME'];
        final name = DigosBarangays.canonical(rawName?.toString());
        if (name == null) continue;

        final geometry = feature['geometry'] as Map<String, dynamic>?;
        if (geometry == null) continue;

        final type = geometry['type']?.toString() ?? '';
        final coords = geometry['coordinates'];

        final rings = <List<_LatLng>>[];
        if (type == 'Polygon') {
          rings.addAll(_parsePolygon(coords));
        } else if (type == 'MultiPolygon' && coords is List) {
          for (final poly in coords) {
            rings.addAll(_parsePolygon(poly));
          }
        }

        if (rings.isNotEmpty) {
          parsed.putIfAbsent(name, () => []).addAll(rings);
        }
      }

      if (!mounted) return;
      if (parsed.isNotEmpty) {
        _boundaryCache = parsed;
        _anchorsFor(parsed);
      }
      setState(() {
        _boundaries = parsed;
        _labelAnchors = _anchorCache ?? {};
        _loading = false;
        _loadError = parsed.isEmpty
            ? 'The barangay boundary file loaded but contained no usable '
                'polygons.'
            : null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError =
            'Could not load barangay boundaries from '
            'assets/maps/digos_barangays.geojson.\n\n$error';
      });
    }
  }

  List<List<_LatLng>> _parsePolygon(dynamic coordinates) {
    if (coordinates is! List || coordinates.isEmpty) return const [];
    final outer = coordinates.first;
    if (outer is! List || outer.isEmpty) return const [];

    final points = <_LatLng>[];
    for (final coord in outer) {
      if (coord is List && coord.length >= 2) {
        final lng = _toDouble(coord[0]);
        final lat = _toDouble(coord[1]);
        if (lng != null && lat != null) {
          points.add(_LatLng(lat, lng));
        }
      }
    }
    if (points.length < 3) return const [];
    return [points];
  }

  double? _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '');
  }

  List<AppUser> get _visibleDonors {
    return _repo.findDonors(
      bloodType: _bloodType,
      barangay: _selectedBarangay,
    ).where((donor) {
      if (_query.isEmpty) return true;
      final q = _query.toLowerCase();
      return donor.alias.toLowerCase().contains(q) ||
          (donor.shareBarangay &&
              donor.barangay.toLowerCase().contains(q)) ||
          (donor.bloodType?.label.toLowerCase().contains(q) ?? false);
    }).toList();
  }

  _Projection _projectionFor(Size size) {
    return _Projection(
      bounds: _Bounds.fromBoundaries(_boundaries),
      size: size,
      padding: 18,
    );
  }

  void _handleMapTap(Offset localPosition, Size size) {
    if (_boundaries.isEmpty) return;
    final projection = _projectionFor(size);
    final point = projection.toLatLng(localPosition);
    final hit = _barangayAt(point);
    setState(() {
      _selectedBarangay = hit == _selectedBarangay ? null : hit;
    });
  }

  String? _barangayAt(_LatLng point) {
    for (final entry in _boundaries.entries) {
      for (final ring in entry.value) {
        if (_pointInRing(point, ring)) return entry.key;
      }
    }
    return null;
  }

  bool _pointInRing(_LatLng point, List<_LatLng> ring) {
    var inside = false;
    for (var i = 0, j = ring.length - 1; i < ring.length; j = i++) {
      final a = ring[i];
      final b = ring[j];
      final intersects = ((a.lat > point.lat) != (b.lat > point.lat)) &&
          (point.lng <
              (b.lng - a.lng) * (point.lat - a.lat) / (b.lat - a.lat) + a.lng);
      if (intersects) inside = !inside;
    }
    return inside;
  }

  void _anchorsFor(Map<String, List<List<_LatLng>>> boundaries) {
    _anchorCache ??= _computeLabelAnchors(boundaries);
  }

  /// Samples a grid inside each barangay and keeps the point furthest from
  /// any boundary edge, so the name always sits well inside its own area even
  /// when the polygon is concave.
  Map<String, _LatLng> _computeLabelAnchors(
    Map<String, List<List<_LatLng>>> boundaries,
  ) {
    final anchors = <String, _LatLng>{};
    boundaries.forEach((name, rings) {
      var largest = <_LatLng>[];
      for (final ring in rings) {
        if (ring.length > largest.length) largest = ring;
      }
      if (largest.length < 3) return;

      var minLat = double.infinity, maxLat = -double.infinity;
      var minLng = double.infinity, maxLng = -double.infinity;
      for (final point in largest) {
        minLat = math.min(minLat, point.lat);
        maxLat = math.max(maxLat, point.lat);
        minLng = math.min(minLng, point.lng);
        maxLng = math.max(maxLng, point.lng);
      }

      _LatLng? best;
      var bestDistance = -1.0;
      const steps = 18;
      for (var i = 1; i < steps; i++) {
        for (var j = 1; j < steps; j++) {
          final candidate = _LatLng(
            minLat + (maxLat - minLat) * i / steps,
            minLng + (maxLng - minLng) * j / steps,
          );
          if (!_pointInRing(candidate, largest)) continue;
          final distance = _minEdgeDistance(candidate, largest);
          if (distance > bestDistance) {
            bestDistance = distance;
            best = candidate;
          }
        }
      }

      anchors[name] = best ??
          _centroidOf(rings) ??
          _LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);
    });
    return anchors;
  }

  double _minEdgeDistance(_LatLng point, List<_LatLng> ring) {
    var best = double.infinity;
    for (var i = 0; i < ring.length; i++) {
      final a = ring[i];
      final b = ring[(i + 1) % ring.length];
      best = math.min(best, _pointSegmentDistance(point, a, b));
    }
    return best;
  }

  double _pointSegmentDistance(_LatLng p, _LatLng a, _LatLng b) {
    final dx = b.lng - a.lng;
    final dy = b.lat - a.lat;
    if (dx == 0 && dy == 0) {
      return math.sqrt(
        math.pow(p.lng - a.lng, 2) + math.pow(p.lat - a.lat, 2),
      );
    }
    var t = ((p.lng - a.lng) * dx + (p.lat - a.lat) * dy) /
        (dx * dx + dy * dy);
    t = t.clamp(0.0, 1.0);
    return math.sqrt(
      math.pow(p.lng - (a.lng + t * dx), 2) +
          math.pow(p.lat - (a.lat + t * dy), 2),
    );
  }

  _LatLng? _centroidOf(List<List<_LatLng>> rings) {
    var largest = <_LatLng>[];
    for (final ring in rings) {
      if (ring.length > largest.length) largest = ring;
    }
    if (largest.isEmpty) return null;
    var sumLat = 0.0;
    var sumLng = 0.0;
    for (final point in largest) {
      sumLat += point.lat;
      sumLng += point.lng;
    }
    return _LatLng(sumLat / largest.length, sumLng / largest.length);
  }

  void _zoomBy(double factor) {
    if (_viewportSize == Size.zero) return;
    final center = Offset(_viewportSize.width / 2, _viewportSize.height / 2);
    // Scale about the viewport centre. Built entry by entry because the
    // Matrix4 translate/scale helpers are deprecated in this SDK.
    final matrix = Matrix4.identity()
      ..setEntry(0, 0, factor)
      ..setEntry(1, 1, factor)
      ..setEntry(0, 3, center.dx * (1 - factor))
      ..setEntry(1, 3, center.dy * (1 - factor));
    _viewController.value = matrix.multiplied(_viewController.value);
  }

  void _resetView() {
    _viewController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Phones and portrait tablets stack the map above the donor list;
        // landscape tablets and desktops keep the classic side-by-side split.
        // The donor pane can be collapsed in both layouts.
        final narrow = constraints.maxWidth < 860;
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;

        if (narrow) {
          final mapHeight = _donorsCollapsed
              ? math.max(200.0, height - 46)
              : math.max(220.0, height * 0.52);
          return Column(
            children: [
              SizedBox(
                height: mapHeight,
                width: width,
                child: _buildMapPane(context, compact: true),
              ),
              if (_donorsCollapsed)
                _buildCollapsedDonorBar(context)
              else ...[
                Divider(height: 1, color: context.border),
                Expanded(child: _buildDonorPane(context, compact: true)),
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: _buildMapPane(context, compact: false)),
            if (!_donorsCollapsed)
              Container(
                width: 330,
                decoration: BoxDecoration(
                  color: context.surface,
                  border: Border(left: BorderSide(color: context.border)),
                ),
                child: _buildDonorPane(context, compact: false),
              ),
          ],
        );
      },
    );
  }

  /// Tap bar that brings the donor list back on a phone.
  Widget _buildCollapsedDonorBar(BuildContext context) {
    final donors = _visibleDonors;
    return Material(
      color: context.surface,
      child: InkWell(
        onTap: () => setState(() => _donorsCollapsed = false),
        child: Container(
          height: 46,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: TabangSpace.lg),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: context.border)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.people_outline,
                size: 16,
                color: TabangColors.crimson,
              ),
              const SizedBox(width: 8),
              Text(
                'Available donors',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.textColor,
                ),
              ),
              const SizedBox(width: 6),
              StatusPill('${donors.length}', tone: Tone.brand, dense: true),
              const Spacer(),
              Icon(
                Icons.keyboard_arrow_up,
                size: 20,
                color: context.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMapPane(BuildContext context, {required bool compact}) {
    final palette = _MapPalette.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        _viewportSize = size;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: ColoredBox(color: palette.land)),
            if (size.width > 10 && size.height > 10)
              Positioned.fill(
                // A raw Listener, not a GestureDetector: it sees every pointer
                // event regardless of the zoom/pan gesture arena, and toScene
                // converts the click back into canvas coordinates so the hit
                // test is exact at any zoom level. The MouseRegion gives the
                // map a hand cursor so it reads as clickable.
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Listener(
                  behavior: HitTestBehavior.opaque,
                  onPointerDown: (event) =>
                      _pointerDownPosition = event.localPosition,
                  onPointerCancel: (_) => _pointerDownPosition = null,
                  onPointerUp: (event) {
                    final start = _pointerDownPosition;
                    _pointerDownPosition = null;
                    if (start == null) return;
                    // Ignore the end of a pan or pinch.
                    if ((event.localPosition - start).distance > 12) return;
                    final scenePoint =
                        _viewController.toScene(event.localPosition);
                    _handleMapTap(scenePoint, size);
                  },
                  child: InteractiveViewer(
                    transformationController: _viewController,
                    minScale: 1,
                    maxScale: 10,
                    boundaryMargin: const EdgeInsets.all(80),
                    clipBehavior: Clip.hardEdge,
                    child: AnimatedBuilder(
                      animation: _viewController,
                      builder: (context, _) => CustomPaint(
                        size: size,
                        painter: _DigosMapPainter(
                          boundaries: _boundaries,
                          counts: _donorCounts,
                          selected: _selectedBarangay,
                          labelAnchors: _labelAnchors,
                          projection: _projectionFor(size),
                          palette: palette,
                          showDetail: !compact,
                          zoom: _viewController.value.getMaxScaleOnAxis(),
                        ),
                      ),
                    ),
                  ),
                ),
                ),
              ),

            // Title + blood type filter.
            //
            // `left` AND `right` must both be set: a Positioned with only one
            // horizontal edge gives its child unbounded width, and a
            // horizontal ListView with unbounded width fails layout, which
            // takes the whole page's render tree down with it.
            Positioned(
              top: TabangSpace.md,
              left: TabangSpace.md,
              right: TabangSpace.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(TabangSpace.sm),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.map_outlined,
                            size: 14,
                            color: TabangColors.crimson,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'DIGOS CITY · 26 BARANGAYS',
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: context.textColor,
                            ),
                          ),
                          if (_loading) ...[
                            const SizedBox(width: 8),
                            const SizedBox(
                              width: 10,
                              height: 10,
                              child:
                                  CircularProgressIndicator(strokeWidth: 1.5),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  // Scrollable so every blood type is reachable on a phone,
                  // now with a bounded width from the Positioned above.
                  SizedBox(
                    height: 32,
                    width: double.infinity,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        _typeChip(context, null, 'ALL'),
                        ...BloodType.values.map(
                          (t) => _typeChip(context, t, t.label),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Zoom + donor-pane controls.
            Positioned(
              top: TabangSpace.md,
              right: TabangSpace.md,
              child: Column(
                children: [
                  _mapButton(context, Icons.add, () => _zoomBy(1.35)),
                  const SizedBox(height: 6),
                  _mapButton(context, Icons.remove, () => _zoomBy(0.74)),
                  const SizedBox(height: 6),
                  _mapButton(
                    context,
                    Icons.center_focus_strong,
                    _resetView,
                  ),
                  if (!compact) ...[
                    const SizedBox(height: 12),
                    _mapButton(
                      context,
                      _donorsCollapsed
                          ? Icons.chevron_left
                          : Icons.chevron_right,
                      () => setState(
                        () => _donorsCollapsed = !_donorsCollapsed,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            if (!compact)
              Positioned(
                left: TabangSpace.md,
                bottom: TabangSpace.md,
                child: SurfaceCard(
                  padding: const EdgeInsets.all(TabangSpace.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'AVAILABLE DONORS',
                        style: TextStyle(
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: 5),
                      _legendRow(context, 0, 'None'),
                      _legendRow(context, 1, '1–2 donors'),
                      _legendRow(context, 4, '3–5 donors'),
                      _legendRow(context, 7, '6+ donors'),
                    ],
                  ),
                ),
              ),

            if (_loadError != null)
              Positioned.fill(
                child: ColoredBox(
                  color: context.surface.withValues(alpha: 0.92),
                  child: EmptyState(
                    icon: Icons.layers_clear_outlined,
                    title: 'Barangay map unavailable',
                    message: _loadError,
                    action: OutlinedButton.icon(
                      onPressed: () {
                        setState(() {
                          _loading = true;
                          _loadError = null;
                        });
                        _loadBoundaries();
                      },
                      icon: const Icon(Icons.refresh, size: 15),
                      label: const Text('Retry'),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Color _fillFor(int count, bool selected) {
    if (selected) return TabangColors.crimson.withValues(alpha: 0.55);
    if (count == 0) {
      return context.isDark
          ? Colors.white.withValues(alpha: 0.06)
          : Colors.black.withValues(alpha: 0.05);
    }
    final alpha = (0.18 + count * 0.06).clamp(0.18, 0.62);
    return TabangColors.crimson.withValues(alpha: alpha);
  }

  Widget _typeChip(BuildContext context, BloodType? type, String label) {
    final selected = _bloodType == type;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(TabangRadius.pill),
        onTap: () {
          setState(() {
            _bloodType = type;
            _refreshCounts();
          });
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? TabangColors.crimson : context.surface,
            borderRadius: BorderRadius.circular(TabangRadius.pill),
            border: Border.all(
              color: selected ? TabangColors.crimson : context.border,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : context.textColor,
            ),
          ),
        ),
      ),
    );
  }

  Widget _mapButton(BuildContext context, IconData icon, VoidCallback onTap) {
    return Material(
      color: context.surface,
      borderRadius: BorderRadius.circular(TabangRadius.xs),
      child: InkWell(
        borderRadius: BorderRadius.circular(TabangRadius.xs),
        onTap: onTap,
        child: Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(TabangRadius.xs),
            border: Border.all(color: context.border),
          ),
          child: Icon(icon, size: 17, color: context.textColor),
        ),
      ),
    );
  }

  Widget _legendRow(BuildContext context, int count, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: _fillFor(count, false),
              border: Border.all(
                color: TabangColors.crimson.withValues(alpha: 0.5),
              ),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 9.5, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildDonorPane(BuildContext context, {required bool compact}) {
    final donors = _visibleDonors;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(TabangSpace.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _selectedBarangay == null
                          ? 'Available donors'
                          : 'Available donors in $_selectedBarangay',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  StatusPill('${donors.length}', tone: Tone.brand, dense: true),
                  if (_selectedBarangay != null) ...[
                    const SizedBox(width: 6),
                    InkWell(
                      onTap: () => setState(() => _selectedBarangay = null),
                      borderRadius: BorderRadius.circular(20),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Icon(
                          Icons.close,
                          size: 14,
                          color: context.textMuted,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  InkWell(
                    onTap: () => setState(() => _donorsCollapsed = true),
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TabangSpace.sm),
              TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  hintText: 'Search alias or barangay',
                  isDense: true,
                  prefixIcon: Icon(Icons.search, size: 16),
                ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.border),
        Expanded(
          child: donors.isEmpty
              ? const EmptyState(
                  art: TabangArt.donors,
                  title: 'No eligible donors',
                  message:
                      'No donor matches this filter right now. Donors in '
                      'cooldown are hidden automatically.',
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(TabangSpace.md),
                  itemCount: donors.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: TabangSpace.sm),
                  itemBuilder: (context, i) =>
                      _buildDonorCard(context, donors[i]),
                ),
        ),
      ],
    );
  }

  Widget _buildDonorCard(BuildContext context, AppUser donor) {
    final eligibility = EligibilityEngine.evaluate(donor);

    return SurfaceCard(
      padding: const EdgeInsets.all(TabangSpace.md),
      onTap: donor.shareBarangay
          ? () => setState(() => _selectedBarangay = donor.barangay)
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BloodTypeChip(donor.bloodType ?? BloodType.oPos, size: 30),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      donor.alias,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    Text(
                      donor.shareBarangay ? donor.barangay : 'Barangay hidden',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              StatusPill(
                eligibility.isEligible ? 'Eligible' : 'Cooldown',
                tone: toneForEligibility(eligibility),
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          Row(
            children: [
              Icon(Icons.favorite_border, size: 11, color: context.textMuted),
              const SizedBox(width: 3),
              Text(
                '${donor.totalDonations} donations',
                style: TextStyle(fontSize: 10, color: context.textMuted),
              ),
              const SizedBox(width: TabangSpace.md),
              Icon(Icons.schedule, size: 11, color: context.textMuted),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                  donor.lastDonationDate == null
                      ? 'First-time donor'
                      : 'Last ${formatDate(donor.lastDonationDate!)}',
                  style: TextStyle(fontSize: 10, color: context.textMuted),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Geometry
// ---------------------------------------------------------------------------

/// A latitude/longitude pair. Kept private to this page; the domain models do
/// not need a geo type because no coordinates are ever persisted.
class _LatLng {
  const _LatLng(this.lat, this.lng);

  final double lat;
  final double lng;
}

class _Bounds {
  const _Bounds({
    required this.minLat,
    required this.maxLat,
    required this.minLng,
    required this.maxLng,
  });

  final double minLat;
  final double maxLat;
  final double minLng;
  final double maxLng;

  double get heightLat => math.max(maxLat - minLat, 0.001);
  double get widthLng => math.max(maxLng - minLng, 0.001);

  static _Bounds fromBoundaries(
    Map<String, List<List<_LatLng>>> boundaries,
  ) {
    var minLat = 90.0, maxLat = -90.0, minLng = 180.0, maxLng = -180.0;
    for (final rings in boundaries.values) {
      for (final ring in rings) {
        for (final point in ring) {
          minLat = math.min(minLat, point.lat);
          maxLat = math.max(maxLat, point.lat);
          minLng = math.min(minLng, point.lng);
          maxLng = math.max(maxLng, point.lng);
        }
      }
    }
    if (minLat > maxLat) {
      return const _Bounds(
        minLat: 6.68,
        maxLat: 6.83,
        minLng: 125.27,
        maxLng: 125.42,
      );
    }
    return _Bounds(
      minLat: minLat,
      maxLat: maxLat,
      minLng: minLng,
      maxLng: maxLng,
    );
  }
}

/// Equirectangular projection fitted to the canvas. Digos City spans a few
/// kilometres, so the distortion of a simple lat/lng scale is invisible.
class _Projection {
  _Projection({
    required this.bounds,
    required this.size,
    required this.padding,
  }) {
    scale = math.min(
      (size.width - padding * 2) / bounds.widthLng,
      (size.height - padding * 2) / bounds.heightLat,
    );
    final dx = (size.width - bounds.widthLng * scale) / 2;
    final dy = (size.height - bounds.heightLat * scale) / 2;
    offset = Offset(
      dx - bounds.minLng * scale,
      dy + bounds.maxLat * scale,
    );
  }

  final _Bounds bounds;
  final Size size;
  final double padding;
  late final double scale;
  late final Offset offset;

  Offset toCanvas(_LatLng point) => Offset(
        point.lng * scale + offset.dx,
        -point.lat * scale + offset.dy,
      );

  _LatLng toLatLng(Offset point) => _LatLng(
        (offset.dy - point.dy) / scale,
        (point.dx - offset.dx) / scale,
      );
}

// ---------------------------------------------------------------------------
// Painting
// ---------------------------------------------------------------------------

class _MapPalette {
  const _MapPalette({
    required this.land,
    required this.border,
    required this.label,
    required this.halo,
  });

  final Color land;
  final Color border;
  final Color label;
  final Color halo;

  static _MapPalette of(BuildContext context) {
    final dark = context.isDark;
    return _MapPalette(
      land: dark ? const Color(0xFF1A1615) : const Color(0xFFF4F1EE),
      border: dark ? const Color(0xFF4A3B38) : const Color(0xFFB9A9A4),
      label: dark ? const Color(0xFFE8DEDB) : const Color(0xFF4A3B38),
      halo: dark ? const Color(0xFF1A1615) : const Color(0xFFF4F1EE),
    );
  }
}

class _DigosMapPainter extends CustomPainter {
  _DigosMapPainter({
    required this.boundaries,
    required this.counts,
    required this.selected,
    required this.labelAnchors,
    required this.projection,
    required this.palette,
    required this.showDetail,
    required this.zoom,
  });

  final Map<String, List<List<_LatLng>>> boundaries;
  final Map<String, int> counts;
  final String? selected;
  final Map<String, _LatLng> labelAnchors;
  final _Projection projection;
  final _MapPalette palette;
  final bool showDetail;

  /// Current InteractiveViewer scale. Small barangay labels in the crowded
  /// city proper only appear once the user has zoomed in.
  final double zoom;

  @override
  void paint(Canvas canvas, Size size) {
    if (boundaries.isEmpty) return;

    final maxCount = counts.values.fold(1, math.max);
    // Everything below is drawn in scene coordinates and then magnified by the
    // InteractiveViewer. Dividing sizes by the zoom keeps strokes, labels and
    // decorations a constant size on screen instead of ballooning when the
    // user zooms in.
    final counter = 1 / zoom.clamp(1.0, 20.0);

    // Barangay shapes.
    boundaries.forEach((name, rings) {
      final count = counts[name] ?? 0;
      final isSelected = selected == name;

      final path = Path();
      for (final ring in rings) {
        if (ring.length < 3) continue;
        final first = projection.toCanvas(ring.first);
        path.moveTo(first.dx, first.dy);
        for (var i = 1; i < ring.length; i++) {
          final point = projection.toCanvas(ring[i]);
          path.lineTo(point.dx, point.dy);
        }
        path.close();
      }

      // Selection is deliberately BLUE: crimson already means "donors are
      // available here", so the two states must not read as the same thing.
      final fill = isSelected
          ? TabangColors.info.withValues(alpha: 0.45)
          : count == 0
              ? (palette.label.withValues(alpha: 0.10))
              : TabangColors.crimson.withValues(
                  alpha: ((0.14 + 0.5 * count / maxCount).clamp(0.14, 0.64)),
                );

      canvas.drawPath(path, Paint()..color = fill);
      canvas.drawPath(
        path,
        Paint()
          ..color = isSelected ? TabangColors.info : palette.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = (isSelected ? 2.6 : 1) * counter,
      );
    });

    // Barangay names, placed at the interior anchor computed for each shape
    // (not the centroid, which can fall outside concave barangays). Every name
    // is always drawn: small polygons simply get a smaller type size, and the
    // counter-scale keeps the text a constant size on screen as you zoom.
    boundaries.forEach((name, rings) {
      final anchor = labelAnchors[name] ?? _centroid(rings);
      if (anchor == null) return;
      final point = projection.toCanvas(anchor);
      if (point.dx < 14 ||
          point.dy < 14 ||
          point.dx > size.width - 14 ||
          point.dy > size.height - 14) {
        return;
      }
      final bounds = _screenBounds(rings);
      final fits = bounds.width >= 52 && bounds.height >= 22;
      final baseSize = selected == name
          ? 11.0
          : fits
              ? 9.5
              : 8.0;
      _paintText(
        canvas,
        _shortName(name),
        point,
        fontSize: baseSize * counter,
        weight: selected == name ? FontWeight.w800 : FontWeight.w600,
        color: palette.label,
        halo: palette.halo,
        blur: 3 * counter,
      );
    });

    if (showDetail) {
      _paintScaleBar(canvas, size, counter);
      _paintCompass(canvas, size, counter);
    }
  }

  /// Projected bounding box of a barangay, used to decide whether its label
  /// has room at the current zoom.
  Rect _screenBounds(List<List<_LatLng>> rings) {
    var minX = double.infinity, minY = double.infinity;
    var maxX = -double.infinity, maxY = -double.infinity;
    for (final ring in rings) {
      for (final point in ring) {
        final projected = projection.toCanvas(point);
        minX = math.min(minX, projected.dx);
        minY = math.min(minY, projected.dy);
        maxX = math.max(maxX, projected.dx);
        maxY = math.max(maxY, projected.dy);
      }
    }
    if (minX > maxX) return Rect.zero;
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  void _paintScaleBar(Canvas canvas, Size size, double counter) {
    final scale = projection.scale;
    // One kilometre in degrees of latitude, then converted to pixels. The bar
    // length is intentionally NOT counter-scaled: a scale bar must grow on
    // screen as you zoom in. Only its strokes and label stay constant.
    const kmInLat = 1 / 110.574;
    final pixels = kmInLat * scale;
    if (!pixels.isFinite || pixels < 12 || pixels > size.width * 0.6) return;

    final y = size.height - 22;
    final x = size.width - pixels - 26;
    final tick = 4 * counter;
    final paint = Paint()
      ..color = palette.label.withValues(alpha: 0.75)
      ..strokeWidth = 1.5 * counter;
    final path = Path()
      ..moveTo(x, y)
      ..lineTo(x + pixels, y)
      ..moveTo(x, y - tick)
      ..lineTo(x, y + tick)
      ..moveTo(x + pixels, y - tick)
      ..lineTo(x + pixels, y + tick);
    canvas.drawPath(path, paint);
    _paintText(
      canvas,
      '1 km',
      Offset(x + pixels / 2, y + 6 * counter),
      fontSize: 8 * counter,
      weight: FontWeight.w600,
      color: palette.label.withValues(alpha: 0.75),
      halo: palette.halo,
      blur: 3 * counter,
    );
  }

  void _paintCompass(Canvas canvas, Size size, double counter) {
    // Drawn inside a counter-scaled space so the rose keeps a constant size
    // on screen at every zoom level.
    final center = Offset(size.width - 26, size.height - 44);
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(counter);

    final paint = Paint()
      ..color = palette.label.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawCircle(Offset.zero, 11, paint);
    final north = Path()
      ..moveTo(0, -8)
      ..lineTo(-4, 3)
      ..lineTo(0, 1)
      ..lineTo(4, 3)
      ..close();
    canvas.drawPath(
      north,
      Paint()..color = TabangColors.crimson.withValues(alpha: 0.85),
    );
    _paintText(
      canvas,
      'N',
      const Offset(0, 6),
      fontSize: 7.5,
      weight: FontWeight.w700,
      color: palette.label.withValues(alpha: 0.75),
      halo: palette.halo,
      blur: 3,
    );
    canvas.restore();
  }

  void _paintText(
    Canvas canvas,
    String text,
    Offset center, {
    required double fontSize,
    required FontWeight weight,
    required Color color,
    required Color halo,
    double letterSpacing = 0,
    double blur = 3,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: weight,
          letterSpacing: letterSpacing,
          color: color,
          shadows: [
            Shadow(color: halo, blurRadius: blur),
            Shadow(color: halo, blurRadius: blur),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    )..layout();
    painter.paint(
      canvas,
      center.translate(-painter.width / 2, -painter.height / 2),
    );
  }

  String _shortName(String name) => name;

  _LatLng? _centroid(List<List<_LatLng>> rings) {
    var best = <_LatLng>[];
    for (final ring in rings) {
      if (ring.length > best.length) best = ring;
    }
    if (best.isEmpty) return null;
    var sumLat = 0.0;
    var sumLng = 0.0;
    for (final point in best) {
      sumLat += point.lat;
      sumLng += point.lng;
    }
    return _LatLng(sumLat / best.length, sumLng / best.length);
  }

  @override
  bool shouldRepaint(_DigosMapPainter oldDelegate) {
    return oldDelegate.selected != selected ||
        oldDelegate.counts != counts ||
        oldDelegate.boundaries != boundaries ||
        oldDelegate.labelAnchors != labelAnchors ||
        oldDelegate.palette.label != palette.label ||
        oldDelegate.showDetail != showDetail ||
        oldDelegate.zoom != zoom;
  }
}
