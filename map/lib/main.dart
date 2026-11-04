import 'dart:ui';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import 'data/digos_geodata.dart';

void main() {
  runApp(const DigosBarangayMapApp());
}

/// Design tokens matching the CSS variables in the original HTML
class AppColors {
  static const Color ink = Color(0xFF27332F);
  static const Color muted = Color(0xFF78847E);
  static const Color paper = Color(0xFFF6F7F3);
  static const Color line = Color(0xFFDFE5DF);
  static const Color accent = Color(0xFF47766D);
  static const Color water = Color(0xFFB8DCE2);
  static const Color brgyFill = Color(0xFF8EAFA1);
}

class DigosBarangayMapApp extends StatelessWidget {
  const DigosBarangayMapApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digos City | Barangay Map',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.paper,
        colorScheme: ColorScheme.fromSeed(seedColor: AppColors.accent),
        useMaterial3: true,
      ),
      home: const DigosMapScreen(),
    );
  }
}

class DigosMapScreen extends StatefulWidget {
  const DigosMapScreen({super.key});

  @override
  State<DigosMapScreen> createState() => _DigosMapScreenState();
}

class _DigosMapScreenState extends State<DigosMapScreen> {
  final MapController _mapController = MapController();

  late final List<LatLng> _cityHoleRing;
  late final List<BarangayFeature> _barangays;
  late final List<List<LatLng>> _internalBorders;

  int? _hoveredBarangayId;
  BarangayFeature? _selectedBarangay;
  LatLng? _popupLocation;
  double _currentZoom = 11.0;

  static final LatLngBounds _digosBounds = LatLngBounds(
    const LatLng(6.71695, 125.2524),
    const LatLng(6.9874, 125.3930),
  );

  @override
  void initState() {
    super.initState();
    _cityHoleRing = DigosGeoData.stitchRing(DigosGeoData.cityArcs);
    _barangays = DigosGeoData.buildBarangays();
    _internalBorders = DigosGeoData.buildInternalBorders();
  }

  /// Linearly interpolate values across zoom levels (matching MapLibre's interpolate)
  double _lerpZoom(double minZ, double minVal, double maxZ, double maxVal) {
    final double t = ((_currentZoom - minZ) / (maxZ - minZ)).clamp(0.0, 1.0);
    return minVal + (maxVal - minVal) * t;
  }

  BarangayFeature? _findBarangayAt(LatLng point) {
    for (final brgy in _barangays) {
      if (DigosGeoData.isPointInPolygon(point, brgy.ring)) {
        return brgy;
      }
    }
    return null;
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    final BarangayFeature? hit = _findBarangayAt(point);
    setState(() {
      _selectedBarangay = hit;
      _popupLocation = hit != null ? point : null;
    });
  }

  void _handlePointerHover(PointerHoverEvent event, LatLng point) {
    final BarangayFeature? hit = _findBarangayAt(point);
    final int? newId = hit?.id;
    if (newId != _hoveredBarangayId) {
      setState(() {
        _hoveredBarangayId = newId;
      });
    }
  }

  void _fitDigosBounds() {
    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: _digosBounds,
        padding: const EdgeInsets.all(40),
        maxZoom: 13.0,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isMobile = MediaQuery.sizeOf(context).width <= 600;

    final double internalStrokeWidth = _lerpZoom(9, 1.2, 14, 2.2);
    final double outerStrokeWidth = _lerpZoom(9, 2.2, 14, 3.4);
    final double labelFontSize = _lerpZoom(10, 9.5, 13, 11.5);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(isMobile),
            Expanded(
              child: Stack(
                children: [
                  FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: const LatLng(6.84, 125.33),
                      initialZoom: 11.0,
                      minZoom: 9.5,
                      maxZoom: 18.0,
                      backgroundColor: AppColors.paper,
                      initialCameraFit: CameraFit.bounds(
                        bounds: _digosBounds,
                        padding: const EdgeInsets.all(40),
                        maxZoom: 13.0,
                      ),
                      interactionOptions: const InteractionOptions(
                        flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                      ),
                      onPositionChanged: (camera, hasGesture) {
                        if ((camera.zoom - _currentZoom).abs() > 0.05) {
                          setState(() {
                            _currentZoom = camera.zoom;
                          });
                        }
                      },
                      onTap: _handleMapTap,
                      onPointerHover: _handlePointerHover,
                    ),
                    children: [
                      // Base Tile Layer (Positron No-Labels with warm paper tint)
                      ColorFiltered(
                        colorFilter: const ColorFilter.matrix(<double>[
                          0.575, 0.422, 0.043, 0, -6,
                          0.125, 0.872, 0.043, 0, -4,
                          0.125, 0.422, 0.493, 0, -8,
                          0.000, 0.000, 0.000, 1,  0,
                        ]),
                        child: TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.digos.barangay_map',
                          maxNativeZoom: 19,
                        ),
                      ),

                      // 1. Inverse Mask: hides everything outside Digos City
                      PolygonLayer(
                        polygons: [
                          Polygon(
                            points: const [
                              LatLng(5.0, 123.0),
                              LatLng(5.0, 127.0),
                              LatLng(9.0, 127.0),
                              LatLng(9.0, 123.0),
                              LatLng(5.0, 123.0),
                            ],
                            holePointsList: [_cityHoleRing],
                            color: AppColors.paper,
                            borderStrokeWidth: 0,
                          ),
                        ],
                      ),

                      // 2. Barangay interactive fill polygons
                      PolygonLayer(
                        polygons: _barangays.map((brgy) {
                          final bool isHighlighted =
                              brgy.id == _hoveredBarangayId ||
                                  brgy.id == _selectedBarangay?.id;
                          return Polygon(
                            points: brgy.ring,
                            color: AppColors.brgyFill.withValues(
                              alpha: isHighlighted ? 0.22 : 0.055,
                            ),
                            borderStrokeWidth: 0,
                          );
                        }).toList(),
                      ),

                      // 3. Seamless internal barangay boundary lines
                      PolylineLayer(
                        polylines: _internalBorders
                            .map(
                              (arc) => Polyline(
                                points: arc,
                                color: AppColors.accent.withValues(alpha: 0.95),
                                strokeWidth: internalStrokeWidth,
                                strokeCap: StrokeCap.round,
                                strokeJoin: StrokeJoin.round,
                              ),
                            )
                            .toList(),
                      ),

                      // 4. Outer boundary around Digos City
                      PolylineLayer(
                        polylines: [
                          Polyline(
                            points: _cityHoleRing,
                            color: AppColors.ink,
                            strokeWidth: outerStrokeWidth,
                            strokeCap: StrokeCap.round,
                            strokeJoin: StrokeJoin.round,
                          ),
                        ],
                      ),

                      // 5. Barangay name labels
                      MarkerLayer(
                        markers: _barangays
                            .map(
                              (brgy) => Marker(
                                point: brgy.centroid,
                                width: 110,
                                height: 34,
                                child: IgnorePointer(
                                  child: Center(
                                    child: _HaloText(
                                      text: brgy.name,
                                      fontSize: labelFontSize,
                                    ),
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),

                      // 6. Interactive Popup when a barangay is tapped
                      if (_selectedBarangay != null && _popupLocation != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _popupLocation!,
                              width: 190,
                              height: 60,
                              alignment: Alignment.topCenter,
                              child: _PopupCard(
                                label: _selectedBarangay!.name,
                                onClose: () {
                                  setState(() {
                                    _selectedBarangay = null;
                                    _popupLocation = null;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),

                  // Top-left Navigation Controls (+ / - / Reset Bounds)
                  Positioned(
                    top: 14,
                    left: 14,
                    child: _MapZoomControls(
                      onZoomIn: () => _mapController.move(
                        _mapController.camera.center,
                        (_currentZoom + 0.75).clamp(9.5, 18.0),
                      ),
                      onZoomOut: () => _mapController.move(
                        _mapController.camera.center,
                        (_currentZoom - 0.75).clamp(9.5, 18.0),
                      ),
                      onResetBounds: _fitDigosBounds,
                    ),
                  ),

                  // Top-right Status Box
                  Positioned(
                    top: 14,
                    right: 14,
                    child: _buildStatusBox(),
                  ),

                  // Bottom-left Legend
                  Positioned(
                    left: isMobile ? 10 : 16,
                    bottom: isMobile ? 20 : 28,
                    child: const _MapLegend(),
                  ),

                  // Bottom-right Attribution
                  Positioned(
                    right: 10,
                    bottom: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xEBFAFBF8),
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Text(
                        '© OpenStreetMap · © CARTO',
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 14 : 20,
        vertical: isMobile ? 12 : 14,
      ),
      decoration: const BoxDecoration(
        color: Color(0xF5FAFBF8),
        border: Border(
          bottom: BorderSide(color: AppColors.line, width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'DAVAO DEL SUR · PHILIPPINES',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Digos City Barangay Map',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'A simplified, interactive map of local areas and infrastructure',
                  style: TextStyle(
                    color: AppColors.muted,
                    fontSize: isMobile ? 11 : 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 8 : 10,
              vertical: isMobile ? 6 : 7,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFFEDF3EE),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: const Color(0xFFD9E2DC)),
            ),
            child: Text(
              '2D VECTOR MAP',
              style: TextStyle(
                color: const Color(0xFF426D64),
                fontSize: isMobile ? 10 : 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBox() {
    final String statusText = _selectedBarangay != null
        ? 'Selected: ${_selectedBarangay!.name}'
        : '26 barangays in Digos City loaded';

    return Container(
      constraints: const BoxConstraints(maxWidth: 340),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xF0FAFBF8),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F25352E),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Text(
        statusText,
        style: const TextStyle(
          color: Color(0xFF596760),
          fontSize: 11,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// Haloed text widget replicating MapLibre's text-halo-color / text-halo-width
class _HaloText extends StatelessWidget {
  final String text;
  final double fontSize;

  const _HaloText({required this.text, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Halo outline
        Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.15,
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = 3.0
              ..color = const Color(0xFFF7F8F4),
          ),
        ),
        // Foreground fill
        Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.visible,
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            height: 1.15,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }
}

/// Popup card matching `.maplibregl-popup-content`
class _PopupCard extends StatelessWidget {
  final String label;
  final VoidCallback onClose;

  const _PopupCard({required this.label, required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          boxShadow: const [
            BoxShadow(
              color: Color(0x2625352E),
              blurRadius: 24,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(width: 6),
            InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(4),
              child: const Padding(
                padding: EdgeInsets.all(2),
                child: Icon(
                  Icons.close,
                  size: 14,
                  color: AppColors.muted,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Top-left map zoom controls
class _MapZoomControls extends StatelessWidget {
  final VoidCallback onZoomIn;
  final VoidCallback onZoomOut;
  final VoidCallback onResetBounds;

  const _MapZoomControls({
    required this.onZoomIn,
    required this.onZoomOut,
    required this.onResetBounds,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppColors.line),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1425352E),
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _ControlIconButton(
            icon: Icons.add,
            tooltip: 'Zoom in',
            onTap: onZoomIn,
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.line),
          _ControlIconButton(
            icon: Icons.remove,
            tooltip: 'Zoom out',
            onTap: onZoomOut,
          ),
          const Divider(height: 1, thickness: 1, color: AppColors.line),
          _ControlIconButton(
            icon: Icons.crop_free,
            tooltip: 'Fit Digos City',
            onTap: onResetBounds,
          ),
        ],
      ),
    );
  }
}

class _ControlIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _ControlIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 32,
          height: 32,
          child: Icon(icon, size: 17, color: AppColors.ink),
        ),
      ),
    );
  }
}

/// Frosted-glass legend card matching `.legend`
class _MapLegend extends StatelessWidget {
  const _MapLegend();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          width: 230,
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xF0FAFBF8),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xF2D3DCD5)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1425352E),
                blurRadius: 22,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'MAP LAYERS',
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 1.2,
                  color: AppColors.muted,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              _buildRow(
                swatch: Container(
                  width: 20,
                  height: 2.5,
                  color: AppColors.ink,
                ),
                label: 'Digos City boundary',
              ),
              _buildRow(
                swatch: Container(
                  width: 20,
                  height: 2,
                  color: AppColors.accent,
                ),
                label: 'Barangay boundaries',
              ),
              _buildRow(
                swatch: Container(
                  width: 20,
                  height: 9,
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9D8D1),
                    border: Border.all(color: const Color(0xFFC8C7BF)),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                label: 'Buildings / built-up areas',
              ),
              _buildRow(
                swatch: Container(
                  width: 20,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFC9C9C1)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                label: 'Roads and streets',
              ),
              _buildRow(
                swatch: Container(
                  width: 20,
                  height: 9,
                  decoration: BoxDecoration(
                    color: AppColors.water,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                label: 'Water bodies and rivers',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow({required Widget swatch, required String label}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.5),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Center(child: swatch),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.ink,
              ),
            ),
          ),
        ],
      ),
    );
  }
}