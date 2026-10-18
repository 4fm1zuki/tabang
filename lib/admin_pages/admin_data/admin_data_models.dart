import 'package:flutter/material.dart';

// Key Metric Summary Model
class AnalyticsSummary {
  final int totalDonationsToday;
  final int totalDonationsThisMonth;
  final int totalRegisteredUsers;
  final int totalActiveDonors;
  final int activeBloodDrives;
  final String topDonatingBarangay;

  AnalyticsSummary({
    required this.totalDonationsToday,
    required this.totalDonationsThisMonth,
    required this.totalRegisteredUsers,
    required this.totalActiveDonors,
    required this.activeBloodDrives,
    required this.topDonatingBarangay,
  });
}

// Blood Type Breakdown Data Model
class BloodTypeStat {
  final String bloodType;
  final int totalDonated;
  final int totalRequested;

  BloodTypeStat({
    required this.bloodType,
    required this.totalDonated,
    required this.totalRequested,
  });
}

// Barangay Distribution Data Model
class BarangayStat {
  final String barangayName;
  final int donationCount;
  final double percentage;

  BarangayStat({
    required this.barangayName,
    required this.donationCount,
    required this.percentage,
  });
}

// Blood Drive Info Model
class BloodDriveInfo {
  final String title;
  final String location;
  final String date;
  final int expectedDonors;
  final String status;

  BloodDriveInfo({
    required this.title,
    required this.location,
    required this.date,
    required this.expectedDonors,
    required this.status,
  });
}

// Dummy Data Repository
class AdminAnalyticsRepository {
  static AnalyticsSummary getSummaryData() {
    return AnalyticsSummary(
      totalDonationsToday: 18,
      totalDonationsThisMonth: 342,
      totalRegisteredUsers: 1250,
      totalActiveDonors: 840,
      activeBloodDrives: 4,
      topDonatingBarangay: 'Barangay Zone 3',
    );
  }

  static List<BloodTypeStat> getBloodTypeStats() {
    return [
      BloodTypeStat(bloodType: 'O+', totalDonated: 145, totalRequested: 160),
      BloodTypeStat(bloodType: 'A+', totalDonated: 98, totalRequested: 85),
      BloodTypeStat(bloodType: 'B+', totalDonated: 64, totalRequested: 70),
      BloodTypeStat(bloodType: 'O-', totalDonated: 22, totalRequested: 45),
      BloodTypeStat(bloodType: 'AB+', totalDonated: 18, totalRequested: 12),
      BloodTypeStat(bloodType: 'A-', totalDonated: 12, totalRequested: 15),
      BloodTypeStat(bloodType: 'B-', totalDonated: 8, totalRequested: 10),
      BloodTypeStat(bloodType: 'AB-', totalDonated: 5, totalRequested: 8),
    ];
  }

  static List<BarangayStat> getBarangayStats() {
    return [
      BarangayStat(barangayName: 'Barangay Zone 3', donationCount: 92, percentage: 0.27),
      BarangayStat(barangayName: 'Barangay Kapatagan', donationCount: 68, percentage: 0.20),
      BarangayStat(barangayName: 'Barangay Matti', donationCount: 54, percentage: 0.16),
      BarangayStat(barangayName: 'Barangay Aplaya', donationCount: 45, percentage: 0.13),
      BarangayStat(barangayName: 'Barangay Tres De Mayo', donationCount: 38, percentage: 0.11),
      BarangayStat(barangayName: 'Barangay San Jose', donationCount: 25, percentage: 0.07),
    ];
  }

  static List<BloodDriveInfo> getBloodDrives() {
    return [
      BloodDriveInfo(
        title: 'Digos City Gym Blood Drive',
        location: 'Digos City Gymnasium, Zone 1',
        date: 'Oct 18, 2026 • 8:00 AM',
        expectedDonors: 120,
        status: 'Upcoming',
      ),
      BloodDriveInfo(
        title: 'Barangay Matti Health Drive',
        location: 'Matti Covered Court',
        date: 'Oct 22, 2026 • 9:00 AM',
        expectedDonors: 75,
        status: 'Upcoming',
      ),
      BloodDriveInfo(
        title: 'Cor Jesu College Campus Mobile Drive',
        location: 'Student Activity Center',
        date: 'Oct 28, 2026 • 10:00 AM',
        expectedDonors: 150,
        status: 'Scheduled',
      ),
    ];
  }
}