import 'package:flutter/material.dart';

enum BloodComponent { all, wholeBlood, packedRbc, platelets, plasma }
enum BloodType { all, oNeg, oPos, aNeg, aPos, bNeg, bPos, abNeg, abPos }

class BloodUnit {
  final String barcode;
  final String bloodType;
  final String product;
  final BloodComponent component;
  String timeLeft;
  String storageBay;
  String status; // Available, Reserved, Quarantined, Dispatched

  BloodUnit({
    required this.barcode,
    required this.bloodType,
    required this.product,
    required this.component,
    required this.timeLeft,
    required this.storageBay,
    required this.status,
  });
}

class AdminBloodBankService {
  static final List<BloodUnit> initialInventory = [
    BloodUnit(
      barcode: 'RBC-8849-O-',
      bloodType: 'O-',
      product: 'Packed red blood cells',
      component: BloodComponent.packedRbc,
      timeLeft: '18 hours',
      storageBay: 'Cold room R-02 (4 °C)',
      status: 'Available',
    ),
    BloodUnit(
      barcode: 'RBC-8850-O-',
      bloodType: 'O-',
      product: 'Packed red blood cells',
      component: BloodComponent.packedRbc,
      timeLeft: '3 days',
      storageBay: 'Cold room R-02 (4 °C)',
      status: 'Available',
    ),
    BloodUnit(
      barcode: 'PLT-4019-A+',
      bloodType: 'A+',
      product: 'Platelets (apheresis)',
      component: BloodComponent.platelets,
      timeLeft: '48 hours',
      storageBay: 'Agitator A-01 (22 °C)',
      status: 'Available',
    ),
    BloodUnit(
      barcode: 'FFP-7712-B+',
      bloodType: 'B+',
      product: 'Fresh frozen plasma',
      component: BloodComponent.plasma,
      timeLeft: '180 days',
      storageBay: 'Freezer F-03 (-30 °C)',
      status: 'Available',
    ),
    BloodUnit(
      barcode: 'RBC-9014-AB-',
      bloodType: 'AB-',
      product: 'Packed red blood cells',
      component: BloodComponent.packedRbc,
      timeLeft: '14 days',
      storageBay: 'Bay 03 (4 °C)',
      status: 'Reserved',
    ),
    BloodUnit(
      barcode: 'WB-1092-A-',
      bloodType: 'A-',
      product: 'Whole blood',
      component: BloodComponent.wholeBlood,
      timeLeft: '4 days',
      storageBay: 'Cold room R-03 (4 °C)',
      status: 'Quarantined',
    ),
  ];
}