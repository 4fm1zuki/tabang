import 'dart:math' as math;

import 'eligibility.dart';
import 'models.dart';

/// The 26 barangays of Digos City, Davao del Sur.
///
/// Names match the `NAME_3` property in the bundled GeoJSON so donor records,
/// map polygons and analytics all join on the same key.
class DigosBarangays {
  const DigosBarangays._();

  static const List<String> all = [
    'Aplaya',
    'Balabag',
    'Binaton',
    'Cogon',
    'Colorado',
    'Dawis',
    'Dulangan',
    'Goma',
    'Igpit',
    'Kapatagan',
    'Kiagot',
    'Lungag',
    'Mahayahay',
    'Matti',
    'Ruparan',
    'San Agustin',
    'San Jose',
    'San Miguel',
    'San Roque',
    'Sinawilan',
    'Soong',
    'Tiguman',
    'Tres De Mayo',
    'Zone 1',
    'Zone 2',
    'Zone 3',
  ];

  /// Normalise a free-text barangay name to a canonical key, or null.
  static String? canonical(String? raw) {
    if (raw == null) return null;
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'\(.*?\)'), '')
        .replaceAll(RegExp(r'[^a-z0-9]'), '');

    const aliases = {
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
      'kapataganrizal': 'Kapatagan',
      'lungag': 'Lungag',
      'mahayahay': 'Mahayahay',
      'matti': 'Matti',
      'ruparan': 'Ruparan',
      'sanagustin': 'San Agustin',
      'sanjose': 'San Jose',
      'sanjosebalutakay': 'San Jose',
      'sanmiguel': 'San Miguel',
      'sanmiguelodaca': 'San Miguel',
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
}

/// Participating facilities named in the prototype. The paper's recipient flow
/// asks the user to check nearby participating facilities before posting to the
/// donor network; this list is the prototype's facility directory. Inventory is
/// still held by the single PRC chapter, so multi-facility stock is a documented
/// gap rather than a modelled entity.
class DigosFacilities {
  const DigosFacilities._();

  static const List<String> names = [
    'Philippine Red Cross — Davao del Sur Chapter',
    'Digos Provincial Hospital',
    'Digos Doctors Hospital',
  ];
}

/// In-memory data store for the TABANG prototype.
///
/// The study is explicitly scoped to simulated data (paper p.10, p.14), so
/// this repository *is* the data layer: it holds synthetic donor records,
/// inventory and request workflows. It is deliberately the only place seed
/// data lives — the previous build scattered copies across five files and the
/// donor and admin surfaces disagreed about what was in stock.
///
/// Every mutating method notifies listeners so both dashboards stay in sync.
class TabangRepository {
  TabangRepository._() {
    _seed();
  }

  static final TabangRepository instance = TabangRepository._();

  final List<AppUser> _users = [];
  final List<BloodUnit> _units = [];
  final List<RemovedUnitRecord> _removedUnits = [];
  final List<BloodRequest> _requests = [];
  final List<RequestResponse> _responses = [];
  final List<ChatThread> _threads = [];
  final List<UserReport> _reports = [];
  final List<ActivityEvent> _activity = [];
  final List<BloodDrive> _drives = [];
  final List<ContentItem> _content = [];
  final List<DonorApplication> _donorApplications = [];

  /// Admin-editable denominators for the readiness score. The score itself is
  /// always computed from live data; only these planning targets are settable.
  ReadinessTargets _readinessTargets = ReadinessTargets.defaults;

  /// `<driveId>|<userId>` keys for donors who told the chapter they are
  /// attending a drive.
  final Set<String> _driveInterests = {};

  /// Directed block pairs, keyed `blockerId|blockedId`.
  final Set<String> _blocks = {};

  /// When a block was lifted, used for the 48-hour re-block cooldown.
  final Map<String, DateTime> _unblockedAt = {};

  final List<void Function()> _listeners = [];

  /// The signed-in user. Null when nobody is signed in.
  AppUser? currentUser;

  void addListener(void Function() fn) => _listeners.add(fn);
  void removeListener(void Function() fn) => _listeners.remove(fn);
  void _notify() {
    for (final fn in List.of(_listeners)) {
      fn();
    }
  }

  // ---------------------------------------------------------------- reads

  List<AppUser> get users => List.unmodifiable(_users);
  List<BloodUnit> get units => List.unmodifiable(_units);
  List<BloodRequest> get requests => List.unmodifiable(_requests);
  List<RequestResponse> get responses => List.unmodifiable(_responses);
  List<ChatThread> get threads => List.unmodifiable(_threads);
  List<UserReport> get reports => List.unmodifiable(_reports);
  /// Drives the donor-facing surfaces may show: approved and still scheduled.
  /// Proposed, rejected and cancelled drives stay in [allDrives] so staff can
  /// see and act on them.
  List<BloodDrive> get drives =>
      List.unmodifiable(_drives.where((d) => d.isLive));

  /// Every drive on record, whatever its approval state. Staff only.
  List<BloodDrive> get allDrives => List.unmodifiable(_drives);

  /// Drives waiting for an admin decision, oldest submission first.
  List<BloodDrive> get pendingDrives {
    final list = _drives
        .where((d) => d.approval == DriveApproval.pending)
        .toList();
    list.sort((a, b) => a.startsAt.compareTo(b.startsAt));
    return List.unmodifiable(list);
  }

  /// Drives an admin cancelled; they can be restored from here.
  List<BloodDrive> get cancelledDrives => List.unmodifiable(
    _drives.where((d) => d.approval == DriveApproval.cancelled),
  );
  List<ContentItem> get content => List.unmodifiable(_content);

  AppUser? userById(String id) {
    // The chapter is a standalone organization account, deliberately not one
    // of the staff members' personal accounts; it is not part of [_users] so
    // it can never leak into staff lists or the staff room.
    if (id == chapterAccountId) return chapterAccount;
    for (final u in _users) {
      if (u.id == id) return u;
    }
    return null;
  }

  AppUser? userByEmail(String email) {
    final needle = email.trim().toLowerCase();
    for (final u in _users) {
      if (u.email.toLowerCase() == needle) return u;
    }
    return null;
  }

  /// Donors only — recipients and staff never appear in the donor directory.
  List<AppUser> get donors =>
      _users.where((u) => u.role == UserRole.donor).toList(growable: false);

  /// Donors who pass every eligibility rule right now.
  ///
  /// Pass [component] when the question is component-specific (for example,
  /// whether a platelet donor is still inside the platelet cooldown).
  List<AppUser> eligibleDonorsFor({BloodComponent? component}) => donors
      .where(
        (u) => EligibilityEngine.evaluate(u, component: component).isEligible,
      )
      .toList(growable: false);

  List<AppUser> get eligibleDonors => eligibleDonorsFor();

  /// Donors matching a blood type filter and optional barangay.
  ///
  /// When [compatibleWith] is supplied, the filter is component-aware: plasma
  /// uses the reverse ABO rule, red cells and platelets use the red-cell rule.
  List<AppUser> findDonors({
    BloodType? bloodType,
    String? barangay,
    bool onlyEligible = true,
    BloodComponent? component,
    BloodType? compatibleWith,
  }) {
    return donors
        .where((u) {
          if (onlyEligible &&
              !EligibilityEngine.evaluate(u, component: component).isEligible) {
            return false;
          }
          if (bloodType != null && u.bloodType != bloodType) return false;
          if (barangay != null && u.barangay != barangay) return false;
          if (compatibleWith != null) {
            final donorType = u.bloodType;
            if (donorType == null ||
                !Compatibility.canDonateComponentTo(
                  donorType,
                  compatibleWith,
                  component ?? BloodComponent.wholeBlood,
                )) {
              return false;
            }
          }
          return true;
        })
        .toList(growable: false);
  }

  /// Available donor count per barangay, optionally filtered by blood type.
  Map<String, int> donorCountsByBarangay({
    BloodType? bloodType,
    BloodComponent? component,
  }) {
    final counts = <String, int>{};
    for (final u in eligibleDonorsFor(component: component)) {
      if (bloodType != null && u.bloodType != bloodType) continue;
      counts[u.barangay] = (counts[u.barangay] ?? 0) + 1;
    }
    return counts;
  }

  /// Open (not yet matched/closed) requests per barangay. Drives the staff
  /// operations map's request heat layer.
  Map<String, int> openRequestsByBarangay() {
    final counts = <String, int>{};
    for (final request in _requests) {
      if (request.status != RequestStatus.open &&
          request.status != RequestStatus.matched) {
        continue;
      }
      counts[request.barangay] = (counts[request.barangay] ?? 0) + 1;
    }
    return counts;
  }

  /// Donor registrations waiting on chapter staff, per barangay.
  Map<String, int> pendingApplicationsByBarangay() {
    final counts = <String, int>{};
    for (final application in openDonorApplications) {
      final barangay = userById(application.userId)?.barangay;
      if (barangay == null) continue;
      counts[barangay] = (counts[barangay] ?? 0) + 1;
    }
    return counts;
  }

  /// Requests in [barangay] that chapter staff can still act on, newest first.
  List<BloodRequest> openRequestsIn(String barangay) {
    return _requests
        .where(
          (r) =>
              r.barangay == barangay &&
              (r.status == RequestStatus.open ||
                  r.status == RequestStatus.matched),
        )
        .toList(growable: false)
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<BloodUnit> get availableUnits =>
      _units.where((u) => u.isUsable).toList(growable: false);

  int unitsOfType(BloodType type) =>
      availableUnits.where((u) => u.bloodType == type).length;

  /// Usable units of [component] that can be transfused into [recipientType].
  List<BloodUnit> compatibleUnitsFor({
    required BloodType recipientType,
    required BloodComponent component,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    return _units
        .where(
          (u) =>
              u.component == component &&
              u.isUsableAt(today) &&
              Compatibility.canDonateComponentTo(
                u.bloodType,
                recipientType,
                component,
              ),
        )
        .toList(growable: false);
  }

  /// Donors who could serve [request] and have not already responded.
  List<AppUser> compatibleDonorsForRequest(BloodRequest request) {
    final responded = _responses
        .where((r) => r.requestId == request.id)
        .map((r) => r.donorId)
        .toSet();
    return donors
        .where((u) {
          if (responded.contains(u.id)) return false;
          final donorType = u.bloodType;
          if (donorType == null) return false;
          if (!EligibilityEngine.evaluate(
            u,
            component: request.component,
          ).isEligible) {
            return false;
          }
          return Compatibility.canDonateComponentTo(
            donorType,
            request.bloodType,
            request.component,
          );
        })
        .toList(growable: false);
  }

  List<BloodRequest> get openRequests => _requests
      .where((r) => r.status == RequestStatus.open)
      .toList(growable: false);

  List<BloodRequest> get donorNetworkRequests =>
      _requests.where((r) => r.acceptsDonorResponses).toList(growable: false);

  List<RequestResponse> responsesFor(String requestId) =>
      _responses.where((r) => r.requestId == requestId).toList(growable: false)
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  RequestResponse? responseForDonor(String requestId, String donorId) {
    for (final r in _responses) {
      if (r.requestId == requestId && r.donorId == donorId) return r;
    }
    return null;
  }

  List<ChatThread> threadsFor(String userId) =>
      _threads.where((t) => t.includes(userId)).toList(growable: false);

  ChatThread? threadBetween(String a, String b) {
    for (final t in _threads) {
      final hasA = t.participantAId == a || t.participantBId == a;
      final hasB = t.participantAId == b || t.participantBId == b;
      if (hasA && hasB) return t;
    }
    return null;
  }

  /// Requests with a booked blood-bank slot, soonest first.
  ///
  /// This replaces the old separate "appointment with blood" queue: the slot is
  /// part of the request, so staff confirm it when they verify the request.
  List<BloodRequest> get scheduledRequests =>
      _requests
          .where(
            (request) =>
                request.scheduledFor != null &&
                request.status != RequestStatus.cancelled &&
                request.status != RequestStatus.rejected,
          )
          .toList(growable: false)
        ..sort((a, b) => a.scheduledFor!.compareTo(b.scheduledFor!));

  /// Slots still awaiting chapter verification.
  List<BloodRequest> get pendingScheduledRequests => scheduledRequests
      .where((request) => request.status == RequestStatus.pendingReview)
      .toList(growable: false);

  /// Units currently on hold by [userId].
  List<BloodUnit> reservedUnitsFor(String userId) => _units
      .where((u) => u.reservedBy == userId && !u.isExpiredAt(DateTime.now()))
      .toList(growable: false);

  bool isBlocked(String blockerId, String blockedId) =>
      _blocks.contains('$blockerId|$blockedId');

  /// True when either party has blocked the other.
  bool isBlockedBetween(String a, String b) =>
      isBlocked(a, b) || isBlocked(b, a);

  /// A block may be re-applied 48 hours after it was lifted. This mirrors the
  /// cooldown stated in the Help FAQ.
  bool canBlock(String blockerId, String blockedId) {
    if (isBlocked(blockerId, blockedId)) return false;
    final lifted = _unblockedAt['$blockerId|$blockedId'];
    if (lifted == null) return true;
    return DateTime.now().difference(lifted) >= const Duration(hours: 48);
  }

  // --------------------------------------------------------------- writes

  void signIn(AppUser user) {
    currentUser = userById(user.id) ?? user;
    _notify();
  }

  /// Records app activity for [userId]. Directory actions and the Donor Hub's
  /// "I'm active" button call this so the automatic "away" rule resets.
  /// Signing in alone deliberately does not: a returning donor sees the away
  /// notice and chooses to come back.
  void markActive(String userId) {
    final user = userById(userId);
    if (user == null) return;
    updateUser(user.copyWith(lastActiveAt: DateTime.now()));
  }

  void signOut() {
    currentUser = null;
    _notify();
  }

  AppUser register({
    required String fullName,
    required String alias,
    required String email,
    required String phone,
    required String barangay,
    required UserRole role,
    BloodType? bloodType,
    DateTime? birthDate,
    double? weightKg,
  }) {
    final user = AppUser(
      id: 'USR-${(_users.length + 1).toString().padLeft(3, '0')}',
      fullName: fullName,
      alias: alias,
      email: email,
      phone: phone,
      barangay: barangay,
      role: role,
      bloodType: bloodType,
      birthDate: birthDate,
      weightKg: weightKg,
      registeredOn: DateTime.now(),
      lastActiveAt: DateTime.now(),
      // New donors start unverified until staff review their blood card.
      status: role == UserRole.donor
          ? AccountStatus.unverified
          : AccountStatus.verified,
    );
    _users.add(user);
    _notify();
    return user;
  }

  /// Aliases are the public identity, so two accounts must never share one.
  /// Matching is case- and whitespace-insensitive.
  bool isAliasTaken(String alias, {String? exceptUserId}) {
    final normalized = alias.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return _users.any(
      (u) => u.id != exceptUserId && u.alias.trim().toLowerCase() == normalized,
    );
  }

  /// Marks the post-registration walkthrough as seen.
  void completeOnboarding(String userId) {
    final user = userById(userId);
    if (user == null || user.onboardingCompleted) return;
    updateUser(user.copyWith(onboardingCompleted: true));
  }

  void updateUser(AppUser updated) {
    final index = _users.indexWhere((u) => u.id == updated.id);
    if (index == -1) return;
    _users[index] = updated;
    if (currentUser?.id == updated.id) currentUser = updated;
    _notify();
  }

  /// Promote a community user to a volunteer donor.
  ///
  /// A new donor is deliberately left unverified so chapter staff review the
  /// blood card before the profile appears in the matching directory. The
  /// method refuses accounts that are already donors or are staff/admin.
  bool upgradeToDonor({
    required String userId,
    // Nullable: many walk-in applicants do not know their type yet and are
    // typed at the chapter during screening.
    required BloodType? bloodType,
    required DateTime birthDate,
    required double weightKg,
  }) {
    final user = userById(userId);
    if (user == null || !user.role.canRegisterAsDonor) return false;
    final age = DateTime.now().difference(birthDate).inDays ~/ 365;
    if (age < EligibilityEngine.minimumAge ||
        age > EligibilityEngine.maximumAge) {
      return false;
    }
    if (weightKg < EligibilityEngine.minimumWeightKg || weightKg > 300) {
      return false;
    }
    updateUser(
      user.copyWith(
        role: UserRole.donor,
        bloodType: bloodType,
        birthDate: birthDate,
        weightKg: weightKg,
        status: AccountStatus.unverified,
        bloodCardVerified: false,
        isAvailable: true,
      ),
    );
    return true;
  }

  void setDonorAvailability(String userId, bool isAvailable) {
    final user = userById(userId);
    if (user == null) return;
    // Touching the switch counts as activity, so turning availability back on
    // also clears an automatic "away".
    updateUser(
      user.copyWith(isAvailable: isAvailable, lastActiveAt: DateTime.now()),
    );
  }

  void recordDonation(
    String userId, {
    DateTime? at,
    BloodComponent? component,
  }) {
    final user = userById(userId);
    if (user == null) return;
    final recordedComponent =
        component ?? user.lastDonationComponent ?? BloodComponent.packedRbc;
    updateUser(
      user.copyWith(
        lastDonationDate: at ?? DateTime.now(),
        lastDonationComponent: recordedComponent,
        totalDonations: user.totalDonations + 1,
      ),
    );
    _logActivity(
      kind: ActivityKind.donation,
      actorId: currentUser?.id ?? staffAccountId,
      subjectId: userId,
      summary:
          'Recorded a ${recordedComponent.label.toLowerCase()} donation for '
          '${user.alias}',
    );
  }

  /// Correct the donation window without counting a second donation.
  ///
  /// After a transfusion or a late data entry, staff may need to move the
  /// recorded donation date or change the component. The total donation count
  /// stays untouched; only the cooldown anchor moves.
  void updateDonationWindow(
    String userId, {
    required DateTime lastDonationDate,
    BloodComponent? component,
  }) {
    final user = userById(userId);
    if (user == null) return;
    updateUser(
      user.copyWith(
        lastDonationDate: lastDonationDate,
        lastDonationComponent: component ?? user.lastDonationComponent,
      ),
    );
    _logActivity(
      kind: ActivityKind.donationWindow,
      actorId: currentUser?.id ?? staffAccountId,
      subjectId: userId,
      summary:
          'Corrected ${user.alias}\'s donation window to '
          '${_shortDate(lastDonationDate)}',
    );
  }

  void setUserStatus(String userId, AccountStatus status, {String? reason}) {
    final user = userById(userId);
    if (user == null) return;
    updateUser(
      user.copyWith(
        status: status,
        suspensionReason: reason,
        clearSuspensionReason: reason == null,
        // Reinstating an account clears the warning ladder, so a single new
        // warning starts from one instead of instantly suspending again.
        warningCount: status == AccountStatus.verified ? 0 : null,
      ),
    );
    _logActivity(
      kind: status == AccountStatus.suspended
          ? ActivityKind.suspension
          : ActivityKind.verification,
      actorId: currentUser?.id ?? staffAccountId,
      subjectId: userId,
      summary:
          'Set ${user.alias} to ${status.label.toLowerCase()}'
          '${reason == null || reason.isEmpty ? '' : ' · $reason'}',
    );
  }

  void verifyUser(String userId) {
    final user = userById(userId);
    if (user == null) return;
    updateUser(
      user.copyWith(status: AccountStatus.verified, bloodCardVerified: true),
    );
    _logActivity(
      kind: ActivityKind.verification,
      actorId: currentUser?.id ?? staffAccountId,
      subjectId: userId,
      summary: 'Verified the blood card for ${user.alias}',
    );
  }

  // ------------------------------------------------- donor applications

  /// Every donor registration, newest first.
  List<DonorApplication> get donorApplications =>
      List.unmodifiable(_donorApplications.reversed);

  DonorApplication? donorApplicationFor(String userId) {
    for (final application in _donorApplications.reversed) {
      if (application.userId == userId) return application;
    }
    return null;
  }

  /// Registrations staff still has to act on.
  List<DonorApplication> get openDonorApplications =>
      _donorApplications
          .where(
            (a) =>
                a.status == DonorApplicationStatus.pending ||
                a.status == DonorApplicationStatus.documentsRequested,
          )
          .toList(growable: false)
        ..sort((a, b) => b.submittedAt.compareTo(a.submittedAt));

  /// Register interest in becoming a volunteer donor.
  ///
  /// The medical interview, physical examination, blood typing and screening
  /// happen face-to-face at the chapter, so this only records the intent to
  /// visit (plus whether the applicant already has a donor card). The account
  /// becomes a donor immediately but stays **unverified**, which the
  /// eligibility engine treats as not yet donatable, and the application enters
  /// the staff queue for the in-person verification.
  DonorApplication? submitDonorApplication({
    required String userId,
    required bool hasExistingCard,
    String? cardNumber,
    BloodType? bloodType,
    DateTime? birthDate,
    double? weightKg,
    DateTime? preferredVisit,
    String? note,
  }) {
    final user = userById(userId);
    if (user == null) return null;

    // A community user converts here; an unverified donor may re-submit,
    // which is why this is not restricted to community accounts.
    final freshApplicant = user.role.canRegisterAsDonor;
    final resubmitting = user.role == UserRole.donor && !user.bloodCardVerified;
    if (!freshApplicant && !resubmitting) return null;

    // Birth date and weight are the two eligibility inputs the chapter cannot
    // verify remotely. When provided they are stored now so a donor verified
    // from the queue is immediately matchable instead of failing on
    // `weightMissing` forever.
    final effectiveBirthDate = birthDate ?? user.birthDate;
    final effectiveWeight = weightKg ?? user.weightKg;

    if (freshApplicant) {
      updateUser(
        user.copyWith(
          role: UserRole.donor,
          bloodType: bloodType,
          birthDate: effectiveBirthDate,
          weightKg: effectiveWeight,
          status: AccountStatus.unverified,
          bloodCardVerified: false,
          isAvailable: true,
        ),
      );
    } else {
      updateUser(
        user.copyWith(
          bloodType: bloodType ?? user.bloodType,
          birthDate: effectiveBirthDate,
          weightKg: effectiveWeight,
          status: AccountStatus.unverified,
          bloodCardVerified: false,
        ),
      );
    }

    _donorApplications.removeWhere((a) => a.userId == userId);
    final application = DonorApplication(
      id: 'DNA-${(_donorApplications.length + 1).toString().padLeft(3, '0')}',
      userId: userId,
      submittedAt: DateTime.now(),
      status: DonorApplicationStatus.pending,
      hasExistingCard: hasExistingCard,
      cardNumber: cardNumber,
      preferredVisit: preferredVisit,
      note: note,
      requestedDocuments: hasExistingCard
          ? const [
              'PRC blood donor card',
              'Valid government or school ID',
              'Chapter screening before the next donation',
            ]
          : const [
              'Valid government or school ID',
              'Chapter interview and physical examination',
              'Blood typing and infection screening',
            ],
    );
    _donorApplications.add(application);
    _logActivity(
      kind: ActivityKind.application,
      actorId: userId,
      subjectId: userId,
      summary: 'Submitted a donor registration',
    );
    ensureChapterThread(
      userId,
      welcome:
          'Registration received — thank you for stepping forward. This is the '
          'official thread of the $chapterName. Chapter staff will review '
          'your form during office hours and update you here. Bring your valid '
          'ID${hasExistingCard ? ' and PRC donor card' : ''} to the chapter for '
          'the interview, blood typing and screening.',
    );
    _notify();
    return application;
  }

  /// Staff decision on a donor application. The applicant gets an official
  /// update in their chapter thread so they do not have to keep reopening
  /// Donor Hub to learn the outcome.
  void setDonorApplicationStatus(
    String userId,
    DonorApplicationStatus status, {
    String? note,
    List<String>? requestedDocuments,
  }) {
    final index = _donorApplications.indexWhere((a) => a.userId == userId);
    if (index == -1) return;
    _donorApplications[index] = _donorApplications[index].copyWith(
      status: status,
      staffNote: note,
      requestedDocuments: requestedDocuments,
    );

    switch (status) {
      case DonorApplicationStatus.pending:
        break;
      case DonorApplicationStatus.documentsRequested:
        final docs = requestedDocuments == null || requestedDocuments.isEmpty
            ? 'the documents listed in Donor Hub'
            : requestedDocuments.join(', ');
        postChapterNotice(
          userId,
          'Before we can verify your card we still need: $docs. Reply here or '
          'visit the chapter during office hours.',
        );
      case DonorApplicationStatus.verified:
        postChapterNotice(
          userId,
          'Your blood card is verified — you can now appear in the donor '
          'directory and answer requests when eligible. Thank you!',
        );
        // verifyUser notifies, so this path must not notify twice.
        verifyUser(userId);
        return;
      case DonorApplicationStatus.rejected:
        postChapterNotice(
          userId,
          'We could not accept the registration as submitted. '
          '${note == null || note.trim().isEmpty ? 'Please visit the chapter so we can review it together.' : note.trim()}',
        );
    }
    _notify();
  }

  // --------------------------------------------------------- drive interest

  bool isInterestedInDrive(String driveId, String userId) =>
      _driveInterests.contains('$driveId|$userId');

  /// Donors only. A community user must become a donor first, so the drive
  /// list can never promise a donation the chapter cannot screen.
  bool toggleDriveInterest(String driveId, String userId) {
    final user = userById(userId);
    if (user == null ||
        user.role != UserRole.donor ||
        user.status == AccountStatus.suspended) {
      return false;
    }
    final key = '$driveId|$userId';
    final added = _driveInterests.add(key);
    if (!added) _driveInterests.remove(key);
    _notify();
    return added;
  }

  int driveInterestCount(String driveId) =>
      _driveInterests.where((key) => key.startsWith('$driveId|')).length;

  // -------------------------------------------------------- drive approvals

  /// Sequential id for staff-proposed drives; the seeded ones are DRV-001..005.
  int _nextDriveNumber = 6;

  /// Staff propose a drive. It stays [DriveApproval.pending] until an admin
  /// approves it, so a proposal can never reach the donor surfaces by itself.
  ///
  /// Returns null when the input is unusable (blank fields, end before start,
  /// no expected donors) so the caller can show a validation message.
  BloodDrive? proposeBloodDrive({
    required String actorId,
    required String title,
    required String venue,
    required String barangay,
    required DateTime startsAt,
    required DateTime endsAt,
    required int expectedDonors,
    String? note,
  }) {
    final actor = userById(actorId);
    if (actor == null || !actor.role.isAdminSide) return null;
    if (title.trim().isEmpty ||
        venue.trim().isEmpty ||
        barangay.trim().isEmpty ||
        expectedDonors <= 0 ||
        !endsAt.isAfter(startsAt)) {
      return null;
    }
    final drive = BloodDrive(
      id: 'DRV-${_nextDriveNumber.toString().padLeft(3, '0')}',
      title: title.trim(),
      venue: venue.trim(),
      barangay: barangay,
      startsAt: startsAt,
      endsAt: endsAt,
      expectedDonors: expectedDonors,
      approval: DriveApproval.pending,
      proposedById: actorId,
      reviewNote: (note ?? '').trim().isEmpty ? null : note!.trim(),
    );
    _nextDriveNumber++;
    _drives.add(drive);
    _logDrive(actor.id, 'Proposed the drive "${drive.title}" at ${drive.venue}');
    return drive;
  }

  /// Withdraws a proposal, and is also the Undo for [proposeBloodDrive].
  /// Refused once an admin has decided, so nothing approved can vanish.
  bool withdrawDriveProposal(String driveId, {required String actorId}) {
    final actor = userById(actorId);
    final index = _drives.indexWhere((d) => d.id == driveId);
    if (actor == null || index == -1) return false;
    final drive = _drives[index];
    if (drive.approval != DriveApproval.pending) return false;
    if (drive.proposedById != actorId && !actor.role.isAdminSide) return false;
    _drives.removeAt(index);
    _logDrive(actorId, 'Withdrew the proposed drive "${drive.title}"');
    return true;
  }

  /// Admin approves a proposed drive; it becomes visible to donors.
  bool approveDrive(String driveId, {required String actorId}) {
    return _setDriveApproval(
      driveId,
      actorId: actorId,
      from: DriveApproval.pending,
      to: DriveApproval.approved,
      summary: 'Approved the drive',
    );
  }

  /// Undo of [approveDrive]: the drive returns to the pending queue.
  bool undoDriveApproval(String driveId, {required String actorId}) {
    return _setDriveApproval(
      driveId,
      actorId: actorId,
      from: DriveApproval.approved,
      to: DriveApproval.pending,
      summary: 'Returned the drive to the approval queue',
    );
  }

  /// Admin rejects a proposal, with a reason the proposer can read.
  bool rejectDriveProposal(
    String driveId, {
    required String actorId,
    String? reason,
  }) {
    return _setDriveApproval(
      driveId,
      actorId: actorId,
      from: DriveApproval.pending,
      to: DriveApproval.rejected,
      summary: 'Rejected the drive',
      note: reason,
    );
  }

  /// Undo of [rejectDriveProposal].
  bool undoDriveRejection(String driveId, {required String actorId}) {
    return _setDriveApproval(
      driveId,
      actorId: actorId,
      from: DriveApproval.rejected,
      to: DriveApproval.pending,
      summary: 'Reopened the rejected drive',
      clearNote: true,
    );
  }

  /// Admin cancels an approved drive, e.g. a venue fell through.
  bool cancelBloodDrive(
    String driveId, {
    required String actorId,
    String? reason,
  }) {
    return _setDriveApproval(
      driveId,
      actorId: actorId,
      from: DriveApproval.approved,
      to: DriveApproval.cancelled,
      summary: 'Cancelled the drive',
      note: reason,
    );
  }

  /// Undo of [cancelBloodDrive]: the drive is scheduled again.
  bool undoDriveCancellation(String driveId, {required String actorId}) {
    return _setDriveApproval(
      driveId,
      actorId: actorId,
      from: DriveApproval.cancelled,
      to: DriveApproval.approved,
      summary: 'Restored the cancelled drive',
      clearNote: true,
    );
  }

  /// One guarded transition behind every approve/reject/cancel/undo action, so
  /// they all enforce "admins only" and "only from the expected state".
  ///
  /// Approving, rejecting and cancelling are admin decisions: staff can propose,
  /// but a proposal must never be able to approve itself.
  bool _setDriveApproval(
    String driveId, {
    required String actorId,
    required DriveApproval from,
    required DriveApproval to,
    required String summary,
    String? note,
    bool clearNote = false,
  }) {
    final actor = userById(actorId);
    final index = _drives.indexWhere((d) => d.id == driveId);
    if (actor == null || index == -1) return false;
    if (!actor.role.canManageStaff) return false;
    final drive = _drives[index];
    if (drive.approval != from) return false;
    _drives[index] = drive.copyWith(
      approval: to,
      reviewedById: actorId,
      reviewNote: note,
      clearReviewNote: clearNote,
    );
    _logDrive(actorId, '$summary "${drive.title}"');
    return true;
  }

  void _logDrive(String actorId, String summary) {
    _logActivity(
      kind: ActivityKind.driveUpdate,
      actorId: actorId,
      summary: summary,
    );
    _notify();
  }

  /// Adds a warning, capped at three.
  ///
  /// Repeatedly pressing Warn must not keep stacking: once an account is
  /// suspended the action is refused, and reinstating an account clears its
  /// warning count back to zero. Each warning carries the reason staff entered.
  bool warnUser(String userId, {String? reason}) {
    final user = userById(userId);
    if (user == null) return false;
    if (user.status == AccountStatus.suspended) return false;
    final next = (user.warningCount + 1).clamp(1, 3);
    final note = reason?.trim();
    updateUser(
      user.copyWith(
        warningCount: next,
        status: next >= 3 ? AccountStatus.suspended : AccountStatus.warned,
        suspensionReason: next >= 3
            ? 'Three moderation warnings on record.'
            : null,
      ),
    );
    _logActivity(
      kind: ActivityKind.warning,
      actorId: currentUser?.id ?? staffAccountId,
      subjectId: userId,
      summary:
          'Issued warning $next to ${user.alias}'
          '${note == null || note.isEmpty ? '' : ': $note'}',
    );
    return true;
  }

  /// `YYYY-MM-DD`, used in activity summaries where the widgets layer is not
  /// available to format a date.
  String _shortDate(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';

  /// Published blood-bank service windows. Requests must book inside them;
  /// staff can only review what the shelf can actually serve.
  static const List<int> bloodBankWeekdayHours = [8, 9, 10, 11, 13, 14, 15];
  static const List<int> bloodBankSaturdayHours = [8, 9, 10, 11];

  static List<int> _hoursFor(int weekday) {
    if (weekday == DateTime.sunday) return const [];
    if (weekday == DateTime.saturday) return bloodBankSaturdayHours;
    return bloodBankWeekdayHours;
  }

  /// True when [slot] falls on a published half-day slot in the future.
  bool isWithinBloodBankSchedule(DateTime slot, {DateTime? now}) {
    final base = now ?? DateTime.now();
    if (!slot.isAfter(base)) return false;
    if (slot.minute != 0) return false;
    return _hoursFor(slot.weekday).contains(slot.hour);
  }

  /// Bookable slots for the next [days] days, already filtered to the
  /// chapter's published schedule.
  List<DateTime> bloodBankSlots({int days = 21, DateTime? now}) {
    final base = now ?? DateTime.now();
    final slots = <DateTime>[];
    for (var i = 0; i < days; i++) {
      final day = DateTime(base.year, base.month, base.day + i);
      for (final hour in _hoursFor(day.weekday)) {
        final slot = DateTime(day.year, day.month, day.day, hour);
        if (slot.isAfter(base)) slots.add(slot);
      }
    }
    return slots;
  }

  /// Submit a request for chapter verification.
  ///
  /// Nothing is posted to donors or held from stock at submission time: the
  /// request first needs the three required documents as actual uploaded files
  /// and a slot inside the blood-bank schedule, then staff verify or reject
  /// it. Returns null when the submission is incomplete — a checklist tick
  /// without a file is not enough.
  BloodRequest? addRequest({
    required String requesterId,
    required String patientAlias,
    required BloodType bloodType,
    required BloodComponent component,
    required int unitsNeeded,
    required String hospital,
    required String barangay,
    required RequestUrgency urgency,
    RequestSource source = RequestSource.donorNetwork,
    String? note,
    List<RequestDocument> documents = const [],
    DateTime? scheduledFor,
    bool postToDonorNetwork = true,
  }) {
    final uploaded = documents
        .where((document) => document.fileName.trim().isNotEmpty)
        .toList(growable: false);
    final kinds = uploaded.map((document) => document.kind).toSet();
    final hasRequiredDocuments = RequestDocuments.required.every(
      kinds.contains,
    );
    if (!hasRequiredDocuments) return null;
    if (!uploaded.every((document) => document.hasFile)) return null;
    if (unitsNeeded < 1 || unitsNeeded > 20) return null;
    if (scheduledFor == null || !isWithinBloodBankSchedule(scheduledFor)) {
      return null;
    }

    final request = BloodRequest(
      id: 'REQ-${(_requests.length + 1).toString().padLeft(3, '0')}',
      requesterId: requesterId,
      patientAlias: patientAlias,
      bloodType: bloodType,
      component: component,
      unitsNeeded: unitsNeeded,
      hospital: hospital,
      barangay: barangay,
      urgency: urgency,
      createdAt: DateTime.now(),
      status: RequestStatus.pendingReview,
      source: postToDonorNetwork ? source : RequestSource.bloodBank,
      note: note,
      documents: uploaded,
      scheduledFor: scheduledFor,
      postToDonorNetwork: postToDonorNetwork,
    );
    _requests.insert(0, request);
    _logActivity(
      kind: ActivityKind.requestSubmitted,
      actorId: requesterId,
      subjectId: requesterId,
      summary:
          'Submitted request ${request.id} for ${request.patientAlias} '
          '(${request.component.label.toLowerCase()})',
    );
    markActive(requesterId);
    _notify();
    return request;
  }

  /// Staff verify a submitted request. Blood-bank requests may assign usable
  /// units, which are held for the requester at verification time.
  bool verifyRequest(
    String requestId, {
    required String actorId,
    List<String> unitIds = const [],
  }) {
    final actor = userById(actorId);
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (actor == null || index == -1) return false;
    if (!actor.role.isAdminSide) return false;
    final request = _requests[index];
    if (request.status != RequestStatus.pendingReview) return false;

    // Validate every assigned bag before touching any of them.
    for (final barcode in unitIds) {
      final unit = _firstOrNull(_units, (u) => u.barcode == barcode);
      if (unit == null ||
          !unit.isUsable ||
          unit.reservedBy != null ||
          unit.effectiveStatus(DateTime.now()) != UnitStatus.available) {
        return false;
      }
    }
    for (final barcode in unitIds) {
      reserveUnit(
        barcode: barcode,
        userId: request.requesterId,
        note: 'Blood-bank hold for ${request.id}',
      );
    }

    _requests[index] = request.copyWith(
      status: RequestStatus.open,
      reviewedById: actorId,
      assignedUnitIds: unitIds,
      clearReviewNote: true,
    );
    _logActivity(
      kind: ActivityKind.requestVerified,
      actorId: actorId,
      subjectId: request.requesterId,
      summary:
          'Verified request ${request.id} for ${request.patientAlias}'
          '${unitIds.isEmpty ? '' : ' · ${unitIds.length} unit hold'}',
    );
    _notify();
    return true;
  }

  /// Staff reject a submitted request with a reason the requester can read.
  bool rejectRequest(
    String requestId, {
    required String actorId,
    required String reason,
  }) {
    final actor = userById(actorId);
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (actor == null || index == -1) return false;
    if (!actor.role.isAdminSide) return false;
    final trimmed = reason.trim();
    if (trimmed.isEmpty) return false;
    final request = _requests[index];
    if (request.status != RequestStatus.pendingReview) return false;

    _requests[index] = request.copyWith(
      status: RequestStatus.rejected,
      reviewedById: actorId,
      reviewNote: trimmed,
    );
    _logActivity(
      kind: ActivityKind.requestRejected,
      actorId: actorId,
      subjectId: request.requesterId,
      summary: 'Rejected request ${request.id}: $trimmed',
    );
    _notify();
    return true;
  }

  /// Undo a rejection made moments ago from the snackbar: the request returns to
  /// the review queue and the reason is cleared.
  ///
  /// Refused unless the request is still rejected, so an undo can never unwind a
  /// rejection the requester has already acted on.
  bool undoRejectRequest(String requestId, {required String actorId}) {
    final actor = userById(actorId);
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (actor == null || index == -1) return false;
    if (!actor.role.isAdminSide) return false;
    final request = _requests[index];
    if (request.status != RequestStatus.rejected) return false;
    _requests[index] = request.copyWith(
      status: RequestStatus.pendingReview,
      clearReview: true,
    );
    _logActivity(
      kind: ActivityKind.requestReopened,
      actorId: actorId,
      subjectId: request.requesterId,
      summary: 'Reopened request ${request.id} after an undo',
    );
    _notify();
    return true;
  }

  /// Undo a verification: the request returns to the review queue and any
  /// blood-bank holds placed at verification time are released.
  ///
  /// Refused once fulfilment has started, so an undo cannot unwind a real
  /// donation.
  bool revertRequestVerification(String requestId, {required String actorId}) {
    final actor = userById(actorId);
    final index = _requests.indexWhere((r) => r.id == requestId);
    if (actor == null || index == -1) return false;
    if (!actor.role.isAdminSide) return false;
    final request = _requests[index];
    if (request.status != RequestStatus.open || request.unitsFulfilled > 0) {
      return false;
    }
    for (final barcode in request.assignedUnitIds) {
      cancelReservation(barcode: barcode, userId: request.requesterId);
    }
    _requests[index] = request.copyWith(
      status: RequestStatus.pendingReview,
      clearReview: true,
      assignedUnitIds: const [],
    );
    _logActivity(
      kind: ActivityKind.requestSubmitted,
      actorId: actorId,
      subjectId: request.requesterId,
      summary:
          'Reopened request ${request.id} for review after an undo '
          '(${request.patientAlias})',
    );
    _notify();
    return true;
  }

  /// A donor offers to serve a request. This does not consume a unit and does
  /// not mark the request matched; the requester must select a response.
  ///
  /// Returns null when the request is closed, the donor is not eligible for the
  /// requested component, the blood types are incompatible, or the donor has
  /// already responded.
  RequestResponse? respondToRequest({
    required String requestId,
    required String donorId,
    String? message,
  }) {
    final request = _firstOrNull(_requests, (r) => r.id == requestId);
    final donor = userById(donorId);
    if (request == null || donor == null) return null;
    if (!request.acceptsDonorResponses) return null;
    if (donor.role != UserRole.donor || donor.bloodType == null) return null;
    if (!EligibilityEngine.evaluate(
      donor,
      component: request.component,
    ).isEligible) {
      return null;
    }
    if (!Compatibility.canDonateComponentTo(
      donor.bloodType!,
      request.bloodType,
      request.component,
    )) {
      return null;
    }
    if (responseForDonor(requestId, donorId) != null) return null;

    final trimmedMessage = message?.trim();
    final response = RequestResponse(
      id: 'RES-${(_responses.length + 1).toString().padLeft(3, '0')}',
      requestId: requestId,
      donorId: donorId,
      donorAlias: donor.mapHandle,
      createdAt: DateTime.now(),
      message: trimmedMessage == null || trimmedMessage.isEmpty
          ? null
          : trimmedMessage,
    );
    _responses.add(response);
    markActive(donorId);
    _notify();
    return response;
  }

  /// A donor who has already been selected for another active request.
  ///
  /// The donor stays visible in Find Donor and in the response list, but a
  /// requester cannot silently reserve the same person twice. Fairness is
  /// enforced when selecting, not by hiding the donor.
  RequestResponse? commitmentForDonor(
    String donorId, {
    String? excludingRequestId,
  }) {
    for (final response in _responses) {
      if (response.donorId != donorId ||
          response.status != ResponseStatus.selected) {
        continue;
      }
      if (excludingRequestId != null &&
          response.requestId == excludingRequestId) {
        continue;
      }
      final request = _firstOrNull(
        _requests,
        (r) => r.id == response.requestId,
      );
      if (request == null) continue;
      if (request.status == RequestStatus.open ||
          request.status == RequestStatus.matched) {
        return response;
      }
    }
    return null;
  }

  /// The request a donor is currently committed to, if any.
  BloodRequest? activeCommitmentFor(String donorId) {
    final response = commitmentForDonor(donorId);
    if (response == null) return null;
    return _firstOrNull(_requests, (r) => r.id == response.requestId);
  }

  /// The requester selects a donor response.
  ///
  /// Staff do not pick donors: they verify the request, and the requester
  /// coordinates with the people who offered. Selection creates the
  /// coordination thread and, once enough donors are selected, moves the
  /// request to `matched`. No unit is counted as fulfilled until staff record
  /// the donation.
  ChatThread? selectResponse({
    required String responseId,
    required String selectedById,
  }) {
    final response = _firstOrNull(_responses, (r) => r.id == responseId);
    if (response == null) return null;
    final request = _firstOrNull(_requests, (r) => r.id == response.requestId);
    if (request == null || request.status != RequestStatus.open) return null;

    final actor = userById(selectedById);
    if (actor == null) return null;
    if (actor.id != request.requesterId) return null;
    if (response.status != ResponseStatus.pending) return null;

    final donor = userById(response.donorId);
    final requester = userById(request.requesterId);
    if (donor == null || requester == null) return null;

    // Chat-first rule: selection is only allowed after the requester and donor
    // have both exchanged at least one message. This prevents choosing a donor
    // based on a one-line offer without any human coordination.
    if (!hasReciprocalChat(requester.id, donor.id)) return null;

    // Re-check at selection time: a donor may have become unavailable,
    // suspended, or entered a cooldown after responding.
    if (donor.bloodType == null ||
        !EligibilityEngine.evaluate(
          donor,
          component: request.component,
        ).isEligible ||
        !Compatibility.canDonateComponentTo(
          donor.bloodType!,
          request.bloodType,
          request.component,
        )) {
      return null;
    }

    // One donor, one active commitment. A second requester must not be able to
    // reserve someone who is already coordinating another donation.
    if (commitmentForDonor(donor.id, excludingRequestId: request.id) != null) {
      return null;
    }

    final index = _responses.indexWhere((r) => r.id == responseId);
    _responses[index] = response.copyWith(status: ResponseStatus.selected);

    ChatThread? thread = threadBetween(requester.id, donor.id);
    if (thread == null) {
      thread = ChatThread(
        id: 'ROOM-${(_threads.length + 101).toString().padLeft(3, '0')}',
        participantAId: requester.id,
        participantAAlias: requester.alias,
        participantBId: donor.id,
        participantBAlias: donor.alias,
        participantAReadAt: DateTime.now(),
        participantBReadAt: DateTime.now(),
        messages: [
          ChatMessage(
            id: 'MSG-${DateTime.now().microsecondsSinceEpoch}',
            senderId: 'system',
            senderAlias: 'TABANG',
            text:
                'You were connected because ${requester.alias} selected '
                '${donor.alias} for request ${request.id}. Keep identities '
                'hidden until both of you agree to reveal them.',
            sentAt: DateTime.now(),
          ),
        ],
      );
      _threads.insert(0, thread);
    }

    final selectedCount = _responses
        .where(
          (r) =>
              r.requestId == request.id && r.status == ResponseStatus.selected,
        )
        .length;
    if (selectedCount >= request.unitsNeeded) {
      final reqIndex = _requests.indexWhere((r) => r.id == request.id);
      _requests[reqIndex] = request.copyWith(status: RequestStatus.matched);
      // Close the remaining offers so donors are not left waiting on a request
      // that already has enough selected donors.
      for (var i = 0; i < _responses.length; i++) {
        final other = _responses[i];
        if (other.requestId == request.id &&
            other.status == ResponseStatus.pending) {
          _responses[i] = other.copyWith(status: ResponseStatus.declined);
        }
      }
    }

    _notify();
    return thread;
  }

  /// Staff mark a request fulfilled after the donation is recorded. This is the
  /// only path that increments `unitsFulfilled`.
  bool markRequestFulfilled(String requestId, {required String actorId}) {
    final request = _firstOrNull(_requests, (r) => r.id == requestId);
    final actor = userById(actorId);
    if (request == null || actor == null) return false;
    if (actor.role != UserRole.staff && actor.role != UserRole.admin) {
      return false;
    }
    if (request.status == RequestStatus.fulfilled ||
        request.status == RequestStatus.cancelled) {
      return false;
    }
    // A donor-network request must have enough selected donors before staff can
    // close it as fulfilled. Blood-bank requests are processed directly by
    // staff, so they may be fulfilled from the open state.
    if (request.source == RequestSource.donorNetwork &&
        request.status != RequestStatus.matched) {
      return false;
    }
    final index = _requests.indexWhere((r) => r.id == requestId);
    _requests[index] = request.copyWith(
      status: RequestStatus.fulfilled,
      unitsFulfilled: request.unitsNeeded,
    );
    _notify();
    return true;
  }

  bool cancelRequest(String requestId, {required String actorId}) {
    final request = _firstOrNull(_requests, (r) => r.id == requestId);
    final actor = userById(actorId);
    if (request == null || actor == null) return false;
    final canCancel =
        actor.id == request.requesterId ||
        actor.role == UserRole.staff ||
        actor.role == UserRole.admin;
    if (!canCancel ||
        request.status == RequestStatus.fulfilled ||
        request.status == RequestStatus.cancelled) {
      return false;
    }
    final index = _requests.indexWhere((r) => r.id == requestId);
    _requests[index] = request.copyWith(status: RequestStatus.cancelled);
    _notify();
    return true;
  }

  void setUnitStatus(String barcode, UnitStatus status, {String? actorId}) {
    // When a caller identifies itself, the inventory capability is enforced.
    // Legacy call sites without an actor keep working for seeded data and
    // tests; every screen passes the acting staff/admin id.
    if (actorId != null) {
      final actor = userById(actorId);
      if (actor == null || !actor.role.canManageInventory) return;
    }
    final index = _units.indexWhere((u) => u.barcode == barcode);
    if (index == -1) return;
    final u = _units[index];
    // Never return an expired bag to available stock.
    if (status == UnitStatus.available && u.isExpiredAt(DateTime.now())) {
      return;
    }
    _units[index] = BloodUnit(
      barcode: u.barcode,
      bloodType: u.bloodType,
      component: u.component,
      storageBay: u.storageBay,
      status: status,
      collectedOn: u.collectedOn,
      expiresOn: u.expiresOn,
    );
    _notify();
  }

  /// Place a hold on a usable unit. A reservation is not a transfusion order:
  /// chapter staff still confirm release after clinical screening. Reserving an
  /// already-held unit fails so two people cannot claim the same bag.
  bool reserveUnit({
    required String barcode,
    required String userId,
    String? note,
  }) {
    final index = _units.indexWhere((u) => u.barcode == barcode);
    if (index == -1) return false;
    final unit = _units[index];
    final actor = userById(userId);
    if (actor == null || !unit.isUsable) return false;
    if (unit.effectiveStatus(DateTime.now()) != UnitStatus.available) {
      return false;
    }
    if (unit.reservedBy != null) return false;

    _units[index] = unit.copyWith(
      status: UnitStatus.reserved,
      reservedBy: userId,
      reservationNote: note == null || note.trim().isEmpty ? null : note.trim(),
      reservedAt: DateTime.now(),
    );
    _notify();
    return true;
  }

  bool cancelReservation({required String barcode, required String userId}) {
    final index = _units.indexWhere((u) => u.barcode == barcode);
    if (index == -1) return false;
    final unit = _units[index];
    final actor = userById(userId);
    if (actor == null) return false;
    final allowed = unit.reservedBy == userId || actor.role.isAdminSide;
    if (!allowed || unit.reservedBy == null) return false;
    if (unit.isExpiredAt(DateTime.now())) return false;

    _units[index] = unit.copyWith(
      status: UnitStatus.available,
      clearReservation: true,
    );
    _notify();
    return true;
  }

  /// Staff release or dispatch a held bag after screening.
  bool releaseUnit(String barcode, {required String actorId}) {
    final actor = userById(actorId);
    if (actor == null || !actor.role.isAdminSide) return false;
    if (cancelReservation(barcode: barcode, userId: actorId)) return true;
    setUnitStatus(barcode, UnitStatus.available, actorId: actorId);
    return true;
  }

  /// Staff remove a bag from the ledger entirely, for example a discarded or
  /// mislabelled unit that should no longer appear in any inventory view.
  ///
  /// The removal is recorded in [removedUnits] so the shelf change is visible
  /// and can be undone with [restoreRemovedUnit].
  bool removeBloodUnit(String barcode, {required String actorId}) {
    final actor = userById(actorId);
    if (actor == null || !actor.role.isAdminSide) return false;
    final index = _units.indexWhere((unit) => unit.barcode == barcode);
    if (index == -1) return false;
    final removed = _units.removeAt(index);
    _removedUnits.insert(
      0,
      RemovedUnitRecord(
        unit: removed,
        removedAt: DateTime.now(),
        removedById: actorId,
      ),
    );
    _logActivity(
      kind: ActivityKind.inventory,
      actorId: actorId,
      summary:
          'Removed unit ${removed.barcode} '
          '(${removed.bloodType.label} ${removed.component.label.toLowerCase()})',
    );
    _notify();
    return true;
  }

  /// Every ledger removal, newest first, including units already restored.
  List<RemovedUnitRecord> get removedUnits => List.unmodifiable(_removedUnits);

  /// Puts a removed bag back on the shelf.
  ///
  /// A restore reuses the original barcode; when a new bag already claimed it
  /// the caller can pass [newBarcode]. The restored record keeps its history
  /// entry so the audit trail still shows the removal and the restore.
  bool restoreRemovedUnit(
    String barcode, {
    required String actorId,
    String? newBarcode,
  }) {
    final actor = userById(actorId);
    if (actor == null || !actor.role.canManageInventory) return false;
    final index = _removedUnits.indexWhere(
      (record) => !record.restored && record.unit.barcode == barcode,
    );
    if (index == -1) return false;
    final record = _removedUnits[index];
    final restored = record.unit;
    final desired = (newBarcode == null || newBarcode.trim().isEmpty)
        ? restored.barcode
        : newBarcode.trim();
    if (_units.any((unit) => unit.barcode == desired)) return false;

    _units.insert(
      0,
      BloodUnit(
        barcode: desired,
        bloodType: restored.bloodType,
        component: restored.component,
        storageBay: restored.storageBay,
        status: UnitStatus.available,
        collectedOn: restored.collectedOn,
        expiresOn: restored.expiresOn,
      ),
    );
    _removedUnits[index] = record.copyWith(restored: true);
    _logActivity(
      kind: ActivityKind.inventory,
      actorId: actorId,
      summary: 'Restored unit $desired to available stock',
    );
    _notify();
    return true;
  }

  /// Component shelf lives used when a new bag is received, matching the seed
  /// data so inventory ages consistently.
  static const Map<BloodComponent, int> shelfLifeDays = {
    BloodComponent.wholeBlood: 42,
    BloodComponent.packedRbc: 42,
    BloodComponent.platelets: 5,
    BloodComponent.plasma: 365,
  };

  /// Receive a new bag into the shelf.
  ///
  /// Only chapter staff and admins may add stock. The expiry is derived from
  /// the component's shelf life so a manually-added unit can never claim an
  /// impossible date; a custom barcode is accepted when the chapter already
  /// labelled the bag.
  BloodUnit? addBloodUnit({
    required String actorId,
    required BloodType bloodType,
    required BloodComponent component,
    required String storageBay,
    DateTime? collectedOn,
    String? barcode,
  }) {
    final actor = userById(actorId);
    if (actor == null || !actor.role.canManageInventory) return null;
    final collected = collectedOn ?? DateTime.now();
    final expires = collected.add(
      Duration(days: shelfLifeDays[component] ?? 42),
    );
    final provided = barcode?.trim();
    final batch = _units.where((u) => u.component == component).length + 1;
    final code = (provided == null || provided.isEmpty)
        ? '${component.code}-${7700 + batch}-${bloodType.label}'
        : provided;
    if (_units.any((u) => u.barcode == code)) return null;

    final unit = BloodUnit(
      barcode: code,
      bloodType: bloodType,
      component: component,
      storageBay: storageBay.trim().isEmpty ? 'Unassigned' : storageBay.trim(),
      status: UnitStatus.available,
      collectedOn: collected,
      expiresOn: expires,
    );
    _units.insert(0, unit);
    markActive(actorId);
    _notify();
    return unit;
  }

  // ------------------------------------------------------------ messaging

  /// Open (or reuse) a private thread between two community accounts.
  ///
  /// Starting a conversation is the explicit step the paper requires before a
  /// recipient can choose a donor. It is safe to call repeatedly: an existing
  /// thread is returned rather than duplicated.
  ChatThread? startConversation({
    required String initiatorId,
    required String otherId,
    String? firstMessage,
  }) {
    if (initiatorId == otherId) return null;
    final initiator = userById(initiatorId);
    final other = userById(otherId);
    if (initiator == null || other == null) return null;
    if (isBlockedBetween(initiatorId, otherId)) return null;

    var thread = threadBetween(initiatorId, otherId);
    if (thread == null) {
      thread = ChatThread(
        id: 'ROOM-${(_threads.length + 101).toString().padLeft(3, '0')}',
        participantAId: initiatorId,
        participantAAlias: initiator.alias,
        participantBId: otherId,
        participantBAlias: other.alias,
        participantAReadAt: DateTime.now(),
        messages: const [],
      );
      _threads.insert(0, thread);
    }

    final trimmed = firstMessage?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      final sentAt = DateTime.now();
      final classified = classifyMessage(trimmed);
      final index = _threads.indexWhere((t) => t.id == thread!.id);
      _threads[index] = thread.copyWith(
        participantAReadAt: sentAt,
        messages: [
          ...thread.messages,
          ChatMessage(
            id: 'MSG-${DateTime.now().microsecondsSinceEpoch}',
            senderId: initiatorId,
            senderAlias: initiator.alias,
            text: trimmed,
            sentAt: sentAt,
            flag: classified.flag,
            flagReason: classified.reason,
            // A welcome opened from the chapter account is an official
            // notice, even though the staff member's account carries the id.
            sentAsChapter: initiatorId == chapterAccountId,
          ),
        ],
      );
      thread = _threads[index];
    }
    _notify();
    return thread;
  }

  /// Official chapter account that receives support messages and donor
  /// registrations. Its display identity is [chapterName], never a staff
  /// member's alias, and it is separate from every personal staff account so
  /// staff can also message each other as themselves.
  static const String chapterAccountId = 'USR-CHAPTER';

  /// Backwards-compatible alias used by older call sites.
  static const String staffAccountId = chapterAccountId;

  /// Official organization name shown on every chapter thread and profile.
  static const String chapterName =
      'Philippine Red Cross — Davao del Sur Chapter';

  /// The organization account behind [chapterAccountId]. It is resolved by
  /// [userById] without being part of the user list.
  static final AppUser chapterAccount = AppUser(
    id: chapterAccountId,
    fullName: chapterName,
    alias: chapterName,
    email: 'bloodservices@tabang.app',
    phone: '+63 82 000 0000',
    barangay: 'Zone 1',
    role: UserRole.staff,
    registeredOn: DateTime(2020, 1, 1),
    status: AccountStatus.verified,
  );
  static const String chapterSubtitle =
      'Official chapter account · Quezon Avenue, Digos City';

  bool isChapterAccount(String? userId) => userId == chapterAccountId;

  bool isChapterThread(ChatThread thread) =>
      !thread.isGroup &&
      (thread.participantAId == chapterAccountId ||
          thread.participantBId == chapterAccountId);

  /// Internal room for chapter staff and admins.
  ///
  /// Everyone posts as their own account with a Staff/Admin role; the room is
  /// never listed for community users and carries no Red Cross branding.
  static const String staffRoomId = 'STAFF-ROOM';

  ChatThread? get staffRoom =>
      _firstOrNull(_threads, (thread) => thread.id == staffRoomId);

  /// The name a chat list or header should show for [thread]. The chapter is
  /// always branded as the organization, not as the staff member's alias.
  String displayNameFor(ChatThread thread, String? selfId) {
    if (thread.isGroup) return thread.groupName ?? 'Group';
    if (isChapterThread(thread)) return chapterName;
    final otherId = thread.participantAId == selfId
        ? thread.participantBId
        : thread.participantAId;
    return userById(otherId)?.alias ??
        (otherId == thread.participantAId
            ? thread.participantAAlias
            : thread.participantBAlias);
  }

  /// Opens (or reuses) the official chapter thread for [userId]. Used when a
  /// donor registers and whenever chapter staff need to reach a community user
  /// outside a person-to-person coordination thread.
  ChatThread? ensureChapterThread(String userId, {String? welcome}) {
    if (userId == chapterAccountId) return null;
    return startConversation(
      initiatorId: chapterAccountId,
      otherId: userId,
      firstMessage: welcome,
    );
  }

  /// Posts an official chapter update into the user's chapter thread, creating
  /// the thread when it does not exist yet.
  void postChapterNotice(String userId, String text) {
    final thread = ensureChapterThread(userId);
    if (thread == null) return;
    sendMessage(thread.id, chapterAccountId, text, asChapter: true);
  }

  /// Send a system question, data correction or feedback to the chapter.
  ///
  /// Opens (or reuses) the chapter thread, posts the message with its category,
  /// and adds an acknowledgement from the chapter so the report visibly lands
  /// in a real conversation.
  ChatThread? sendStaffFeedback({
    required String userId,
    required String category,
    required String message,
  }) {
    if (userId == chapterAccountId) return null;
    final thread = startConversation(
      initiatorId: userId,
      otherId: chapterAccountId,
      firstMessage: '[$category] ${message.trim()}',
    );
    if (thread == null) return null;
    sendMessage(
      thread.id,
      chapterAccountId,
      'Thanks — your ${category.toLowerCase()} was received. Chapter staff '
      'review messages during office hours (Mon–Sat, 8:00 AM – 5:00 PM) and '
      'will reply in this thread.',
      asChapter: true,
    );
    return threadBetween(userId, chapterAccountId);
  }

  /// True when both participants have sent at least one human message. System
  /// notices do not count, so simply opening a thread is not enough.
  bool hasReciprocalChat(String a, String b) {
    final thread = threadBetween(a, b);
    if (thread == null) return false;
    final fromA = thread.messages.any(
      (m) => m.senderId == a && m.senderId != 'system',
    );
    final fromB = thread.messages.any(
      (m) => m.senderId == b && m.senderId != 'system',
    );
    return fromA && fromB;
  }

  /// Posts [text] into [threadId].
  ///
  /// [asChapter] lets a staff or admin sender post as the official chapter
  /// identity in a one-to-one thread, so they can contact a community user
  /// without exposing their personal alias. It is ignored in group rooms and
  /// in the chapter thread itself (which is always the chapter).
  void sendMessage(
    String threadId,
    String senderId,
    String text, {
    bool asChapter = false,
  }) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index == -1) return;
    final thread = _threads[index];
    if (thread.isMuted) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    if (!thread.includes(senderId)) return;

    if (!thread.isGroup) {
      final otherId = thread.participantAId == senderId
          ? thread.participantBId
          : thread.participantAId;
      if (isBlockedBetween(senderId, otherId)) return;
    }

    final sender = userById(senderId);
    final sendAsChapter =
        asChapter && !thread.isGroup && (sender?.role.isAdminSide ?? false);
    final sentAt = DateTime.now();
    final classified = classifyMessage(trimmed);
    final message = ChatMessage(
      id: 'MSG-${DateTime.now().microsecondsSinceEpoch}',
      senderId: sendAsChapter ? chapterAccountId : senderId,
      senderAlias: sendAsChapter ? chapterName : (sender?.alias ?? 'Unknown'),
      text: trimmed,
      sentAt: sentAt,
      flag: classified.flag,
      flagReason: classified.reason,
      sentAsChapter: sendAsChapter,
    );

    _threads[index] = thread.isGroup
        ? thread.copyWith(
            messages: [...thread.messages, message],
            memberReadAt: {...thread.memberReadAt, senderId: sentAt},
          )
        : thread.copyWith(
            messages: [...thread.messages, message],
            // Sending a message implies you have seen the thread up to that
            // point.
            participantAReadAt: thread.participantAId == senderId
                ? sentAt
                : thread.participantAReadAt,
            participantBReadAt: thread.participantBId == senderId
                ? sentAt
                : thread.participantBReadAt,
          );
    markActive(senderId);
    _notify();
  }

  /// Mark one conversation as read for [userId]. Called when the person opens
  /// the thread, so the navigation badge clears as soon as there is nothing
  /// new to see.
  bool markThreadRead(String threadId, String userId) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index == -1) return false;
    final thread = _threads[index];
    if (thread.readAtFor(userId) != null && !thread.hasUnreadFor(userId)) {
      return false;
    }
    final now = DateTime.now();
    _threads[index] = thread.isGroup
        ? thread.copyWith(memberReadAt: {...thread.memberReadAt, userId: now})
        : thread.copyWith(
            participantAReadAt: thread.participantAId == userId
                ? now
                : thread.participantAReadAt,
            participantBReadAt: thread.participantBId == userId
                ? now
                : thread.participantBReadAt,
          );
    _notify();
    return true;
  }

  /// Total unread messages across every conversation for [userId].
  int unreadMessageCountFor(String userId) =>
      threadsFor(userId)
          .fold<int>(0, (sum, thread) => sum + thread.unreadCountFor(userId));

  /// Number of conversations with at least one unread message.
  int unreadThreadCountFor(String userId) =>
      threadsFor(userId).where((thread) => thread.hasUnreadFor(userId)).length;

  /// Which activity kinds light the shell's "new" dot for each surface.
  ///
  /// Messages keep their own unread counters; every other tab reads the
  /// chapter activity log, which already records requests, inventory moves,
  /// verifications and moderation actions with timestamps.
  static const Map<String, Set<ActivityKind>> _tabActivityKinds = {
    'home': {
      ActivityKind.donation,
      ActivityKind.inventory,
      ActivityKind.requestVerified,
    },
    'find_donor': {ActivityKind.verification, ActivityKind.requestVerified},
    'requests': {
      ActivityKind.requestSubmitted,
      ActivityKind.requestVerified,
      ActivityKind.requestRejected,
    },
    'bloodbank': {ActivityKind.inventory},
    'donor_hub': {
      ActivityKind.application,
      ActivityKind.verification,
      ActivityKind.warning,
      ActivityKind.suspension,
      ActivityKind.donation,
      ActivityKind.donationWindow,
    },
    'overview': {ActivityKind.donation},
    'operations': {
      ActivityKind.requestSubmitted,
      ActivityKind.requestVerified,
      ActivityKind.requestRejected,
      ActivityKind.inventory,
    },
    'users': {
      ActivityKind.application,
      ActivityKind.verification,
      ActivityKind.warning,
      ActivityKind.suspension,
      ActivityKind.profile,
      ActivityKind.avatar,
    },
    'moderation': {ActivityKind.report},
  };

  /// Surfaces whose dot only counts events about [userId] rather than the
  /// whole chapter.
  static const Set<String> _personalTabs = {'donor_hub'};

  /// Highest seen event count per user and tab. Session state on purpose: a
  /// fresh login should show what happened since it last looked.
  final Map<String, Map<String, int>> _tabSeen = {};

  Iterable<ActivityEvent> _tabEvents(String userId, String tab) {
    final kinds = _tabActivityKinds[tab] ?? const <ActivityKind>{};
    return _activity.where(
      (event) =>
          kinds.contains(event.kind) &&
          (!_personalTabs.contains(tab) || event.subjectId == userId),
    );
  }

  /// Unseen activity behind the "new" dot for [tab]. Zero means nothing new.
  int tabActivityCount(String userId, String tab) {
    final seen = _tabSeen[userId]?[tab] ?? 0;
    final count = _tabEvents(userId, tab).length;
    return count <= seen ? 0 : count - seen;
  }

  /// Clears the dot for [tab] and remembers how much activity was on screen.
  void markTabSeen(String userId, String tab) {
    if (!_tabActivityKinds.containsKey(tab)) return;
    final count = _tabEvents(userId, tab).length;
    final previous = _tabSeen[userId]?[tab];
    _tabSeen.putIfAbsent(userId, () => {})[tab] = count;
    if (previous != count) _notify();
  }

  void flagMessage(String threadId, String messageId, ModerationFlag flag) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index == -1) return;
    final thread = _threads[index];
    _threads[index] = thread.copyWith(
      messages: thread.messages
          .map((m) => m.id == messageId ? m.copyWith(flag: flag) : m)
          .toList(),
    );
    _notify();
  }

  void setThreadMuted(String threadId, bool muted) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index == -1) return;
    _threads[index] = _threads[index].copyWith(isMuted: muted);
    _notify();
  }

  /// Ask the other participant to reveal real identities. This is a request,
  /// not a reveal: identities stay hidden until the other side accepts.
  bool requestIdentityReveal(String threadId, String requesterId) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index == -1) return false;
    final thread = _threads[index];
    if (thread.identityRevealed) return false;
    final isParticipant =
        thread.participantAId == requesterId ||
        thread.participantBId == requesterId;
    if (!isParticipant) return false;
    if (thread.identityRevealRequestedBy != null) return false;
    _threads[index] = thread.copyWith(identityRevealRequestedBy: requesterId);
    _notify();
    return true;
  }

  /// Accept the other participant's reveal request. Both sides have now
  /// explicitly consented, so real names and contact details may be shown.
  bool acceptIdentityReveal(String threadId, String accepterId) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index == -1) return false;
    final thread = _threads[index];
    if (thread.identityRevealed) return false;
    final isParticipant =
        thread.participantAId == accepterId ||
        thread.participantBId == accepterId;
    if (!isParticipant) return false;
    final requestedBy = thread.identityRevealRequestedBy;
    if (requestedBy == null || requestedBy == accepterId) return false;
    _threads[index] = thread.copyWith(
      identityRevealed: true,
      clearIdentityRevealRequest: true,
    );
    _notify();
    return true;
  }

  bool declineIdentityReveal(String threadId, String declinerId) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index == -1) return false;
    final thread = _threads[index];
    final requestedBy = thread.identityRevealRequestedBy;
    if (requestedBy == null || requestedBy == declinerId) return false;
    final isParticipant =
        thread.participantAId == declinerId ||
        thread.participantBId == declinerId;
    if (!isParticipant) return false;
    _threads[index] = thread.copyWith(clearIdentityRevealRequest: true);
    _notify();
    return true;
  }

  /// Persist a moderation report so it appears in the staff reports queue.
  UserReport submitReport({
    required String reporterId,
    required String reportedUserId,
    required String reason,
    String? details,
    String? threadId,
  }) {
    final reporter = userById(reporterId);
    final reported = userById(reportedUserId);
    final trimmedDetails = details?.trim();
    final report = UserReport(
      id: 'RPT-${(_reports.length + 1).toString().padLeft(3, '0')}',
      reporterId: reporterId,
      reporterAlias: reporter?.alias ?? 'Unknown',
      reportedUserId: reportedUserId,
      reportedAlias: reported?.alias ?? 'Unknown',
      reason: reason.trim(),
      details: trimmedDetails == null || trimmedDetails.isEmpty
          ? null
          : trimmedDetails,
      createdAt: DateTime.now(),
      threadId: threadId,
    );
    _reports.insert(0, report);
    _logActivity(
      kind: ActivityKind.report,
      actorId: reporterId,
      subjectId: reportedUserId,
      summary:
          '${reporter?.alias ?? 'A member'} reported '
          '${reported?.alias ?? 'an account'}: ${reason.trim()}',
    );
    _notify();
    return report;
  }

  // ------------------------------------------------------------ activity log

  /// Everything the chapter console should be able to review after the fact,
  /// newest first: recorded transfusions, donation-window corrections, donor
  /// registrations and profile or avatar changes.
  List<ActivityEvent> get activityLog => List.unmodifiable(_activity);

  List<ActivityEvent> recentActivity({int limit = 12}) =>
      _activity.take(limit).toList(growable: false);

  List<ActivityEvent> activityFor(String userId) => _activity
      .where((event) => event.subjectId == userId)
      .toList(growable: false);

  /// [actorId] falls back to the chapter account when an update is triggered
  /// by seed data or a test rather than a signed-in staff member.
  void _logActivity({
    required ActivityKind kind,
    required String actorId,
    required String summary,
    String? subjectId,
    DateTime? at,
  }) {
    final actor = userById(actorId);
    final subject = subjectId == null ? null : userById(subjectId);
    _activity.insert(
      0,
      ActivityEvent(
        id: 'ACT-${DateTime.now().microsecondsSinceEpoch}',
        kind: kind,
        actorId: actorId,
        actorAlias: actor?.alias ?? 'Chapter account',
        subjectId: subjectId,
        subjectAlias: subject?.alias,
        summary: summary,
        at: at ?? DateTime.now(),
      ),
    );
  }

  /// Records a profile edit or photo change from the profile page. The page
  /// builds the human summary; the repository keeps the audit entry.
  void logProfileActivity({
    required String userId,
    required ActivityKind kind,
    required String summary,
  }) {
    _logActivity(
      kind: kind,
      actorId: userId,
      subjectId: userId,
      summary: summary,
    );
    _notify();
  }

  bool resolveReport(String reportId, ReportStatus status) {
    final index = _reports.indexWhere((r) => r.id == reportId);
    if (index == -1) return false;
    _reports[index] = _reports[index].copyWith(status: status);
    _notify();
    return true;
  }

  bool blockUser(String blockerId, String blockedId) {
    if (blockerId == blockedId) return false;
    if (!canBlock(blockerId, blockedId)) return false;
    _blocks.add('$blockerId|$blockedId');
    _unblockedAt.remove('$blockerId|$blockedId');
    _notify();
    return true;
  }

  bool unblockUser(String blockerId, String blockedId) {
    final key = '$blockerId|$blockedId';
    if (!_blocks.remove(key)) return false;
    _unblockedAt[key] = DateTime.now();
    _notify();
    return true;
  }

  // ------------------------------------------------------------ analytics

  /// Planning targets behind the readiness score, as set by an admin.
  ReadinessTargets get readinessTargets => _readinessTargets;

  /// Replaces the readiness targets. Only an admin may change them, every
  /// value must be positive, and the change is written to the activity log so
  /// the rest of the chapter can see why the score moved.
  bool setReadinessTargets(
    ReadinessTargets targets, {
    required String actorId,
  }) {
    final actor = userById(actorId);
    if (actor == null || actor.role != UserRole.admin) return false;
    if (!targets.isValid) return false;
    final previous = _readinessTargets;
    if (previous.unitTarget == targets.unitTarget &&
        previous.donorTarget == targets.donorTarget &&
        previous.requestPressureCap == targets.requestPressureCap &&
        previous.communityTarget == targets.communityTarget) {
      return true;
    }
    _readinessTargets = targets;
    _logActivity(
      kind: ActivityKind.readinessTargets,
      actorId: actorId,
      summary:
          'Updated readiness targets: ${targets.describe()} '
          '(was ${previous.describe()})',
    );
    _notify();
    return true;
  }

  /// Restores the shipped planning targets. Admin only, same as setting them.
  bool resetReadinessTargets({required String actorId}) {
    final actor = userById(actorId);
    if (actor == null || actor.role != UserRole.admin) return false;
    if (_readinessTargets == ReadinessTargets.defaults) return true;
    _readinessTargets = ReadinessTargets.defaults;
    _logActivity(
      kind: ActivityKind.readinessTargets,
      actorId: actorId,
      summary:
          'Reset readiness targets to the chapter defaults: '
          '${ReadinessTargets.defaults.describe()}',
    );
    _notify();
    return true;
  }

  /// Computed from the live seed data rather than hardcoded literals, so the
  /// numbers on the admin overview always agree with the tables below them.
  AnalyticsSummary summary({DateTime? now}) {
    final today = now ?? DateTime.now();
    final monthStart = DateTime(today.year, today.month, 1);

    final donationsToday = _users
        .where(
          (u) =>
              u.lastDonationDate != null &&
              _sameDay(u.lastDonationDate!, today),
        )
        .length;

    final donationsThisMonth = _users
        .where(
          (u) =>
              u.lastDonationDate != null &&
              !u.lastDonationDate!.isBefore(monthStart),
        )
        .length;

    final barangayCounts = donorCountsByBarangay();
    final topBarangay = barangayCounts.isEmpty
        ? '—'
        : barangayCounts.entries
              .reduce((a, b) => a.value >= b.value ? a : b)
              .key;

    return AnalyticsSummary(
      donationsToday: donationsToday,
      donationsThisMonth: donationsThisMonth,
      registeredUsers: _users.length,
      activeDonors: eligibleDonors.length,
      activeDrives: _drives.where((d) => d.status != 'Completed').length,
      topBarangay: topBarangay,
      unitsAvailable: availableUnits.length,
      openRequests: openRequests.length,
    );
  }

  List<BloodTypeStat> bloodTypeStats() {
    return BloodType.values
        .map((type) {
          final donated = _users
              .where((u) => u.bloodType == type)
              .fold<int>(0, (sum, u) => sum + u.totalDonations);
          final requested = _requests
              .where(
                (r) =>
                    r.bloodType == type && r.status != RequestStatus.cancelled,
              )
              .fold<int>(0, (sum, r) => sum + r.unitsNeeded);
          return BloodTypeStat(
            bloodType: type,
            donated: donated,
            requested: requested,
          );
        })
        .toList(growable: false);
  }

  List<BarangayStat> barangayStats() {
    final stats = <BarangayStat>[];
    for (final barangay in DigosBarangays.all) {
      final donorsHere = donors.where((u) => u.barangay == barangay).toList();
      if (donorsHere.isEmpty) continue;
      stats.add(
        BarangayStat(
          barangay: barangay,
          donationCount: donorsHere.fold<int>(
            0,
            (s, u) => s + u.totalDonations,
          ),
          donorCount: donorsHere.length,
        ),
      );
    }
    stats.sort((a, b) => b.donationCount.compareTo(a.donationCount));
    return stats;
  }

  /// Usable units expiring within [days] days, soonest first. Expired bags are
  /// excluded: they belong in the expired filter, not the expiry-pressure list.
  List<BloodUnit> expiringSoon({int days = 7, DateTime? now}) {
    final today = now ?? DateTime.now();
    final list =
        _units
            .where(
              (u) =>
                  u.isUsableAt(today) &&
                  u.daysUntilExpiry(today) >= 0 &&
                  u.daysUntilExpiry(today) <= days,
            )
            .toList()
          ..sort((a, b) => a.expiresOn.compareTo(b.expiresOn));
    return list;
  }

  /// Blood types with no usable units in any component. Used by the landing
  /// page's urgent-shortage banner.
  List<BloodType> get criticalShortageTypes => BloodType.values
      .where((type) => unitsOfType(type) == 0)
      .toList(growable: false);

  // ------------------------------------------------------------- internals

  /// Reset the simulated store to its seed state. Intended for tests so one
  /// lifecycle test cannot leak responses or reports into the next.
  void resetForTesting() {
    _users.clear();
    _units.clear();
    _requests.clear();
    _responses.clear();
    _threads.clear();
    _reports.clear();
    _activity.clear();
    _drives.clear();
    _content.clear();
    _removedUnits.clear();
    _blocks.clear();
    _unblockedAt.clear();
    // These two were the leak that let an earlier test's donor application or
    // drive interest survive into the next test.
    _donorApplications.clear();
    _driveInterests.clear();
    _readinessTargets = ReadinessTargets.defaults;
    _tabSeen.clear();
    currentUser = null;
    _seed();
    _notify();
  }

  static T? _firstOrNull<T>(Iterable<T> items, bool Function(T) test) {
    for (final item in items) {
      if (test(item)) return item;
    }
    return null;
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// A date [days] from [from], set to a specific wall-clock [hour].
  ///
  /// Drive times must land on round hours (8:00 AM), not "now plus 8 hours",
  /// which produced 5:52 PM start times when seeded in the afternoon.
  static DateTime _atHour(DateTime from, int days, int hour) {
    final base = from.add(Duration(days: days));
    return DateTime(base.year, base.month, base.day, hour);
  }

  /// Keyword classifier standing in for the moderation service.
  ///
  /// The lists are public so the Moderation console can show exactly what it
  /// detects, and so staff can add or remove phrases without a code change.
  static final Map<ModerationFlag, List<String>> moderationKeywords = {
    ModerationFlag.spam: [
      'http://',
      'https://',
      'buy now',
      'click this link',
      'free money',
    ],
    ModerationFlag.inappropriate: [
      'pay me',
      'cash upfront',
      'php upfront',
      'bribe',
      'payment first',
    ],
  };

  /// Returns the flag and the phrase that triggered it, or a clean result with
  /// no reason.
  static ({ModerationFlag flag, String? reason}) classifyMessage(String text) {
    final lower = text.toLowerCase();
    for (final entry in moderationKeywords.entries) {
      for (final marker in entry.value) {
        if (lower.contains(marker)) {
          return (flag: entry.key, reason: marker);
        }
      }
    }
    return (flag: ModerationFlag.clean, reason: null);
  }

  void addModerationKeyword(ModerationFlag flag, String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final list = moderationKeywords[flag];
    if (list == null || list.contains(trimmed.toLowerCase())) return;
    list.add(trimmed.toLowerCase());
    _notify();
  }

  void removeModerationKeyword(ModerationFlag flag, String keyword) {
    moderationKeywords[flag]?.remove(keyword);
    _notify();
  }

  void _seed() {
    final now = DateTime.now();
    DateTime daysAgo(int d) => now.subtract(Duration(days: d));

    // ---- users ---------------------------------------------------------
    _users.addAll([
      AppUser(
        id: 'USR-001',
        fullName: 'Juan Dela Cruz',
        alias: 'JuanDC',
        email: 'juan.delacruz@tabang.app',
        phone: '+63 912 345 6789',
        barangay: 'Zone 1',
        role: UserRole.donor,
        bloodType: BloodType.oPos,
        birthDate: DateTime(2004, 3, 12),
        weightKg: 68,
        registeredOn: daysAgo(420),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(140),
        totalDonations: 4,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-002',
        fullName: 'Maria Teresa Santos',
        alias: 'Tere',
        email: 'tere.santos@tabang.app',
        phone: '+63 917 220 4411',
        barangay: 'Kapatagan',
        role: UserRole.donor,
        bloodType: BloodType.aPos,
        birthDate: DateTime(1996, 7, 4),
        weightKg: 55,
        registeredOn: daysAgo(310),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(30),
        totalDonations: 9,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-003',
        fullName: 'Rogelio Bautista',
        alias: 'Rogel',
        email: 'rogelio.bautista@tabang.app',
        phone: '+63 918 553 9021',
        barangay: 'Matti',
        role: UserRole.donor,
        bloodType: BloodType.bNeg,
        birthDate: DateTime(1991, 11, 22),
        weightKg: 72,
        registeredOn: daysAgo(260),
        status: AccountStatus.warned,
        warningCount: 2,
        lastDonationDate: daysAgo(200),
        totalDonations: 3,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-004',
        fullName: 'Ricardo Dalisay',
        alias: 'Cardo',
        email: 'cardo.dalisay@tabang.app',
        phone: '+63 915 887 3344',
        barangay: 'Tres De Mayo',
        role: UserRole.donor,
        bloodType: BloodType.oNeg,
        birthDate: DateTime(1988, 2, 9),
        weightKg: 80,
        registeredOn: daysAgo(500),
        status: AccountStatus.suspended,
        warningCount: 3,
        suspensionReason: 'Multiple no-shows for urgent blood donations.',
        lastDonationDate: daysAgo(95),
        totalDonations: 6,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-005',
        fullName: 'Angelica Ramos',
        alias: 'Angel',
        email: 'angelica.ramos@tabang.app',
        phone: '+63 920 441 7788',
        barangay: 'Cogon',
        role: UserRole.donor,
        bloodType: BloodType.abPos,
        birthDate: DateTime(1999, 5, 30),
        weightKg: 58,
        registeredOn: daysAgo(180),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(70),
        totalDonations: 5,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-006',
        fullName: 'Noel Villanueva',
        alias: 'Noel',
        email: 'noel.villanueva@tabang.app',
        phone: '+63 906 223 1199',
        // Seeded so the map shows a real heat spread: Zone 1, Matti and
        // Zone 3 carry several donors while the outer barangays stay low.
        barangay: 'Zone 1',
        role: UserRole.donor,
        bloodType: BloodType.aNeg,
        birthDate: DateTime(1993, 9, 14),
        weightKg: 65,
        registeredOn: daysAgo(150),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(10),
        totalDonations: 2,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-007',
        fullName: 'Bea Lagrimas',
        alias: 'Bea',
        email: 'bea.lagrimas@tabang.app',
        phone: '+63 927 118 2200',
        barangay: 'Zone 3',
        role: UserRole.donor,
        bloodType: BloodType.bPos,
        birthDate: DateTime(2001, 1, 8),
        weightKg: 54,
        registeredOn: daysAgo(95),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(120),
        totalDonations: 3,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-008',
        fullName: 'Karl Mendoza',
        alias: 'Karl',
        email: 'karl.mendoza@tabang.app',
        phone: '+63 939 664 5512',
        barangay: 'Igpit',
        role: UserRole.donor,
        bloodType: BloodType.oPos,
        birthDate: DateTime(1997, 6, 19),
        weightKg: 70,
        registeredOn: daysAgo(60),
        status: AccountStatus.unverified,
        lastDonationDate: null,
        totalDonations: 0,
      ),
      AppUser(
        id: 'USR-012',
        fullName: 'Liza Mae Ocampo',
        alias: 'Liza',
        email: 'liza.ocampo@tabang.app',
        phone: '+63 908 442 7711',
        barangay: 'Matti',
        role: UserRole.donor,
        bloodType: BloodType.oNeg,
        birthDate: DateTime(1995, 8, 17),
        weightKg: 60,
        registeredOn: daysAgo(220),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(110),
        totalDonations: 2,
        bloodCardVerified: true,
      ),

      // ---- additional available donors ---------------------------------
      // The directory needs enough depth to demonstrate matching across every
      // blood type. These donors are eligible today; the cooldown, suspended
      // and unverified fixtures above are kept deliberately so blocker states
      // remain testable.
      AppUser(
        id: 'USR-013',
        fullName: 'Paolo Reyes',
        alias: 'Paolo',
        email: 'paolo.reyes@tabang.app',
        phone: '+63 917 481 2201',
        barangay: 'Zone 3',
        role: UserRole.donor,
        bloodType: BloodType.oPos,
        birthDate: DateTime(1998, 4, 16),
        weightKg: 74,
        registeredOn: daysAgo(340),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(100),
        totalDonations: 6,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-014',
        fullName: 'Shamira Ampatuan',
        alias: 'Mira',
        email: 'shamira.ampatuan@tabang.app',
        phone: '+63 918 220 4477',
        barangay: 'San Jose',
        role: UserRole.donor,
        bloodType: BloodType.aPos,
        birthDate: DateTime(1995, 12, 2),
        weightKg: 58,
        registeredOn: daysAgo(290),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(150),
        totalDonations: 7,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-015',
        fullName: 'Dominic Fuentes',
        alias: 'Dom',
        email: 'dominic.fuentes@tabang.app',
        phone: '+63 927 553 1180',
        barangay: 'Aplaya',
        role: UserRole.donor,
        bloodType: BloodType.bPos,
        birthDate: DateTime(1993, 6, 27),
        weightKg: 81,
        registeredOn: daysAgo(210),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(96),
        totalDonations: 4,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-016',
        fullName: 'Grace Villamor',
        alias: 'Grace',
        email: 'grace.villamor@tabang.app',
        phone: '+63 906 781 9922',
        barangay: 'Kiagot',
        role: UserRole.donor,
        bloodType: BloodType.abPos,
        birthDate: DateTime(1997, 9, 8),
        weightKg: 56,
        registeredOn: daysAgo(260),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(170),
        totalDonations: 3,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-017',
        fullName: 'Arnel Bautista',
        alias: 'Arnel',
        email: 'arnel.bautista@tabang.app',
        phone: '+63 915 330 6614',
        barangay: 'Binaton',
        role: UserRole.donor,
        bloodType: BloodType.oNeg,
        birthDate: DateTime(1990, 2, 21),
        weightKg: 77,
        registeredOn: daysAgo(380),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(120),
        totalDonations: 11,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-018',
        fullName: 'Fatima Macabangon',
        alias: 'Fati',
        email: 'fatima.macabangon@tabang.app',
        phone: '+63 920 118 7744',
        barangay: 'Colorado',
        role: UserRole.donor,
        bloodType: BloodType.aNeg,
        birthDate: DateTime(1994, 8, 30),
        weightKg: 61,
        registeredOn: daysAgo(190),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(130),
        totalDonations: 5,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-019',
        fullName: 'Jessa Mae Tupas',
        alias: 'Jessa',
        email: 'jessa.tupas@tabang.app',
        phone: '+63 939 224 8801',
        barangay: 'Matti',
        role: UserRole.donor,
        bloodType: BloodType.bNeg,
        birthDate: DateTime(2000, 3, 5),
        weightKg: 53,
        registeredOn: daysAgo(160),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(140),
        totalDonations: 2,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-020',
        fullName: 'Mark Anthony Salazar',
        alias: 'Mark',
        email: 'mark.salazar@tabang.app',
        phone: '+63 917 662 3318',
        barangay: 'Cogon',
        role: UserRole.donor,
        bloodType: BloodType.abNeg,
        birthDate: DateTime(1987, 10, 12),
        weightKg: 84,
        registeredOn: daysAgo(450),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(160),
        totalDonations: 14,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-021',
        fullName: 'Amando Lumibao',
        alias: 'Amando',
        email: 'amando.lumibao@tabang.app',
        phone: '+63 908 991 2277',
        barangay: 'Mahayahay',
        role: UserRole.donor,
        bloodType: BloodType.oPos,
        birthDate: DateTime(1985, 5, 18),
        weightKg: 79,
        registeredOn: daysAgo(520),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(200),
        totalDonations: 18,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-022',
        fullName: 'Rina Mae Lanticse',
        alias: 'Rina',
        email: 'rina.lanticse@tabang.app',
        phone: '+63 927 447 5533',
        barangay: 'Soong',
        role: UserRole.donor,
        bloodType: BloodType.aPos,
        birthDate: DateTime(1999, 11, 23),
        weightKg: 57,
        registeredOn: daysAgo(130),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(95),
        totalDonations: 3,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-023',
        fullName: 'Kevin Paul Abellera',
        alias: 'Kevin',
        email: 'kevin.abellera@tabang.app',
        phone: '+63 918 880 4420',
        barangay: 'Zone 2',
        role: UserRole.donor,
        bloodType: BloodType.bPos,
        birthDate: DateTime(1996, 7, 14),
        weightKg: 72,
        registeredOn: daysAgo(240),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(110),
        totalDonations: 6,
        bloodCardVerified: true,
      ),
      AppUser(
        id: 'USR-009',
        fullName: 'Maria Santos',
        alias: 'Recipient 209',
        email: 'maria.santos@tabang.app',
        phone: '+63 917 000 1122',
        barangay: 'Zone 2',
        role: UserRole.recipient,
        registeredOn: daysAgo(40),
        status: AccountStatus.verified,
      ),

      // ---- additional recipients ---------------------------------------
      // Recipients are community members representing a patient. They have no
      // donor weight/cooldown fields, but a recorded blood type helps prefill
      // request forms and keeps the directory realistic.
      AppUser(
        id: 'USR-024',
        fullName: 'Ana Liza Dizon',
        alias: 'Ana',
        email: 'ana.dizon@tabang.app',
        phone: '+63 917 230 1144',
        barangay: 'Zone 3',
        role: UserRole.recipient,
        bloodType: BloodType.aPos,
        birthDate: DateTime(1982, 6, 11),
        registeredOn: daysAgo(75),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-025',
        fullName: 'Rodel Cabrera',
        alias: 'Rodel',
        email: 'rodel.cabrera@tabang.app',
        phone: '+63 918 552 0091',
        barangay: 'Matti',
        role: UserRole.recipient,
        bloodType: BloodType.bPos,
        birthDate: DateTime(1979, 1, 27),
        registeredOn: daysAgo(64),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-026',
        fullName: 'Celeste Padilla',
        alias: 'Celeste',
        email: 'celeste.padilla@tabang.app',
        phone: '+63 927 771 3320',
        barangay: 'San Jose',
        role: UserRole.recipient,
        bloodType: BloodType.oPos,
        birthDate: DateTime(2001, 9, 3),
        registeredOn: daysAgo(52),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-027',
        fullName: 'Nathaniel Lim',
        alias: 'Nate',
        email: 'nathaniel.lim@tabang.app',
        phone: '+63 906 331 8845',
        barangay: 'Zone 1',
        role: UserRole.recipient,
        bloodType: BloodType.abPos,
        birthDate: DateTime(1990, 4, 19),
        registeredOn: daysAgo(48),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-028',
        fullName: 'Rowena Tiu',
        alias: 'Wena',
        email: 'rowena.tiu@tabang.app',
        phone: '+63 915 664 2201',
        barangay: 'Aplaya',
        role: UserRole.recipient,
        bloodType: BloodType.aNeg,
        birthDate: DateTime(1988, 12, 8),
        registeredOn: daysAgo(41),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-029',
        fullName: 'Benjie Alcantara',
        alias: 'Benjie',
        email: 'benjie.alcantara@tabang.app',
        phone: '+63 920 887 4452',
        barangay: 'Kapatagan',
        role: UserRole.recipient,
        bloodType: BloodType.oNeg,
        birthDate: DateTime(1974, 7, 22),
        registeredOn: daysAgo(37),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-030',
        fullName: 'Marilou Espino',
        alias: 'Lulu',
        email: 'marilou.espino@tabang.app',
        phone: '+63 939 112 7790',
        barangay: 'Cogon',
        role: UserRole.recipient,
        bloodType: BloodType.bNeg,
        birthDate: DateTime(1969, 2, 14),
        registeredOn: daysAgo(31),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-031',
        fullName: 'Cyrus Villareal',
        alias: 'Cyrus',
        email: 'cyrus.villareal@tabang.app',
        phone: '+63 917 559 6603',
        barangay: 'Dawis',
        role: UserRole.recipient,
        bloodType: BloodType.abNeg,
        birthDate: DateTime(1993, 8, 26),
        registeredOn: daysAgo(29),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-032',
        fullName: 'Edna Mae Rosales',
        alias: 'Edna',
        email: 'edna.rosales@tabang.app',
        phone: '+63 908 772 1188',
        barangay: 'Igpit',
        role: UserRole.recipient,
        bloodType: BloodType.oPos,
        birthDate: DateTime(1965, 10, 5),
        registeredOn: daysAgo(24),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-033',
        fullName: 'Francis Solano',
        alias: 'Francis',
        email: 'francis.solano@tabang.app',
        phone: '+63 927 330 5528',
        barangay: 'Kiagot',
        role: UserRole.recipient,
        bloodType: BloodType.aPos,
        birthDate: DateTime(1986, 5, 30),
        registeredOn: daysAgo(19),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-034',
        fullName: 'Honey Grace Bacalso',
        alias: 'Honey',
        email: 'honey.bacalso@tabang.app',
        phone: '+63 918 441 9902',
        barangay: 'Balabag',
        role: UserRole.recipient,
        bloodType: BloodType.bPos,
        birthDate: DateTime(1998, 3, 17),
        registeredOn: daysAgo(15),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-035',
        fullName: 'Isko Salvador',
        alias: 'Isko',
        email: 'isko.salvador@tabang.app',
        phone: '+63 906 990 3317',
        barangay: 'Sinawilan',
        role: UserRole.recipient,
        bloodType: BloodType.oPos,
        birthDate: DateTime(1971, 11, 9),
        registeredOn: daysAgo(11),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-036',
        fullName: 'Jasmine Kwan',
        alias: 'Jas',
        email: 'jasmine.kwan@tabang.app',
        phone: '+63 915 220 7734',
        barangay: 'Soong',
        role: UserRole.recipient,
        bloodType: BloodType.abPos,
        birthDate: DateTime(2003, 1, 31),
        registeredOn: daysAgo(7),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-037',
        fullName: 'Lorenzo Basco',
        alias: 'Enzo',
        email: 'lorenzo.basco@tabang.app',
        phone: '+63 920 664 1109',
        barangay: 'San Miguel',
        role: UserRole.recipient,
        bloodType: BloodType.aNeg,
        birthDate: DateTime(1983, 6, 6),
        registeredOn: daysAgo(3),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-010',
        fullName: 'Marco Villanueva',
        alias: 'Staff Marco',
        email: 'marco.villanueva@tabang.app',
        phone: '+63 918 777 6655',
        barangay: 'Zone 1',
        role: UserRole.staff,
        registeredOn: daysAgo(600),
        status: AccountStatus.verified,
      ),
      AppUser(
        id: 'USR-011',
        fullName: 'System Administrator',
        alias: 'Admin',
        email: 'admin@tabang.app',
        phone: '+63 900 000 0000',
        barangay: 'Zone 1',
        role: UserRole.admin,
        registeredOn: daysAgo(600),
        status: AccountStatus.verified,
      ),

      // Default community account: can request blood, browse the directory and
      // later choose "Register as a donor" without switching accounts.
      AppUser(
        id: 'USR-038',
        fullName: 'Kairos Villanueva',
        alias: 'Kai',
        email: 'community@tabang.app',
        phone: '+63 917 555 0101',
        barangay: 'Zone 2',
        role: UserRole.user,
        bloodType: BloodType.oPos,
        birthDate: DateTime(2000, 5, 21),
        registeredOn: daysAgo(9),
        status: AccountStatus.verified,
      ),

      // Two donors who have been away for over a month. Their switch is still
      // on, but the eligibility engine hides them from the directory until
      // their next activity — the automatic counterpart to the manual
      // "Directory availability" toggle.
      AppUser(
        id: 'USR-039',
        fullName: 'Rafael Mendoza',
        alias: 'Rafael',
        email: 'rafael.mendoza@tabang.app',
        phone: '+63 917 202 4455',
        barangay: 'Matti',
        role: UserRole.donor,
        bloodType: BloodType.oPos,
        birthDate: DateTime(1996, 4, 12),
        weightKg: 68,
        registeredOn: daysAgo(320),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(121),
        totalDonations: 3,
        lastActiveAt: daysAgo(47),
      ),
      AppUser(
        id: 'USR-040',
        fullName: 'Joanna Lim',
        alias: 'Joanna',
        email: 'joanna.lim@tabang.app',
        phone: '+63 918 341 2277',
        barangay: 'Colorado',
        role: UserRole.donor,
        bloodType: BloodType.aPos,
        birthDate: DateTime(1993, 11, 2),
        weightKg: 57,
        registeredOn: daysAgo(260),
        status: AccountStatus.verified,
        lastDonationDate: daysAgo(96),
        totalDonations: 2,
        lastActiveAt: daysAgo(38),
      ),
    ]);

    // Every seeded profile gets its own bundled illustration. The generator in
    // tools/make_avatars.py produces one distinct portrait per account, so no
    // image is reused across donors, recipients, staff or the demo community
    // user.
    const avatarCount = 48;
    for (var i = 0; i < _users.length; i++) {
      final asset =
          'assets/images/avatars/avatar_${(i % avatarCount + 1).toString().padLeft(3, '0')}.png';
      _users[i] = _users[i].copyWith(
        onboardingCompleted: true,
        photoAsset: asset,
        // Seeded accounts are active by default; the two deliberately-away
        // donors keep their explicit older date. Real sign-ins refresh this.
        lastActiveAt: _users[i].lastActiveAt ?? daysAgo(1 + (i % 7)),
      );
    }

    // ---- inventory -----------------------------------------------------
    // Shelf lives follow standard component storage: RBC 42 days, platelets
    // 5 days, plasma 365 days frozen.
    void addUnit(
      String barcode,
      BloodType type,
      BloodComponent component,
      String bay,
      int collectedDaysAgo,
      int shelfLifeDays, {
      UnitStatus status = UnitStatus.available,
    }) {
      final collected = daysAgo(collectedDaysAgo);
      _units.add(
        BloodUnit(
          barcode: barcode,
          bloodType: type,
          component: component,
          storageBay: bay,
          status: status,
          collectedOn: collected,
          expiresOn: collected.add(Duration(days: shelfLifeDays)),
        ),
      );
    }

    addUnit(
      'RBC-8849-O-',
      BloodType.oNeg,
      BloodComponent.packedRbc,
      'Cold room R-02 (4 °C)',
      40,
      42,
    );
    addUnit(
      'RBC-8850-O-',
      BloodType.oNeg,
      BloodComponent.packedRbc,
      'Cold room R-02 (4 °C)',
      39,
      42,
    );
    addUnit(
      'RBC-6612-O+',
      BloodType.oPos,
      BloodComponent.packedRbc,
      'Cold room R-01 (4 °C)',
      20,
      42,
    );
    addUnit(
      'RBC-3391-B-',
      BloodType.bNeg,
      BloodComponent.packedRbc,
      'Cold room R-02 (4 °C)',
      14,
      42,
    );
    addUnit(
      'RBC-9014-AB-',
      BloodType.abNeg,
      BloodComponent.packedRbc,
      'Bay 03 (4 °C)',
      28,
      42,
      status: UnitStatus.reserved,
    );
    addUnit(
      'PLT-4019-A+',
      BloodType.aPos,
      BloodComponent.platelets,
      'Agitator A-01 (22 °C)',
      3,
      5,
    );
    addUnit(
      'PLT-4020-O+',
      BloodType.oPos,
      BloodComponent.platelets,
      'Agitator A-01 (22 °C)',
      2,
      5,
    );
    addUnit(
      'FFP-7712-B+',
      BloodType.bPos,
      BloodComponent.plasma,
      'Freezer F-03 (-30 °C)',
      185,
      365,
    );
    addUnit(
      'FFP-9912-AB+',
      BloodType.abPos,
      BloodComponent.plasma,
      'Freezer F-01 (-30 °C)',
      205,
      365,
    );
    addUnit(
      'WB-1092-A-',
      BloodType.aNeg,
      BloodComponent.wholeBlood,
      'Cold room R-03 (4 °C)',
      38,
      42,
      status: UnitStatus.quarantined,
    );
    addUnit(
      'WB-1093-A+',
      BloodType.aPos,
      BloodComponent.wholeBlood,
      'Cold room R-03 (4 °C)',
      12,
      42,
    );
    addUnit(
      'RBC-7723-B+',
      BloodType.bPos,
      BloodComponent.packedRbc,
      'Cold room R-01 (4 °C)',
      8,
      42,
    );
    // Kept in the record with its stored status still `available` to exercise
    // effective-status expiry handling; it is never counted as usable.
    addUnit(
      'RBC-7700-O+',
      BloodType.oPos,
      BloodComponent.packedRbc,
      'Cold room R-01 (4 °C)',
      45,
      42,
    );

    // ---- requests ------------------------------------------------------
    _requests.addAll([
      BloodRequest(
        id: 'REQ-001',
        requesterId: 'USR-009',
        patientAlias: 'Patient 209',
        bloodType: BloodType.oNeg,
        component: BloodComponent.packedRbc,
        unitsNeeded: 3,
        hospital: 'Digos Provincial Hospital',
        barangay: 'Zone 2',
        urgency: RequestUrgency.critical,
        createdAt: now.subtract(const Duration(hours: 5)),
        status: RequestStatus.open,
        source: RequestSource.donorNetwork,
        note: 'Postpartum hemorrhage, OR scheduled tonight.',
      ),
      BloodRequest(
        id: 'REQ-002',
        requesterId: 'USR-009',
        patientAlias: 'Patient 214',
        bloodType: BloodType.aPos,
        component: BloodComponent.platelets,
        unitsNeeded: 2,
        hospital: 'Digos Doctors Hospital',
        barangay: 'Zone 3',
        urgency: RequestUrgency.urgent,
        createdAt: now.subtract(const Duration(days: 1, hours: 3)),
        status: RequestStatus.open,
        source: RequestSource.bloodBank,
      ),
      BloodRequest(
        id: 'REQ-003',
        requesterId: 'USR-009',
        patientAlias: 'Patient 118',
        bloodType: BloodType.bPos,
        component: BloodComponent.wholeBlood,
        unitsNeeded: 1,
        hospital: 'Digos Doctors Hospital',
        barangay: 'Zone 1',
        urgency: RequestUrgency.routine,
        createdAt: now.subtract(const Duration(days: 3)),
        status: RequestStatus.open,
        source: RequestSource.donorNetwork,
      ),
      BloodRequest(
        id: 'REQ-004',
        requesterId: 'USR-024',
        patientAlias: 'Patient 312',
        bloodType: BloodType.aPos,
        component: BloodComponent.plasma,
        unitsNeeded: 2,
        hospital: 'Digos Doctors Hospital',
        barangay: 'Zone 3',
        urgency: RequestUrgency.routine,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      BloodRequest(
        id: 'REQ-005',
        requesterId: 'USR-025',
        patientAlias: 'Patient 041',
        bloodType: BloodType.bPos,
        component: BloodComponent.wholeBlood,
        unitsNeeded: 2,
        hospital: 'Digos Provincial Hospital',
        barangay: 'Matti',
        urgency: RequestUrgency.urgent,
        createdAt: now.subtract(const Duration(days: 1, hours: 8)),
        status: RequestStatus.open,
        source: RequestSource.donorNetwork,
        note:
            'Dialysis patient, two units requested by the attending physician.',
      ),
      BloodRequest(
        id: 'REQ-006',
        requesterId: 'USR-026',
        patientAlias: 'Patient 177',
        bloodType: BloodType.oPos,
        component: BloodComponent.platelets,
        unitsNeeded: 1,
        hospital: 'Digos Doctors Hospital',
        barangay: 'San Jose',
        urgency: RequestUrgency.routine,
        createdAt: now.subtract(const Duration(hours: 20)),
        status: RequestStatus.open,
        source: RequestSource.bloodBank,
      ),
      BloodRequest(
        id: 'REQ-007',
        requesterId: 'USR-029',
        patientAlias: 'Patient 205',
        bloodType: BloodType.oNeg,
        component: BloodComponent.packedRbc,
        unitsNeeded: 4,
        hospital: 'Digos Provincial Hospital',
        barangay: 'Kapatagan',
        urgency: RequestUrgency.critical,
        createdAt: now.subtract(const Duration(hours: 16)),
        status: RequestStatus.open,
        source: RequestSource.donorNetwork,
        note: 'Trauma case in the emergency room; universal donor needed.',
      ),
      BloodRequest(
        id: 'REQ-008',
        requesterId: 'USR-033',
        patientAlias: 'Patient 390',
        bloodType: BloodType.aPos,
        component: BloodComponent.packedRbc,
        unitsNeeded: 1,
        hospital: 'Digos Doctors Hospital',
        barangay: 'Kiagot',
        urgency: RequestUrgency.urgent,
        createdAt: now.subtract(const Duration(hours: 11)),
        status: RequestStatus.open,
        source: RequestSource.donorNetwork,
      ),
      BloodRequest(
        id: 'REQ-009',
        requesterId: 'USR-037',
        patientAlias: 'Patient 088',
        bloodType: BloodType.aNeg,
        component: BloodComponent.wholeBlood,
        unitsNeeded: 2,
        hospital: 'Digos Provincial Hospital',
        barangay: 'San Miguel',
        urgency: RequestUrgency.urgent,
        createdAt: now.subtract(const Duration(hours: 7)),
        status: RequestStatus.open,
        source: RequestSource.donorNetwork,
      ),
      BloodRequest(
        id: 'REQ-010',
        requesterId: 'USR-031',
        patientAlias: 'Patient 143',
        bloodType: BloodType.abNeg,
        component: BloodComponent.plasma,
        unitsNeeded: 1,
        hospital: 'Digos Doctors Hospital',
        barangay: 'Dawis',
        urgency: RequestUrgency.routine,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
      // One example still waiting for chapter verification, so staff can see
      // the review queue on first sign-in.
      BloodRequest(
        id: 'REQ-011',
        requesterId: 'USR-038',
        patientAlias: 'Patient 055',
        bloodType: BloodType.oPos,
        component: BloodComponent.wholeBlood,
        unitsNeeded: 1,
        hospital: 'Digos Doctors Hospital',
        barangay: 'Zone 2',
        urgency: RequestUrgency.routine,
        createdAt: now.subtract(const Duration(hours: 4)),
        documents: const [
          RequestDocument(
            kind: RequestDocuments.doctorsForm,
            fileName: 'patient-055-doctor-request.pdf',
          ),
          RequestDocument(
            kind: RequestDocuments.transfusionSlip,
            fileName: 'patient-055-transfusion-slip.pdf',
          ),
          RequestDocument(
            kind: RequestDocuments.patientId,
            fileName: 'patient-055-hospital-id.jpg',
          ),
        ],
        scheduledFor: bloodBankSlots(days: 3).first,
        status: RequestStatus.pendingReview,
      ),
    ]);

    // Every seeded request carries documents on file and a booked slot so the
    // verification sheet, the staff queue and the community list all start
    // populated: already-verified donor-network requests are open, blood-bank
    // requests are open for chapter processing, and a few stay pendingReview
    // for the verification queue. Seed documents have no payload, meaning
    // "already on file with the chapter"; uploads made in the app do carry the
    // file bytes. Documents attached to a request (REQ-011) are kept as-is.
    const seededDocuments = <RequestDocument>[
      RequestDocument(
        kind: RequestDocuments.doctorsForm,
        fileName: 'doctor-request-form.pdf',
      ),
      RequestDocument(
        kind: RequestDocuments.transfusionSlip,
        fileName: 'blood-transfusion-slip.pdf',
      ),
      RequestDocument(
        kind: RequestDocuments.patientId,
        fileName: 'hospital-patient-id.jpg',
      ),
    ];
    final seededSlots = bloodBankSlots(days: 14);
    for (var i = 0; i < _requests.length; i++) {
      final request = _requests[i];
      _requests[i] = request.copyWith(
        documents: request.documents.isEmpty ? seededDocuments : null,
        // Stagger the demo slots instead of parking every request on the
        // same hour.
        scheduledFor:
            request.scheduledFor ?? seededSlots[i % seededSlots.length],
      );
    }

    // A pending response demonstrates the selection step without marking the
    // request matched or counting an unperformed donation.
    _responses.addAll([
      RequestResponse(
        id: 'RES-001',
        requestId: 'REQ-001',
        donorId: 'USR-012',
        donorAlias: 'Liza',
        createdAt: now.subtract(const Duration(hours: 2)),
        message:
            'O- donor available tomorrow morning at Digos Provincial '
            'Hospital.',
      ),
      RequestResponse(
        id: 'RES-002',
        requestId: 'REQ-003',
        donorId: 'USR-007',
        donorAlias: 'Bea',
        createdAt: now.subtract(const Duration(days: 2, hours: 20)),
      ),
    ]);

    _reports.add(
      UserReport(
        id: 'RPT-001',
        reporterId: 'USR-009',
        reporterAlias: 'Recipient 209',
        reportedUserId: 'USR-003',
        reportedAlias: 'Rogel',
        reason: 'Asked for PHP 5,000 cash in exchange for a donation.',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        threadId: 'ROOM-102',
      ),
    );

    // ---- chapter activity log ------------------------------------------
    // Newest first. Gives the staff console a realistic starting feed of
    // transfusions and account changes to review.
    _activity.addAll([
      ActivityEvent(
        id: 'ACT-001',
        kind: ActivityKind.donation,
        actorId: 'USR-010',
        actorAlias: 'Staff Marco',
        subjectId: 'USR-002',
        subjectAlias: 'Tere',
        summary: 'Recorded a packed RBC donation for Tere',
        at: now.subtract(const Duration(hours: 2)),
      ),
      ActivityEvent(
        id: 'ACT-002',
        kind: ActivityKind.avatar,
        actorId: 'USR-001',
        actorAlias: 'JuanDC',
        subjectId: 'USR-001',
        subjectAlias: 'JuanDC',
        summary: 'Changed their profile photo',
        at: now.subtract(const Duration(days: 1, hours: 2)),
      ),
      ActivityEvent(
        id: 'ACT-003',
        kind: ActivityKind.donation,
        actorId: 'USR-010',
        actorAlias: 'Staff Marco',
        subjectId: 'USR-020',
        subjectAlias: 'Mark',
        summary: 'Recorded a whole blood donation for Mark',
        at: now.subtract(const Duration(days: 1, hours: 8)),
      ),
      ActivityEvent(
        id: 'ACT-004',
        kind: ActivityKind.verification,
        actorId: 'USR-010',
        actorAlias: 'Staff Marco',
        subjectId: 'USR-019',
        subjectAlias: 'Jessa',
        summary: 'Verified the blood card for Jessa',
        at: now.subtract(const Duration(days: 2, hours: 3)),
      ),
      ActivityEvent(
        id: 'ACT-005',
        kind: ActivityKind.profile,
        actorId: 'USR-038',
        actorAlias: 'Kai',
        subjectId: 'USR-038',
        subjectAlias: 'Kai',
        summary: 'Updated contact number, barangay',
        at: now.subtract(const Duration(days: 3)),
      ),
      ActivityEvent(
        id: 'ACT-006',
        kind: ActivityKind.donationWindow,
        actorId: 'USR-010',
        actorAlias: 'Staff Marco',
        subjectId: 'USR-007',
        subjectAlias: 'Bea',
        summary:
            'Corrected Bea\'s donation window to '
            '${_shortDate(daysAgo(84))}',
        at: now.subtract(const Duration(days: 4)),
      ),
      ActivityEvent(
        id: 'ACT-007',
        kind: ActivityKind.donation,
        actorId: 'USR-010',
        actorAlias: 'Staff Marco',
        subjectId: 'USR-004',
        subjectAlias: 'Cardo',
        summary: 'Recorded a platelets donation for Cardo',
        at: now.subtract(const Duration(days: 6)),
      ),
    ]);

    // ---- chat threads --------------------------------------------------
    _threads.addAll([
      ChatThread(
        id: 'ROOM-101',
        participantAId: 'USR-009',
        participantAAlias: 'Recipient 209',
        participantBId: 'USR-001',
        participantBAlias: 'JuanDC',
        participantAReadAt: now.subtract(const Duration(hours: 2, minutes: 44)),
        participantBReadAt: now.subtract(const Duration(hours: 3, minutes: 5)),
        messages: [
          ChatMessage(
            id: 'MSG-001',
            senderId: 'USR-009',
            senderAlias: 'Recipient 209',
            text: 'Hello, are you available to donate at Digos Provincial Hospital tomorrow morning?',
            sentAt: now.subtract(const Duration(hours: 3)),
          ),
          ChatMessage(
            id: 'MSG-002',
            senderId: 'USR-001',
            senderAlias: 'JuanDC',
            text: 'Yes, I am free at 9 AM. I will bring my donor card.',
            sentAt: now.subtract(const Duration(hours: 2, minutes: 50)),
          ),
          ChatMessage(
            id: 'MSG-003',
            senderId: 'USR-009',
            senderAlias: 'Recipient 209',
            text: 'Thank you. See you tomorrow.',
            sentAt: now.subtract(const Duration(hours: 2, minutes: 45)),
          ),
        ],
      ),
      ChatThread(
        id: 'ROOM-102',
        participantAId: 'USR-009',
        participantAAlias: 'Recipient 209',
        participantBId: 'USR-003',
        participantBAlias: 'Rogel',
        isMuted: true,
        participantAReadAt: now.subtract(const Duration(hours: 1, minutes: 50)),
        participantBReadAt: now.subtract(const Duration(hours: 1, minutes: 50)),
        messages: [
          ChatMessage(
            id: 'MSG-101',
            senderId: 'USR-009',
            senderAlias: 'Recipient 209',
            text: 'Hi, can you meet at the clinic for the donation?',
            sentAt: now.subtract(const Duration(days: 1, hours: 4)),
          ),
          ChatMessage(
            id: 'MSG-102',
            senderId: 'USR-003',
            senderAlias: 'Rogel',
            text: 'I will only donate if you pay me 5,000 PHP upfront cash.',
            sentAt: now.subtract(const Duration(days: 1, hours: 3)),
            flag: ModerationFlag.inappropriate,
          ),
          ChatMessage(
            id: 'MSG-103',
            senderId: 'USR-009',
            senderAlias: 'Recipient 209',
            text: 'Paid blood donation is not allowed under TABANG policy.',
            sentAt: now.subtract(const Duration(days: 1, hours: 2)),
            flag: ModerationFlag.flagged,
          ),
        ],
      ),
      ChatThread(
        id: 'ROOM-103',
        participantAId: 'USR-005',
        participantAAlias: 'Angel',
        participantBId: 'USR-002',
        participantBAlias: 'Tere',
        participantAReadAt: now.subtract(const Duration(hours: 11)),
        participantBReadAt: now.subtract(const Duration(hours: 11)),
        messages: [
          ChatMessage(
            id: 'MSG-201',
            senderId: 'USR-002',
            senderAlias: 'Tere',
            text: 'Click this link to buy supplements before donating: http://spam-link.test',
            sentAt: now.subtract(const Duration(hours: 12)),
            flag: ModerationFlag.spam,
          ),
        ],
      ),
      // Seeded reciprocal conversations let the demo select pre-existing
      // responses immediately; newly posted responses still require chat first.
      ChatThread(
        id: 'ROOM-104',
        participantAId: 'USR-009',
        participantAAlias: 'Recipient 209',
        participantBId: 'USR-012',
        participantBAlias: 'Liza',
        participantAReadAt: now.subtract(const Duration(hours: 2, minutes: 20)),
        participantBReadAt: now.subtract(const Duration(hours: 2, minutes: 20)),
        messages: [
          ChatMessage(
            id: 'MSG-301',
            senderId: 'USR-009',
            senderAlias: 'Recipient 209',
            text: 'Thank you for responding. Are you free tomorrow morning?',
            sentAt: now.subtract(const Duration(hours: 2, minutes: 40)),
          ),
          ChatMessage(
            id: 'MSG-302',
            senderId: 'USR-012',
            senderAlias: 'Liza',
            text: 'Yes, I can be at the hospital by 8 AM.',
            sentAt: now.subtract(const Duration(hours: 2, minutes: 25)),
          ),
        ],
      ),
      ChatThread(
        id: 'ROOM-105',
        participantAId: 'USR-009',
        participantAAlias: 'Recipient 209',
        participantBId: 'USR-007',
        participantBAlias: 'Bea',
        participantAReadAt: now.subtract(
          const Duration(days: 2, hours: 22, minutes: 30),
        ),
        participantBReadAt: now.subtract(const Duration(days: 2, hours: 21)),
        messages: [
          ChatMessage(
            id: 'MSG-401',
            senderId: 'USR-009',
            senderAlias: 'Recipient 209',
            text:
                'Hello Bea, can you confirm your availability for Patient 118?',
            sentAt: now.subtract(const Duration(days: 2, hours: 22)),
          ),
          ChatMessage(
            id: 'MSG-402',
            senderId: 'USR-007',
            senderAlias: 'Bea',
            text: 'Confirmed. I can donate at the infirmary this week.',
            sentAt: now.subtract(const Duration(days: 2, hours: 21)),
          ),
        ],
      ),
    ]);

    // ---- staff room ----------------------------------------------------
    // Internal channel for staff and admins only. Messages carry each
    // member's own alias, and the UI labels the role (Staff/Admin) instead of
    // dressing the conversation as the Red Cross.
    final staffMembers = _users
        .where((user) => user.role.isAdminSide)
        .map((user) => user.id)
        .toList(growable: false);
    if (staffMembers.isNotEmpty) {
      final staffMessages = [
        ChatMessage(
          id: 'MSG-STF-001',
          senderId: 'USR-010',
          senderAlias: 'Staff Marco',
          text:
              'Staff room — use this for shift swaps, verification '
              'hand-offs and anything the community thread should not see.',
          sentAt: now.subtract(const Duration(hours: 6)),
        ),
        ChatMessage(
          id: 'MSG-STF-002',
          senderId: 'USR-011',
          senderAlias: 'Admin',
          text:
              'Noted. Keep request verification and slot confirmation '
              'before 5 PM so donors have time to confirm.',
          sentAt: now.subtract(const Duration(hours: 5, minutes: 20)),
        ),
      ];
      _threads.insert(
        0,
        ChatThread(
          id: staffRoomId,
          participantAId: 'staff-room',
          participantAAlias: 'Staff room',
          participantBId: 'staff-room',
          participantBAlias: 'Staff room',
          groupName: 'Staff room',
          memberIds: staffMembers,
          // Seeded history is read up to each member's own last message,
          // matching `sendMessage` ("sending implies reading"). Without this
          // the admin started with an unread badge on a room whose latest
          // message they wrote, and the navigation badge disagreed with the
          // row.
          memberReadAt: {
            for (final id in staffMembers)
              id: staffMessages
                  .where((message) => message.senderId == id)
                  .fold<DateTime?>(
                    null,
                    (latest, message) =>
                        latest == null || message.sentAt.isAfter(latest)
                        ? message.sentAt
                        : latest,
                  ) ??
                  now.subtract(const Duration(days: 30)),
          },
          messages: staffMessages,
        ),
      );
    }

    // ---- drives --------------------------------------------------------
    // Venue coordinates are the real OpenStreetMap points for each site.
    // DigosVectorMap.toMapFrame rebases them into the hand-traced map frame
    // when drawing, so a marker sits on its venue under the nudged raster and
    // stays inside the drive's own barangay.
    _drives.addAll([
      BloodDrive(
        id: 'DRV-001',
        title: 'Digos City Gym Blood Drive',
        venue: 'Digos City Gymnasium, Zone 3',
        barangay: 'Zone 3',
        lat: 6.74378,
        lng: 125.35629,
        startsAt: _atHour(now, 4, 8),
        endsAt: _atHour(now, 4, 15),
        expectedDonors: 120,
        photoAsset: 'assets/images/Blood Drives/Digos City Gym Blood Drive.jpg',
      ),
      BloodDrive(
        id: 'DRV-002',
        title: 'Barangay Matti Health Drive',
        venue: 'Matti Covered Court',
        barangay: 'Matti',
        // Matti Barangay Hall compound; the covered court is not mapped.
        lat: 6.7683092,
        lng: 125.3078194,
        startsAt: _atHour(now, 8, 9),
        endsAt: _atHour(now, 8, 14),
        expectedDonors: 75,
        photoAsset: 'assets/images/Blood Drives/Barangay Matti Health Drive.jpg',
      ),
      BloodDrive(
        id: 'DRV-003',
        title: 'Cor Jesu College Campus Mobile Drive',
        venue: 'Cor Jesu College, Student Activity Center',
        barangay: 'Zone 2',
        lat: 6.75210,
        lng: 125.35365,
        startsAt: _atHour(now, 14, 10),
        endsAt: _atHour(now, 14, 16),
        expectedDonors: 150,
        photoAsset:
            'assets/images/Blood Drives/Cor Jesu College Campus Drive.jpg',
      ),
      BloodDrive(
        id: 'DRV-004',
        title: 'Aplaya Coastal Community Drive',
        venue: 'Aplaya Barangay Hall',
        barangay: 'Aplaya',
        lat: 6.7365659,
        lng: 125.3775360,
        startsAt: _atHour(now, 5, 8),
        endsAt: _atHour(now, 5, 13),
        expectedDonors: 60,
        photoAsset: 'assets/images/Blood Drives/Aplaya Community Drive.jpg',
      ),
      BloodDrive(
        id: 'DRV-005',
        title: 'San Jose Community Bloodletting',
        venue: 'San Jose Barangay Hall',
        barangay: 'San Jose',
        lat: 6.7331466,
        lng: 125.3549049,
        startsAt: _atHour(now, 11, 9),
        endsAt: _atHour(now, 11, 17),
        expectedDonors: 95,
        photoAsset:
            'assets/images/Blood Drives/San Jose Community Bloodletting.jpg',
      ),
    ]);

    // ---- educational content -------------------------------------------
    _content.addAll(const [
      ContentItem(
        id: 'CNT-001',
        title: 'One Donation, Three Lives',
        subtitle: 'A single bag can become red cells, platelets and plasma for three patients.',
        body:
            'A single whole-blood donation can be separated into red cells, platelets and plasma, '
            'which may support up to three different patients. Voluntary, non-remunerated donors '
            'are the only sustainable source of supply under RA 7719, and every donation is '
            'screened, typed and tracked before it reaches a patient.',
        tag: 'WHY DONATE',
        category: ContentCategory.explore,
        imageAsset: 'assets/images/hero_donation.jpg',
      ),
      ContentItem(
        id: 'CNT-002',
        title: 'Hydration First Before Donating',
        subtitle: 'Drink at least 16 oz of water before your appointment for a smoother donation.',
        body:
            'Plasma is roughly 90 percent water. Being well hydrated before donation keeps your '
            'blood pressure stable and reduces the chance of light-headedness afterwards. Avoid '
            'alcohol in the 24 hours before your appointment.',
        tag: 'PRE-DONATION',
        category: ContentCategory.tips,
        imageAsset:
            'assets/images/Learn & Prepare/Hydration First Before Donating.jpg',
      ),
      ContentItem(
        id: 'CNT-003',
        title: 'Eat Iron-Rich Foods',
        subtitle:
            'Eat spinach, beans, or lean meat leading up to your appointment.',
        body:
            'Each donation removes about 200 to 250 mg of iron. Eating iron-rich foods in the '
            'week before and after donation helps your body rebuild stores faster. Pair plant '
            'sources with vitamin C to improve absorption.',
        tag: 'NUTRITION',
        category: ContentCategory.tips,
        imageAsset: 'assets/images/Learn & Prepare/Eat Iron-Rich Foods.jpg',
      ),
      ContentItem(
        id: 'CNT-004',
        title: 'Post-Donation Rest & Recovery',
        subtitle: 'Avoid heavy lifting and rest for 24 hours to let your body rebuild.',
        body:
            'Keep the bandage on for at least four hours. Drink extra fluids for the rest of the '
            'day, avoid strenuous activity and smoking for 24 hours, and sit or lie down if you '
            'feel dizzy.',
        tag: 'RECOVERY',
        category: ContentCategory.tips,
        imageAsset:
            'assets/images/Learn & Prepare/Post-Donation Rest & Recovery.jpg',
      ),
      ContentItem(
        id: 'CNT-005',
        title: 'Basic Requirements: Age, Weight & Health',
        subtitle: 'Must be at least 18 years old, weigh 50 kg or more, and be in general good health.',
        body:
            'Donors must be 18 to 65 years old, weigh at least 50 kg, and pass the pre-donation '
            'screening. Bring a valid ID and your blood donor card if you have one.',
        tag: 'CHECKLIST',
        category: ContentCategory.eligibility,
        imageAsset:
            'assets/images/Learn & Prepare/Basic Requirements = Age, Weight & Health.jpg',
      ),
      ContentItem(
        id: 'CNT-006',
        title: 'Can I Donate If I Got a Tattoo?',
        subtitle: 'You can donate if the tattoo was applied by a regulated shop with sterile needles.',
        body:
            'Tattoos and piercings from regulated establishments using sterile single-use '
            'equipment do not disqualify you. Unregulated settings carry a deferral period. '
            'The screening nurse makes the final call.',
        tag: 'FAQ',
        category: ContentCategory.eligibility,
        imageAsset: 'assets/images/Learn & Prepare/Can I Donate If I Got a Tattoo.jpg',
      ),
      ContentItem(
        id: 'CNT-007',
        title: 'How Often Can You Donate?',
        subtitle: 'Whole blood every 12 weeks. Platelets every 2 weeks. Plasma every 4 weeks.',
        body:
            'Whole blood and packed red cells require a 12-week interval so red cell volume and '
            'iron stores recover. Platelets can be given more frequently because they are '
            'returned or replaced quickly, and plasma every four weeks. TABANG enforces these '
            'intervals automatically through the donor cooldown timer.',
        tag: 'INTERVALS',
        category: ContentCategory.eligibility,
        imageAsset: 'assets/images/Learn & Prepare/How Often Can You Donate.jpg',
      ),
      ContentItem(
        id: 'CNT-008',
        title: 'Why TABANG Never Shows Real Names',
        subtitle: 'Donor and patient identities stay tokenized until both sides agree.',
        body:
            'Under RA 10173, health information is sensitive personal data. TABANG shows aliases '
            'in the directory and in chat. Real names and exact addresses are only exchanged '
            'once both parties confirm they intend to proceed with a donation.',
        tag: 'PRIVACY',
        category: ContentCategory.eligibility,
        imageAsset:
            'assets/images/Learn & Prepare/Why TABANG Never Shows Real Names.jpg',
      ),
      ContentItem(
        id: 'CNT-009',
        title: '"A stranger\'s donation saved my daughter\'s life."',
        subtitle: 'How an emergency transfusion changed one family\'s story in Digos City.',
        body:
            'When local stock ran low, the family spent hours calling around. A matched donor '
            'found through a community drive arrived within the window. This is the gap TABANG '
            'is built to close: visibility of who is available, right now, nearby.',
        tag: 'RECIPIENT STORY',
        category: ContentCategory.stories,
        imageAsset:
            "assets/images/Announcements & Stories/A stranger's donation saved my daughter's life.jpg",
      ),
      ContentItem(
        id: 'CNT-010',
        title: 'Meet Mark: 50th Blood Donation Milestone',
        subtitle: 'Why one donor has given every 12 weeks for over a decade.',
        body:
            'Fifty donations is roughly 150 units of separated components. Regular donors like '
            'Mark are the backbone of a stable supply, because predictable donation beats '
            'emergency recruitment every time.',
        tag: 'DONOR SPOTLIGHT',
        category: ContentCategory.stories,
        imageAsset:
            'assets/images/Announcements & Stories/daniel-article-1000x800px.png',
      ),
      ContentItem(
        id: 'CNT-011',
        title: 'What to Bring on Donation Day',
        subtitle:
            'A valid ID, your donor card, and a light meal before you arrive.',
        body:
            'Bring a government-issued ID and your blood donor card. Eat a '
            'normal meal within four hours of donating and avoid fatty food, '
            'which can affect screening. The chapter team will confirm your '
            'identity and walk you through the questionnaire.',
        tag: 'CHECKLIST',
        category: ContentCategory.tips,
        imageAsset: 'assets/images/Learn & Prepare/What to Bring on Donation Day.jpg',
      ),
      ContentItem(
        id: 'CNT-012',
        title: 'How Donation Helps the Whole Community',
        subtitle: 'One bag can become red cells, platelets and plasma for three patients.',
        body:
            'Voluntary, unpaid donation keeps the supply safe and sustainable. '
            'Red cells support surgery and trauma, platelets support cancer '
            'treatment, and plasma supports burns and clotting disorders. '
            'Regular donors make planned care possible.',
        tag: 'WHY DONATE',
        category: ContentCategory.explore,
        imageAsset:
            'assets/images/Announcements & Stories/How Donation Helps the Whole Community.jpg',
      ),
      ContentItem(
        id: 'CNT-013',
        title: 'Plan Your Recovery After Donating',
        subtitle:
            'Rest, hydrate and avoid heavy lifting for the rest of the day.',
        body:
            'Sit for at least ten minutes after donation and have a snack. '
            'Drink extra fluids, keep the bandage on for four hours, and avoid '
            'strenuous work, saunas and smoking for 24 hours. Contact the '
            'chapter if you feel faint or the site starts bleeding.',
        tag: 'AFTERCARE',
        category: ContentCategory.tips,
        imageAsset:
            'assets/images/Learn & Prepare/Plan Your Recovery After Donation.jpg',
      ),
    ]);
  }
}

/// Convenience for formatting a percentage without importing math everywhere.
double ratio(int part, int whole) {
  if (whole <= 0) return 0;
  return (part / whole).clamp(0.0, 1.0);
}

/// Largest value in a list, minimum 1, for bar-chart scaling.
double maxOrOne(Iterable<int> values) {
  if (values.isEmpty) return 1;
  return math.max(1, values.reduce(math.max)).toDouble();
}
