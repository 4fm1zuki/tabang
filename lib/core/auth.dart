import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import 'eligibility.dart';
import 'models.dart';
import 'repository.dart';

/// Outcome of a staff-initiated account creation.
///
/// The generated password is returned exactly once so the staff member can
/// hand it to the new user; it is never stored in plain text.
class ManagedUserResult {
  const ManagedUserResult._({this.user, this.password, this.error});

  factory ManagedUserResult.success(AppUser user, String password) =>
      ManagedUserResult._(user: user, password: password);

  factory ManagedUserResult.failure(String error) =>
      ManagedUserResult._(error: error);

  final AppUser? user;
  final String? password;
  final String? error;

  bool get ok => user != null;
}

/// Outcome of a sign-in or registration attempt.
class AuthResult {
  const AuthResult._({required this.ok, this.user, this.error});

  factory AuthResult.success(AppUser user) =>
      AuthResult._(ok: true, user: user);

  factory AuthResult.failure(String error) =>
      AuthResult._(ok: false, error: error);

  final bool ok;
  final AppUser? user;
  final String? error;
}

/// Credential-based authentication for the TABANG prototype.
///
/// The paper (p.28) specifies "user authentication and registration via email
/// credentials and Google OAuth 2.0". This service implements the email
/// credential half against the local simulated store: passwords are salted and
/// SHA-256 hashed, never held in plain text, and every sign-in is checked
/// before a session is created.
///
/// Two properties matter for the study:
///
/// 1. **No self-service admin.** [register] rejects [UserRole.admin] and
///    [UserRole.staff]. Administrative roles exist only on seeded accounts.
///    The previous build let anyone pick "System Admin" from a dropdown.
/// 2. **Sessions are explicit.** [signOut] clears the current user, and the
///    router reacts to that. There is no path from the login screen to the
///    admin dashboard without valid credentials.
///
/// Google OAuth is not wired in this build because it requires a provisioned
/// OAuth client. [googleOAuthConfigured] reports that honestly so the UI can
/// say so rather than pretending.
class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  final TabangRepository _repo = TabangRepository.instance;

  /// email (lowercased) -> salted hash
  final Map<String, String> _credentials = {};

  static const String _salt = 'tabang::2026';

  /// Whether a Google OAuth client is provisioned for this build.
  bool get googleOAuthConfigured => false;

  String _hash(String password) {
    return sha256.convert(utf8.encode('$_salt|$password')).toString();
  }

  /// Seed credentials for the demo accounts.
  ///
  /// These are intentionally documented so the panel can sign in. In a real
  /// deployment they would be provisioned, not hardcoded.
  void bootstrap() {
    if (_credentials.isNotEmpty) return;

    // Demo passwords — documented in README.
    _credentials['iverson.briones@tabang.app'] = _hash('donor1234');
    _credentials['tere.santos@tabang.app'] = _hash('donor1234');
    // Inactive donor: signs in to demonstrate the automatic "away" state.
    _credentials['rafael.mendoza@tabang.app'] = _hash('donor1234');
    _credentials['maria.santos@tabang.app'] = _hash('recipient1234');
    _credentials['community@tabang.app'] = _hash('community1234');
    _credentials['staff@tabang.app'] = _hash('staff1234');
    _credentials['admin@tabang.app'] = _hash('admin1234');
  }

  /// Validate credentials and start a session.
  AuthResult signIn({required String email, required String password}) {
    bootstrap();

    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) {
      return AuthResult.failure('Enter your email address.');
    }
    if (password.isEmpty) {
      return AuthResult.failure('Enter your password.');
    }

    final stored = _credentials[normalized];
    if (stored == null) {
      return AuthResult.failure('No account found for that email address.');
    }
    if (stored != _hash(password)) {
      return AuthResult.failure('Incorrect password. Please try again.');
    }

    final user = _repo.userByEmail(normalized);
    if (user == null) {
      return AuthResult.failure('Account record is missing. Contact support.');
    }
    if (user.status == AccountStatus.suspended) {
      return AuthResult.failure(
        user.suspensionReason == null
            ? 'This account is suspended.'
            : 'This account is suspended: ${user.suspensionReason}',
      );
    }

    _repo.signIn(user);
    return AuthResult.success(user);
  }

  /// Create an account and start a session.
  ///
  /// Self-registration always creates a [UserRole.user] community account.
  /// Donor status is a later, opt-in upgrade so new users can request blood and
  /// browse safely before exposing themselves in the donor directory.
  AuthResult register({
    required String fullName,
    required String alias,
    required String email,
    required String password,
    required String phone,
    required String barangay,
    UserRole role = UserRole.user,
    BloodType? bloodType,
    DateTime? birthDate,
    double? weightKg,
  }) {
    bootstrap();

    final normalized = email.trim().toLowerCase();

    if (fullName.trim().length < 3) {
      return AuthResult.failure('Enter your full name.');
    }
    final aliasError = _validateAlias(alias, fullName);
    if (aliasError != null) return AuthResult.failure(aliasError);
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      return AuthResult.failure('Enter a valid email address.');
    }
    if (_credentials.containsKey(normalized)) {
      return AuthResult.failure('An account with that email already exists.');
    }
    if (password.length < 8) {
      return AuthResult.failure('Password must be at least 8 characters.');
    }
    if (role == UserRole.admin || role == UserRole.staff) {
      return AuthResult.failure(
        'Administrative accounts are provisioned by the Red Cross chapter '
        'and cannot be self-registered.',
      );
    }
    if (role != UserRole.user) {
      return AuthResult.failure(
        'Create a community account first, then register as a donor from '
        'your profile.',
      );
    }
    if (role == UserRole.donor && bloodType == null) {
      return AuthResult.failure(
        'Select your blood type to register as a donor.',
      );
    }
    if (role == UserRole.donor && birthDate == null) {
      return AuthResult.failure(
        'Enter your birth date to register as a donor.',
      );
    }
    if (role == UserRole.donor && weightKg == null) {
      return AuthResult.failure('Enter your weight to register as a donor.');
    }
    if (role == UserRole.donor &&
        weightKg != null &&
        (weightKg < 20 || weightKg > 300)) {
      return AuthResult.failure('Enter a weight between 20 and 300 kg.');
    }
    if (role == UserRole.donor && birthDate != null) {
      final age = _ageOn(birthDate, DateTime.now());
      if (age < EligibilityEngine.minimumAge) {
        return AuthResult.failure(
          'Donors must be at least ${EligibilityEngine.minimumAge} years old.',
        );
      }
      if (age > EligibilityEngine.maximumAge) {
        return AuthResult.failure(
          'Donors must be ${EligibilityEngine.maximumAge} years old or younger.',
        );
      }
    }

    final user = _repo.register(
      fullName: fullName.trim(),
      alias: alias.trim(),
      email: normalized,
      phone: phone.trim(),
      barangay: barangay,
      role: role,
      bloodType: bloodType,
      birthDate: birthDate,
      weightKg: weightKg,
    );

    _credentials[normalized] = _hash(password);
    _repo.signIn(user);
    return AuthResult.success(user);
  }

  /// Create an account on behalf of a walk-in donor or patient representative.
  ///
  /// Staff may create community accounts; only an admin may create another
  /// staff account, and nobody can create an admin account from inside the
  /// app. A temporary password is generated and returned once for the staff
  /// member to hand over.
  ManagedUserResult adminCreateUser({
    required String actorId,
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
    bootstrap();

    final actor = _repo.userById(actorId);
    if (actor == null || !actor.role.isAdminSide) {
      return ManagedUserResult.failure(
        'Only chapter staff or admins can create accounts.',
      );
    }
    if (role == UserRole.admin) {
      return ManagedUserResult.failure(
        'Admin accounts are provisioned outside the app.',
      );
    }
    if (role == UserRole.staff && actor.role != UserRole.admin) {
      return ManagedUserResult.failure(
        'Only an admin can create another staff account.',
      );
    }

    final normalized = email.trim().toLowerCase();
    if (fullName.trim().length < 3) {
      return ManagedUserResult.failure('Enter the full name.');
    }
    final aliasError = _validateAlias(alias, fullName);
    if (aliasError != null) return ManagedUserResult.failure(aliasError);
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(normalized)) {
      return ManagedUserResult.failure('Enter a valid email address.');
    }
    if (_credentials.containsKey(normalized)) {
      return ManagedUserResult.failure(
        'An account with that email already exists.',
      );
    }
    if (role == UserRole.donor) {
      if (bloodType == null) {
        return ManagedUserResult.failure('Select the donor\'s blood type.');
      }
      if (birthDate == null) {
        return ManagedUserResult.failure('Enter the donor\'s birth date.');
      }
      if (weightKg == null || weightKg < 20 || weightKg > 300) {
        return ManagedUserResult.failure(
          'Enter a weight between 20 and 300 kg.',
        );
      }
      final age = _ageOn(birthDate, DateTime.now());
      if (age < EligibilityEngine.minimumAge ||
          age > EligibilityEngine.maximumAge) {
        return ManagedUserResult.failure(
          'Donors must be between ${EligibilityEngine.minimumAge} and '
          '${EligibilityEngine.maximumAge} years old.',
        );
      }
    }

    final password = _generatePassword();
    final user = _repo.register(
      fullName: fullName.trim(),
      alias: alias.trim(),
      email: normalized,
      phone: phone.trim(),
      barangay: barangay,
      role: role,
      bloodType: bloodType,
      birthDate: birthDate,
      weightKg: weightKg,
    );
    _credentials[normalized] = _hash(password);
    return ManagedUserResult.success(user, password);
  }

  /// Nicknames are the only public identity, so they must be unique and must
  /// not simply repeat the legal name the anonymity rule is protecting.
  String? _validateAlias(String alias, String fullName) {
    final trimmed = alias.trim();
    if (trimmed.length < 2) {
      return 'Choose a nickname of at least 2 characters.';
    }
    if (trimmed.toLowerCase() == fullName.trim().toLowerCase()) {
      return 'Choose a nickname, not your full name. Other users only see '
          'the nickname.';
    }
    if (_repo.isAliasTaken(trimmed)) {
      return 'That nickname is already taken. Choose another.';
    }
    return null;
  }

  String _generatePassword() {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final body = List.generate(
      8,
      (_) => alphabet[random.nextInt(alphabet.length)],
    ).join();
    return 'tab-$body';
  }

  /// Register the signed-in community user as a volunteer donor.
  ///
  /// The record starts unverified: chapter staff must review the blood card
  /// before the donor becomes visible in matching.
  AuthResult registerAsDonor({
    required String userId,
    required BloodType bloodType,
    required DateTime birthDate,
    required double weightKg,
  }) {
    final user = _repo.userById(userId);
    if (user == null) {
      return AuthResult.failure('Sign in before registering as a donor.');
    }
    if (user.role == UserRole.donor) {
      return AuthResult.failure('This account is already a donor.');
    }
    if (!user.role.canRegisterAsDonor) {
      return AuthResult.failure(
        'Staff and administrator accounts cannot register as donors.',
      );
    }
    final age = _ageOn(birthDate, DateTime.now());
    if (age < EligibilityEngine.minimumAge) {
      return AuthResult.failure(
        'Donors must be at least ${EligibilityEngine.minimumAge} years old.',
      );
    }
    if (age > EligibilityEngine.maximumAge) {
      return AuthResult.failure(
        'Donors must be ${EligibilityEngine.maximumAge} years old or younger.',
      );
    }
    if (weightKg < EligibilityEngine.minimumWeightKg || weightKg > 300) {
      return AuthResult.failure(
        'Enter a weight of at least ${EligibilityEngine.minimumWeightKg.toInt()} kg.',
      );
    }
    final ok = _repo.upgradeToDonor(
      userId: userId,
      bloodType: bloodType,
      birthDate: birthDate,
      weightKg: weightKg,
    );
    if (!ok) return AuthResult.failure('Could not update the donor profile.');
    return AuthResult.success(_repo.userById(userId)!);
  }

  void signOut() => _repo.signOut();

  AppUser? get currentUser => _repo.currentUser;

  /// Whole-year age on [on], accounting for whether the birthday has occurred.
  static int _ageOn(DateTime birthDate, DateTime on) {
    var age = on.year - birthDate.year;
    if (on.month < birthDate.month ||
        (on.month == birthDate.month && on.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
