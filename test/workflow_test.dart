import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tabang/core/auth.dart';
import 'package:tabang/core/eligibility.dart';
import 'package:tabang/core/models.dart';
import 'package:tabang/core/repository.dart';

/// Three required uploads with real bytes, as the request dialog supplies.
List<RequestDocument> uploadedDocuments() => [
  RequestDocument(
    kind: RequestDocuments.doctorsForm,
    fileName: 'doctor-request-form.pdf',
    bytes: Uint8List.fromList(const [1, 2, 3, 4]),
    sizeBytes: 4,
  ),
  RequestDocument(
    kind: RequestDocuments.transfusionSlip,
    fileName: 'transfusion-slip.jpg',
    bytes: Uint8List.fromList(const [5, 6, 7, 8]),
    sizeBytes: 4,
  ),
  RequestDocument(
    kind: RequestDocuments.patientId,
    fileName: 'patient-id.png',
    bytes: Uint8List.fromList(const [9, 10, 11, 12]),
    sizeBytes: 4,
  ),
];

/// Creates a request through the full documented flow and verifies it as
/// chapter staff, so lifecycle tests start from a live open request instead of
/// bypassing the review step.
BloodRequest addRequest(
  TabangRepository repo, {
  required String patientAlias,
  BloodType bloodType = BloodType.oNeg,
  BloodComponent component = BloodComponent.packedRbc,
  int unitsNeeded = 1,
  RequestSource source = RequestSource.donorNetwork,
}) {
  final created = repo.addRequest(
    requesterId: 'USR-009',
    patientAlias: patientAlias,
    bloodType: bloodType,
    component: component,
    unitsNeeded: unitsNeeded,
    hospital: DigosFacilities.names.first,
    barangay: 'Zone 2',
    urgency: RequestUrgency.urgent,
    source: source,
    documents: uploadedDocuments(),
    scheduledFor: repo.bloodBankSlots(days: 7).first,
  )!;
  repo.verifyRequest(created.id, actorId: 'USR-010');
  return repo.requests.firstWhere((r) => r.id == created.id);
}

void main() {
  final repo = TabangRepository.instance;

  setUp(repo.resetForTesting);

  group('Seed data', () {
    test(
      'provides 15 available donors, 15 recipients and a community demo',
      () {
        final eligibleDonors = repo.users
            .where(
              (u) =>
                  u.role == UserRole.donor &&
                  EligibilityEngine.evaluate(u).isEligible,
            )
            .toList();
        expect(eligibleDonors, hasLength(15));

        final recipients = repo.users
            .where((u) => u.role == UserRole.recipient)
            .toList();
        expect(recipients, hasLength(15));

        final community = repo.users
            .where((u) => u.email == 'community@tabang.app')
            .toList();
        expect(community, hasLength(1));
        expect(community.single.role, UserRole.user);

        // Profiles must be individually illustrated rather than sharing a
        // placeholder.
        final avatars = repo.users
            .map((u) => u.photoAsset)
            .whereType<String>()
            .toSet();
        expect(avatars.length, repo.users.length);
      },
    );
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
        Compatibility.donorsForComponent(
          BloodType.oNeg,
          BloodComponent.plasma,
        ).toSet(),
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
      final expired = repo.units.firstWhere((u) => u.barcode == 'RBC-7700-O+');
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
      expect(
        units.every((u) => u.component == BloodComponent.packedRbc),
        isTrue,
      );
      expect(units.every((u) => u.isUsableAt(now)), isTrue);
      expect(
        units.every(
          (u) => Compatibility.canDonateTo(u.bloodType, BloodType.oNeg),
        ),
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
      expect(
        repo.requests.firstWhere((r) => r.id == request.id).status,
        RequestStatus.open,
      );
    });

    test(
      'incompatible, ineligible, suspended and duplicate responses fail',
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
          repo.respondToRequest(requestId: request.id, donorId: 'USR-012'),
          isNotNull,
        );
        expect(
          repo.respondToRequest(requestId: request.id, donorId: 'USR-012'),
          isNull,
        );
      },
    );

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

    test('only the requester can select a response', () {
      final request = addRequest(repo, patientAlias: 'Lifecycle 4');
      final response = repo.respondToRequest(
        requestId: request.id,
        donorId: 'USR-012',
      )!;

      expect(
        repo.selectResponse(responseId: response.id, selectedById: 'USR-001'),
        isNull,
      );
      // Staff verify and fulfil; they do not choose the donor for the
      // requester.
      expect(
        repo.selectResponse(responseId: response.id, selectedById: 'USR-010'),
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
        repo.selectResponse(responseId: response.id, selectedById: 'USR-009'),
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
        repo.selectResponse(responseId: response.id, selectedById: 'USR-009'),
        isNull,
      );

      repo.sendMessage(thread.id, 'USR-017', 'Yes, I can donate on Friday.');
      expect(repo.hasReciprocalChat('USR-009', 'USR-017'), isTrue);
      expect(
        repo.selectResponse(responseId: response.id, selectedById: 'USR-009'),
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
        repo.selectResponse(responseId: response.id, selectedById: 'USR-009'),
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
        repo.selectResponse(responseId: response.id, selectedById: 'USR-009'),
        isNotNull,
      );
    });

    test('a selected donor cannot be reserved by a second active request', () {
      final firstRequest = addRequest(repo, patientAlias: 'Fairness 1');
      final secondRequest = addRequest(repo, patientAlias: 'Fairness 2');

      // USR-012 already has a reciprocal seeded conversation with USR-009, so
      // both offers are selectable under the chat-first rule.
      final firstResponse = repo.respondToRequest(
        requestId: firstRequest.id,
        donorId: 'USR-012',
      )!;
      final secondResponse = repo.respondToRequest(
        requestId: secondRequest.id,
        donorId: 'USR-012',
      )!;

      expect(
        repo.selectResponse(
          responseId: firstResponse.id,
          selectedById: 'USR-009',
        ),
        isNotNull,
      );
      expect(repo.activeCommitmentFor('USR-012')?.id, firstRequest.id);
      expect(repo.commitmentForDonor('USR-012')?.id, firstResponse.id);
      expect(
        repo
            .commitmentForDonor('USR-012', excludingRequestId: secondRequest.id)
            ?.id,
        firstResponse.id,
      );

      // The donor stays visible in the second request's response list, but the
      // second selection is refused instead of silently double-booking them.
      expect(
        repo.responsesFor(secondRequest.id).single.status,
        ResponseStatus.pending,
      );
      expect(
        repo.selectResponse(
          responseId: secondResponse.id,
          selectedById: 'USR-009',
        ),
        isNull,
      );
      expect(
        repo.responsesFor(secondRequest.id).single.status,
        ResponseStatus.pending,
      );
      expect(
        repo.requests.firstWhere((r) => r.id == secondRequest.id).status,
        RequestStatus.open,
      );

      // Once the first request closes, the donor is free again.
      expect(
        repo.markRequestFulfilled(firstRequest.id, actorId: 'USR-010'),
        isTrue,
      );
      expect(repo.activeCommitmentFor('USR-012'), isNull);
      expect(
        repo.selectResponse(
          responseId: secondResponse.id,
          selectedById: 'USR-009',
        ),
        isNotNull,
      );
    });

    test(
      'selection creates one coordination thread and does not double-count',
      () {
        final request = addRequest(repo, patientAlias: 'Lifecycle 5');
        final response = repo.respondToRequest(
          requestId: request.id,
          donorId: 'USR-012',
        )!;

        repo.selectResponse(responseId: response.id, selectedById: 'USR-009');
        final threadCount = repo.threads.length;

        expect(
          repo.selectResponse(responseId: response.id, selectedById: 'USR-009'),
          isNull,
        );
        expect(repo.threads.length, threadCount);
        expect(
          repo.requests.firstWhere((r) => r.id == request.id).unitsFulfilled,
          0,
        );
      },
    );

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
      repo.selectResponse(responseId: response.id, selectedById: 'USR-009');

      expect(
        repo.markRequestFulfilled(request.id, actorId: 'USR-009'),
        isFalse,
      );
      expect(repo.markRequestFulfilled(request.id, actorId: 'USR-010'), isTrue);

      final fulfilled = repo.requests.firstWhere((r) => r.id == request.id);
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
      expect(repo.markRequestFulfilled(request.id, actorId: 'USR-010'), isTrue);
      expect(
        repo.requests.firstWhere((r) => r.id == request.id).status,
        RequestStatus.fulfilled,
      );
    });

    test('requester can cancel an open request, but not twice', () {
      final request = addRequest(repo, patientAlias: 'Lifecycle 9');

      expect(repo.cancelRequest(request.id, actorId: 'USR-001'), isFalse);
      expect(repo.cancelRequest(request.id, actorId: 'USR-009'), isTrue);
      expect(repo.cancelRequest(request.id, actorId: 'USR-009'), isFalse);
      expect(
        repo.markRequestFulfilled(request.id, actorId: 'USR-010'),
        isFalse,
      );
    });
  });

  group('Request verification', () {
    BloodRequest? submit({
      RequestSource source = RequestSource.donorNetwork,
      List<RequestDocument>? documents,
      DateTime? scheduledFor,
      bool withoutSlot = false,
      bool postToDonorNetwork = true,
      BloodType bloodType = BloodType.oNeg,
      BloodComponent component = BloodComponent.packedRbc,
      int unitsNeeded = 1,
    }) {
      return repo.addRequest(
        requesterId: 'USR-009',
        patientAlias: 'Review ${DateTime.now().microsecondsSinceEpoch}',
        bloodType: bloodType,
        component: component,
        unitsNeeded: unitsNeeded,
        hospital: DigosFacilities.names.first,
        barangay: 'Zone 2',
        urgency: RequestUrgency.urgent,
        source: source,
        documents: documents ?? uploadedDocuments(),
        scheduledFor: withoutSlot
            ? null
            : scheduledFor ?? repo.bloodBankSlots(days: 7).first,
        postToDonorNetwork: postToDonorNetwork,
      );
    }

    test('a request stays hidden until staff verify it', () {
      final created = submit()!;
      expect(created.status, RequestStatus.pendingReview);
      expect(
        repo.donorNetworkRequests.map((r) => r.id),
        isNot(contains(created.id)),
      );
      expect(
        repo.respondToRequest(requestId: created.id, donorId: 'USR-012'),
        isNull,
      );

      // Only staff or an admin can verify.
      expect(repo.verifyRequest(created.id, actorId: 'USR-001'), isFalse);
      expect(repo.verifyRequest(created.id, actorId: 'USR-010'), isTrue);
      expect(
        repo.requests.firstWhere((r) => r.id == created.id).status,
        RequestStatus.open,
      );
      expect(
        repo.respondToRequest(requestId: created.id, donorId: 'USR-012'),
        isNotNull,
      );
    });

    test('documents, a published slot and 1–20 units are required', () {
      expect(submit(documents: const []), isNull);
      expect(submit(withoutSlot: true), isNull);

      // Pick a Sunday even if the suite happens to run on a Sunday, so the
      // slot is deterministically outside the Mon–Sat blood-bank schedule.
      final now = DateTime.now();
      final daysToSunday = (DateTime.sunday - now.weekday) % 7;
      final nextSunday = DateTime(
        now.year,
        now.month,
        now.day + (daysToSunday == 0 ? 7 : daysToSunday),
        9,
      );
      expect(submit(scheduledFor: nextSunday), isNull);
      expect(submit(unitsNeeded: 0), isNull);
      expect(submit(unitsNeeded: 21), isNull);
    });

    test('a checklist tick without an uploaded file is rejected', () {
      final files = uploadedDocuments();
      final onFileOnly = [
        const RequestDocument(
          kind: RequestDocuments.doctorsForm,
          fileName: 'doctor-form.pdf',
        ),
        ...files.skip(1),
      ];
      expect(submit(documents: onFileOnly), isNull);
    });

    test('uploaded files are stored with the request', () {
      final created = submit()!;
      expect(created.documents, hasLength(3));
      expect(created.documents.every((document) => document.hasFile), isTrue);
    });

    test('staff reject a request with a reason the requester can read', () {
      final created = submit()!;
      expect(
        repo.rejectRequest(created.id, actorId: 'USR-009', reason: 'nope'),
        isFalse,
      );
      expect(
        repo.rejectRequest(
          created.id,
          actorId: 'USR-010',
          reason: 'No transfusion slip attached yet',
        ),
        isTrue,
      );
      final rejected = repo.requests.firstWhere((r) => r.id == created.id);
      expect(rejected.status, RequestStatus.rejected);
      expect(rejected.reviewNote, 'No transfusion slip attached yet');
    });

    test('verifying a blood-bank request holds the assigned units', () {
      final created = submit(source: RequestSource.bloodBank)!;
      final compatible = repo.compatibleUnitsFor(
        recipientType: created.bloodType,
        component: created.component,
      );
      expect(compatible, isNotEmpty);
      expect(
        repo.verifyRequest(
          created.id,
          actorId: 'USR-010',
          unitIds: [compatible.first.barcode],
        ),
        isTrue,
      );
      final held = repo.units.firstWhere(
        (unit) => unit.barcode == compatible.first.barcode,
      );
      expect(held.status, UnitStatus.reserved);
      expect(held.reservedBy, 'USR-009');
    });

    test('warnings cap at three and reset on reinstatement', () {
      repo.currentUser = repo.userById('USR-010');
      addTearDown(() => repo.currentUser = null);

      expect(repo.warnUser('USR-019', reason: 'First warning'), isTrue);
      expect(repo.userById('USR-019')!.warningCount, 1);
      repo.warnUser('USR-019', reason: 'Second warning');
      repo.warnUser('USR-019', reason: 'Third warning');
      expect(repo.userById('USR-019')!.warningCount, 3);
      expect(repo.userById('USR-019')!.status, AccountStatus.suspended);
      // A suspended account cannot be warned again.
      expect(repo.warnUser('USR-019'), isFalse);

      repo.setUserStatus('USR-019', AccountStatus.verified);
      expect(repo.userById('USR-019')!.warningCount, 0);
    });

    test('only donors can join a drive', () {
      expect(
        repo.toggleDriveInterest('DRV-001', 'USR-038'), // community user
        isFalse,
      );
      expect(
        repo.toggleDriveInterest('DRV-001', 'USR-001'), // donor
        isTrue,
      );
    });
  });

  group('Readiness targets', () {
    test('only an admin can change the score targets', () {
      const targets = ReadinessTargets(
        unitTarget: 40,
        donorTarget: 24,
        requestPressureCap: 12,
        communityTarget: 75,
      );

      // Staff can read the targets but not change them.
      expect(repo.setReadinessTargets(targets, actorId: 'USR-010'), isFalse);
      expect(repo.readinessTargets, ReadinessTargets.defaults);

      expect(repo.setReadinessTargets(targets, actorId: 'USR-011'), isTrue);
      expect(repo.readinessTargets, targets);
      expect(
        repo.activityLog.any(
          (event) => event.kind == ActivityKind.readinessTargets,
        ),
        isTrue,
      );
    });

    test('invalid targets are refused', () {
      const invalid = ReadinessTargets(
        unitTarget: 0,
        donorTarget: 20,
        requestPressureCap: 0,
        communityTarget: -5,
      );
      expect(repo.setReadinessTargets(invalid, actorId: 'USR-011'), isFalse);
      expect(repo.readinessTargets, ReadinessTargets.defaults);
    });

    test('an admin can restore the shipped defaults', () {
      expect(
        repo.setReadinessTargets(
          const ReadinessTargets(unitTarget: 10),
          actorId: 'USR-011',
        ),
        isTrue,
      );
      expect(repo.readinessTargets.unitTarget, 10);
      expect(repo.resetReadinessTargets(actorId: 'USR-010'), isFalse);
      expect(repo.resetReadinessTargets(actorId: 'USR-011'), isTrue);
      expect(repo.readinessTargets, ReadinessTargets.defaults);
    });
  });

  group('Donor request authoring and anonymity', () {
    test('a donor can post a request that other donors can serve', () {
      final created = repo.addRequest(
        requesterId: 'USR-001', // a donor
        patientAlias: 'Donor patient 01',
        bloodType: BloodType.aPos,
        component: BloodComponent.wholeBlood,
        unitsNeeded: 1,
        hospital: DigosFacilities.names.first,
        barangay: 'Zone 2',
        urgency: RequestUrgency.urgent,
        documents: uploadedDocuments(),
        scheduledFor: repo.bloodBankSlots(days: 7).first,
      )!;
      repo.verifyRequest(created.id, actorId: 'USR-010');
      final request = repo.requests.firstWhere(
        (r) => r.patientAlias == 'Donor patient 01',
      );
      expect(request.requesterId, 'USR-001');

      final response = repo.respondToRequest(
        requestId: request.id,
        donorId: 'USR-012', // eligible O- donor
        message: 'I can donate.',
      );
      expect(response, isNotNull);
      final alias = response!.donorAlias;
      expect(alias, 'Donor #012');
      expect(alias, isNot(contains('Liza')));
    });

    test('donor map handles never expose the alias or real name', () {
      final donor = repo.userById('USR-001')!;
      expect(donor.mapHandle, 'Donor #001');
      expect(donor.mapHandle, isNot(donor.alias));
      expect(donor.mapHandle, isNot(contains(donor.fullName.split(' ').first)));
    });
  });

  group('Automatic away availability', () {
    test('a donor inactive for 30+ days is hidden until active again', () {
      final away = repo.userById('USR-039')!;
      final result = EligibilityEngine.evaluate(away);
      expect(result.isEligible, isFalse);
      expect(result.blocker, EligibilityBlocker.away);
      expect(
        repo.findDonors().map((u) => u.id),
        isNot(contains(away.id)),
        reason: 'an away donor never reaches the directory',
      );

      repo.markActive(away.id);
      final refreshed = repo.userById('USR-039')!;
      expect(EligibilityEngine.evaluate(refreshed).isEligible, isTrue);
      expect(repo.findDonors().map((u) => u.id), contains(away.id));
    });

    test('seeded data still has exactly 15 eligible donors', () {
      final eligibleDonors = repo.users
          .where(
            (u) =>
                u.role == UserRole.donor &&
                EligibilityEngine.evaluate(u).isEligible,
          )
          .toList();
      expect(eligibleDonors, hasLength(15));
      // The two deliberate away cases exist but are not among the 15.
      expect(eligibleDonors.map((u) => u.id), isNot(contains('USR-039')));
      expect(eligibleDonors.map((u) => u.id), isNot(contains('USR-040')));
    });
  });

  group('Chapter identity and staff stock', () {
    test('a donor registration opens an official chapter thread', () {
      final result = AuthService.instance.register(
        fullName: 'Chapter Chat',
        alias: 'Chapter 01',
        email: 'chapter01@tabang.app',
        password: 'password123',
        phone: '+63 900 111 7777',
        barangay: 'Zone 1',
      );
      expect(result.ok, isTrue);
      final userId = result.user!.id;

      repo.submitDonorApplication(
        userId: userId,
        hasExistingCard: false,
        bloodType: BloodType.oPos,
        birthDate: DateTime(1998, 3, 3),
        weightKg: 62,
      );

      final thread = repo.threadBetween(
        userId,
        TabangRepository.chapterAccountId,
      );
      expect(thread, isNotNull);
      expect(thread!.messages, isNotEmpty);
      expect(thread.messages.first.senderId, TabangRepository.chapterAccountId);
      expect(repo.isChapterThread(thread), isTrue);
      expect(repo.displayNameFor(thread, userId), TabangRepository.chapterName);
      // Another donor's application does not create a second chapter thread.
      final threadsBefore = repo.threads.length;
      repo.setDonorApplicationStatus(
        userId,
        DonorApplicationStatus.documentsRequested,
        requestedDocuments: const ['Valid ID'],
      );
      expect(repo.threads.length, threadsBefore);
      expect(
        repo
            .threadBetween(userId, TabangRepository.chapterAccountId)!
            .messages
            .last
            .senderId,
        TabangRepository.chapterAccountId,
      );
    });

    test(
      'a donor verified from the queue is matchable (weight backfilled)',
      () {
        final result = AuthService.instance.register(
          fullName: 'Queue Donor',
          alias: 'Queue 01',
          email: 'queue01@tabang.app',
          password: 'password123',
          phone: '+63 900 111 8888',
          barangay: 'Zone 2',
        );
        expect(result.ok, isTrue);
        final userId = result.user!.id;

        repo.submitDonorApplication(
          userId: userId,
          hasExistingCard: true,
          cardNumber: 'PRC-123',
          bloodType: BloodType.aPos,
          birthDate: DateTime(1995, 5, 5),
          weightKg: 58,
        );
        expect(
          EligibilityEngine.evaluate(repo.userById(userId)!).isEligible,
          isFalse,
          reason: 'unverified until the chapter checks the card',
        );

        repo.setDonorApplicationStatus(userId, DonorApplicationStatus.verified);
        final verified = repo.userById(userId)!;
        expect(verified.bloodCardVerified, isTrue);
        expect(verified.weightKg, 58);
        expect(
          EligibilityEngine.evaluate(verified).isEligible,
          isTrue,
          reason: 'the queue decision must not leave the donor unmatchable',
        );
      },
    );

    test('staff can add stock and the expiry follows the component', () {
      final before = repo.units.length;
      final unit = repo.addBloodUnit(
        actorId: 'USR-010', // clinical personnel
        bloodType: BloodType.bPos,
        component: BloodComponent.platelets,
        storageBay: 'Fridge B · Shelf 1',
        collectedOn: DateTime(2026, 1, 1),
      );
      expect(unit, isNotNull);
      expect(repo.units.length, before + 1);
      expect(
        unit!.expiresOn,
        DateTime(2026, 1, 1).add(const Duration(days: 5)),
      );
      expect(unit.status, UnitStatus.available);

      // Community members cannot add stock, even with a valid payload.
      expect(
        repo.addBloodUnit(
          actorId: 'USR-001', // donor
          bloodType: BloodType.oNeg,
          component: BloodComponent.packedRbc,
          storageBay: 'Fridge A',
        ),
        isNull,
      );

      // A barcode that already exists is refused.
      expect(
        repo.addBloodUnit(
          actorId: 'USR-010',
          bloodType: BloodType.bPos,
          component: BloodComponent.platelets,
          storageBay: 'Fridge B · Shelf 1',
          barcode: unit.barcode,
        ),
        isNull,
      );
    });

    test('staff-only status changes are ignored for community actors', () {
      final unit = repo.availableUnits.first;
      final original = unit.effectiveStatus(DateTime.now());
      repo.setUnitStatus(
        unit.barcode,
        UnitStatus.quarantined,
        actorId: 'USR-001',
      );
      expect(
        repo.units
            .firstWhere((u) => u.barcode == unit.barcode)
            .effectiveStatus(DateTime.now()),
        original,
      );
      repo.setUnitStatus(
        unit.barcode,
        UnitStatus.quarantined,
        actorId: 'USR-010',
      );
      expect(
        repo.units
            .firstWhere((u) => u.barcode == unit.barcode)
            .effectiveStatus(DateTime.now()),
        UnitStatus.quarantined,
      );
    });
  });

  group('Bilateral identity reveal', () {
    test('reveal requires the other participant to accept', () {
      expect(repo.requestIdentityReveal('ROOM-101', 'USR-009'), isTrue);
      expect(
        repo.acceptIdentityReveal('ROOM-101', 'USR-009'),
        isFalse,
        reason: 'the requester cannot accept their own request',
      );
      expect(
        repo.threads.firstWhere((t) => t.id == 'ROOM-101').identityRevealed,
        isFalse,
      );

      expect(repo.acceptIdentityReveal('ROOM-101', 'USR-001'), isTrue);
      final thread = repo.threads.firstWhere((t) => t.id == 'ROOM-101');
      expect(thread.identityRevealed, isTrue);
      expect(thread.identityRevealRequestedBy, isNull);
      expect(repo.requestIdentityReveal('ROOM-101', 'USR-001'), isFalse);
    });

    test('the other participant can decline', () {
      expect(repo.requestIdentityReveal('ROOM-103', 'USR-005'), isTrue);
      expect(repo.declineIdentityReveal('ROOM-103', 'USR-002'), isTrue);
      final thread = repo.threads.firstWhere((t) => t.id == 'ROOM-103');
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
      expect(report.details, isNull);
      expect(repo.resolveReport(report.id, ReportStatus.resolved), isTrue);
      expect(
        repo.reports.firstWhere((r) => r.id == report.id).status,
        ReportStatus.resolved,
      );
    });

    test('a report keeps the reporter\'s free-text explanation', () {
      final report = repo.submitReport(
        reporterId: 'USR-009',
        reportedUserId: 'USR-003',
        reason: 'Harassment or threats',
        details:
            '  They demanded cash and threatened to cancel the donation.  ',
        threadId: 'ROOM-102',
      );

      expect(report.reason, 'Harassment or threats');
      expect(
        report.details,
        'They demanded cash and threatened to cancel the donation.',
      );
      expect(repo.reports.first.details, report.details);

      final blank = repo.submitReport(
        reporterId: 'USR-009',
        reportedUserId: 'USR-003',
        reason: 'Spam or advertising',
        details: '   ',
      );
      expect(blank.details, isNull);
    });

    test('unread counts follow each participant\'s read marker', () {
      final thread = repo.threads.firstWhere((t) => t.id == 'ROOM-101');
      // Two messages from USR-009 arrived after USR-001's read marker.
      expect(thread.unreadCountFor('USR-001'), 2);
      expect(repo.unreadMessageCountFor('USR-001'), 2);
      expect(repo.unreadThreadCountFor('USR-001'), 1);

      expect(repo.markThreadRead('ROOM-101', 'USR-001'), isTrue);
      expect(thread.unreadCountFor('USR-001'), 2); // old snapshot unchanged
      final refreshed = repo.threads.firstWhere((t) => t.id == 'ROOM-101');
      expect(refreshed.unreadCountFor('USR-001'), 0);
      expect(repo.unreadMessageCountFor('USR-001'), 0);
      expect(repo.unreadThreadCountFor('USR-001'), 0);

      // The other participant's marker is untouched; they had already read
      // the conversation before the last message was sent.
      expect(refreshed.unreadCountFor('USR-009'), 0);
      expect(repo.markThreadRead('ROOM-101', 'USR-001'), isFalse);
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

    test('staff can correct the window without counting another donation', () {
      final donor = repo.userById('USR-012')!;
      final before = donor.totalDonations;
      final at = DateTime.now().subtract(const Duration(days: 10));

      repo.updateDonationWindow(
        donor.id,
        lastDonationDate: at,
        component: BloodComponent.wholeBlood,
      );

      final updated = repo.userById(donor.id)!;
      expect(updated.totalDonations, before);
      expect(updated.lastDonationDate, at);
      expect(updated.lastDonationComponent, BloodComponent.wholeBlood);
      expect(EligibilityEngine.evaluate(updated).isEligible, isFalse);
    });
  });

  group('Inventory holds and booked slots', () {
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

    test('request slots merge into the staff booked-slot queue', () {
      final created = repo.addRequest(
        requesterId: 'USR-009',
        patientAlias: 'Patient 118',
        bloodType: BloodType.oNeg,
        component: BloodComponent.packedRbc,
        unitsNeeded: 2,
        hospital: DigosFacilities.names.first,
        barangay: 'Zone 2',
        urgency: RequestUrgency.urgent,
        documents: uploadedDocuments(),
        scheduledFor: repo.bloodBankSlots(days: 7)[1],
      )!;

      expect(repo.scheduledRequests.map((r) => r.id), contains(created.id));
      expect(
        repo.pendingScheduledRequests.map((r) => r.id),
        contains(created.id),
      );
      expect(
        repo.verifyRequest(created.id, actorId: 'USR-009'),
        isFalse,
        reason: 'requesters cannot verify their own request',
      );
      expect(repo.verifyRequest(created.id, actorId: 'USR-010'), isTrue);

      final confirmed = repo.scheduledRequests.firstWhere(
        (request) => request.id == created.id,
      );
      expect(confirmed.scheduledFor, created.scheduledFor);
      expect(
        repo.pendingScheduledRequests.map((r) => r.id),
        isNot(contains(created.id)),
      );
    });

    test('cancelled requests leave the booked-slot queue', () {
      final created = repo.addRequest(
        requesterId: 'USR-009',
        patientAlias: 'Patient 119',
        bloodType: BloodType.oNeg,
        component: BloodComponent.packedRbc,
        unitsNeeded: 1,
        hospital: DigosFacilities.names.first,
        barangay: 'Zone 2',
        urgency: RequestUrgency.routine,
        documents: uploadedDocuments(),
        scheduledFor: repo.bloodBankSlots(days: 7)[2],
      )!;
      expect(repo.cancelRequest(created.id, actorId: 'USR-009'), isTrue);
      expect(
        repo.scheduledRequests.map((request) => request.id),
        isNot(contains(created.id)),
      );
    });
  });

  group('Account creation and privacy', () {
    test('registration rejects a nickname that is already taken', () {
      final result = AuthService.instance.register(
        fullName: 'New Donor',
        alias: 'JuanDC', // seeded demo donor
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

    test('staff can create a community account with a temporary password', () {
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

      // Registration is face-to-face: the app only records the intent to
      // visit and whether the applicant already holds a donor card.
      final application = repo.submitDonorApplication(
        userId: result.user!.id,
        hasExistingCard: false,
        bloodType: BloodType.oNeg,
        preferredVisit: DateTime.now().add(const Duration(days: 2)),
        note: 'First donation',
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

  group('Chapter activity log', () {
    test('seeded log covers transfusions and account changes', () {
      final kinds = repo.activityLog.map((event) => event.kind).toSet();
      expect(kinds, contains(ActivityKind.donation));
      expect(kinds, contains(ActivityKind.avatar));
      expect(kinds, contains(ActivityKind.verification));
      expect(repo.recentActivity(limit: 3), hasLength(3));
      // Newest first: the seed starts with a recorded transfusion.
      expect(repo.activityLog.first.isDonation, isTrue);
    });

    test('records donations, window corrections and profile changes', () {
      final before = repo.activityLog.length;

      repo.recordDonation('USR-019', component: BloodComponent.platelets);
      expect(repo.activityLog.first.kind, ActivityKind.donation);
      expect(repo.activityLog.first.summary, contains('Jessa'));
      expect(repo.activityLog.first.summary, contains('platelets'));
      expect(repo.activityLog.first.isDonation, isTrue);

      repo.updateDonationWindow(
        'USR-019',
        lastDonationDate: DateTime.now().subtract(const Duration(days: 3)),
        component: BloodComponent.platelets,
      );
      expect(repo.activityLog.first.kind, ActivityKind.donationWindow);
      expect(repo.activityLog.first.summary, contains('Corrected'));

      repo.logProfileActivity(
        userId: 'USR-019',
        kind: ActivityKind.avatar,
        summary: 'Changed their profile photo',
      );
      expect(repo.activityLog.first.kind, ActivityKind.avatar);
      expect(repo.activityLog.length, before + 3);
    });

    test('per-user activity filters by the affected account', () {
      repo.recordDonation('USR-019', component: BloodComponent.wholeBlood);
      repo.recordDonation('USR-020', component: BloodComponent.wholeBlood);

      final jessa = repo.activityFor('USR-019');
      final mark = repo.activityFor('USR-020');
      expect(jessa, isNotEmpty);
      expect(mark, isNotEmpty);
      expect(jessa.every((event) => event.subjectId == 'USR-019'), isTrue);
      expect(mark.every((event) => event.subjectId == 'USR-020'), isTrue);
    });

    test('staff actions record the actor when a session is signed in', () {
      repo.currentUser = repo.userById('USR-010');
      addTearDown(() => repo.currentUser = null);

      repo.recordDonation('USR-004', component: BloodComponent.packedRbc);
      final event = repo.activityLog.first;
      expect(event.actorId, 'USR-010');
      expect(event.actorAlias, repo.userById('USR-010')!.alias);
      expect(event.subjectAlias, 'Cardo');
    });
  });

  group('Staff communications', () {
    test('the staff room includes every staff and admin account', () {
      final room = repo.staffRoom!;
      expect(room.isGroup, isTrue);
      expect(room.groupName, 'Staff room');
      final staffIds = repo.users
          .where((user) => user.role.isAdminSide)
          .map((user) => user.id)
          .toSet();
      expect(room.memberIds.toSet(), staffIds);

      // Community users never see the room; staff and admins always do.
      expect(
        repo
            .threadsFor('USR-001')
            .any((t) => t.id == TabangRepository.staffRoomId),
        isFalse,
      );
      expect(
        repo
            .threadsFor('USR-010')
            .any((t) => t.id == TabangRepository.staffRoomId),
        isTrue,
      );
      expect(
        repo
            .threadsFor('USR-011')
            .any((t) => t.id == TabangRepository.staffRoomId),
        isTrue,
      );
    });

    test('staff-to-staff messages keep personal aliases, not the chapter', () {
      repo.sendMessage(
        TabangRepository.staffRoomId,
        'USR-010',
        'Shift swap: I can cover Friday.',
      );
      final message = repo.staffRoom!.messages.last;
      expect(message.senderId, 'USR-010');
      expect(message.senderAlias, 'Staff Marco');
      // The chapter account shares the staff user's id, so the flag is what
      // tells the UI this was a personal message.
      expect(message.sentAsChapter, isFalse);
    });

    test('staff choose the chapter identity or their own account', () {
      final thread = repo.startConversation(
        initiatorId: 'USR-010',
        otherId: 'USR-001',
        firstMessage: 'Hi Juan — quick chapter update.',
      )!;

      repo.sendMessage(
        thread.id,
        'USR-010',
        'Your slot is confirmed.',
        asChapter: true,
      );
      var latest = repo.threadBetween('USR-010', 'USR-001')!.messages.last;
      expect(latest.senderId, TabangRepository.chapterAccountId);
      expect(latest.senderAlias, TabangRepository.chapterName);
      expect(latest.sentAsChapter, isTrue);

      repo.sendMessage(
        thread.id,
        'USR-010',
        'Ping me if you need anything.',
        asChapter: false,
      );
      latest = repo.threadBetween('USR-010', 'USR-001')!.messages.last;
      expect(latest.senderId, 'USR-010');
      expect(latest.senderAlias, 'Staff Marco');
      expect(latest.sentAsChapter, isFalse);
    });

    test('reading the staff room clears the badge only for that member', () {
      expect(repo.staffRoom!.hasUnreadFor('USR-010'), isTrue);
      repo.markThreadRead(TabangRepository.staffRoomId, 'USR-010');
      expect(repo.staffRoom!.hasUnreadFor('USR-010'), isFalse);
      expect(repo.staffRoom!.hasUnreadFor('USR-011'), isTrue);
    });
  });

  group('Undo and the removed-units ledger', () {
    test('a removed unit is listed and can be restored', () {
      final staff = repo.userById('USR-010')!;
      final unit = repo.units.firstWhere(
        (u) => u.effectiveStatus(DateTime.now()) == UnitStatus.available,
      );

      expect(repo.removeBloodUnit(unit.barcode, actorId: staff.id), isTrue);
      expect(repo.units.any((u) => u.barcode == unit.barcode), isFalse);
      expect(repo.activityLog.first.kind, ActivityKind.inventory);

      final record = repo.removedUnits.first;
      expect(record.unit.barcode, unit.barcode);
      expect(record.restored, isFalse);

      expect(repo.restoreRemovedUnit(unit.barcode, actorId: staff.id), isTrue);
      expect(repo.units.any((u) => u.barcode == unit.barcode), isTrue);
      expect(repo.removedUnits.first.restored, isTrue);
      // A record is restored once; a second undo is refused.
      expect(repo.restoreRemovedUnit(unit.barcode, actorId: staff.id), isFalse);
    });

    test('restoring refuses a barcode that is back in use', () {
      final staff = repo.userById('USR-010')!;
      final unit = repo.units.first;
      expect(repo.removeBloodUnit(unit.barcode, actorId: staff.id), isTrue);
      expect(
        repo.addBloodUnit(
          actorId: staff.id,
          bloodType: unit.bloodType,
          component: unit.component,
          storageBay: unit.storageBay,
          barcode: unit.barcode,
        ),
        isNotNull,
      );
      expect(repo.restoreRemovedUnit(unit.barcode, actorId: staff.id), isFalse);
    });

    test(
      'verification undo returns a request to review and releases holds',
      () {
        final staff = repo.userById('USR-010')!;
        final created = repo.addRequest(
          requesterId: 'USR-009',
          patientAlias: 'Undo verification',
          bloodType: BloodType.oNeg,
          component: BloodComponent.packedRbc,
          unitsNeeded: 1,
          hospital: DigosFacilities.names.first,
          barangay: 'Zone 2',
          urgency: RequestUrgency.urgent,
          source: RequestSource.bloodBank,
          documents: uploadedDocuments(),
          scheduledFor: repo.bloodBankSlots(days: 7).first,
        )!;
        final unit = repo
            .compatibleUnitsFor(
              recipientType: created.bloodType,
              component: created.component,
            )
            .first;

        expect(
          repo.verifyRequest(
            created.id,
            actorId: staff.id,
            unitIds: [unit.barcode],
          ),
          isTrue,
        );
        expect(
          repo.units.firstWhere((u) => u.barcode == unit.barcode).reservedBy,
          'USR-009',
        );

        expect(
          repo.revertRequestVerification(created.id, actorId: staff.id),
          isTrue,
        );
        final reverted = repo.requests.firstWhere((r) => r.id == created.id);
        expect(reverted.status, RequestStatus.pendingReview);
        expect(reverted.assignedUnitIds, isEmpty);
        expect(
          repo.units.firstWhere((u) => u.barcode == unit.barcode).reservedBy,
          isNull,
        );
        expect(
          repo.revertRequestVerification(created.id, actorId: staff.id),
          isFalse,
        );
      },
    );

    test('tab dots clear when the surface is visited', () {
      // Seeded donation activity lights Home.
      expect(repo.tabActivityCount('USR-001', 'home'), greaterThan(0));
      repo.markTabSeen('USR-001', 'home');
      expect(repo.tabActivityCount('USR-001', 'home'), 0);

      // A new verified request lights Requests.
      expect(repo.tabActivityCount('USR-001', 'requests'), 0);
      final created = repo.addRequest(
        requesterId: 'USR-009',
        patientAlias: 'Notification request',
        bloodType: BloodType.oNeg,
        component: BloodComponent.packedRbc,
        unitsNeeded: 1,
        hospital: DigosFacilities.names.first,
        barangay: 'Zone 2',
        urgency: RequestUrgency.urgent,
        documents: uploadedDocuments(),
        scheduledFor: repo.bloodBankSlots(days: 7).first,
      )!;
      expect(repo.verifyRequest(created.id, actorId: 'USR-010'), isTrue);
      expect(repo.tabActivityCount('USR-001', 'requests'), greaterThan(0));
    });
  });
}
