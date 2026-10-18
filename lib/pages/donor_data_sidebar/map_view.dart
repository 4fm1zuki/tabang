import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
    show Supabase, SupabaseClient;

class BarangayMapView extends StatefulWidget {
  final String? selectedBarangay;
  final String selectedBloodType;
  final Function(String) onBarangaySelected;
  final ThemeMode themeMode; // Added to receive theme changes

  const BarangayMapView({
    super.key,
    required this.selectedBarangay,
    required this.selectedBloodType,
    required this.onBarangaySelected,
    required this.themeMode,
  });

  @override
  State<BarangayMapView> createState() => _BarangayMapViewState();
}

class _BarangayMapViewState extends State<BarangayMapView> {
  final SupabaseClient _supabase = Supabase.instance.client;

  GoogleMapController? _mapController;

  // Canonical barangay name -> donor count
  Map<String, int> _barangayDonorCounts = {};

  // Canonical barangay name -> one or more boundary polygons
  Map<String, List<List<LatLng>>> _barangayBoundaries = {};

  bool _isLoading = true;
  bool _isMapLoading = true;

  // Prevent an older Supabase request from overwriting a newer request.
  int _requestVersion = 0;

  // Approximate center of Digos City.
  static const LatLng _digosCenter = LatLng(
    6.7498,
    125.3572,
  );

  static const CameraPosition _initialCameraPosition = CameraPosition(
    target: _digosCenter,
    zoom: 12.7,
  );

  // Clean Dark Mode JSON style for Google Maps
  static const String _darkMapStyle = '''
  [
    {"elementType": "geometry", "stylers": [{"color": "#212121"}]},
    {"elementType": "labels.icon", "stylers": [{"visibility": "off"}]},
    {"elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"elementType": "labels.text.stroke", "stylers": [{"color": "#212121"}]},
    {"featureType": "administrative", "elementType": "geometry", "stylers": [{"color": "#757575"}]},
    {"featureType": "administrative.country", "elementType": "geometry.stroke", "stylers": [{"color": "#4b4b4b"}]},
    {"featureType": "administrative.land_parcel", "elementType": "labels.text.fill", "stylers": [{"color": "#bdbdbd"}]},
    {"featureType": "poi", "elementType": "labels.text.fill", "stylers": [{"color": "#757575"}]},
    {"featureType": "poi.park", "elementType": "geometry", "stylers": [{"color": "#181818"}]},
    {"featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [{"color": "#616161"}]},
    {"featureType": "road", "elementType": "geometry", "stylers": [{"color": "#2c2c2c"}]},
    {"featureType": "road.arterial", "elementType": "geometry", "stylers": [{"color": "#373737"}]},
    {"featureType": "road.highway", "elementType": "geometry", "stylers": [{"color": "#3c3c3c"}]},
    {"featureType": "road.highway.controlled_access", "elementType": "geometry", "stylers": [{"color": "#4e4e4e"}]},
    {"featureType": "road.local", "elementType": "labels.text.fill", "stylers": [{"color": "#9e9e9e"}]},
    {"featureType": "water", "elementType": "geometry", "stylers": [{"color": "#000000"}]},
    {"featureType": "water", "elementType": "labels.text.fill", "stylers": [{"color": "#3d3d3d"}]}
  ]
  ''';

  @override
  void initState() {
    super.initState();
    _initializeMapData();
  }

  @override
  void didUpdateWidget(covariant BarangayMapView oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Refresh counts when the selected blood type changes.
    if (oldWidget.selectedBloodType != widget.selectedBloodType) {
      _fetchDonorCounts();
    }

    // Move the camera when the selected barangay changes.
    if (oldWidget.selectedBarangay != widget.selectedBarangay) {
      _focusOnSelectedBarangay();
    }

    // Update map style when theme mode changes
    if (oldWidget.themeMode != widget.themeMode) {
      _applyMapTheme();
    }
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  bool _isDarkMode() {
    if (widget.themeMode == ThemeMode.dark) return true;
    if (widget.themeMode == ThemeMode.light) return false;
    return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
  }

  Future<void> _applyMapTheme() async {
    if (_mapController == null) return;
    try {
      if (_isDarkMode()) {
        await _mapController!.setMapStyle(_darkMapStyle);
      } else {
        await _mapController!.setMapStyle(''); // Reset to default light style
      }
    } catch (e) {
      debugPrint('Error applying map theme: $e');
    }
  }

  Future<void> _initializeMapData() async {
    try {
      await _loadBarangayBoundaries();
      await _fetchDonorCounts();

      if (mounted) {
        setState(() {
          _isMapLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error initializing barangay map: $e');

      if (mounted) {
        setState(() {
          _isMapLoading = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadBarangayBoundaries() async {
    final String rawJson = await rootBundle.loadString(
      'assets/maps/digos_barangays.geojson',
    );

    final Map<String, dynamic> geoJson =
    jsonDecode(rawJson) as Map<String, dynamic>;

    final List<dynamic> features =
        (geoJson['features'] as List<dynamic>?) ?? [];

    final Map<String, List<List<LatLng>>> boundaries = {};

    for (final dynamic feature in features) {
      if (feature is! Map<String, dynamic>) {
        continue;
      }

      final Map<String, dynamic> properties =
          (feature['properties'] as Map<String, dynamic>?) ?? {};

      final dynamic rawName =
          properties['NAME_3'] ??
              properties['NAME3'] ??
              properties['name'] ??
              properties['NAME'];

      if (rawName == null) {
        continue;
      }

      final String? barangayName = _canonicalBarangayName(
        rawName.toString(),
      );

      if (barangayName == null) {
        continue;
      }

      final Map<String, dynamic>? geometry =
      feature['geometry'] as Map<String, dynamic>?;

      if (geometry == null) {
        continue;
      }

      final String geometryType =
          geometry['type']?.toString() ?? '';

      final dynamic coordinates = geometry['coordinates'];

      if (geometryType == 'Polygon') {
        final List<List<LatLng>> polygons =
        _parsePolygonCoordinates(coordinates);

        if (polygons.isNotEmpty) {
          boundaries.putIfAbsent(barangayName, () => []);
          boundaries[barangayName]!.addAll(polygons);
        }
      } else if (geometryType == 'MultiPolygon') {
        final List<List<LatLng>> polygons =
        _parseMultiPolygonCoordinates(coordinates);

        if (polygons.isNotEmpty) {
          boundaries.putIfAbsent(barangayName, () => []);
          boundaries[barangayName]!.addAll(polygons);
        }
      }
    }

    if (mounted) {
      setState(() {
        _barangayBoundaries = boundaries;
      });
    }
  }

  List<List<LatLng>> _parsePolygonCoordinates(dynamic coordinates) {
    if (coordinates is! List || coordinates.isEmpty) {
      return [];
    }

    final dynamic outerRing = coordinates[0];

    if (outerRing is! List || outerRing.isEmpty) {
      return [];
    }

    final List<LatLng> points = [];

    for (final dynamic coordinate in outerRing) {
      if (coordinate is List && coordinate.length >= 2) {
        final double? longitude = _toDouble(coordinate[0]);
        final double? latitude = _toDouble(coordinate[1]);

        if (longitude != null && latitude != null) {
          points.add(
            LatLng(latitude, longitude),
          );
        }
      }
    }

    if (points.length < 3) {
      return [];
    }

    return [points];
  }

  List<List<LatLng>> _parseMultiPolygonCoordinates(dynamic coordinates) {
    if (coordinates is! List) {
      return [];
    }

    final List<List<LatLng>> polygons = [];

    for (final dynamic polygon in coordinates) {
      final List<List<LatLng>> parsed =
      _parsePolygonCoordinates(polygon);

      polygons.addAll(parsed);
    }

    return polygons;
  }

  double? _toDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(value.toString());
  }

  String? _canonicalBarangayName(String name) {
    final String normalized = name
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    const Map<String, String> aliases = {
      'aplaya': 'Aplaya',
      'balabag': 'Balabag',
      'binaton': 'Binaton',
      'cogon': 'Cogon',
      'cogan': 'Cogon',
      'colorado': 'Colorado',
      'dawis': 'Dawis',
      'dulangan': 'Dulangan',
      'goma': 'Goma',
      'igpit': 'Igpit',
      'kiagot': 'Kiagot',
      'kapatagan': 'Kapatagan',
      'lungag': 'Lungag',
      'mahayahay': 'Mahayahay',
      'matti': 'Matti',
      'ruparan': 'Ruparan',
      'sanagustin': 'San Agustin',
      'sanjose': 'San Jose',
      'sanmiguel': 'San Miguel',
      'sanroque': 'San Roque',
      'sinawilan': 'Sinawilan',
      'soong': 'Soong',
      'tiguman': 'Tiguman',
      'tresdemayo': 'Tres De Mayo',
      'zone1': 'Zone 1',
      'zone1pob': 'Zone 1',
      'zone2': 'Zone 2',
      'zone2pob': 'Zone 2',
      'zone3': 'Zone 3',
      'zone3pob': 'Zone 3',
    };

    return aliases[normalized];
  }

  Future<void> _fetchDonorCounts() async {
    final int requestId = ++_requestVersion;

    if (!mounted) return;

    setState(() {
      _isLoading = true;
    });

    try {
      dynamic query = _supabase
          .from('donors')
          .select('barangay, blood_type')
          .eq('is_available', true);

      if (widget.selectedBloodType != 'ALL') {
        query = query.eq(
          'blood_type',
          widget.selectedBloodType,
        );
      }

      final List<dynamic> response = await query;

      if (requestId != _requestVersion || !mounted) {
        return;
      }

      final Map<String, int> counts = {};

      for (final dynamic donor in response) {
        if (donor is! Map<String, dynamic>) {
          continue;
        }

        final dynamic rawBarangay = donor['barangay'];

        if (rawBarangay == null) {
          continue;
        }

        final String? barangay =
        _canonicalBarangayName(rawBarangay.toString());

        if (barangay == null) {
          continue;
        }

        counts[barangay] = (counts[barangay] ?? 0) + 1;
      }

      setState(() {
        _barangayDonorCounts = counts;
      });
    } catch (e) {
      if (requestId == _requestVersion) {
        debugPrint('Error fetching donor counts: $e');
      }
    } finally {
      if (requestId == _requestVersion && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Set<Polygon> _buildBarangayPolygons() {
    final Set<Polygon> polygons = {};

    _barangayBoundaries.forEach(
          (String barangay, List<List<LatLng>> polygonGroups) {
        final bool isSelected =
            widget.selectedBarangay == barangay;

        final int donorCount =
            _barangayDonorCounts[barangay] ?? 0;

        for (int i = 0; i < polygonGroups.length; i++) {
          final List<LatLng> points = polygonGroups[i];

          polygons.add(
            Polygon(
              polygonId: PolygonId(
                '${barangay}_$i',
              ),
              points: points,
              consumeTapEvents: true,
              strokeColor: isSelected
                  ? const Color(0xFF7A1C1E)
                  : const Color(0xFFB42318),
              strokeWidth: isSelected ? 4 : 2,
              fillColor: _getBarangayFillColor(
                donorCount,
                isSelected,
              ),
              onTap: () {
                _selectBarangay(barangay);
              },
            ),
          );
        }
      },
    );

    return polygons;
  }

  Color _getBarangayFillColor(int donorCount, bool isSelected) {
    if (isSelected) {
      return const Color(0x667A1C1E);
    }

    if (donorCount == 0) {
      return _isDarkMode() ? const Color(0x25FFFFFF) : const Color(0x15000000);
    }

    final int opacity = (35 + (donorCount * 8)).clamp(35, 130);

    return Color.fromARGB(
      opacity,
      180,
      30,
      35,
    );
  }

  void _selectBarangay(String barangay) {
    final bool alreadySelected =
        widget.selectedBarangay == barangay;

    widget.onBarangaySelected(
      alreadySelected ? '' : barangay,
    );

    if (!alreadySelected) {
      _focusOnBarangay(barangay);
    }
  }

  void _focusOnSelectedBarangay() {
    final String? barangay = widget.selectedBarangay;

    if (barangay == null || barangay.isEmpty) {
      return;
    }

    _focusOnBarangay(barangay);
  }

  Future<void> _focusOnBarangay(String barangay) async {
    final GoogleMapController? controller = _mapController;

    if (controller == null) {
      return;
    }

    final List<List<LatLng>> polygons =
        _barangayBoundaries[barangay] ?? [];

    if (polygons.isEmpty) {
      return;
    }

    final List<LatLng> points = polygons
        .expand((polygon) => polygon)
        .toList();

    if (points.isEmpty) {
      return;
    }

    double minLat = points.first.latitude;
    double maxLat = points.first.latitude;
    double minLng = points.first.longitude;
    double maxLng = points.first.longitude;

    for (final LatLng point in points) {
      if (point.latitude < minLat) minLat = point.latitude;
      if (point.latitude > maxLat) maxLat = point.latitude;
      if (point.longitude < minLng) minLng = point.longitude;
      if (point.longitude > maxLng) maxLng = point.longitude;
    }

    if ((maxLat - minLat).abs() < 0.0005) {
      maxLat += 0.0005;
      minLat -= 0.0005;
    }

    if ((maxLng - minLng).abs() < 0.0005) {
      maxLng += 0.0005;
      minLng -= 0.0005;
    }

    final LatLngBounds bounds = LatLngBounds(
      southwest: LatLng(minLat, minLng),
      northeast: LatLng(maxLat, maxLng),
    );

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(bounds, 70),
      );
    } catch (e) {
      debugPrint('Error focusing on barangay $barangay: $e');
    }
  }

  Widget _buildMapLegend(Color cardColor, Color textColor) {
    return Positioned(
      left: 16,
      bottom: 16,
      child: Card(
        color: cardColor,
        elevation: 4,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'AVAILABLE DONORS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.7,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 8),
              _legendItem(
                _isDarkMode() ? const Color(0x25FFFFFF) : const Color(0x15000000),
                'No available donors',
                textColor,
              ),
              const SizedBox(height: 5),
              _legendItem(
                const Color(0x66B41E23),
                'Available donors',
                textColor,
              ),
              const SizedBox(height: 5),
              _legendItem(
                const Color(0x667A1C1E),
                'Selected barangay',
                textColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendItem(Color color, String text, Color textColor) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(
              color: const Color(0xFF7A1C1E),
              width: 1,
            ),
          ),
        ),
        const SizedBox(width: 7),
        Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: textColor.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildSelectedBarangayCard(Color cardColor, Color textColor) {
    final String? barangay = widget.selectedBarangay;

    if (barangay == null || barangay.isEmpty) {
      return const SizedBox.shrink();
    }

    final int count = _barangayDonorCounts[barangay] ?? 0;

    return Positioned(
      top: 16,
      left: 16,
      right: 16,
      child: Center(
        child: Card(
          color: cardColor,
          elevation: 5,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 10,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.location_on,
                  size: 18,
                  color: Color(0xFF7A1C1E),
                ),
                const SizedBox(width: 8),
                Text(
                  barangay,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: textColor,
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEE4E2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$count available',
                    style: const TextStyle(
                      color: Color(0xFFB42318),
                      fontWeight: FontWeight.bold,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = _isDarkMode();

    final cardColor = isDark ? const Color(0xFF292929) : Colors.white;
    final textColor = theme.colorScheme.onSurface;

    return Container(
      color: theme.scaffoldBackgroundColor,
      child: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: _initialCameraPosition,
            mapType: MapType.normal,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            mapToolbarEnabled: false,
            polygons: _buildBarangayPolygons(),
            onMapCreated: (GoogleMapController controller) {
              _mapController = controller;
              _applyMapTheme();

              if (mounted) {
                setState(() {
                  _isMapLoading = false;
                });
              }

              _focusOnSelectedBarangay();
            },
          ),

          // Header
          Positioned(
            top: 16,
            left: 16,
            child: Card(
              color: cardColor,
              elevation: 4,
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'DIGOS CITY BARANGAY MAP',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.8,
                        color: Color(0xFF7A1C1E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      widget.selectedBloodType == 'ALL'
                          ? 'All available donors'
                          : '${widget.selectedBloodType} available donors',
                      style: TextStyle(
                        fontSize: 10,
                        color: textColor.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Selected barangay information.
          _buildSelectedBarangayCard(cardColor, textColor),

          // Legend
          _buildMapLegend(cardColor, textColor),

          // Loading indicator.
          if (_isLoading || _isMapLoading)
            Positioned(
              top: 16,
              right: 16,
              child: Card(
                color: cardColor,
                elevation: 4,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 13,
                        height: 13,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        _isMapLoading
                            ? 'Loading map...'
                            : 'Syncing donors...',
                        style: TextStyle(
                          fontSize: 10,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}