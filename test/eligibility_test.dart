import 'package:flutter_test/flutter_test.dart';
import 'package:tabang/core/eligibility.dart';
import 'package:tabang/core/models.dart';
import 'package:tabang/core/repository.dart';

AppUser donor({
  BloodType? bloodType = BloodType.oNeg,
  DateTime? lastDonation,
  bool isAvailable = true,
  AccountStatus status = AccountStatus.verified,
  DateTime? birthDate,
  double? weightKg = 60,
}) {
  return AppUser(
    id: 'T-001',
    fullName: 'Test Donor',
    alias: 'Test',
    email: 'test@tabang.app',
    phone: '+63 900 000 0000',
    barangay: 'Zone 1',
    role: UserRole.donor,
    registeredOn: DateTime(2025, 1, 1),
    bloodType: bloodType,
    birthDate: birthDate ?? DateTime(1995, 1, 1),
    weightKg: weightKg,
    status: status,
    lastDonationDate: lastDonation,
    isAvailable: isAvailable,
  );
}

void main() {
  group('Compatibility — ABO/Rh red cell rules', () {
    test('O- is the universal donor', () {
      for (final recipient in BloodType.values) {
        expect(
          Compatibility.canDonateTo(BloodType.oNeg, recipient),
          isTrue,
          reason: 'O- should give to ${recipient.label}',
        );
      }
    });

    test('AB+ is the universal recipient', () {
      for (final donorType in BloodType.values) {
        expect(
          Compatibility.canDonateTo(donorType, BloodType.abPos),
          isTrue,
          reason: '${donorType.label} should give to AB+',
        );
      }
    });

    test('O- recipient can only receive from O-', () {
      for (final donorType in BloodType.values) {
        expect(
          Compatibility.canDonateTo(donorType, BloodType.oNeg),
          donorType == BloodType.oNeg,
          reason: '${donorType.label} -> O-',
        );
      }
    });

    test('AB+ donor can only give to AB+', () {
      for (final recipient in BloodType.values) {
        expect(
          Compatibility.canDonateTo(BloodType.abPos, recipient),
          recipient == BloodType.abPos,
          reason: 'AB+ -> ${recipient.label}',
        );
      }
    });

    test('A+ recipient accepts O-, O+, A-, A+ only', () {
      expect(Compatibility.donorsFor(BloodType.aPos).toSet(), {
        BloodType.oNeg,
        BloodType.oPos,
        BloodType.aNeg,
        BloodType.aPos,
      });
    });

    test('B- recipient accepts O- and B- only', () {
      expect(Compatibility.donorsFor(BloodType.bNeg).toSet(), {
        BloodType.oNeg,
        BloodType.bNeg,
      });
    });

    test('every blood type has at least one donor source', () {
      for (final recipient in BloodType.values) {
        expect(Compatibility.donorsFor(recipient), isNotEmpty);
      }
    });

    test('recipientsFor is the inverse of donorsFor', () {
      for (final donorType in BloodType.values) {
        for (final recipient in Compatibility.recipientsFor(donorType)) {
          expect(Compatibility.donorsFor(recipient), contains(donorType));
        }
      }
    });
  });

  group('EligibilityEngine — cooldown enforcement', () {
    final now = DateTime(2026, 10, 31);

    test('first-time donor with no last donation is eligible', () {
      final result = EligibilityEngine.evaluate(donor(), now: now);
      expect(result.isEligible, isTrue);
      expect(result.blocker, EligibilityBlocker.none);
    });

    test('donor inside 84-day whole blood cooldown is blocked', () {
      final result = EligibilityEngine.evaluate(
        donor(lastDonation: now.subtract(const Duration(days: 30))),
        component: BloodComponent.wholeBlood,
        now: now,
      );
      expect(result.isEligible, isFalse);
      expect(result.blocker, EligibilityBlocker.cooldown);
      expect(result.daysRemaining, greaterThan(0));
      expect(result.eligibleFrom, isNotNull);
    });

    test('donor past the 84-day cooldown is eligible', () {
      final result = EligibilityEngine.evaluate(
        donor(lastDonation: now.subtract(const Duration(days: 85))),
        component: BloodComponent.wholeBlood,
        now: now,
      );
      expect(result.isEligible, isTrue);
    });

    test('exactly on the cooldown boundary is eligible', () {
      final result = EligibilityEngine.evaluate(
        donor(lastDonation: now.subtract(const Duration(days: 84))),
        component: BloodComponent.wholeBlood,
        now: now,
      );
      expect(result.isEligible, isTrue);
    });

    test('platelet cooldown is shorter than whole blood', () {
      final last = now.subtract(const Duration(days: 20));
      final platelets = EligibilityEngine.evaluate(
        donor(lastDonation: last),
        component: BloodComponent.platelets,
        now: now,
      );
      final wholeBlood = EligibilityEngine.evaluate(
        donor(lastDonation: last),
        component: BloodComponent.wholeBlood,
        now: now,
      );

      expect(platelets.isEligible, isTrue);
      expect(wholeBlood.isEligible, isFalse);
    });

    test('suspended account is never eligible', () {
      final result = EligibilityEngine.evaluate(
        donor(status: AccountStatus.suspended),
        now: now,
      );
      expect(result.isEligible, isFalse);
      expect(result.blocker, EligibilityBlocker.suspended);
    });

    test('unavailable donor is blocked', () {
      final result = EligibilityEngine.evaluate(
        donor(isAvailable: false),
        now: now,
      );
      expect(result.isEligible, isFalse);
      expect(result.blocker, EligibilityBlocker.unavailable);
    });

    test('under-18 donor is blocked', () {
      final result = EligibilityEngine.evaluate(
        donor(birthDate: DateTime(2012, 1, 1)),
        now: now,
      );
      expect(result.isEligible, isFalse);
      expect(result.blocker, EligibilityBlocker.underage);
    });

    test('over-65 donor is blocked', () {
      final result = EligibilityEngine.evaluate(
        donor(birthDate: DateTime(1950, 1, 1)),
        now: now,
      );
      expect(result.isEligible, isFalse);
      expect(result.blocker, EligibilityBlocker.overage);
    });

    test('donor below the minimum weight is blocked', () {
      final result = EligibilityEngine.evaluate(
        donor(weightKg: 49.9),
        now: now,
      );
      expect(result.isEligible, isFalse);
      expect(result.blocker, EligibilityBlocker.underweight);
    });

    test('donor without a recorded weight is blocked', () {
      final result = EligibilityEngine.evaluate(
        donor(weightKg: null),
        now: now,
      );
      expect(result.isEligible, isFalse);
      expect(result.blocker, EligibilityBlocker.weightMissing);
    });

    test('donor without a recorded blood type is blocked', () {
      final result = EligibilityEngine.evaluate(
        donor(bloodType: null),
        now: now,
      );
      expect(result.isEligible, isFalse);
      expect(result.blocker, EligibilityBlocker.noBloodType);
    });

    test('nextEligibleDate returns null when already eligible', () {
      expect(EligibilityEngine.nextEligibleDate(donor(), now: now), isNull);
    });

    test('nextEligibleDate is last donation plus the cooldown window', () {
      final last = DateTime(2026, 10, 1);
      final next = EligibilityEngine.nextEligibleDate(
        donor(lastDonation: last),
        component: BloodComponent.wholeBlood,
        now: now,
      );
      expect(next, last.add(const Duration(days: 84)));
    });
  });

  group('DigosBarangays — canonicalisation', () {
    test('all 26 barangays are listed', () {
      expect(DigosBarangays.all.length, 26);
    });

    test('parenthetical suffixes are stripped', () {
      expect(DigosBarangays.canonical('Zone 1 (Pob.)'), 'Zone 1');
      expect(DigosBarangays.canonical('San Jose (Balutakay)'), 'San Jose');
      expect(DigosBarangays.canonical('Kapatagan (Rizal)'), 'Kapatagan');
    });

    test('case and punctuation are ignored', () {
      expect(DigosBarangays.canonical('TRES DE MAYO'), 'Tres De Mayo');
      expect(DigosBarangays.canonical('san-agustin'), 'San Agustin');
    });

    test('unknown names return null', () {
      expect(DigosBarangays.canonical('Atlantis'), isNull);
      expect(DigosBarangays.canonical(null), isNull);
    });

    test('every canonical result is in the master list', () {
      for (final name in DigosBarangays.all) {
        expect(DigosBarangays.canonical(name), name);
      }
    });
  });
}
