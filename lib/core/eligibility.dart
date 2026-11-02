import 'models.dart';

/// Why a donor is or is not currently eligible to give blood.
enum EligibilityBlocker {
  none('Eligible'),
  cooldown('Within donation cooldown'),
  underage('Below minimum age'),
  overage('Above maximum age'),
  underweight('Below minimum weight'),
  weightMissing('Weight not recorded'),
  suspended('Account suspended'),
  unverified('Blood card not verified'),
  unavailable('Marked unavailable'),
  noBloodType('Blood type not recorded');

  const EligibilityBlocker(this.label);
  final String label;
}

/// Result of an eligibility evaluation, carrying the reason and the date the
/// donor becomes eligible again (when the blocker is a cooldown).
class EligibilityResult {
  const EligibilityResult({
    required this.isEligible,
    required this.blocker,
    this.eligibleFrom,
    this.daysRemaining = 0,
    this.donorType,
  });

  final bool isEligible;
  final EligibilityBlocker blocker;

  /// The date the donor may next donate. Null when not in cooldown.
  final DateTime? eligibleFrom;

  /// Whole days remaining in the cooldown. Zero when not in cooldown.
  final int daysRemaining;

  /// The blood type the donor would be giving, when known.
  final BloodType? donorType;

  String get summary {
    if (isEligible) return 'Eligible to donate';
    if (blocker == EligibilityBlocker.cooldown && daysRemaining > 0) {
      return 'Cooldown active — $daysRemaining day${daysRemaining == 1 ? '' : 's'} remaining';
    }
    return blocker.label;
  }
}

/// Donation eligibility rules.
///
/// Intervals follow Philippine Red Cross / RA 7719 practice, which the paper
/// aligns with on p.6 (the e-RaktAlert three-month lock). The previous build
/// had no cooldown logic at all and displayed eligibility as a hardcoded
/// string; this class is what makes the SEIPS "cooldown enforcement" item on
/// p.11 measurable.
class EligibilityEngine {
  const EligibilityEngine._();

  /// Minimum donor age, per the study's respondent criteria (paper p.17).
  static const int minimumAge = 18;

  /// Maximum donor age, per the study's respondent criteria (paper p.17).
  static const int maximumAge = 65;

  /// Minimum donor weight in kilograms.
  static const double minimumWeightKg = 50;

  /// Minimum interval between donations, by component.
  ///
  /// Whole blood and packed RBC both represent a full red-cell donation, so
  /// they share the 12-week interval. Platelets and plasma are returned or
  /// replaced faster and follow shorter cycles.
  static const Map<BloodComponent, int> cooldownDays = {
    BloodComponent.wholeBlood: 84,
    BloodComponent.packedRbc: 84,
    BloodComponent.platelets: 14,
    BloodComponent.plasma: 28,
  };

  /// The cooldown applied when the component is not specified.
  static const int defaultCooldownDays = 84;

  static int cooldownFor(BloodComponent? component) {
    if (component == null) return defaultCooldownDays;
    return cooldownDays[component] ?? defaultCooldownDays;
  }

  /// Evaluate a donor against every eligibility rule.
  ///
  /// [now] is injectable so tests are deterministic.
  static EligibilityResult evaluate(
    AppUser donor, {
    BloodComponent? component,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();

    if (donor.status == AccountStatus.suspended) {
      return EligibilityResult(
        isEligible: false,
        blocker: EligibilityBlocker.suspended,
        donorType: donor.bloodType,
      );
    }

    // A donor's blood card must be reviewed before they can be matched.
    // This mirrors the "information validation" step in the donor flow.
    if (donor.status == AccountStatus.unverified) {
      return EligibilityResult(
        isEligible: false,
        blocker: EligibilityBlocker.unverified,
        donorType: donor.bloodType,
      );
    }

    if (donor.bloodType == null) {
      return const EligibilityResult(
        isEligible: false,
        blocker: EligibilityBlocker.noBloodType,
      );
    }

    final age = donor.age;
    if (age != null && age < minimumAge) {
      return EligibilityResult(
        isEligible: false,
        blocker: EligibilityBlocker.underage,
        donorType: donor.bloodType,
      );
    }
    if (age != null && age > maximumAge) {
      return EligibilityResult(
        isEligible: false,
        blocker: EligibilityBlocker.overage,
        donorType: donor.bloodType,
      );
    }

    // Weight is a donor-safety requirement, not a cosmetic profile field.
    // A missing value blocks matching rather than silently passing the check.
    if (donor.role == UserRole.donor && donor.weightKg == null) {
      return EligibilityResult(
        isEligible: false,
        blocker: EligibilityBlocker.weightMissing,
        donorType: donor.bloodType,
      );
    }
    if (donor.weightKg != null && donor.weightKg! < minimumWeightKg) {
      return EligibilityResult(
        isEligible: false,
        blocker: EligibilityBlocker.underweight,
        donorType: donor.bloodType,
      );
    }

    if (!donor.isAvailable) {
      return EligibilityResult(
        isEligible: false,
        blocker: EligibilityBlocker.unavailable,
        donorType: donor.bloodType,
      );
    }

    final last = donor.lastDonationDate;
    if (last != null) {
      final window = cooldownFor(component);
      final eligibleFrom = last.add(Duration(days: window));
      if (today.isBefore(eligibleFrom)) {
        final remaining = eligibleFrom.difference(today);
        return EligibilityResult(
          isEligible: false,
          blocker: EligibilityBlocker.cooldown,
          eligibleFrom: eligibleFrom,
          daysRemaining: remaining.inHours ~/ 24 + 1,
          donorType: donor.bloodType,
        );
      }
    }

    return EligibilityResult(
      isEligible: true,
      blocker: EligibilityBlocker.none,
      donorType: donor.bloodType,
    );
  }

  /// The date a donor becomes eligible again, or null if already eligible.
  static DateTime? nextEligibleDate(
    AppUser donor, {
    BloodComponent? component,
    DateTime? now,
  }) {
    final result = evaluate(donor, component: component, now: now);
    return result.isEligible ? null : result.eligibleFrom;
  }
}

/// ABO/Rh transfusion compatibility.
///
/// Red-cell rules: O- is the universal donor, AB+ the universal recipient.
/// Plasma follows the *reverse* ABO rule because plasma carries antibodies:
/// AB plasma is the universal plasma donor and O plasma can only go to O
/// recipients. Applying red-cell rules to plasma, as the previous build did,
/// is a patient-safety error. Platelets use the ABO/Rh red-cell baseline in
/// this prototype, with ABO-identical units preferred in clinical practice.
class Compatibility {
  const Compatibility._();

  /// Whether red cells from [donor] can be transfused into [recipient].
  static bool canDonateTo(BloodType donor, BloodType recipient) {
    switch (recipient) {
      case BloodType.oNeg:
        return donor == BloodType.oNeg;
      case BloodType.oPos:
        return donor == BloodType.oNeg || donor == BloodType.oPos;
      case BloodType.aNeg:
        return donor == BloodType.oNeg || donor == BloodType.aNeg;
      case BloodType.aPos:
        return donor == BloodType.oNeg ||
            donor == BloodType.oPos ||
            donor == BloodType.aNeg ||
            donor == BloodType.aPos;
      case BloodType.bNeg:
        return donor == BloodType.oNeg || donor == BloodType.bNeg;
      case BloodType.bPos:
        return donor == BloodType.oNeg ||
            donor == BloodType.oPos ||
            donor == BloodType.bNeg ||
            donor == BloodType.bPos;
      case BloodType.abNeg:
        return donor == BloodType.oNeg ||
            donor == BloodType.aNeg ||
            donor == BloodType.bNeg ||
            donor == BloodType.abNeg;
      case BloodType.abPos:
        return true;
    }
  }

  /// Every blood type that can safely give to [recipient].
  static List<BloodType> donorsFor(BloodType recipient) {
    return BloodType.values
        .where((d) => canDonateTo(d, recipient))
        .toList(growable: false);
  }

  /// Every blood type [donor] can safely give to.
  static List<BloodType> recipientsFor(BloodType donor) {
    return BloodType.values
        .where((r) => canDonateTo(donor, r))
        .toList(growable: false);
  }

  /// Whether plasma from [donor] can be transfused into [recipient].
  ///
  /// Plasma compatibility is the reverse of red-cell compatibility:
  /// AB plasma has no anti-A/anti-B and is the universal plasma donor; O
  /// plasma carries both antibodies and can only go to an O recipient.
  static bool canDonatePlasmaTo(BloodType donor, BloodType recipient) {
    switch (donor) {
      case BloodType.abNeg:
      case BloodType.abPos:
        return true;
      case BloodType.aNeg:
      case BloodType.aPos:
        return recipient == BloodType.aNeg ||
            recipient == BloodType.aPos ||
            recipient == BloodType.oNeg ||
            recipient == BloodType.oPos;
      case BloodType.bNeg:
      case BloodType.bPos:
        return recipient == BloodType.bNeg ||
            recipient == BloodType.bPos ||
            recipient == BloodType.oNeg ||
            recipient == BloodType.oPos;
      case BloodType.oNeg:
      case BloodType.oPos:
        return recipient == BloodType.oNeg || recipient == BloodType.oPos;
    }
  }

  /// Whether platelets from [donor] can be transfused into [recipient].
  ///
  /// ABO/Rh matching follows the red-cell baseline. ABO-identical units are
  /// preferred clinically; this prototype does not model antigen-negative
  /// selection or HLA matching.
  static bool canDonatePlateletsTo(BloodType donor, BloodType recipient) {
    return canDonateTo(donor, recipient);
  }

  /// Component-aware compatibility used by inventory filters, request
  /// matching and the donor response guard.
  static bool canDonateComponentTo(
    BloodType donor,
    BloodType recipient,
    BloodComponent component,
  ) {
    switch (component) {
      case BloodComponent.wholeBlood:
      case BloodComponent.packedRbc:
        return canDonateTo(donor, recipient);
      case BloodComponent.plasma:
        return canDonatePlasmaTo(donor, recipient);
      case BloodComponent.platelets:
        return canDonatePlateletsTo(donor, recipient);
    }
  }

  /// Every blood type that can safely provide [component] to [recipient].
  static List<BloodType> donorsForComponent(
    BloodType recipient,
    BloodComponent component,
  ) {
    return BloodType.values
        .where((d) => canDonateComponentTo(d, recipient, component))
        .toList(growable: false);
  }

  /// Every recipient blood type that can safely receive [component] from
  /// [donor].
  static List<BloodType> recipientsForComponent(
    BloodType donor,
    BloodComponent component,
  ) {
    return BloodType.values
        .where((r) => canDonateComponentTo(donor, r, component))
        .toList(growable: false);
  }
}
