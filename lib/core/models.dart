/// Core domain models for TABANG.
///
/// This file is the single source of truth for the data shapes used across
/// both the donor-facing and admin-facing surfaces. The previous build
/// declared `BloodUnit`, `BloodType` and `BloodComponent` twice (once in
/// `blood_bank_page.dart`, once in `admin_data/blood_bank_service.dart`) with
/// two different inventories. That duplication is gone: everything imports
/// from here.
library;

import 'dart:typed_data';

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

  /// Staff and admin verify blood cards and decide donor applications.
  bool get canVerifyDonors => isAdminSide;

  /// Staff and admin run the shelf: new units, status changes, releases.
  bool get canManageInventory => isAdminSide;

  /// Staff and admin work the request queue and confirm appointments.
  bool get canFulfillRequests => isAdminSide;

  /// Moderation is shared by the chapter console.
  bool get canModerate => isAdminSide;

  /// Only an admin adds staff or manages another staff/admin account.
  bool get canAddStaff => this == UserRole.admin;
  bool get canManageStaff => this == UserRole.admin;

  /// Short human-readable capability list for the permissions card.
  List<String> get capabilities => switch (this) {
    UserRole.admin => const [
      'Everything Clinical Personnel can do',
      'Create and manage all accounts, including staff',
      'Issue warnings, suspend and reinstate',
      'Set the chapter readiness targets',
      'Full audit of inventory, requests and moderation',
    ],
    UserRole.staff => const [
      'Verify blood cards and decide donor applications',
      'Add stock, change unit status and release units',
      'Work the request queue and confirm appointments',
      'Moderate chat, warnings and reports',
    ],
    _ => const [
      'Request blood and message donors',
      'Register as a donor from Donor Hub',
    ],
  };

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
    this.lastActiveAt,
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

  /// Last time the donor was active in TABANG (sign-in or a directory action).
  /// The eligibility engine treats a donor who has been away for more than
  /// [EligibilityEngine.awayAfterDays] as unavailable automatically, even when
  /// the manual availability switch is still on.
  final DateTime? lastActiveAt;

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
    DateTime? lastActiveAt,
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
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      bloodCardVerified: bloodCardVerified ?? this.bloodCardVerified,
      shareBarangay: shareBarangay ?? this.shareBarangay,
      notifyRequests: notifyRequests ?? this.notifyRequests,
      notifyChat: notifyChat ?? this.notifyChat,
      notifyNews: notifyNews ?? this.notifyNews,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    );
  }
}

/// Urgency of a blood request, stated as a response window rather than a bare
/// label so requesters and staff read the same expectation.
enum RequestUrgency {
  routine('Routine', 'Planned — book a blood-bank slot'),
  urgent('Urgent', 'Needed within 24–48 hours'),
  critical('Critical', 'Needed the same day');

  const RequestUrgency(this.label, this.detail);
  final String label;
  final String detail;
}

/// Lifecycle of a blood request.
///
/// Nothing reaches the donor network or the inventory queue until chapter
/// staff have checked the documents: a request starts in [pendingReview] and
/// is either opened by [verifyRequest] or rejected with a reason.
enum RequestStatus {
  pendingReview('Awaiting verification'),
  open('Open'),
  matched('Matched'),
  fulfilled('Fulfilled'),
  rejected('Rejected'),
  cancelled('Cancelled');

  const RequestStatus(this.label);
  final String label;
}

/// Documents a requester must line up before chapter staff verify a request.
class RequestDocuments {
  const RequestDocuments._();

  static const String doctorsForm = "Doctor's request form";
  static const String transfusionSlip = 'Blood transfusion slip';
  static const String patientId = 'Valid hospital patient ID';
  static const String typingResult = 'Blood typing / cross-match result';

  static const List<String> all = [
    doctorsForm,
    transfusionSlip,
    patientId,
    typingResult,
  ];

  /// The three documents every request must carry. The typing result is only
  /// required by some hospitals, so it is optional.
  static const List<String> required = [
    doctorsForm,
    transfusionSlip,
    patientId,
  ];
}

/// One file actually attached to a blood request.
///
/// A checkbox is not evidence: staff need the file the requester sent. [bytes]
/// holds the uploaded payload for requests created in this session; seeded
/// requests carry [fileName] only, representing documents already on file with
/// the chapter.
class RequestDocument {
  const RequestDocument({
    required this.kind,
    required this.fileName,
    this.bytes,
    this.sizeBytes = 0,
  });

  /// One of the [RequestDocuments] constants, so the checklist and the file
  /// are stored under the same label.
  final String kind;
  final String fileName;

  /// Uploaded content, or null when the document is already on file at the
  /// chapter (seed data).
  final Uint8List? bytes;
  final int sizeBytes;

  bool get hasFile => bytes != null;

  String get sizeLabel {
    if (sizeBytes <= 0) return '';
    if (sizeBytes < 1024) return '$sizeBytes B';
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(0)} KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }
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
    this.status = RequestStatus.pendingReview,
    this.unitsFulfilled = 0,
    this.source = RequestSource.donorNetwork,
    this.note,
    this.documents = const [],
    this.scheduledFor,
    this.postToDonorNetwork = true,
    this.reviewNote,
    this.reviewedById,
    this.assignedUnitIds = const [],
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

  /// Files uploaded at submission and checked by staff during verification.
  final List<RequestDocument> documents;

  /// The blood-bank slot the requester booked. Always inside the chapter's
  /// published schedule; staff can still adjust it when verifying.
  final DateTime? scheduledFor;

  /// Whether the requester agreed to broadcast to the donor network when the
  /// blood bank cannot cover the request.
  final bool postToDonorNetwork;

  /// Why staff rejected or adjusted the request.
  final String? reviewNote;
  final String? reviewedById;

  /// Units the blood bank put on hold for this request when it was verified.
  final List<String> assignedUnitIds;

  int get unitsOutstanding =>
      (unitsNeeded - unitsFulfilled).clamp(0, unitsNeeded);

  bool get isAwaitingReview => status == RequestStatus.pendingReview;

  /// Only verified open donor-network requests accept new donor responses.
  /// Blood-bank requests are processed by chapter staff, not broadcast.
  bool get acceptsDonorResponses =>
      status == RequestStatus.open &&
      source == RequestSource.donorNetwork &&
      postToDonorNetwork &&
      unitsOutstanding > 0;

  BloodRequest copyWith({
    RequestStatus? status,
    int? unitsFulfilled,
    RequestSource? source,
    List<RequestDocument>? documents,
    DateTime? scheduledFor,
    bool? postToDonorNetwork,
    String? reviewNote,
    bool clearReviewNote = false,
    String? reviewedById,
    List<String>? assignedUnitIds,
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
      documents: documents ?? this.documents,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      postToDonorNetwork: postToDonorNetwork ?? this.postToDonorNetwork,
      reviewNote: clearReviewNote ? null : (reviewNote ?? this.reviewNote),
      reviewedById: reviewedById ?? this.reviewedById,
      assignedUnitIds: assignedUnitIds ?? this.assignedUnitIds,
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
    this.details,
    this.threadId,
    this.status = ReportStatus.open,
  });

  final String id;
  final String reporterId;
  final String reporterAlias;
  final String reportedUserId;
  final String reportedAlias;

  /// Short category chosen from the report dialog.
  final String reason;

  /// The reporter's own explanation of what happened. Kept separate from
  /// [reason] so staff can see both the category and the full context.
  final String? details;
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
    details: details,
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
    this.flagReason,
  });

  final String id;
  final String senderId;
  final String senderAlias;
  final String text;
  final DateTime sentAt;
  final ModerationFlag flag;

  /// Which phrase the keyword classifier matched, so staff can see why a
  /// message was flagged instead of trusting an opaque badge.
  final String? flagReason;

  ChatMessage copyWith({ModerationFlag? flag, String? flagReason}) =>
      ChatMessage(
        id: id,
        senderId: senderId,
        senderAlias: senderAlias,
        text: text,
        sentAt: sentAt,
        flag: flag ?? this.flag,
        flagReason: flagReason ?? this.flagReason,
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
    this.participantAReadAt,
    this.participantBReadAt,
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

  /// When each participant last opened the conversation. A reply that arrives
  /// after this instant is new activity for that person.
  final DateTime? participantAReadAt;
  final DateTime? participantBReadAt;

  DateTime? readAtFor(String userId) {
    if (userId == participantAId) return participantAReadAt;
    if (userId == participantBId) return participantBReadAt;
    return null;
  }

  /// Messages from the other participant that have not been read yet. System
  /// notices and the reader's own messages are never counted.
  int unreadCountFor(String userId) {
    final readAt = readAtFor(userId);
    return messages.where((message) {
      if (message.senderId == userId || message.senderId == 'system') {
        return false;
      }
      return readAt == null || message.sentAt.isAfter(readAt);
    }).length;
  }

  bool hasUnreadFor(String userId) => unreadCountFor(userId) > 0;

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
    DateTime? participantAReadAt,
    DateTime? participantBReadAt,
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
      participantAReadAt: participantAReadAt ?? this.participantAReadAt,
      participantBReadAt: participantBReadAt ?? this.participantBReadAt,
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

/// Admin-editable planning targets behind the readiness score.
///
/// The score itself is never typed in by hand: it is computed live from the
/// chapter's units, donors, requests and accounts. Admins set the denominators
/// (what "full marks" means for this chapter) so the score reflects local
/// capacity instead of a fixed number chosen by the developer.
class ReadinessTargets {
  const ReadinessTargets({
    this.unitTarget = 32,
    this.donorTarget = 20,
    this.requestPressureCap = 16,
    this.communityTarget = 60,
  });

  /// Usable units on the shelf that count as full supply coverage.
  final int unitTarget;

  /// Eligible, available donors that count as full donor capacity.
  final int donorTarget;

  /// Open requests at which the request-pressure bar scores zero.
  final int requestPressureCap;

  /// Registered accounts that count as full community reach.
  final int communityTarget;

  static const ReadinessTargets defaults = ReadinessTargets();

  /// Every target must be a positive whole number; a zero denominator would
  /// divide by zero or make the bar meaningless.
  bool get isValid =>
      unitTarget > 0 &&
      donorTarget > 0 &&
      requestPressureCap > 0 &&
      communityTarget > 0;

  ReadinessTargets copyWith({
    int? unitTarget,
    int? donorTarget,
    int? requestPressureCap,
    int? communityTarget,
  }) {
    return ReadinessTargets(
      unitTarget: unitTarget ?? this.unitTarget,
      donorTarget: donorTarget ?? this.donorTarget,
      requestPressureCap: requestPressureCap ?? this.requestPressureCap,
      communityTarget: communityTarget ?? this.communityTarget,
    );
  }

  String describe() =>
      '$unitTarget units · $donorTarget donors · '
      '$requestPressureCap request cap · $communityTarget accounts';

  @override
  bool operator ==(Object other) =>
      other is ReadinessTargets &&
      other.unitTarget == unitTarget &&
      other.donorTarget == donorTarget &&
      other.requestPressureCap == requestPressureCap &&
      other.communityTarget == communityTarget;

  @override
  int get hashCode =>
      Object.hash(unitTarget, donorTarget, requestPressureCap, communityTarget);
}

/// What a chapter activity entry records.
///
/// Staff use this feed to answer two operational questions after the fact:
/// which transfusions were recorded and for whom, and who changed their
/// account information or profile photo.
enum ActivityKind {
  donation,
  donationWindow,
  profile,
  avatar,
  verification,
  warning,
  suspension,
  application,
  report,
  requestSubmitted,
  requestVerified,
  requestRejected,
  inventory,
  readinessTargets,
}

/// One entry in the chapter activity log, newest first.
class ActivityEvent {
  const ActivityEvent({
    required this.id,
    required this.kind,
    required this.actorId,
    required this.actorAlias,
    required this.summary,
    required this.at,
    this.subjectId,
    this.subjectAlias,
  });

  final String id;
  final ActivityKind kind;

  /// The account that performed the action. Falls back to the chapter account
  /// for seeded entries and background updates.
  final String actorId;
  final String actorAlias;

  /// The account the action affected, when there is one.
  final String? subjectId;
  final String? subjectAlias;

  /// One line a staff member can scan, e.g.
  /// `Recorded a whole blood donation for Tere`.
  final String summary;
  final DateTime at;

  bool get isDonation => kind == ActivityKind.donation;
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
