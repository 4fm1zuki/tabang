/// Core domain models for TABANG.
///
/// This file is the single source of truth for the data shapes used across
/// both the donor-facing and admin-facing surfaces. The previous build
/// declared `BloodUnit`, `BloodType` and `BloodComponent` twice (once in
/// `blood_bank_page.dart`, once in `admin_data/blood_bank_service.dart`) with
/// two different inventories. That duplication is gone: everything imports
/// from here.
library;

/// ABO/Rh blood group.
enum BloodType {
  oNeg('O-'),
  oPos('O+'),
  aNeg('A-'),
  aPos('A+'),
  bNeg('B-'),
  bPos('B+'),
  abNeg('AB-'),
  abPos('AB+');

  const BloodType(this.label);

  /// Display label, e.g. `O+`.
  final String label;

  static BloodType? tryParse(String? raw) {
    if (raw == null) return null;
    final normalized = raw.trim().toUpperCase().replaceAll(' ', '');
    for (final type in BloodType.values) {
      if (type.label == normalized) return type;
    }
    return null;
  }
}

/// Transfusable blood product.
enum BloodComponent {
  wholeBlood('Whole blood', 'WB'),
  packedRbc('Packed red blood cells', 'RBC'),
  platelets('Platelets (apheresis)', 'PLT'),
  plasma('Fresh frozen plasma', 'FFP');

  const BloodComponent(this.label, this.code);

  final String label;
  final String code;
}

/// Storage state of a physical unit.
enum UnitStatus {
  available('Available'),
  reserved('Reserved'),
  quarantined('Quarantined'),
  dispatched('Dispatched'),
  expired('Expired');

  const UnitStatus(this.label);
  final String label;
}

/// A physical bag of blood in the inventory.
class BloodUnit {
  const BloodUnit({
    required this.barcode,
    required this.bloodType,
    required this.component,
    required this.storageBay,
    required this.status,
    required this.collectedOn,
    required this.expiresOn,
    this.reservedBy,
    this.reservationNote,
    this.reservedAt,
  });

  final String barcode;
  final BloodType bloodType;
  final BloodComponent component;
  final String storageBay;
  final UnitStatus status;
  final DateTime collectedOn;
  final DateTime expiresOn;

  /// Community user who placed a hold on this unit, if any. Staff still confirm
  /// the clinical release; a hold is not a transfusion order.
  final String? reservedBy;
  final String? reservationNote;
  final DateTime? reservedAt;

  BloodUnit copyWith({
    UnitStatus? status,
    String? reservedBy,
    String? reservationNote,
    DateTime? reservedAt,
    bool clearReservation = false,
  }) {
    return BloodUnit(
      barcode: barcode,
      bloodType: bloodType,
      component: component,
      storageBay: storageBay,
      status: status ?? this.status,
      collectedOn: collectedOn,
      expiresOn: expiresOn,
      reservedBy: clearReservation ? null : (reservedBy ?? this.reservedBy),
      reservationNote: clearReservation
          ? null
          : (reservationNote ?? this.reservationNote),
      reservedAt: clearReservation ? null : (reservedAt ?? this.reservedAt),
    );
  }

  String get product => component.label;

  /// Whole days until expiry. Negative means already expired.
  int daysUntilExpiry(DateTime now) {
    return (expiresOn.difference(now).inMinutes / Duration.minutesPerDay)
        .floor();
  }

  /// Human-readable shelf life, e.g. `18 hours`, `3 days`, `180 days`.
  String timeLeft(DateTime now) {
    final remaining = expiresOn.difference(now);
    if (remaining.isNegative || remaining == Duration.zero) return 'Expired';
    if (remaining.inHours < 48) return '${remaining.inHours} hours';
    return '${remaining.inDays} days';
  }

  /// A unit is expired once its shelf life has elapsed, regardless of the
  /// stored status. Inventory must never advertise an expired bag as usable.
  bool isExpiredAt(DateTime now) => !now.isBefore(expiresOn);

  /// Available *and* within shelf life. This is the only definition the rest
  /// of the app should use when counting or reserving stock.
  bool isUsableAt(DateTime now) =>
      status == UnitStatus.available && !isExpiredAt(now);

  /// The status a user should see. An `available` bag past its expiry date is
  /// shown as expired even if staff have not manually changed the record.
  UnitStatus effectiveStatus(DateTime now) {
    if (isExpiredAt(now) &&
        (status == UnitStatus.available ||
            status == UnitStatus.reserved ||
            status == UnitStatus.quarantined)) {
      return UnitStatus.expired;
    }
    return status;
  }

  bool get isUsable => isUsableAt(DateTime.now());
}

/// Account lifecycle for a registered user.
enum AccountStatus {
  unverified('Unverified'),
  verified('Verified'),
  warned('Warned'),
  suspended('Suspended');

  const AccountStatus(this.label);
  final String label;
}

/// Role determines which dashboard a session lands on. There is no
/// self-service path to [admin] — see `AuthService`.
enum UserRole {
  user('Community User'),
  donor('Voluntary Donor'),
  recipient('Recipient / Patient Representative'),
  staff('Clinical Personnel'),
  admin('System Administrator');

  const UserRole(this.label);
  final String label;

  bool get isAdminSide => this == UserRole.admin || this == UserRole.staff;

  /// Community members can post a blood request. This intentionally includes
  /// donors: donating and needing blood are not mutually exclusive.
  bool get canRequestBlood =>
      this == UserRole.user ||
      this == UserRole.donor ||
      this == UserRole.recipient;

  bool get canRegisterAsDonor =>
      this == UserRole.user || this == UserRole.recipient;

  static UserRole? tryParse(String? raw) {
    if (raw == null) return null;
    for (final role in UserRole.values) {
      if (role.name == raw) return role;
    }
    return null;
  }
}

/// A registered platform user.
///
/// [alias] is the only identity exposed to other users until both parties
/// consent to reveal real names — the anonymity rule on p.34 of the paper.
/// The internal [id] is never shown on community surfaces; it exists for
/// audit trails, blocks and lifecycle rules.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.alias,
    required this.email,
    required this.phone,
    required this.barangay,
    required this.role,
    required this.registeredOn,
    this.bloodType,
    this.birthDate,
    this.weightKg,
    this.status = AccountStatus.unverified,
    this.warningCount = 0,
    this.suspensionReason,
    this.lastDonationDate,
    this.lastDonationComponent,
    this.totalDonations = 0,
    this.isAvailable = true,
    this.bloodCardVerified = false,
    this.shareBarangay = true,
    this.notifyRequests = true,
    this.notifyChat = true,
    this.notifyNews = true,
    this.onboardingCompleted = false,
    this.photoAsset,
  });

  final String id;
  final String fullName;
  final String alias;
  final String email;
  final String phone;
  final String barangay;
  final UserRole role;

  /// Bundled, uniquely generated profile illustration. Avatars are original
  /// TABANG artwork so fictional profiles never borrow a real person's face.
  final String? photoAsset;
  final DateTime registeredOn;
  final BloodType? bloodType;
  final DateTime? birthDate;

  /// Self-reported weight in kilograms. Donors must meet the eligibility
  /// engine's minimum before they can be matched.
  final double? weightKg;

  final AccountStatus status;
  final int warningCount;
  final String? suspensionReason;
  final DateTime? lastDonationDate;

  /// The component recorded for [lastDonationDate]. Kept for the audit trail
  /// and profile display; eligibility still evaluates the component the donor
  /// is being considered for, so a platelet donor is not shown a red-cell
  /// cooldown when asking about platelets.
  final BloodComponent? lastDonationComponent;

  final int totalDonations;
  final bool isAvailable;
  final bool bloodCardVerified;

  /// Whether the donor's barangay may be shown to other community users.
  /// Exact addresses are never stored or displayed.
  final bool shareBarangay;

  /// In-app notification preferences. Push delivery is outside this build.
  final bool notifyRequests;
  final bool notifyChat;
  final bool notifyNews;

  /// Whether the post-registration welcome guide has been shown.
  final bool onboardingCompleted;

  String get initials {
    final parts = fullName.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return (parts.first[0] + parts.last[0]).toUpperCase();
  }

  int? get age {
    final dob = birthDate;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  bool get isDonor => role == UserRole.donor;

  /// Public handle used on the map and donor directory.
  ///
  /// Aliases are friendly names and, on a map that anyone can browse, they
  /// still read as a person. The directory therefore shows a stable anonymous
  /// token instead; real names and aliases only surface in a thread after the
  /// mutual identity reveal.
  String get mapHandle {
    final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
    final number = digits.isEmpty ? id : digits;
    return 'Donor #$number';
  }

  AppUser copyWith({
    AccountStatus? status,
    int? warningCount,
    String? suspensionReason,
    bool clearSuspensionReason = false,
    bool? isAvailable,
    bool? bloodCardVerified,
    DateTime? lastDonationDate,
    BloodComponent? lastDonationComponent,
    int? totalDonations,
    BloodType? bloodType,
    double? weightKg,
    String? alias,
    String? phone,
    String? barangay,
    String? fullName,
    String? email,
    String? photoAsset,
    UserRole? role,
    DateTime? birthDate,
    bool? shareBarangay,
    bool? notifyRequests,
    bool? notifyChat,
    bool? notifyNews,
    bool? onboardingCompleted,
  }) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      alias: alias ?? this.alias,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      barangay: barangay ?? this.barangay,
      role: role ?? this.role,
      registeredOn: registeredOn,
      bloodType: bloodType ?? this.bloodType,
      birthDate: birthDate ?? this.birthDate,
      weightKg: weightKg ?? this.weightKg,
      photoAsset: photoAsset ?? this.photoAsset,
      status: status ?? this.status,
      warningCount: warningCount ?? this.warningCount,
      suspensionReason: clearSuspensionReason
          ? null
          : (suspensionReason ?? this.suspensionReason),
      lastDonationDate: lastDonationDate ?? this.lastDonationDate,
      lastDonationComponent:
          lastDonationComponent ?? this.lastDonationComponent,
      totalDonations: totalDonations ?? this.totalDonations,
      isAvailable: isAvailable ?? this.isAvailable,
      bloodCardVerified: bloodCardVerified ?? this.bloodCardVerified,
      shareBarangay: shareBarangay ?? this.shareBarangay,
      notifyRequests: notifyRequests ?? this.notifyRequests,
      notifyChat: notifyChat ?? this.notifyChat,
      notifyNews: notifyNews ?? this.notifyNews,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}

/// Urgency of a blood request.
enum RequestUrgency {
  routine('Routine'),
  urgent('Urgent'),
  critical('Critical');

  const RequestUrgency(this.label);
  final String label;
}

/// Lifecycle of a blood request.
enum RequestStatus {
  open('Open'),
  matched('Matched'),
  fulfilled('Fulfilled'),
  cancelled('Cancelled');

  const RequestStatus(this.label);
  final String label;
}

/// Where a request is being fulfilled from.
///
/// The paper's recipient flow (p.21) first checks participating facilities for
/// compatible stock. If stock exists the request goes to the blood bank for
/// processing; otherwise it is posted to the eligible donor network.
enum RequestSource {
  bloodBank('Blood bank'),
  donorNetwork('Donor network');

  const RequestSource(this.label);
  final String label;
}

/// A recipient's posted need for blood.
class BloodRequest {
  const BloodRequest({
    required this.id,
    required this.requesterId,
    required this.patientAlias,
    required this.bloodType,
    required this.component,
    required this.unitsNeeded,
    required this.hospital,
    required this.barangay,
    required this.urgency,
    required this.createdAt,
    this.status = RequestStatus.open,
    this.unitsFulfilled = 0,
    this.source = RequestSource.donorNetwork,
    this.note,
  });

  final String id;
  final String requesterId;

  /// Tokenized patient reference — never the real patient name.
  final String patientAlias;
  final BloodType bloodType;
  final BloodComponent component;
  final int unitsNeeded;
  final String hospital;
  final String barangay;
  final RequestUrgency urgency;
  final DateTime createdAt;
  final RequestStatus status;
  final int unitsFulfilled;
  final RequestSource source;
  final String? note;

  int get unitsOutstanding =>
      (unitsNeeded - unitsFulfilled).clamp(0, unitsNeeded);

  /// Only open donor-network requests accept new donor responses. Blood-bank
  /// requests are processed by chapter staff, not broadcast to donors.
  bool get acceptsDonorResponses =>
      status == RequestStatus.open &&
      source == RequestSource.donorNetwork &&
      unitsOutstanding > 0;

  BloodRequest copyWith({
    RequestStatus? status,
    int? unitsFulfilled,
    RequestSource? source,
  }) {
    return BloodRequest(
      id: id,
      requesterId: requesterId,
      patientAlias: patientAlias,
      bloodType: bloodType,
      component: component,
      unitsNeeded: unitsNeeded,
      hospital: hospital,
      barangay: barangay,
      urgency: urgency,
      createdAt: createdAt,
      status: status ?? this.status,
      unitsFulfilled: unitsFulfilled ?? this.unitsFulfilled,
      source: source ?? this.source,
      note: note,
    );
  }
}

/// A donor's offer to serve a specific request.
///
/// Responding does not consume a unit and does not change the request status.
/// The requester (or staff) selects among eligible responses, which is the
/// "prioritize eligible donor responses" step in the paper's recipient flow.
enum ResponseStatus {
  pending('Pending'),
  selected('Selected'),
  declined('Declined'),
  withdrawn('Withdrawn');

  const ResponseStatus(this.label);
  final String label;
}

class RequestResponse {
  const RequestResponse({
    required this.id,
    required this.requestId,
    required this.donorId,
    required this.donorAlias,
    required this.createdAt,
    this.message,
    this.status = ResponseStatus.pending,
  });

  final String id;
  final String requestId;
  final String donorId;
  final String donorAlias;
  final DateTime createdAt;
  final String? message;
  final ResponseStatus status;

  RequestResponse copyWith({ResponseStatus? status}) => RequestResponse(
    id: id,
    requestId: requestId,
    donorId: donorId,
    donorAlias: donorAlias,
    createdAt: createdAt,
    message: message,
    status: status ?? this.status,
  );
}

/// A moderation report raised from a chat thread.
enum ReportStatus {
  open('Open'),
  resolved('Resolved'),
  dismissed('Dismissed');

  const ReportStatus(this.label);
  final String label;
}

class UserReport {
  const UserReport({
    required this.id,
    required this.reporterId,
    required this.reporterAlias,
    required this.reportedUserId,
    required this.reportedAlias,
    required this.reason,
    required this.createdAt,
    this.threadId,
    this.status = ReportStatus.open,
  });

  final String id;
  final String reporterId;
  final String reporterAlias;
  final String reportedUserId;
  final String reportedAlias;
  final String reason;
  final DateTime createdAt;
  final String? threadId;
  final ReportStatus status;

  UserReport copyWith({ReportStatus? status}) => UserReport(
    id: id,
    reporterId: reporterId,
    reporterAlias: reporterAlias,
    reportedUserId: reportedUserId,
    reportedAlias: reportedAlias,
    reason: reason,
    createdAt: createdAt,
    threadId: threadId,
    status: status ?? this.status,
  );
}

/// Moderation state of a single chat message.
enum ModerationFlag {
  clean('Clean'),
  flagged('Flagged'),
  inappropriate('Inappropriate'),
  spam('Spam');

  const ModerationFlag(this.label);
  final String label;
}

/// One message inside a chat thread.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderAlias,
    required this.text,
    required this.sentAt,
    this.flag = ModerationFlag.clean,
  });

  final String id;
  final String senderId;
  final String senderAlias;
  final String text;
  final DateTime sentAt;
  final ModerationFlag flag;

  ChatMessage copyWith({ModerationFlag? flag}) => ChatMessage(
    id: id,
    senderId: senderId,
    senderAlias: senderAlias,
    text: text,
    sentAt: sentAt,
    flag: flag ?? this.flag,
  );
}

/// A conversation between two parties.
///
/// `identityRevealed` implements the double-blind rule: real names stay
/// hidden until both sides agree to proceed.
class ChatThread {
  const ChatThread({
    required this.id,
    required this.participantAId,
    required this.participantAAlias,
    required this.participantBId,
    required this.participantBAlias,
    required this.messages,
    this.identityRevealed = false,
    this.identityRevealRequestedBy,
    this.isMuted = false,
    this.unblockedAt,
  });

  final String id;
  final String participantAId;
  final String participantAAlias;
  final String participantBId;
  final String participantBAlias;
  final List<ChatMessage> messages;
  final bool identityRevealed;

  /// The participant who has asked to reveal identities. A reveal only takes
  /// effect when the *other* participant accepts, preserving the paper's
  /// double-blind rule.
  final String? identityRevealRequestedBy;
  final bool isMuted;
  final DateTime? unblockedAt;

  bool get hasFlaggedMessages =>
      messages.any((m) => m.flag != ModerationFlag.clean);

  int get flaggedCount =>
      messages.where((m) => m.flag != ModerationFlag.clean).length;

  ChatMessage? get lastMessage => messages.isEmpty ? null : messages.last;

  ChatThread copyWith({
    List<ChatMessage>? messages,
    bool? identityRevealed,
    String? identityRevealRequestedBy,
    bool clearIdentityRevealRequest = false,
    bool? isMuted,
    DateTime? unblockedAt,
    bool clearUnblockedAt = false,
  }) {
    return ChatThread(
      id: id,
      participantAId: participantAId,
      participantAAlias: participantAAlias,
      participantBId: participantBId,
      participantBAlias: participantBAlias,
      messages: messages ?? this.messages,
      identityRevealed: identityRevealed ?? this.identityRevealed,
      identityRevealRequestedBy: clearIdentityRevealRequest
          ? null
          : (identityRevealRequestedBy ?? this.identityRevealRequestedBy),
      isMuted: isMuted ?? this.isMuted,
      unblockedAt: clearUnblockedAt ? null : (unblockedAt ?? this.unblockedAt),
    );
  }
}

/// The medical-history statements asked in the donor interview. Kept in one
/// list so the form, the stored application and the staff review always agree.
const List<String> kDonorMedicalQuestions = [
  'Fever, cough or an infection in the last 7 days',
  'Alcohol in the last 24 hours',
  'Aspirin or pain relievers in the last 3 days',
  'Medication or a vaccine in the last 4 weeks',
  'Tattoo, piercing or acupuncture in the last 12 months',
  'Surgery or dental extraction in the last 12 months',
  'Pregnant or breastfeeding (female donors)',
  'Hepatitis B/C, HIV or a positive screening test',
  'Cancer, heart disease or a bleeding disorder',
  'Travel outside the Philippines in the last 12 months',
];

/// What a donor presents to chapter staff. Verification happens in person;
/// the app only tracks which requirements are still outstanding.
const List<String> kDonorRequirements = [
  'Valid government or school ID',
  'PRC blood donor card, if you have one',
  'List of current medications',
  'Chapter interview and physical examination',
  'Blood typing and infection screening',
];

enum DonorApplicationStatus {
  pending('Pending staff verification'),
  documentsRequested('Documents requested'),
  verified('Verified'),
  rejected('Not accepted');

  const DonorApplicationStatus(this.label);
  final String label;
}

/// One volunteer-donor registration interest submitted from Donor Hub.
///
/// Donor registration in the Philippines is completed face-to-face: the
/// interview, physical examination, blood typing and screening all happen at
/// the chapter, and the PRC interview sheet is filled in there. The app only
/// records the intent to register, whether the applicant already holds a
/// donor card, an optional preferred visit day, and what staff still asks for
/// — everything medical stays with the clinic.
class DonorApplication {
  const DonorApplication({
    required this.id,
    required this.userId,
    required this.submittedAt,
    required this.status,
    required this.hasExistingCard,
    this.cardNumber,
    this.preferredVisit,
    this.note,
    this.requestedDocuments = const [],
    this.staffNote,
  });

  final String id;
  final String userId;
  final DateTime submittedAt;
  final DonorApplicationStatus status;

  /// True when the applicant already holds a PRC blood donor card.
  final bool hasExistingCard;

  /// Donor-card number, when the applicant has one.
  final String? cardNumber;

  /// Day the applicant plans to visit the chapter, if they picked one.
  final DateTime? preferredVisit;
  final String? note;

  /// Requirements chapter staff has asked the applicant to present.
  final List<String> requestedDocuments;
  final String? staffNote;

  DonorApplication copyWith({
    DonorApplicationStatus? status,
    List<String>? requestedDocuments,
    String? staffNote,
    bool clearStaffNote = false,
  }) {
    return DonorApplication(
      id: id,
      userId: userId,
      submittedAt: submittedAt,
      status: status ?? this.status,
      hasExistingCard: hasExistingCard,
      cardNumber: cardNumber,
      preferredVisit: preferredVisit,
      note: note,
      requestedDocuments: requestedDocuments ?? this.requestedDocuments,
      staffNote: clearStaffNote ? null : (staffNote ?? this.staffNote),
    );
  }
}

/// A blood drive / donation event.
class BloodDrive {
  const BloodDrive({
    required this.id,
    required this.title,
    required this.venue,
    required this.barangay,
    required this.startsAt,
    required this.endsAt,
    required this.expectedDonors,
    this.isOpenForRegistration = true,
    this.lat,
    this.lng,
  });

  final String id;
  final String title;
  final String venue;
  final String barangay;
  final DateTime startsAt;
  final DateTime endsAt;
  final int expectedDonors;
  final bool isOpenForRegistration;

  /// Venue coordinates, so the map pin sits on the actual site rather than the
  /// barangay centroid. Null falls back to the barangay centre.
  final double? lat;
  final double? lng;

  String get status {
    final now = DateTime.now();
    if (now.isAfter(endsAt)) return 'Completed';
    if (now.isAfter(startsAt)) return 'Ongoing';
    return 'Upcoming';
  }
}

/// Educational / news content shown on the Discover page.
enum ContentCategory {
  explore('Explore'),
  tips('Donation Tips'),
  eligibility('Eligibility'),
  drives('Blood Drives'),
  stories('Stories');

  const ContentCategory(this.label);
  final String label;
}

class ContentItem {
  const ContentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.body,
    required this.tag,
    required this.category,
    this.imageAsset,
  });

  final String id;
  final String title;
  final String subtitle;
  final String body;
  final String tag;
  final ContentCategory category;

  /// Bundled photo shown on the card and in the article dialog.
  ///
  /// Null falls back to a themed vector/icon surface, so content can be added
  /// before artwork exists without leaving a broken image in the feed.
  final String? imageAsset;
}

/// Aggregate figures for the admin overview.
class AnalyticsSummary {
  const AnalyticsSummary({
    required this.donationsToday,
    required this.donationsThisMonth,
    required this.registeredUsers,
    required this.activeDonors,
    required this.activeDrives,
    required this.topBarangay,
    required this.unitsAvailable,
    required this.openRequests,
  });

  final int donationsToday;
  final int donationsThisMonth;
  final int registeredUsers;
  final int activeDonors;
  final int activeDrives;
  final String topBarangay;
  final int unitsAvailable;
  final int openRequests;
}

/// Donations vs. requests for one blood type.
class BloodTypeStat {
  const BloodTypeStat({
    required this.bloodType,
    required this.donated,
    required this.requested,
  });

  final BloodType bloodType;
  final int donated;
  final int requested;

  /// Positive means supply exceeds demand.
  int get balance => donated - requested;
}

/// Donation volume for one barangay.
class BarangayStat {
  const BarangayStat({
    required this.barangay,
    required this.donationCount,
    required this.donorCount,
  });

  final String barangay;
  final int donationCount;
  final int donorCount;
}

/// A request for a blood-bank appointment.
///
/// The checklist asks for an "appointment with blood" form covering the blood
/// type, patient name, donation type, patient hospital/ward and amount. This
/// record is deliberately a *booking request*: chapter staff confirm the slot
/// and perform the clinical screening before any unit is allocated.
class DonationAppointment {
  const DonationAppointment({
    required this.id,
    required this.requesterId,
    required this.patientName,
    required this.bloodType,
    required this.component,
    required this.hospital,
    required this.ward,
    required this.units,
    required this.scheduledAt,
    this.status = 'Pending confirmation',
    this.note,
  });

  final String id;
  final String requesterId;
  final String patientName;
  final BloodType bloodType;
  final BloodComponent component;
  final String hospital;
  final String ward;
  final int units;
  final DateTime scheduledAt;
  final String status;
  final String? note;
}
