import 'package:flutter_test/flutter_test.dart';
import 'package:tabang/core/auth.dart';
import 'package:tabang/core/eligibility.dart';
import 'package:tabang/core/models.dart';
import 'package:tabang/core/repository.dart';

BloodRequest addRequest(
  TabangRepository repo, {
  required String patientAlias,
  BloodType bloodType = BloodType.oNeg,
  BloodComponent component = BloodComponent.packedRbc,
  int unitsNeeded = 1,
  RequestSource source = RequestSource.donorNetwork,
}) {
  repo.addRequest(
    requesterId: 'USR-009',
    patientAlias: patientAlias,
    bloodType: bloodType,
    component: component,
    unitsNeeded: unitsNeeded,
    hospital: DigosFacilities.names.first,
    barangay: 'Zone 2',
    urgency: RequestUrgency.urgent,
    source: source,
  );
  return repo.requests.firstWhere((r) => r.patientAlias == patientAlias);
}

void main() {
  final repo = TabangRepository.instance;

  setUp(repo.resetForTesting);

  group('Seed data', () {
    test('provides 15 available donors, 15 recipients and a community demo',
        () {
      final eligibleDonors = repo.users
          .where((u) =>
              u.role == UserRole.donor &&
              EligibilityEngine.evaluate(u).isEligible)
          .toList();
      expect(eligibleDonors, hasLength(15));

      final recipients = repo.users
          .where((u) => u.role == UserRole.recipient)
          .toList();
      expect(recipients, hasLength(15));

      final community =
          repo.users.where((u) => u.email == 'community@tabang.app').toList();
      expect(community, hasLength(1));
      expect(community.single.role, UserRole.user);

      // Profiles must be individually illustrated rather than sharing a
      // placeholder.
      final avatars = repo.users
          .map((u) => u.photoAsset)
          .whereType<String>()
          .toSet();
      expect(avatars.length, repo.users.length);
    });
  });

  group('Component-aware compatibility', () {
    test('plasma uses the reverse ABO rule', () {
      expect(
        Compatibility.canDonateComponentTo(
          BloodType.abPos,
          BloodType.oNeg,
          BloodComponent.plasma,
        ),
        isTrue,
        reason: 'AB plasma is the universal plasma donor',
      );
      expect(
        Compatibility.canDonateComponentTo(
          BloodType.oNeg,
          BloodType.aPos,
          BloodComponent.plasma,
        ),
        isFalse,
        reason: 'O plasma carries anti-A and cannot go to an A recipient',
      );
      expect(
        Compatibility.canDonateComponentTo(
          BloodType.aPos,
          BloodType.oNeg,
          BloodComponent.plasma,
        ),
        isTrue,
      );
    });

    test('platelets use the red-cell ABO/Rh baseline in this prototype', () {
      expect(
        Compatibility.canDonateComponentTo(
          BloodType.oNeg,
          BloodType.abPos,
          BloodComponent.platelets,
        ),
        isTrue,
      );
      expect(
        Compatibility.canDonateComponentTo(
          BloodType.abPos,
          BloodType.oNeg,
          BloodComponent.platelets,
        ),
        isFalse,
      );
    });

    test('plasma donorsForComponent(O-) includes every ABO type', () {
      expect(
        Compatibility.donorsForComponent(BloodType.oNeg, BloodComponent.plasma)
            .toSet(),
        BloodType.values.toSet(),
      );
    });
  });

  group('Expiry-aware inventory', () {
    test('an expired bag is never usable and is shown as expired', () {
      final now = DateTime(2026, 1, 10);
      final unit = BloodUnit(
        barcode: 'TEST-EXPIRED',
        bloodType: BloodType.oPos,
        component: BloodComponent.packedRbc,
        storageBay: 'Test',
        status: UnitStatus.available,
        collectedOn: now.subtract(const Duration(days: 43)),
        expiresOn: now.subtract(const Duration(days: 1)),
      );

      expect(unit.isExpiredAt(now), isTrue);
      expect(unit.isUsableAt(now), isFalse);
      expect(unit.effectiveStatus(now), UnitStatus.expired);
      expect(unit.timeLeft(now), 'Expired');
    });

    test('seed expired unit is excluded from available stock', () {
      final expired = repo.units.firstWhere(
        (u) => u.barcode == 'RBC-7700-O+',
      );
      expect(expired.effectiveStatus(DateTime.now()), UnitStatus.expired);
      expect(
        repo.availableUnits.any((u) => u.barcode == expired.barcode),
        isFalse,
      );
      expect(
        repo.expiringSoon(days: 30).any((u) => u.barcode == expired.barcode),
        isFalse,
      );
    });

    test('staff cannot return an expired bag to available stock', () {
      repo.setUnitStatus('RBC-7700-O+', UnitStatus.expired);
      expect(
        repo.units.firstWhere((u) => u.barcode == 'RBC-7700-O+').status,
        UnitStatus.expired,
      );

      repo.setUnitStatus('RBC-7700-O+', UnitStatus.available);
      expect(
        repo.units.firstWhere((u) => u.barcode == 'RBC-7700-O+').status,
        UnitStatus.expired,
        reason: 'expired stock must not be revived as available',
      );
    });

    test('compatibleUnitsFor is component- and expiry-aware', () {
      final now = DateTime.now();
      final units = repo.compatibleUnitsFor(
        recipientType: BloodType.oNeg,
        component: BloodComponent.packedRbc,
        now: now,
      );
      expect(units, isNotEmpty);
      expect(units.every((u) => u.component == BloodComponent.packedRbc), isTrue);
      expect(units.every((u) => u.isUsableAt(now)), isTrue);
      expect(
        units.every((u) =>
            Compatibility.canDonateTo(u.bloodType, BloodType.oNeg)),
        isTrue,
      );
    });
  });

  group('Request response and selection lifecycle', () {
    test('compatible eligible donor can respond', () {
      final request = addRequest(repo, patientAlias: 'Lifecycle 1');
      final response = repo.respondToRequest(
        requestId: request.id,
        donorId: 'USR-012', // O- eligible
        message: 'Available tomorrow.',
      );

      expect(response, isNotNull);
      expect(response!.status, ResponseStatus.pending);
      expect(repo.responsesFor(request.id), hasLength(1));
      expect(repo.requests.firstWhere((r) => r.id == request.id).status,
          RequestStatus.open);
    });

    test('incompatible, ineligible, suspended and duplicate responses fail',
        () {
      final request = addRequest(repo, patientAlias: 'Lifecycle 2');

      expect(
        repo.respondToRequest(
          requestId: request.id,
          donorId: 'USR-001', // O+ cannot give red cells to O-
        ),
        isNull,
      );
      expect(
        repo.respondToRequest(
          requestId: request.id,
          donorId: 'USR-004', // O- but suspended
        ),
        isNull,
      );
      expect(
        repo.respondToRequest(
          requestId: request.id,
          donorId: 'USR-008', // O+ and unverified
        ),
        isNull,
      );

      expect(
        repo.respondToRequest(
          requestId: request.id,
          donorId: 'USR-012',
        ),
        isNotNull,
      );
      expect(
        repo.respondToRequest(
          requestId: request.id,
          donorId: 'USR-012',
        ),
        isNull,
      );
    });

    test('blood-bank requests do not accept donor responses', () {
      final request = addRequest(
        repo,
        patientAlias: 'Lifecycle 3',
        source: RequestSource.bloodBank,
      );
      expect(
        repo.respondToRequest(requestId: request.id, donorId: 'USR-012'),
        isNull,
      );
    });

    test('only the requester or staff can select a response', () {
      final request = addRequest(repo, patientAlias: 'Lifecycle 4');
      final response = repo.respondToRequest(
        requestId: request.id,
        donorId: 'USR-012',
      )!;

      expect(
        repo.selectResponse(
          responseId: response.id,
          selectedById: 'USR-001',
        ),
        isNull,
      );
      expect(
        repo.responsesFor(request.id).single.status,
        ResponseStatus.pending,
      );

      final thread = repo.selectResponse(
        responseId: response.id,
        selectedById: 'USR-009',
      );
      expect(thread, isNotNull);
      expect(thread!.participantAId, 'USR-009');
      expect(thread.participantBId, 'USR-012');
      expect(
        repo.responsesFor(request.id).single.status,
        ResponseStatus.selected,
      );
      expect(
        repo.requests.firstWhere((r) => r.id == request.id).status,
        RequestStatus.matched,
      );
    });

    test('selection requires reciprocal chat before choosing a donor', () {
      final request = addRequest(repo, patientAlias: 'Chat first');
      final response = repo.respondToRequest(
        requestId: request.id,
        donorId: 'USR-017', // O- eligible, no seeded thread with the requester
      )!;

      // A raw donor offer is not enough; the requester must open a real
      // conversation first.
      expect(repo.hasReciprocalChat('USR-009', 'USR-017'), isFalse);
      expect(
        repo.selectResponse(
          responseId: response.id,
          selectedById: 'USR-009',
        ),
        isNull,
      );
      expect(
        repo.responsesFor(request.id).single.status,
        ResponseStatus.pending,
      );

      // One message is also not enough: both sides must take part.
      final thread = repo.startConversation(
        initiatorId: 'USR-009',
        otherId: 'USR-017',
        firstMessage: 'Hello Arnel, are you free to donate this week?',
      )!;
      expect(repo.hasReciprocalChat('USR-009', 'USR-017'), isFalse);
      expect(
        repo.selectResponse(
          responseId: response.id,
          selectedById: 'USR-009',
        ),
        isNull,
      );

      repo.sendMessage(thread.id, 'USR-017', 'Yes, I can donate on Friday.');
      expect(repo.hasReciprocalChat('USR-009', 'USR-017'), isTrue);
      expect(
        repo.selectResponse(
          responseId: response.id,
          selectedById: 'USR-009',
        ),
        isNotNull,
      );
    });

    test('selection is refused if the donor becomes unavailable', () {
      final request = addRequest(repo, patientAlias: 'Lifecycle 5a');
      final response = repo.respondToRequest(
        requestId: request.id,
        donorId: 'USR-012',
      )!;
      final donor = repo.userById('USR-012')!;

      repo.updateUser(donor.copyWith(isAvailable: false));
      expect(
        repo.selectResponse(
          responseId: response.id,
          selectedById: 'USR-009',
        ),
        isNull,
      );
      expect(
        repo.responsesFor(request.id).single.status,
        ResponseStatus.pending,
      );
      expect(
        repo.requests.firstWhere((r) => r.id == request.id).status,
        RequestStatus.open,
      );

      repo.updateUser(donor.copyWith(isAvailable: true));
      expect(
        repo.selectResponse(
          responseId: response.id,
          selectedById: 'USR-009',
        ),
        isNotNull,
      );
    });

    test('selection creates one coordination thread and does not double-count',
        () {
      final request = addRequest(repo, patientAlias: 'Lifecycle 5');
      final response = repo.respondToRequest(
        requestId: request.id,
        donorId: 'USR-012',
      )!;

      repo.selectResponse(
        responseId: response.id,
        selectedById: 'USR-009',
      );
      final threadCount = repo.threads.length;

      expect(
        repo.selectResponse(
          responseId: response.id,
          selectedById: 'USR-009',
        ),
        isNull,
      );
      expect(repo.threads.length, threadCount);
      expect(
        repo.requests
            .firstWhere((r) => r.id == request.id)
            .unitsFulfilled,
        0,
      );
    });

    test('only staff can mark a request fulfilled', () {
      final request = addRequest(repo, patientAlias: 'Lifecycle 6');

      // A donor-network request cannot be closed before a donor is selected.
      expect(
        repo.markRequestFulfilled(request.id, actorId: 'USR-010'),
        isFalse,
      );

      final response = repo.respondToRequest(
        requestId: request.id,
        donorId: 'USR-012',
      )!;
      repo.selectResponse(
        responseId: response.id,
        selectedById: 'USR-009',
      );

      expect(
        repo.markRequestFulfilled(request.id, actorId: 'USR-009'),
        isFalse,
      );
      expect(
        repo.markRequestFulfilled(request.id, actorId: 'USR-010'),
        isTrue,
      );

      final fulfilled =
          repo.requests.firstWhere((r) => r.id == request.id);
      expect(fulfilled.status, RequestStatus.fulfilled);
      expect(fulfilled.unitsFulfilled, fulfilled.unitsNeeded);
      expect(
        repo.markRequestFulfilled(request.id, actorId: 'USR-010'),
        isFalse,
      );
    });

    test('leftover offers are declined once enough donors are selected', () {
      final request = addRequest(
        repo,
        patientAlias: 'Lifecycle 7',
        bloodType: BloodType.bPos,
        component: BloodComponent.wholeBlood,
      );
      final first = repo.respondToRequest(
        requestId: request.id,
        donorId: 'USR-001', // O+
      )!;
      final second = repo.respondToRequest(
        requestId: request.id,
        donorId: 'USR-003', // B-
      )!;
      final third = repo.respondToRequest(
        requestId: request.id,
        donorId: 'USR-007', // B+
      )!;

      repo.selectResponse(responseId: second.id, selectedById: 'USR-009');

      final responses = repo.responsesFor(request.id);
      expect(
        responses.firstWhere((r) => r.id == second.id).status,
        ResponseStatus.selected,
      );
      expect(
        responses.firstWhere((r) => r.id == first.id).status,
        ResponseStatus.declined,
      );
      expect(
        responses.firstWhere((r) => r.id == third.id).status,
        ResponseStatus.declined,
      );
      expect(
        repo.requests.firstWhere((r) => r.id == request.id).status,
        RequestStatus.matched,
      );
    });

    test('staff can fulfil an open blood-bank request directly', () {
      final request = addRequest(
        repo,
        patientAlias: 'Lifecycle 8',
        source: RequestSource.bloodBank,
      );
      expect(
        repo.markRequestFulfilled(request.id, actorId: 'USR-010'),
        isTrue,
      );
      expect(
        repo.requests.firstWhere((r) => r.id == request.id).status,
        RequestStatus.fulfilled,
      );
    });

    test('requester can cancel an open request, but not twice', () {
      final request = addRequest(repo, patientAlias: 'Lifecycle 9');

      expect(
        repo.cancelRequest(request.id, actorId: 'USR-001'),
        isFalse,
      );
      expect(
        repo.cancelRequest(request.id, actorId: 'USR-009'),
        isTrue,
      );
      expect(
        repo.cancelRequest(request.id, actorId: 'USR-009'),
        isFalse,
      );
      expect(
        repo.markRequestFulfilled(request.id, actorId: 'USR-010'),
        isFalse,
      );
    });
  });

  group('Bilateral identity reveal', () {
    test('reveal requires the other participant to accept', () {
      expect(
        repo.requestIdentityReveal('ROOM-101', 'USR-009'),
        isTrue,
      );
      expect(
        repo.acceptIdentityReveal('ROOM-101', 'USR-009'),
        isFalse,
        reason: 'the requester cannot accept their own request',
      );
      expect(
        repo.threads.firstWhere((t) => t.id == 'ROOM-101').identityRevealed,
        isFalse,
      );

      expect(
        repo.acceptIdentityReveal('ROOM-101', 'USR-001'),
        isTrue,
      );
      final thread =
          repo.threads.firstWhere((t) => t.id == 'ROOM-101');
      expect(thread.identityRevealed, isTrue);
      expect(thread.identityRevealRequestedBy, isNull);
      expect(
        repo.requestIdentityReveal('ROOM-101', 'USR-001'),
        isFalse,
      );
    });

    test('the other participant can decline', () {
      expect(
        repo.requestIdentityReveal('ROOM-103', 'USR-005'),
        isTrue,
      );
      expect(
        repo.declineIdentityReveal('ROOM-103', 'USR-002'),
        isTrue,
      );
      final thread =
          repo.threads.firstWhere((t) => t.id == 'ROOM-103');
      expect(thread.identityRevealed, isFalse);
      expect(thread.identityRevealRequestedBy, isNull);
    });
  });

  group('Reports and blocks', () {
    test('submitted reports persist and can be resolved', () {
      final before = repo.reports.length;
      final report = repo.submitReport(
        reporterId: 'USR-009',
        reportedUserId: 'USR-003',
        reason: 'Asked for payment.',
        threadId: 'ROOM-102',
      );

      expect(repo.reports.length, before + 1);
      expect(repo.reports.first.id, report.id);
      expect(report.status, ReportStatus.open);
      expect(repo.resolveReport(report.id, ReportStatus.resolved), isTrue);
      expect(
        repo.reports.firstWhere((r) => r.id == report.id).status,
        ReportStatus.resolved,
      );
    });

    test('blocking disables messaging in both directions', () {
      final thread = repo.threads.firstWhere((t) => t.id == 'ROOM-101');
      final before = thread.messages.length;

      expect(repo.blockUser('USR-009', 'USR-001'), isTrue);
      expect(repo.isBlockedBetween('USR-009', 'USR-001'), isTrue);

      repo.sendMessage('ROOM-101', 'USR-009', 'blocked sender');
      repo.sendMessage('ROOM-101', 'USR-001', 'blocked other sender');
      expect(
        repo.threads.firstWhere((t) => t.id == 'ROOM-101').messages.length,
        before,
      );
    });

    test('unblock works but immediate re-block is blocked for 48 hours', () {
      expect(repo.blockUser('USR-009', 'USR-001'), isTrue);
      expect(repo.unblockUser('USR-009', 'USR-001'), isTrue);
      expect(repo.isBlocked('USR-009', 'USR-001'), isFalse);
      expect(repo.canBlock('USR-009', 'USR-001'), isFalse);
      expect(repo.blockUser('USR-009', 'USR-001'), isFalse);
    });
  });

  group('Donation recording', () {
    test('records the component and starts its cooldown', () {
      final at = DateTime(2026, 1, 1);
      repo.recordDonation(
        'USR-012',
        at: at,
        component: BloodComponent.platelets,
      );

      final donor = repo.userById('USR-012')!;
      expect(donor.totalDonations, 3);
      expect(donor.lastDonationDate, at);
      expect(donor.lastDonationComponent, BloodComponent.platelets);

      expect(
        EligibilityEngine.evaluate(
          donor,
          component: BloodComponent.platelets,
          now: at.add(const Duration(days: 15)),
        ).isEligible,
        isTrue,
      );
      expect(
        EligibilityEngine.evaluate(
          donor,
          component: BloodComponent.wholeBlood,
          now: at.add(const Duration(days: 15)),
        ).isEligible,
        isFalse,
      );
    });
  });

  group('Inventory holds and appointments', () {
    test('a usable unit can be held once and released by its holder', () {
      final unit = repo.availableUnits.first;
      expect(
        repo.reserveUnit(
          barcode: unit.barcode,
          userId: 'USR-038',
          note: 'Test hold',
        ),
        isTrue,
      );
      expect(
        repo.reservedUnitsFor('USR-038').map((u) => u.barcode),
        contains(unit.barcode),
      );

      // A second person cannot claim the same bag.
      expect(
        repo.reserveUnit(barcode: unit.barcode, userId: 'USR-009'),
        isFalse,
      );
      expect(
        repo.cancelReservation(barcode: unit.barcode, userId: 'USR-009'),
        isFalse,
      );
      expect(
        repo.cancelReservation(barcode: unit.barcode, userId: 'USR-038'),
        isTrue,
      );
      expect(repo.reservedUnitsFor('USR-038'), isEmpty);
    });

    test('appointment-with-blood starts pending and staff confirm it', () {
      final appointment = repo.addAppointment(
        requesterId: 'USR-009',
        patientName: 'Patient 118',
        bloodType: BloodType.oNeg,
        component: BloodComponent.packedRbc,
        hospital: DigosFacilities.names.first,
        ward: 'Ward 3',
        units: 2,
        scheduledAt: DateTime.now().add(const Duration(days: 1)),
      );

      expect(appointment, isNotNull);
      expect(appointment!.status, 'Pending confirmation');
      // Look the appointment up by id: the seeded APT-001 can sort ahead of it
      // depending on the wall-clock time the suite runs at, so "first" is not
      // a stable way to find the appointment just created.
      expect(
        repo.appointmentsFor('USR-009').map((a) => a.id),
        contains(appointment.id),
      );
      expect(
        repo.confirmAppointment(appointment.id, actorId: 'USR-009'),
        isFalse,
        reason: 'requesters cannot confirm their own appointment',
      );
      expect(
        repo.confirmAppointment(appointment.id, actorId: 'USR-010'),
        isTrue,
      );
      expect(
        repo
            .appointmentsFor('USR-009')
            .firstWhere((a) => a.id == appointment.id)
            .status,
        'Confirmed',
      );
    });
  });

  group('Account creation and privacy', () {
    test('registration rejects a nickname that is already taken', () {
      final result = AuthService.instance.register(
        fullName: 'New Donor',
        alias: 'Iver', // seeded demo donor
        email: 'new.donor@tabang.app',
        password: 'password123',
        phone: '+63 900 111 2222',
        barangay: 'Zone 1',
      );

      expect(result.ok, isFalse);
      expect(result.error, contains('nickname'));
    });

    test('self-registration always creates a community account', () {
      final result = AuthService.instance.register(
        fullName: 'Direct Donor',
        alias: 'Direct 01',
        email: 'direct01@tabang.app',
        password: 'password123',
        phone: '+63 900 111 5555',
        barangay: 'Zone 1',
        role: UserRole.donor,
        bloodType: BloodType.oPos,
        birthDate: DateTime(2000, 1, 1),
        weightKg: 60,
      );

      expect(result.ok, isFalse);
      expect(result.error, contains('community account first'));
    });

    test('registration rejects a nickname equal to the full name', () {
      final result = AuthService.instance.register(
        fullName: 'Juan Dela Cruz',
        alias: 'juan dela cruz',
        email: 'juan.dc@tabang.app',
        password: 'password123',
        phone: '+63 900 111 3333',
        barangay: 'Zone 2',
      );

      expect(result.ok, isFalse);
      expect(result.error, contains('nickname'));
    });

    test('staff can create a community account with a temporary password',
        () {
      final result = AuthService.instance.adminCreateUser(
        actorId: 'USR-010', // clinical personnel
        fullName: 'Walk In Donor',
        alias: 'Walkin 01',
        email: 'walkin01@tabang.app',
        phone: '+63 900 555 0001',
        barangay: 'Zone 3',
        role: UserRole.donor,
        bloodType: BloodType.aPos,
        birthDate: DateTime(1998, 5, 5),
        weightKg: 65,
      );

      expect(result.ok, isTrue);
      expect(result.password, isNotNull);
      expect(result.password, startsWith('tab-'));

      final signIn = AuthService.instance.signIn(
        email: 'walkin01@tabang.app',
        password: result.password!,
      );
      expect(signIn.ok, isTrue);
      expect(signIn.user!.alias, 'Walkin 01');
    });

    test('privilege rules apply to staff-created accounts', () {
      final asDonor = AuthService.instance.adminCreateUser(
        actorId: 'USR-001', // donor
        fullName: 'Should Not Exist',
        alias: 'Nope 01',
        email: 'nope01@tabang.app',
        phone: '+63 900 555 0002',
        barangay: 'Zone 1',
        role: UserRole.recipient,
      );
      expect(asDonor.ok, isFalse);

      final staffTriesStaff = AuthService.instance.adminCreateUser(
        actorId: 'USR-010', // staff
        fullName: 'Second Staff',
        alias: 'Staff Two',
        email: 'staff.two@tabang.app',
        phone: '+63 900 555 0003',
        barangay: 'Zone 1',
        role: UserRole.staff,
      );
      expect(staffTriesStaff.ok, isFalse);

      final adminCreatesStaff = AuthService.instance.adminCreateUser(
        actorId: 'USR-011', // admin
        fullName: 'Second Staff',
        alias: 'Staff Two',
        email: 'staff.two@tabang.app',
        phone: '+63 900 555 0003',
        barangay: 'Zone 1',
        role: UserRole.staff,
      );
      expect(adminCreatesStaff.ok, isTrue);
    });

    test('new accounts start as community users and can become donors', () {
      // Seeded demo accounts have already completed onboarding.
      expect(repo.userById('USR-001')!.onboardingCompleted, isTrue);

      final result = AuthService.instance.register(
        fullName: 'Fresh Donor',
        alias: 'Fresh 01',
        email: 'fresh01@tabang.app',
        password: 'password123',
        phone: '+63 900 111 4444',
        barangay: 'Zone 4',
      );
      expect(result.ok, isTrue);
      expect(result.user!.role, UserRole.user);
      expect(result.user!.role.canRequestBlood, isTrue);
      expect(result.user!.onboardingCompleted, isFalse);

      repo.completeOnboarding(result.user!.id);
      expect(repo.userById(result.user!.id)!.onboardingCompleted, isTrue);

      final upgrade = AuthService.instance.registerAsDonor(
        userId: result.user!.id,
        bloodType: BloodType.bPos,
        birthDate: DateTime(1999, 9, 9),
        weightKg: 58,
      );
      expect(upgrade.ok, isTrue);
      expect(upgrade.user!.role, UserRole.donor);
      expect(upgrade.user!.bloodType, BloodType.bPos);
    });

    test('donor registrations stay unverified until staff decides', () {
      final result = AuthService.instance.register(
        fullName: 'Form Filler',
        alias: 'Form 01',
        email: 'form01@tabang.app',
        password: 'password123',
        phone: '+63 900 111 6666',
        barangay: 'Zone 4',
      );
      expect(result.ok, isTrue);

      final application = repo.submitDonorApplication(
        userId: result.user!.id,
        bloodType: BloodType.oNeg,
        birthDate: DateTime(2000, 1, 1),
        weightKg: 60,
        sex: 'Female',
        contact: '+63 900 111 5555',
        idType: 'School ID',
        idNumber: '2026-0001',
        medicalFlags: const [
          'Tattoo, piercing or acupuncture in the last 12 months',
        ],
        declarationAccepted: true,
      );
      expect(application, isNotNull);
      expect(application!.status, DonorApplicationStatus.pending);
      expect(
        repo.openDonorApplications.map((a) => a.userId),
        contains(result.user!.id),
      );

      // The account is a donor but unverified, so matching must refuse it.
      final asDonor = repo.userById(result.user!.id)!;
      expect(asDonor.role, UserRole.donor);
      expect(asDonor.bloodCardVerified, isFalse);
      expect(
        EligibilityEngine.evaluate(asDonor).isEligible,
        isFalse,
        reason: 'an unverified donor is never matched yet',
      );

      // Staff asks for documents, then verifies.
      repo.setDonorApplicationStatus(
        result.user!.id,
        DonorApplicationStatus.documentsRequested,
        requestedDocuments: kDonorRequirements,
      );
      expect(
        repo.donorApplicationFor(result.user!.id)!.status,
        DonorApplicationStatus.documentsRequested,
      );
      expect(
        repo.openDonorApplications.map((a) => a.userId),
        contains(result.user!.id),
      );

      repo.setDonorApplicationStatus(
        result.user!.id,
        DonorApplicationStatus.verified,
      );
      final verified = repo.userById(result.user!.id)!;
      expect(verified.bloodCardVerified, isTrue);
      expect(verified.status, AccountStatus.verified);
      expect(
        repo.openDonorApplications.map((a) => a.userId),
        isNot(contains(result.user!.id)),
      );
    });
  });
}
