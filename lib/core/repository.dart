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
    'Cor Jesu College Infirmary',
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
  final List<BloodRequest> _requests = [];
  final List<RequestResponse> _responses = [];
  final List<ChatThread> _threads = [];
  final List<UserReport> _reports = [];
  final List<BloodDrive> _drives = [];
  final List<ContentItem> _content = [];
  final List<DonationAppointment> _appointments = [];
  final List<DonorApplication> _donorApplications = [];

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
  List<BloodDrive> get drives => List.unmodifiable(_drives);
  List<ContentItem> get content => List.unmodifiable(_content);
  List<DonationAppointment> get appointments =>
      List.unmodifiable(_appointments);

  AppUser? userById(String id) {
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
      .where((u) =>
          EligibilityEngine.evaluate(u, component: component).isEligible)
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
    return donors.where((u) {
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
    }).toList(growable: false);
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
        .where((u) =>
            u.component == component &&
            u.isUsableAt(today) &&
            Compatibility.canDonateComponentTo(
              u.bloodType,
              recipientType,
              component,
            ))
        .toList(growable: false);
  }

  /// Donors who could serve [request] and have not already responded.
  List<AppUser> compatibleDonorsForRequest(BloodRequest request) {
    final responded = _responses
        .where((r) => r.requestId == request.id)
        .map((r) => r.donorId)
        .toSet();
    return donors.where((u) {
      if (responded.contains(u.id)) return false;
      final donorType = u.bloodType;
      if (donorType == null) return false;
      if (!EligibilityEngine.evaluate(u, component: request.component)
          .isEligible) {
        return false;
      }
      return Compatibility.canDonateComponentTo(
        donorType,
        request.bloodType,
        request.component,
      );
    }).toList(growable: false);
  }

  List<BloodRequest> get openRequests => _requests
      .where((r) => r.status == RequestStatus.open)
      .toList(growable: false);

  List<BloodRequest> get donorNetworkRequests => _requests
      .where((r) => r.acceptsDonorResponses)
      .toList(growable: false);

  List<RequestResponse> responsesFor(String requestId) => _responses
      .where((r) => r.requestId == requestId)
      .toList(growable: false)
    ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

  RequestResponse? responseForDonor(String requestId, String donorId) {
    for (final r in _responses) {
      if (r.requestId == requestId && r.donorId == donorId) return r;
    }
    return null;
  }

  List<ChatThread> threadsFor(String userId) => _threads
      .where((t) => t.participantAId == userId || t.participantBId == userId)
      .toList(growable: false);

  ChatThread? threadBetween(String a, String b) {
    for (final t in _threads) {
      final hasA =
          t.participantAId == a || t.participantBId == a;
      final hasB =
          t.participantAId == b || t.participantBId == b;
      if (hasA && hasB) return t;
    }
    return null;
  }

  /// Appointments belonging to one requester, newest first.
  List<DonationAppointment> appointmentsFor(String userId) => _appointments
      .where((a) => a.requesterId == userId)
      .toList(growable: false)
    ..sort((a, b) => b.scheduledAt.compareTo(a.scheduledAt));

  /// Units currently on hold by [userId].
  List<BloodUnit> reservedUnitsFor(String userId) => _units
      .where((u) =>
          u.reservedBy == userId && !u.isExpiredAt(DateTime.now()))
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
    currentUser = user;
    _notify();
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
      (u) =>
          u.id != exceptUserId && u.alias.trim().toLowerCase() == normalized,
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
    updateUser(user.copyWith(
      role: UserRole.donor,
      bloodType: bloodType,
      birthDate: birthDate,
      weightKg: weightKg,
      status: AccountStatus.unverified,
      bloodCardVerified: false,
      isAvailable: true,
    ));
    return true;
  }

  void setDonorAvailability(String userId, bool isAvailable) {
    final user = userById(userId);
    if (user == null) return;
    updateUser(user.copyWith(isAvailable: isAvailable));
  }

  void recordDonation(
    String userId, {
    DateTime? at,
    BloodComponent? component,
  }) {
    final user = userById(userId);
    if (user == null) return;
    updateUser(user.copyWith(
      lastDonationDate: at ?? DateTime.now(),
      lastDonationComponent: component ?? user.lastDonationComponent,
      totalDonations: user.totalDonations + 1,
    ));
  }

  void setUserStatus(
    String userId,
    AccountStatus status, {
    String? reason,
  }) {
    final user = userById(userId);
    if (user == null) return;
    updateUser(user.copyWith(
      status: status,
      suspensionReason: reason,
      clearSuspensionReason: reason == null,
    ));
  }

  void verifyUser(String userId) {
    final user = userById(userId);
    if (user == null) return;
    updateUser(user.copyWith(
      status: AccountStatus.verified,
      bloodCardVerified: true,
    ));
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
  List<DonorApplication> get openDonorApplications => _donorApplications
      .where((a) =>
          a.status == DonorApplicationStatus.pending ||
          a.status == DonorApplicationStatus.documentsRequested)
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
    DateTime? preferredVisit,
    String? note,
  }) {
    final user = userById(userId);
    if (user == null) return null;

    // A community user converts here; an unverified donor may re-submit,
    // which is why this is not restricted to community accounts.
    final freshApplicant = user.role.canRegisterAsDonor;
    final resubmitting =
        user.role == UserRole.donor && !user.bloodCardVerified;
    if (!freshApplicant && !resubmitting) return null;

    if (freshApplicant) {
      updateUser(user.copyWith(
        role: UserRole.donor,
        bloodType: bloodType,
        status: AccountStatus.unverified,
        bloodCardVerified: false,
        isAvailable: true,
      ));
    } else {
      updateUser(user.copyWith(
        bloodType: bloodType ?? user.bloodType,
        status: AccountStatus.unverified,
        bloodCardVerified: false,
      ));
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
    _notify();
    return application;
  }

  /// Staff decision on a donor application.
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
    if (status == DonorApplicationStatus.verified) {
      // verifyUser notifies, so this path must not notify twice.
      verifyUser(userId);
      return;
    }
    _notify();
  }

  // --------------------------------------------------------- drive interest

  bool isInterestedInDrive(String driveId, String userId) =>
      _driveInterests.contains('$driveId|$userId');

  bool toggleDriveInterest(String driveId, String userId) {
    final key = '$driveId|$userId';
    final added = _driveInterests.add(key);
    if (!added) _driveInterests.remove(key);
    _notify();
    return added;
  }

  int driveInterestCount(String driveId) =>
      _driveInterests.where((key) => key.startsWith('$driveId|')).length;

  void warnUser(String userId) {
    final user = userById(userId);
    if (user == null) return;
    final next = user.warningCount + 1;
    updateUser(user.copyWith(
      warningCount: next,
      status: next >= 3 ? AccountStatus.suspended : AccountStatus.warned,
      suspensionReason:
          next >= 3 ? 'Three moderation warnings on record.' : null,
    ));
  }

  void addRequest({
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
  }) {
    _requests.insert(
      0,
      BloodRequest(
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
        source: source,
        note: note,
      ),
    );
    _notify();
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
    if (!EligibilityEngine.evaluate(donor, component: request.component)
        .isEligible) {
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
      donorAlias: donor.alias,
      createdAt: DateTime.now(),
      message: trimmedMessage == null || trimmedMessage.isEmpty
          ? null
          : trimmedMessage,
    );
    _responses.add(response);
    _notify();
    return response;
  }

  /// The requester (or staff/admin) selects a donor response. Selection creates
  /// the coordination thread and, once enough donors are selected, moves the
  /// request to `matched`. No unit is counted as fulfilled until staff record
  /// the donation.
  ChatThread? selectResponse({
    required String responseId,
    required String selectedById,
  }) {
    final response = _firstOrNull(_responses, (r) => r.id == responseId);
    if (response == null) return null;
    final request =
        _firstOrNull(_requests, (r) => r.id == response.requestId);
    if (request == null || request.status != RequestStatus.open) return null;

    final actor = userById(selectedById);
    if (actor == null) return null;
    final canSelect = actor.id == request.requesterId ||
        actor.role == UserRole.staff ||
        actor.role == UserRole.admin;
    if (!canSelect) return null;
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
        !EligibilityEngine.evaluate(donor, component: request.component)
            .isEligible ||
        !Compatibility.canDonateComponentTo(
          donor.bloodType!,
          request.bloodType,
          request.component,
        )) {
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
        .where((r) =>
            r.requestId == request.id && r.status == ResponseStatus.selected)
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
    final canCancel = actor.id == request.requesterId ||
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

  void setUnitStatus(String barcode, UnitStatus status) {
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
      reservationNote:
          note == null || note.trim().isEmpty ? null : note.trim(),
      reservedAt: DateTime.now(),
    );
    _notify();
    return true;
  }

  bool cancelReservation({
    required String barcode,
    required String userId,
  }) {
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
    setUnitStatus(barcode, UnitStatus.available);
    return true;
  }

  /// Book a blood-bank appointment. Staff confirm the slot; the record does not
  /// allocate a unit by itself.
  DonationAppointment? addAppointment({
    required String requesterId,
    required String patientName,
    required BloodType bloodType,
    required BloodComponent component,
    required String hospital,
    required String ward,
    required int units,
    required DateTime scheduledAt,
    String? note,
  }) {
    final requester = userById(requesterId);
    if (requester == null || !requester.role.canRequestBlood) return null;
    if (units < 1 || units > 20) return null;
    final appointment = DonationAppointment(
      id: 'APT-${(_appointments.length + 1).toString().padLeft(3, '0')}',
      requesterId: requesterId,
      patientName: patientName.trim(),
      bloodType: bloodType,
      component: component,
      hospital: hospital,
      ward: ward.trim(),
      units: units,
      scheduledAt: scheduledAt,
      note: note == null || note.trim().isEmpty ? null : note.trim(),
    );
    _appointments.insert(0, appointment);
    _notify();
    return appointment;
  }

  bool confirmAppointment(String appointmentId, {required String actorId}) {
    final actor = userById(actorId);
    if (actor == null || !actor.role.isAdminSide) return false;
    final index = _appointments.indexWhere((a) => a.id == appointmentId);
    if (index == -1) return false;
    final current = _appointments[index];
    if (current.status == 'Confirmed') return false;
    _appointments[index] = DonationAppointment(
      id: current.id,
      requesterId: current.requesterId,
      patientName: current.patientName,
      bloodType: current.bloodType,
      component: current.component,
      hospital: current.hospital,
      ward: current.ward,
      units: current.units,
      scheduledAt: current.scheduledAt,
      status: 'Confirmed',
      note: current.note,
    );
    _notify();
    return true;
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
        messages: const [],
      );
      _threads.insert(0, thread);
    }

    final trimmed = firstMessage?.trim();
    if (trimmed != null && trimmed.isNotEmpty) {
      final index = _threads.indexWhere((t) => t.id == thread!.id);
      _threads[index] = thread.copyWith(
        messages: [
          ...thread.messages,
          ChatMessage(
            id: 'MSG-${DateTime.now().microsecondsSinceEpoch}',
            senderId: initiatorId,
            senderAlias: initiator.alias,
            text: trimmed,
            sentAt: DateTime.now(),
            flag: _classify(trimmed),
          ),
        ],
      );
      thread = _threads[index];
    }
    _notify();
    return thread;
  }

  /// True when both participants have sent at least one human message. System
  /// notices do not count, so simply opening a thread is not enough.
  bool hasReciprocalChat(String a, String b) {
    final thread = threadBetween(a, b);
    if (thread == null) return false;
    final fromA =
        thread.messages.any((m) => m.senderId == a && m.senderId != 'system');
    final fromB =
        thread.messages.any((m) => m.senderId == b && m.senderId != 'system');
    return fromA && fromB;
  }

  void sendMessage(String threadId, String senderId, String text) {
    final index = _threads.indexWhere((t) => t.id == threadId);
    if (index == -1) return;
    final thread = _threads[index];
    if (thread.isMuted) return;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final isParticipant = thread.participantAId == senderId ||
        thread.participantBId == senderId;
    if (!isParticipant) return;

    final otherId = thread.participantAId == senderId
        ? thread.participantBId
        : thread.participantAId;
    if (isBlockedBetween(senderId, otherId)) return;

    final sender = userById(senderId);
    final message = ChatMessage(
      id: 'MSG-${DateTime.now().microsecondsSinceEpoch}',
      senderId: senderId,
      senderAlias: sender?.alias ?? 'Unknown',
      text: trimmed,
      sentAt: DateTime.now(),
      flag: _classify(trimmed),
    );

    _threads[index] = thread.copyWith(
      messages: [...thread.messages, message],
    );
    _notify();
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
    final isParticipant = thread.participantAId == requesterId ||
        thread.participantBId == requesterId;
    if (!isParticipant) return false;
    if (thread.identityRevealRequestedBy != null) return false;
    _threads[index] =
        thread.copyWith(identityRevealRequestedBy: requesterId);
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
    final isParticipant = thread.participantAId == accepterId ||
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
    final isParticipant = thread.participantAId == declinerId ||
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
    String? threadId,
  }) {
    final reporter = userById(reporterId);
    final reported = userById(reportedUserId);
    final report = UserReport(
      id: 'RPT-${(_reports.length + 1).toString().padLeft(3, '0')}',
      reporterId: reporterId,
      reporterAlias: reporter?.alias ?? 'Unknown',
      reportedUserId: reportedUserId,
      reportedAlias: reported?.alias ?? 'Unknown',
      reason: reason.trim(),
      createdAt: DateTime.now(),
      threadId: threadId,
    );
    _reports.insert(0, report);
    _notify();
    return report;
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

  /// Computed from the live seed data rather than hardcoded literals, so the
  /// numbers on the admin overview always agree with the tables below them.
  AnalyticsSummary summary({DateTime? now}) {
    final today = now ?? DateTime.now();
    final monthStart = DateTime(today.year, today.month, 1);

    final donationsToday = _users
        .where((u) =>
            u.lastDonationDate != null &&
            _sameDay(u.lastDonationDate!, today))
        .length;

    final donationsThisMonth = _users
        .where((u) =>
            u.lastDonationDate != null &&
            u.lastDonationDate!.isAfter(monthStart))
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
    return BloodType.values.map((type) {
      final donated = _users
          .where((u) => u.bloodType == type)
          .fold<int>(0, (sum, u) => sum + u.totalDonations);
      final requested = _requests
          .where((r) =>
              r.bloodType == type && r.status != RequestStatus.cancelled)
          .fold<int>(0, (sum, r) => sum + r.unitsNeeded);
      return BloodTypeStat(
        bloodType: type,
        donated: donated,
        requested: requested,
      );
    }).toList(growable: false);
  }

  List<BarangayStat> barangayStats() {
    final stats = <BarangayStat>[];
    for (final barangay in DigosBarangays.all) {
      final donorsHere = donors.where((u) => u.barangay == barangay).toList();
      if (donorsHere.isEmpty) continue;
      stats.add(BarangayStat(
        barangay: barangay,
        donationCount: donorsHere.fold<int>(0, (s, u) => s + u.totalDonations),
        donorCount: donorsHere.length,
      ));
    }
    stats.sort((a, b) => b.donationCount.compareTo(a.donationCount));
    return stats;
  }

  /// Usable units expiring within [days] days, soonest first. Expired bags are
  /// excluded: they belong in the expired filter, not the expiry-pressure list.
  List<BloodUnit> expiringSoon({int days = 7, DateTime? now}) {
    final today = now ?? DateTime.now();
    final list = _units
        .where((u) =>
            u.isUsableAt(today) &&
            u.daysUntilExpiry(today) >= 0 &&
            u.daysUntilExpiry(today) <= days)
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
    _drives.clear();
    _content.clear();
    _appointments.clear();
    _blocks.clear();
    _unblockedAt.clear();
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

  /// Lightweight keyword classifier standing in for the moderation service.
  /// Real deployments would route through a review queue; this keeps the
  /// admin moderation surface demonstrable with simulated data.
  static ModerationFlag _classify(String text) {
    final lower = text.toLowerCase();
    const spamMarkers = ['http://', 'https://', 'buy now', 'click this link'];
    const inappropriateMarkers = [
      'pay me',
      'cash upfront',
      'php upfront',
      'bribe',
    ];

    if (spamMarkers.any(lower.contains)) return ModerationFlag.spam;
    if (inappropriateMarkers.any(lower.contains)) {
      return ModerationFlag.inappropriate;
    }
    return ModerationFlag.clean;
  }

  void _seed() {
    final now = DateTime.now();
    DateTime daysAgo(int d) => now.subtract(Duration(days: d));

    // ---- users ---------------------------------------------------------
    _users.addAll([
      AppUser(
        id: 'USR-001',
        fullName: 'Iverson D. Briones',
        alias: 'Iver',
        email: 'iverson.briones@tabang.app',
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
        fullName: 'Juan Miguel Dela Cruz',
        alias: 'Juan',
        email: 'juan.delacruz@tabang.app',
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
        fullName: 'Cleford Jay Bacan',
        alias: 'Staff Bacan',
        email: 'staff@tabang.app',
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
      _units.add(BloodUnit(
        barcode: barcode,
        bloodType: type,
        component: component,
        storageBay: bay,
        status: status,
        collectedOn: collected,
        expiresOn: collected.add(Duration(days: shelfLifeDays)),
      ));
    }

    addUnit('RBC-8849-O-', BloodType.oNeg, BloodComponent.packedRbc,
        'Cold room R-02 (4 °C)', 40, 42);
    addUnit('RBC-8850-O-', BloodType.oNeg, BloodComponent.packedRbc,
        'Cold room R-02 (4 °C)', 39, 42);
    addUnit('RBC-6612-O+', BloodType.oPos, BloodComponent.packedRbc,
        'Cold room R-01 (4 °C)', 20, 42);
    addUnit('RBC-3391-B-', BloodType.bNeg, BloodComponent.packedRbc,
        'Cold room R-02 (4 °C)', 14, 42);
    addUnit('RBC-9014-AB-', BloodType.abNeg, BloodComponent.packedRbc,
        'Bay 03 (4 °C)', 28, 42, status: UnitStatus.reserved);
    addUnit('PLT-4019-A+', BloodType.aPos, BloodComponent.platelets,
        'Agitator A-01 (22 °C)', 3, 5);
    addUnit('PLT-4020-O+', BloodType.oPos, BloodComponent.platelets,
        'Agitator A-01 (22 °C)', 2, 5);
    addUnit('FFP-7712-B+', BloodType.bPos, BloodComponent.plasma,
        'Freezer F-03 (-30 °C)', 185, 365);
    addUnit('FFP-9912-AB+', BloodType.abPos, BloodComponent.plasma,
        'Freezer F-01 (-30 °C)', 205, 365);
    addUnit('WB-1092-A-', BloodType.aNeg, BloodComponent.wholeBlood,
        'Cold room R-03 (4 °C)', 38, 42, status: UnitStatus.quarantined);
    addUnit('WB-1093-A+', BloodType.aPos, BloodComponent.wholeBlood,
        'Cold room R-03 (4 °C)', 12, 42);
    addUnit('RBC-7723-B+', BloodType.bPos, BloodComponent.packedRbc,
        'Cold room R-01 (4 °C)', 8, 42);
    // Kept in the record with its stored status still `available` to exercise
    // effective-status expiry handling; it is never counted as usable.
    addUnit('RBC-7700-O+', BloodType.oPos, BloodComponent.packedRbc,
        'Cold room R-01 (4 °C)', 45, 42);

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
        source: RequestSource.bloodBank,
      ),
      BloodRequest(
        id: 'REQ-003',
        requesterId: 'USR-009',
        patientAlias: 'Patient 118',
        bloodType: BloodType.bPos,
        component: BloodComponent.wholeBlood,
        unitsNeeded: 1,
        hospital: 'Cor Jesu College Infirmary',
        barangay: 'Zone 1',
        urgency: RequestUrgency.routine,
        createdAt: now.subtract(const Duration(days: 3)),
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
        note: 'Dialysis patient, two units requested by the attending physician.',
      ),
      BloodRequest(
        id: 'REQ-006',
        requesterId: 'USR-026',
        patientAlias: 'Patient 177',
        bloodType: BloodType.oPos,
        component: BloodComponent.platelets,
        unitsNeeded: 1,
        hospital: 'Cor Jesu College Infirmary',
        barangay: 'San Jose',
        urgency: RequestUrgency.routine,
        createdAt: now.subtract(const Duration(hours: 20)),
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
      ),
      BloodRequest(
        id: 'REQ-010',
        requesterId: 'USR-031',
        patientAlias: 'Patient 143',
        bloodType: BloodType.abNeg,
        component: BloodComponent.plasma,
        unitsNeeded: 1,
        hospital: 'Cor Jesu College Infirmary',
        barangay: 'Dawis',
        urgency: RequestUrgency.routine,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ]);

    // A pending response demonstrates the selection step without marking the
    // request matched or counting an unperformed donation.
    _responses.addAll([
      RequestResponse(
        id: 'RES-001',
        requestId: 'REQ-001',
        donorId: 'USR-012',
        donorAlias: 'Liza',
        createdAt: now.subtract(const Duration(hours: 2)),
        message: 'O- donor available tomorrow morning at Digos Provincial '
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
        reportedAlias: 'Juan',
        reason: 'Asked for PHP 5,000 cash in exchange for a donation.',
        createdAt: now.subtract(const Duration(days: 1, hours: 2)),
        threadId: 'ROOM-102',
      ),
    );

    // ---- chat threads --------------------------------------------------
    _threads.addAll([
      ChatThread(
        id: 'ROOM-101',
        participantAId: 'USR-009',
        participantAAlias: 'Recipient 209',
        participantBId: 'USR-001',
        participantBAlias: 'Iver',
        messages: [
          ChatMessage(
            id: 'MSG-001',
            senderId: 'USR-009',
            senderAlias: 'Recipient 209',
            text:
                'Hello, are you available to donate at Digos Provincial Hospital tomorrow morning?',
            sentAt: now.subtract(const Duration(hours: 3)),
          ),
          ChatMessage(
            id: 'MSG-002',
            senderId: 'USR-001',
            senderAlias: 'Iver',
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
        participantBAlias: 'Juan',
        isMuted: true,
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
            senderAlias: 'Juan',
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
        messages: [
          ChatMessage(
            id: 'MSG-201',
            senderId: 'USR-002',
            senderAlias: 'Tere',
            text:
                'Click this link to buy supplements before donating: http://spam-link.test',
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
        messages: [
          ChatMessage(
            id: 'MSG-401',
            senderId: 'USR-009',
            senderAlias: 'Recipient 209',
            text: 'Hello Bea, can you confirm your availability for Patient 118?',
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

    // ---- drives --------------------------------------------------------
    _drives.addAll([
      BloodDrive(
        id: 'DRV-001',
        title: 'Digos City Gym Blood Drive',
        venue: 'Digos City Gymnasium, Zone 1',
        barangay: 'Zone 1',
        startsAt: _atHour(now, 4, 8),
        endsAt: _atHour(now, 4, 15),
        expectedDonors: 120,
      ),
      BloodDrive(
        id: 'DRV-002',
        title: 'Barangay Matti Health Drive',
        venue: 'Matti Covered Court',
        barangay: 'Matti',
        startsAt: _atHour(now, 8, 9),
        endsAt: _atHour(now, 8, 14),
        expectedDonors: 75,
      ),
      BloodDrive(
        id: 'DRV-003',
        title: 'Cor Jesu College Campus Mobile Drive',
        venue: 'Student Activity Center',
        barangay: 'Zone 1',
        startsAt: _atHour(now, 14, 10),
        endsAt: _atHour(now, 14, 16),
        expectedDonors: 150,
      ),
      BloodDrive(
        id: 'DRV-004',
        title: 'Aplaya Coastal Community Drive',
        venue: 'Aplaya Barangay Hall',
        barangay: 'Aplaya',
        startsAt: _atHour(now, 5, 8),
        endsAt: _atHour(now, 5, 13),
        expectedDonors: 60,
      ),
      BloodDrive(
        id: 'DRV-005',
        title: 'San Jose Mall Bloodletting',
        venue: 'San Jose Town Plaza',
        barangay: 'San Jose',
        startsAt: _atHour(now, 11, 9),
        endsAt: _atHour(now, 11, 17),
        expectedDonors: 95,
      ),
    ]);

    // ---- blood-bank appointments ---------------------------------------
    _appointments.addAll([
      DonationAppointment(
        id: 'APT-001',
        requesterId: 'USR-009',
        patientName: 'Mercy Santos',
        bloodType: BloodType.oNeg,
        component: BloodComponent.packedRbc,
        hospital: 'Digos Provincial Hospital',
        ward: 'Obstetrics Ward 2',
        units: 2,
        scheduledAt: _atHour(now, 1, 9),
        status: 'Confirmed',
        note: 'Scheduled caesarean section.',
      ),
      DonationAppointment(
        id: 'APT-002',
        requesterId: 'USR-025',
        patientName: 'Elias Cabrera',
        bloodType: BloodType.bPos,
        component: BloodComponent.wholeBlood,
        hospital: 'Digos Doctors Hospital',
        ward: 'Dialysis Unit',
        units: 2,
        scheduledAt: _atHour(now, 2, 10),
      ),
    ]);

    // ---- educational content -------------------------------------------
    _content.addAll(const [
      ContentItem(
        id: 'CNT-001',
        title: 'One Donation, Three Lives',
        subtitle:
            'A single bag can become red cells, platelets and plasma for three patients.',
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
        subtitle:
            'Drink at least 16 oz of water before your appointment for a smoother donation.',
        body:
            'Plasma is roughly 90 percent water. Being well hydrated before donation keeps your '
            'blood pressure stable and reduces the chance of light-headedness afterwards. Avoid '
            'alcohol in the 24 hours before your appointment.',
        tag: 'PRE-DONATION',
        category: ContentCategory.tips,
        imageAsset: 'assets/images/content_hydration.jpg',
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
        imageAsset: 'assets/images/content_nutrition.jpg',
      ),
      ContentItem(
        id: 'CNT-004',
        title: 'Post-Donation Rest & Recovery',
        subtitle:
            'Avoid heavy lifting and rest for 24 hours to let your body rebuild.',
        body:
            'Keep the bandage on for at least four hours. Drink extra fluids for the rest of the '
            'day, avoid strenuous activity and smoking for 24 hours, and sit or lie down if you '
            'feel dizzy.',
        tag: 'RECOVERY',
        category: ContentCategory.tips,
        imageAsset: 'assets/images/content_recovery.jpg',
      ),
      ContentItem(
        id: 'CNT-005',
        title: 'Basic Requirements: Age, Weight & Health',
        subtitle:
            'Must be at least 18 years old, weigh 50 kg or more, and be in general good health.',
        body:
            'Donors must be 18 to 65 years old, weigh at least 50 kg, and pass the pre-donation '
            'screening. Bring a valid ID and your blood donor card if you have one.',
        tag: 'CHECKLIST',
        category: ContentCategory.eligibility,
        imageAsset: 'assets/images/content_screening.jpg',
      ),
      ContentItem(
        id: 'CNT-006',
        title: 'Can I Donate If I Got a Tattoo?',
        subtitle:
            'You can donate if the tattoo was applied by a regulated shop with sterile needles.',
        body:
            'Tattoos and piercings from regulated establishments using sterile single-use '
            'equipment do not disqualify you. Unregulated settings carry a deferral period. '
            'The screening nurse makes the final call.',
        tag: 'FAQ',
        category: ContentCategory.eligibility,
        imageAsset: 'assets/images/educational/edu_eligibility.png',
      ),
      ContentItem(
        id: 'CNT-007',
        title: 'How Often Can You Donate?',
        subtitle:
            'Whole blood every 12 weeks. Platelets every 2 weeks. Plasma every 4 weeks.',
        body:
            'Whole blood and packed red cells require a 12-week interval so red cell volume and '
            'iron stores recover. Platelets can be given more frequently because they are '
            'returned or replaced quickly, and plasma every four weeks. TABANG enforces these '
            'intervals automatically through the donor cooldown timer.',
        tag: 'INTERVALS',
        category: ContentCategory.eligibility,
        imageAsset: 'assets/images/content_drive.jpg',
      ),
      ContentItem(
        id: 'CNT-008',
        title: 'Why TABANG Never Shows Real Names',
        subtitle:
            'Donor and patient identities stay tokenized until both sides agree.',
        body:
            'Under RA 10173, health information is sensitive personal data. TABANG shows aliases '
            'in the directory and in chat. Real names and exact addresses are only exchanged '
            'once both parties confirm they intend to proceed with a donation.',
        tag: 'PRIVACY',
        category: ContentCategory.eligibility,
        imageAsset: 'assets/images/content_privacy.jpg',
      ),
      ContentItem(
        id: 'CNT-009',
        title: '"A stranger\'s donation saved my daughter\'s life."',
        subtitle:
            'How an emergency transfusion changed one family\'s story in Digos City.',
        body:
            'When local stock ran low, the family spent hours calling around. A matched donor '
            'found through a community drive arrived within the window. This is the gap TABANG '
            'is built to close: visibility of who is available, right now, nearby.',
        tag: 'RECIPIENT STORY',
        category: ContentCategory.stories,
        imageAsset: 'assets/images/content_story.jpg',
      ),
      ContentItem(
        id: 'CNT-010',
        title: 'Meet Mark: 50th Blood Donation Milestone',
        subtitle:
            'Why one donor has given every 12 weeks for over a decade.',
        body:
            'Fifty donations is roughly 150 units of separated components. Regular donors like '
            'Mark are the backbone of a stable supply, because predictable donation beats '
            'emergency recruitment every time.',
        tag: 'DONOR SPOTLIGHT',
        category: ContentCategory.stories,
        imageAsset: 'assets/images/drive_community.jpg',
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
        imageAsset: 'assets/images/educational/edu_prepare.png',
      ),
      ContentItem(
        id: 'CNT-012',
        title: 'How Donation Helps the Whole Community',
        subtitle:
            'One bag can become red cells, platelets and plasma for three patients.',
        body:
            'Voluntary, unpaid donation keeps the supply safe and sustainable. '
            'Red cells support surgery and trauma, platelets support cancer '
            'treatment, and plasma supports burns and clotting disorders. '
            'Regular donors make planned care possible.',
        tag: 'WHY DONATE',
        category: ContentCategory.explore,
        imageAsset: 'assets/images/educational/edu_benefits.png',
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
        imageAsset: 'assets/images/educational/edu_aftercare.png',
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
