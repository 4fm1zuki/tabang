import 'package:flutter/material.dart';

/// Model representing a single Barangay polygon shape
class BarangayPolygon {
  final String name;
  final List<Offset> points;

  BarangayPolygon({required this.name, required this.points});

  Path getPath(Size size) {
    final path = Path();
    if (points.isEmpty) return path;

    path.moveTo(points.first.dx * size.width, points.first.dy * size.height);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx * size.width, points[i].dy * size.height);
    }
    path.close();
    return path;
  }
}

class DonorData {
  /// Polygon boundaries for all 26 Digos City Barangays based on map image
  static final List<BarangayPolygon> polygons = [
    // --- NORTH & WEST REGION ---
    BarangayPolygon(
      name: 'Kapatagan (Rizal)',
      points: const [
        Offset(0.14, 0.02),
        Offset(0.66, 0.12),
        Offset(0.63, 0.36),
        Offset(0.55, 0.35),
        Offset(0.41, 0.39),
        Offset(0.33, 0.33),
        Offset(0.13, 0.24),
      ],
    ),
    BarangayPolygon(
      name: 'Balabag',
      points: const [
        Offset(0.13, 0.24),
        Offset(0.20, 0.28),
        Offset(0.16, 0.58),
        Offset(0.04, 0.52),
        Offset(0.06, 0.38),
      ],
    ),
    BarangayPolygon(
      name: 'Goma',
      points: const [
        Offset(0.20, 0.28),
        Offset(0.33, 0.33),
        Offset(0.35, 0.52),
        Offset(0.16, 0.58),
      ],
    ),
    BarangayPolygon(
      name: 'Dulangan',
      points: const [
        Offset(0.33, 0.33),
        Offset(0.41, 0.39),
        Offset(0.48, 0.65),
        Offset(0.37, 0.61),
        Offset(0.35, 0.52),
      ],
    ),
    BarangayPolygon(
      name: 'Binaton',
      points: const [
        Offset(0.41, 0.39),
        Offset(0.55, 0.35),
        Offset(0.63, 0.36),
        Offset(0.62, 0.50),
        Offset(0.66, 0.57),
        Offset(0.60, 0.58),
        Offset(0.48, 0.65),
      ],
    ),

    // --- MID-WEST & MID-EAST CLUSTER ---
    BarangayPolygon(
      name: 'Mahayahay',
      points: const [
        Offset(0.16, 0.58),
        Offset(0.22, 0.61),
        Offset(0.19, 0.65),
        Offset(0.09, 0.62),
      ],
    ),
    BarangayPolygon(
      name: 'Lungag',
      points: const [
        Offset(0.09, 0.62),
        Offset(0.19, 0.65),
        Offset(0.15, 0.70),
        Offset(0.08, 0.66),
      ],
    ),
    BarangayPolygon(
      name: 'San Agustin',
      points: const [
        Offset(0.22, 0.61),
        Offset(0.35, 0.52),
        Offset(0.37, 0.61),
        Offset(0.43, 0.67),
        Offset(0.31, 0.72),
        Offset(0.27, 0.66),
        Offset(0.19, 0.65),
      ],
    ),
    BarangayPolygon(
      name: 'Soong',
      points: const [
        Offset(0.60, 0.58),
        Offset(0.66, 0.57),
        Offset(0.71, 0.64),
        Offset(0.60, 0.65),
      ],
    ),
    BarangayPolygon(
      name: 'Ruparan',
      points: const [
        Offset(0.48, 0.65),
        Offset(0.60, 0.58),
        Offset(0.60, 0.65),
        Offset(0.58, 0.72),
        Offset(0.52, 0.75),
        Offset(0.43, 0.67),
      ],
    ),
    BarangayPolygon(
      name: 'Tres de Mayo',
      points: const [
        Offset(0.60, 0.65),
        Offset(0.71, 0.64),
        Offset(0.75, 0.69),
        Offset(0.63, 0.73),
        Offset(0.58, 0.72),
      ],
    ),

    // --- SOUTH WEST (RURAL/COASTAL) ---
    BarangayPolygon(
      name: 'San Roque',
      points: const [
        Offset(0.15, 0.70),
        Offset(0.27, 0.66),
        Offset(0.24, 0.78),
        Offset(0.17, 0.75),
      ],
    ),
    BarangayPolygon(
      name: 'Matti',
      points: const [
        Offset(0.27, 0.66),
        Offset(0.31, 0.72),
        Offset(0.35, 0.78),
        Offset(0.24, 0.78),
      ],
    ),
    BarangayPolygon(
      name: 'Colorado',
      points: const [
        Offset(0.17, 0.75),
        Offset(0.24, 0.78),
        Offset(0.29, 0.85),
        Offset(0.21, 0.85),
      ],
    ),
    BarangayPolygon(
      name: 'Igpit',
      points: const [
        Offset(0.21, 0.85),
        Offset(0.31, 0.85),
        Offset(0.26, 0.90),
        Offset(0.19, 0.89),
      ],
    ),
    BarangayPolygon(
      name: 'San Miguel (Odaca)',
      points: const [
        Offset(0.31, 0.85),
        Offset(0.45, 0.85),
        Offset(0.43, 0.92),
        Offset(0.26, 0.90),
      ],
    ),
    BarangayPolygon(
      name: 'San Jose (Balutakay)',
      points: const [
        Offset(0.38, 0.92),
        Offset(0.57, 0.91),
        Offset(0.55, 0.96),
        Offset(0.38, 0.95),
      ],
    ),

    // --- CENTRAL URBAN / POBLACION ---
    BarangayPolygon(
      name: 'Zone 1 (Pob.)',
      points: const [
        Offset(0.52, 0.75),
        Offset(0.58, 0.72),
        Offset(0.63, 0.73),
        Offset(0.63, 0.78),
        Offset(0.55, 0.79),
      ],
    ),
    BarangayPolygon(
      name: 'Kiagot',
      points: const [
        Offset(0.63, 0.73),
        Offset(0.75, 0.69),
        Offset(0.78, 0.77),
        Offset(0.63, 0.78),
      ],
    ),
    BarangayPolygon(
      name: 'Sinawilan',
      points: const [
        Offset(0.75, 0.69),
        Offset(0.85, 0.73),
        Offset(0.81, 0.78),
        Offset(0.78, 0.77),
      ],
    ),
    BarangayPolygon(
      name: 'Zone 2 (Pob.)',
      points: const [
        Offset(0.43, 0.77),
        Offset(0.55, 0.79),
        Offset(0.55, 0.82),
        Offset(0.40, 0.81),
      ],
    ),
    BarangayPolygon(
      name: 'Tiguman',
      points: const [
        Offset(0.35, 0.78),
        Offset(0.43, 0.77),
        Offset(0.40, 0.81),
        Offset(0.31, 0.85),
      ],
    ),
    BarangayPolygon(
      name: 'Zone 3 (Pob.)',
      points: const [
        Offset(0.31, 0.85),
        Offset(0.55, 0.82),
        Offset(0.57, 0.91),
        Offset(0.38, 0.92),
      ],
    ),

    // --- SOUTH EAST COASTAL ---
    BarangayPolygon(
      name: 'Cogon',
      points: const [
        Offset(0.63, 0.78),
        Offset(0.81, 0.78),
        Offset(0.83, 0.87),
        Offset(0.71, 0.87),
      ],
    ),
    BarangayPolygon(
      name: 'Aplaya',
      points: const [
        Offset(0.71, 0.87),
        Offset(0.83, 0.87),
        Offset(0.81, 0.93),
        Offset(0.72, 0.92),
      ],
    ),
    BarangayPolygon(
      name: 'Dawis',
      points: const [
        Offset(0.57, 0.91),
        Offset(0.71, 0.87),
        Offset(0.72, 0.92),
        Offset(0.66, 0.95),
      ],
    ),
  ];

  /// Dummy donor list matching all 26 barangays
  static final List<Map<String, String>> mockDonors = [
    // KAPATAGAN
    {'alias': 'Donor #101', 'bloodType': 'O+', 'location': 'Kapatagan (Rizal)', 'lastDonated': '7 weeks ago', 'totalDonations': '2', 'verifiedSince': 'June 26, 2024'},
    {'alias': 'Donor #102', 'bloodType': 'A+', 'location': 'Kapatagan (Rizal)', 'lastDonated': '14 weeks ago', 'totalDonations': '6', 'verifiedSince': 'March 11, 2021'},
    {'alias': 'Donor #103', 'bloodType': 'B-', 'location': 'Kapatagan (Rizal)', 'lastDonated': '3 weeks ago', 'totalDonations': '1', 'verifiedSince': 'January 05, 2026'},
    {'alias': 'Donor #104', 'bloodType': 'O-', 'location': 'Kapatagan (Rizal)', 'lastDonated': '20 weeks ago', 'totalDonations': '4', 'verifiedSince': 'November 19, 2023'},

    // BALABAG
    {'alias': 'Donor #201', 'bloodType': 'O+', 'location': 'Balabag', 'lastDonated': '5 weeks ago', 'totalDonations': '3', 'verifiedSince': 'September 12, 2023'},
    {'alias': 'Donor #202', 'bloodType': 'B+', 'location': 'Balabag', 'lastDonated': '18 weeks ago', 'totalDonations': '8', 'verifiedSince': 'July 04, 2019'},

    // GOMA
    {'alias': 'Donor #301', 'bloodType': 'A+', 'location': 'Goma', 'lastDonated': '11 weeks ago', 'totalDonations': '4', 'verifiedSince': 'April 20, 2024'},
    {'alias': 'Donor #302', 'bloodType': 'O+', 'location': 'Goma', 'lastDonated': '6 weeks ago', 'totalDonations': '7', 'verifiedSince': 'August 08, 2020'},

    // DULANGAN
    {'alias': 'Donor #401', 'bloodType': 'O-', 'location': 'Dulangan', 'lastDonated': '4 weeks ago', 'totalDonations': '3', 'verifiedSince': 'November 10, 2024'},

    // BINATON
    {'alias': 'Donor #501', 'bloodType': 'A+', 'location': 'Binaton', 'lastDonated': '23 weeks ago', 'totalDonations': '5', 'verifiedSince': 'May 09, 2020'},

    // MAHAYAHAY
    {'alias': 'Donor #551', 'bloodType': 'AB+', 'location': 'Mahayahay', 'lastDonated': '2 weeks ago', 'totalDonations': '3', 'verifiedSince': 'August 14, 2025'},

    // LUNGAG
    {'alias': 'Donor #561', 'bloodType': 'O+', 'location': 'Lungag', 'lastDonated': '10 weeks ago', 'totalDonations': '2', 'verifiedSince': 'February 01, 2024'},

    // SAN AGUSTIN
    {'alias': 'Donor #601', 'bloodType': 'O+', 'location': 'San Agustin', 'lastDonated': '6 weeks ago', 'totalDonations': '4', 'verifiedSince': 'July 15, 2023'},

    // SOONG
    {'alias': 'Donor #651', 'bloodType': 'B+', 'location': 'Soong', 'lastDonated': '12 weeks ago', 'totalDonations': '1', 'verifiedSince': 'May 19, 2025'},

    // RUPARAN
    {'alias': 'Donor #701', 'bloodType': 'B+', 'location': 'Ruparan', 'lastDonated': '3 weeks ago', 'totalDonations': '5', 'verifiedSince': 'February 12, 2022'},

    // TRES DE MAYO
    {'alias': 'Donor #1001', 'bloodType': 'AB+', 'location': 'Tres de Mayo', 'lastDonated': '12 weeks ago', 'totalDonations': '3', 'verifiedSince': 'November 03, 2023'},

    // SAN ROQUE
    {'alias': 'Donor #751', 'bloodType': 'A-', 'location': 'San Roque', 'lastDonated': '8 weeks ago', 'totalDonations': '4', 'verifiedSince': 'October 11, 2024'},

    // MATTI
    {'alias': 'Donor #801', 'bloodType': 'O-', 'location': 'Matti', 'lastDonated': '4 weeks ago', 'totalDonations': '1', 'verifiedSince': 'August 12, 2026'},

    // COLORADO
    {'alias': 'Donor #811', 'bloodType': 'B+', 'location': 'Colorado', 'lastDonated': '15 weeks ago', 'totalDonations': '5', 'verifiedSince': 'January 09, 2023'},

    // IGPIT
    {'alias': 'Donor #821', 'bloodType': 'O+', 'location': 'Igpit', 'lastDonated': '1 week ago', 'totalDonations': '6', 'verifiedSince': 'April 22, 2022'},

    // SAN MIGUEL
    {'alias': 'Donor #831', 'bloodType': 'A+', 'location': 'San Miguel (Odaca)', 'lastDonated': '9 weeks ago', 'totalDonations': '3', 'verifiedSince': 'December 18, 2024'},

    // SAN JOSE
    {'alias': 'Donor #841', 'bloodType': 'O-', 'location': 'San Jose (Balutakay)', 'lastDonated': '2 weeks ago', 'totalDonations': '2', 'verifiedSince': 'June 10, 2025'},

    // ZONE 1
    {'alias': 'Donor #901', 'bloodType': 'B+', 'location': 'Zone 1 (Pob.)', 'lastDonated': '10 weeks ago', 'totalDonations': '4', 'verifiedSince': 'January 15, 2025'},

    // KIAGOT
    {'alias': 'Donor #911', 'bloodType': 'AB-', 'location': 'Kiagot', 'lastDonated': '6 weeks ago', 'totalDonations': '2', 'verifiedSince': 'November 05, 2024'},

    // SINAWILAN
    {'alias': 'Donor #921', 'bloodType': 'A+', 'location': 'Sinawilan', 'lastDonated': '4 weeks ago', 'totalDonations': '7', 'verifiedSince': 'March 14, 2021'},

    // ZONE 2
    {'alias': 'Donor #931', 'bloodType': 'O+', 'location': 'Zone 2 (Pob.)', 'lastDonated': '3 weeks ago', 'totalDonations': '5', 'verifiedSince': 'July 29, 2023'},

    // TIGUMAN
    {'alias': 'Donor #941', 'bloodType': 'B-', 'location': 'Tiguman', 'lastDonated': '18 weeks ago', 'totalDonations': '1', 'verifiedSince': 'September 02, 2025'},

    // ZONE 3
    {'alias': 'Donor #951', 'bloodType': 'A-', 'location': 'Zone 3 (Pob.)', 'lastDonated': '11 weeks ago', 'totalDonations': '4', 'verifiedSince': 'May 20, 2024'},

    // COGON
    {'alias': 'Donor #961', 'bloodType': 'O+', 'location': 'Cogon', 'lastDonated': '5 weeks ago', 'totalDonations': '8', 'verifiedSince': 'October 12, 2020'},

    // APLAYA
    {'alias': 'Donor #971', 'bloodType': 'AB+', 'location': 'Aplaya', 'lastDonated': '2 weeks ago', 'totalDonations': '3', 'verifiedSince': 'January 17, 2026'},

    // DAWIS
    {'alias': 'Donor #981', 'bloodType': 'B+', 'location': 'Dawis', 'lastDonated': '14 weeks ago', 'totalDonations': '2', 'verifiedSince': 'August 08, 2024'},
  ];
}