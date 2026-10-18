import 'package:flutter/material.dart';

enum AccountStatus { unverified, verified, warned, suspended }

class AppUser {
  final String id;
  final String fullName;
  final String alias;
  final String email;
  final String bloodType;
  final String barangay;
  final String bloodCardUrl; // Blood card verification image reference
  AccountStatus status;
  int warningCount;
  String? suspensionReason;

  AppUser({
    required this.id,
    required this.fullName,
    required this.alias,
    required this.email,
    required this.bloodType,
    required this.barangay,
    required this.bloodCardUrl,
    this.status = AccountStatus.unverified,
    this.warningCount = 0,
    this.suspensionReason,
  });
}

class UserManagementService {
  static List<AppUser> getInitialUsers() {
    return [
      AppUser(
        id: 'USR-801',
        fullName: 'Iverson Briones',
        alias: 'Iver',
        email: 'iversonbriones@gmail.com',
        bloodType: 'O+',
        barangay: 'Barangay Zone 3',
        bloodCardUrl: 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?q=80&w=400',
        status: AccountStatus.unverified,
        warningCount: 0,
      ),
      AppUser(
        id: 'USR-802',
        fullName: 'Maria Teresa Santos',
        alias: 'Tere',
        email: 'maria.santos@gmail.com',
        bloodType: 'A+',
        barangay: 'Barangay Kapatagan',
        bloodCardUrl: 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?q=80&w=400',
        status: AccountStatus.verified,
        warningCount: 1,
      ),
      AppUser(
        id: 'USR-803',
        fullName: 'Juan Miguel Dela Cruz',
        alias: 'Juan',
        email: 'juan.delacruz@yahoo.com',
        bloodType: 'B-',
        barangay: 'Barangay Matti',
        bloodCardUrl: 'https://images.unsplash.com/photo-1584515979956-d9f6e5d09982?q=80&w=400',
        status: AccountStatus.warned,
        warningCount: 2,
      ),
      AppUser(
        id: 'USR-804',
        fullName: 'Ricardo Dalisay',
        alias: 'Cardo',
        email: 'cardo.dalisay@gmail.com',
        bloodType: 'O-',
        barangay: 'Barangay Tres De Mayo',
        bloodCardUrl: 'https://images.unsplash.com/photo-1576091160399-112ba8d25d1d?q=80&w=400',
        status: AccountStatus.suspended,
        warningCount: 3,
        suspensionReason: 'Multiple no-shows for urgent blood donations.',
      ),
    ];
  }
}