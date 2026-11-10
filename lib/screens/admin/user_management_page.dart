import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/auth.dart';
import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';
import '../../widgets/filter_bar.dart';
import '../../widgets/photo.dart';
import '../donor/chat_page.dart';

/// User management for chapter staff.
///
/// Staff can verify blood cards, issue warnings, suspend and reinstate donor and
/// recipient accounts, and record donations. Role authorization is enforced
/// here as well as in the shell: staff cannot manage their own account or any
/// staff/admin account. Only an admin can manage another staff member. Actions
/// mutate the shared repository, so a suspension immediately removes that donor
/// from the directory and from eligibility.
class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key, required this.currentUser});

  final AppUser currentUser;

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final TabangRepository _repo = TabangRepository.instance;
  final TextEditingController _search = TextEditingController();

  AccountStatus? _statusFilter;
  UserRole? _roleFilter;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    _search.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<AppUser> get _users {
    return _repo.users.where((u) {
      if (_statusFilter != null && u.status != _statusFilter) return false;
      if (_roleFilter != null && u.role != _roleFilter) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        final matches =
            u.fullName.toLowerCase().contains(q) ||
            u.alias.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            u.barangay.toLowerCase().contains(q);
        if (!matches) return false;
      }
      return true;
    }).toList();
  }

  /// Self-service and privilege escalation guard.
  ///
  /// A staff account must never be able to suspend, warn, verify or record a
  /// donation for itself, another staff account, or an admin. An admin can
  /// manage staff and community accounts but still cannot act on itself.
  bool _canManage(AppUser user) {
    if (user.id == widget.currentUser.id) return false;
    switch (widget.currentUser.role) {
      case UserRole.admin:
        return true;
      case UserRole.staff:
        return user.role == UserRole.user ||
            user.role == UserRole.donor ||
            user.role == UserRole.recipient;
      case UserRole.user:
      case UserRole.donor:
      case UserRole.recipient:
        return false;
    }
  }

  String? _protectedLabel(AppUser user) {
    if (user.id == widget.currentUser.id) return 'This is you';
    if (!_canManage(user)) return 'Protected';
    return null;
  }

  /// Walk-in account creation.
  ///
  /// Every field is a fixed choice or an obvious text box, matching the same
  /// registration data. Role options follow the privilege rules: staff may
  /// create community accounts, and only an admin sees the staff option.
  void _showCreateUserDialog(BuildContext context) {
    final actor = _repo.userById(widget.currentUser.id) ?? widget.currentUser;
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final aliasController = TextEditingController();
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final weightController = TextEditingController();

    var role = UserRole.donor;
    var barangay = DigosBarangays.all.first;
    BloodType? bloodType;
    DateTime? birthDate;
    String? error;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          final isDonor = role == UserRole.donor;
          return AlertDialog(
            title: const Text('Create account'),
            content: SizedBox(
              width: 460,
              child: Form(
                key: formKey,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'For walk-in donors and patient representatives. '
                        'TABANG generates a temporary password and shows it '
                        'once for you to hand over.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.5,
                          color: context.textMuted,
                        ),
                      ),
                      const SizedBox(height: TabangSpace.lg),
                      DropdownButtonFormField<UserRole>(
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: [
                          const DropdownMenuItem(
                            value: UserRole.donor,
                            child: Text('Voluntary Donor'),
                          ),
                          const DropdownMenuItem(
                            value: UserRole.recipient,
                            child: Text('Recipient / Patient Representative'),
                          ),
                          if (actor.role == UserRole.admin)
                            const DropdownMenuItem(
                              value: UserRole.staff,
                              child: Text('Clinical Personnel'),
                            ),
                        ],
                        onChanged: (v) => setDialogState(() {
                          role = v ?? UserRole.donor;
                          error = null;
                        }),
                      ),
                      const SizedBox(height: TabangSpace.md),
                      TextFormField(
                        controller: nameController,
                        decoration: const InputDecoration(
                          labelText: 'Full name',
                        ),
                        validator: (v) => (v == null || v.trim().length < 3)
                            ? 'Enter the full name'
                            : null,
                      ),
                      const SizedBox(height: TabangSpace.md),
                      TextFormField(
                        controller: aliasController,
                        decoration: const InputDecoration(
                          labelText: 'Nickname (public)',
                          helperText:
                              'The only name other users see; must be unique',
                        ),
                        validator: (v) {
                          final alias = v?.trim() ?? '';
                          if (alias.length < 2) return 'Choose a nickname';
                          if (alias.toLowerCase() ==
                              nameController.text.trim().toLowerCase()) {
                            return 'Use a nickname, not the full name';
                          }
                          if (_repo.isAliasTaken(alias)) {
                            return 'That nickname is already taken';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: TabangSpace.md),
                      TextFormField(
                        controller: emailController,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Email address',
                        ),
                        validator: (v) =>
                            RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(v?.trim() ?? '')
                            ? null
                            : 'Enter a valid email',
                      ),
                      const SizedBox(height: TabangSpace.md),
                      TextFormField(
                        controller: phoneController,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Contact number',
                        ),
                        validator: (v) => (v == null || v.trim().length < 7)
                            ? 'Enter a contact number'
                            : null,
                      ),
                      const SizedBox(height: TabangSpace.md),
                      DropdownButtonFormField<String>(
                        initialValue: barangay,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Barangay',
                        ),
                        items: DigosBarangays.all
                            .map(
                              (b) => DropdownMenuItem(value: b, child: Text(b)),
                            )
                            .toList(),
                        onChanged: (v) =>
                            setDialogState(() => barangay = v ?? barangay),
                      ),
                      if (isDonor) ...[
                        const SizedBox(height: TabangSpace.md),
                        DropdownButtonFormField<BloodType>(
                          initialValue: bloodType,
                          decoration: const InputDecoration(
                            labelText: 'Blood type',
                          ),
                          items: BloodType.values
                              .map(
                                (t) => DropdownMenuItem(
                                  value: t,
                                  child: Text(t.label),
                                ),
                              )
                              .toList(),
                          onChanged: (v) => setDialogState(() => bloodType = v),
                          validator: (v) =>
                              v == null ? 'Select the blood type' : null,
                        ),
                        const SizedBox(height: TabangSpace.md),
                        TextFormField(
                          readOnly: true,
                          decoration: const InputDecoration(
                            labelText: 'Birth date',
                            suffixIcon: Icon(Icons.event_outlined, size: 18),
                          ),
                          controller: TextEditingController(
                            text: birthDate == null
                                ? ''
                                : formatDate(birthDate!),
                          ),
                          onTap: () async {
                            final now = DateTime.now();
                            final picked = await showDatePicker(
                              context: dialogContext,
                              initialDate: DateTime(
                                now.year - 25,
                                now.month,
                                now.day,
                              ),
                              firstDate: DateTime(now.year - 100),
                              lastDate: now,
                            );
                            if (picked != null) {
                              setDialogState(() => birthDate = picked);
                            }
                          },
                          validator: (_) => birthDate == null
                              ? 'Select the birth date'
                              : null,
                        ),
                        const SizedBox(height: TabangSpace.md),
                        TextFormField(
                          controller: weightController,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                            helperText: 'At least 50 kg is required to donate',
                          ),
                          validator: (v) {
                            final weight = double.tryParse(v?.trim() ?? '');
                            if (weight == null || weight < 20 || weight > 300) {
                              return 'Enter a weight between 20 and 300 kg';
                            }
                            return null;
                          },
                        ),
                      ],
                      if (error != null) ...[
                        const SizedBox(height: TabangSpace.md),
                        Text(
                          error!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: TabangColors.danger,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  if (!formKey.currentState!.validate()) return;
                  final result = AuthService.instance.adminCreateUser(
                    actorId: actor.id,
                    fullName: nameController.text.trim(),
                    alias: aliasController.text.trim(),
                    email: emailController.text.trim(),
                    phone: phoneController.text.trim(),
                    barangay: barangay,
                    role: role,
                    bloodType: isDonor ? bloodType : null,
                    birthDate: isDonor ? birthDate : null,
                    weightKg: isDonor
                        ? double.tryParse(weightController.text.trim())
                        : null,
                  );
                  if (!result.ok) {
                    setDialogState(() => error = result.error);
                    return;
                  }
                  Navigator.pop(dialogContext);
                  _showCredentialsDialog(context, result);
                },
                child: const Text('Create account'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _showCredentialsDialog(BuildContext context, ManagedUserResult result) {
    final user = result.user!;
    final credentials =
        'Email: ${user.email}\nTemporary password: ${result.password}';

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Account created'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${user.fullName} · ${user.alias}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: TabangSpace.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(TabangSpace.md),
                decoration: BoxDecoration(
                  color: context.surfaceAlt,
                  borderRadius: BorderRadius.circular(TabangRadius.sm),
                ),
                child: SelectableText(
                  credentials,
                  style: const TextStyle(
                    fontSize: 12.5,
                    height: 1.6,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              const SizedBox(height: TabangSpace.sm),
              Text(
                'This password is shown once and is stored only as a hash. '
                'Ask the user to change it after signing in.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: credentials));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Credentials copied.')),
                );
              }
            },
            icon: const Icon(Icons.copy_all_outlined, size: 15),
            label: const Text('Copy'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    final pending = _repo.users
        .where((u) => u.status == AccountStatus.unverified)
        .length;

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'User management',
            subtitle:
                'Verify donors, issue warnings and manage account standing.',
            actions: [
              OutlinedButton.icon(
                onPressed: () => _showCreateUserDialog(context),
                icon: const Icon(Icons.person_add_alt_1_outlined, size: 15),
                label: const Text('Create user'),
              ),
              if (pending > 0)
                StatusPill(
                  '$pending awaiting verification',
                  tone: Tone.warning,
                  icon: Icons.pending_outlined,
                ),
            ],
          ),
          const SizedBox(height: TabangSpace.xl),

          // Donor registrations submitted from Donor Hub. They are a different
          // queue from account status: the applicant is already a user, staff
          // just has to verify the blood card before they can donate.
          if (_repo.openDonorApplications.isNotEmpty) ...[
            _buildApplicationsCard(context, _repo.openDonorApplications),
            const SizedBox(height: TabangSpace.lg),
          ],

          TabangFilterBar(
            search: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Name, alias, email, barangay',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 17),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 15),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
            filters: [
              DropdownButtonFormField<AccountStatus?>(
                initialValue: _statusFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Status',
                  isDense: true,
                ),
                style: TextStyle(fontSize: 12.5, color: context.textColor),
                items: [
                  const DropdownMenuItem<AccountStatus?>(
                    value: null,
                    child: Text('All statuses'),
                  ),
                  ...AccountStatus.values.map(
                    (s) => DropdownMenuItem<AccountStatus?>(
                      value: s,
                      child: Text(s.label),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _statusFilter = v),
              ),
              DropdownButtonFormField<UserRole?>(
                initialValue: _roleFilter,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  isDense: true,
                ),
                style: TextStyle(fontSize: 12.5, color: context.textColor),
                items: [
                  const DropdownMenuItem<UserRole?>(
                    value: null,
                    child: Text('All roles'),
                  ),
                  ...UserRole.values.map(
                    (r) => DropdownMenuItem<UserRole?>(
                      value: r,
                      child: Text(r.label),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _roleFilter = v),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          if (users.isEmpty)
            const EmptyState(
              icon: Icons.people_outline,
              title: 'No users match these filters',
            )
          else
            ...users.map(
              (u) => Padding(
                padding: const EdgeInsets.only(bottom: TabangSpace.md),
                child: _buildUserCard(context, u),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildApplicationsCard(
    BuildContext context,
    List<DonorApplication> applications,
  ) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.how_to_reg_outlined,
                size: 18,
                color: TabangColors.crimson,
              ),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Text(
                  'Donor registrations awaiting staff',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: context.textColor,
                  ),
                ),
              ),
              StatusPill(
                '${applications.length}',
                tone: Tone.warning,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'These users already have accounts; verifying the blood card is '
            'what lets them donate and appear in the directory. Interview them '
            'and complete the screening before verifying.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: TabangSpace.md),
          for (final application in applications)
            _applicationRow(context, application),
        ],
      ),
    );
  }

  Widget _applicationRow(BuildContext context, DonorApplication application) {
    final user = _repo.userById(application.userId);

    return Container(
      margin: const EdgeInsets.only(bottom: TabangSpace.sm),
      padding: const EdgeInsets.all(TabangSpace.md),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              BloodTypeChip(user?.bloodType ?? BloodType.oPos, size: 30),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.fullName ?? application.userId,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    Text(
                      '${user?.alias ?? ''} · form ${application.id} · '
                      '${formatRelative(application.submittedAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                ),
              ),
              StatusPill(
                application.status.label,
                tone:
                    application.status ==
                        DonorApplicationStatus.documentsRequested
                    ? Tone.info
                    : Tone.warning,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            application.hasExistingCard
                ? 'Already has a PRC donor card'
                      '${application.cardNumber == null ? '' : ' · ${application.cardNumber}'}'
                      ' — verify the card on site'
                : 'Needs a new donor card — full first-time process on site',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: context.textMuted,
            ),
          ),
          if (application.preferredVisit != null)
            Text(
              'Plans to visit ${formatDate(application.preferredVisit!)}',
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: context.textMuted,
              ),
            ),
          if (application.note != null && application.note!.isNotEmpty)
            Text(
              'Note: ${application.note}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                height: 1.4,
                color: context.textMuted,
              ),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: TabangSpace.sm,
            runSpacing: TabangSpace.sm,
            children: [
              FilledButton.icon(
                onPressed: () => _decideApplication(
                  context,
                  application,
                  DonorApplicationStatus.verified,
                  note: 'Verified at the chapter.',
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: TabangSpace.md,
                  ),
                ),
                icon: const Icon(Icons.verified_outlined, size: 16),
                label: const Text('Verify donor'),
              ),
              OutlinedButton.icon(
                onPressed: () => _decideApplication(
                  context,
                  application,
                  DonorApplicationStatus.documentsRequested,
                  note: 'Please present your ID and complete the screening.',
                  requestedDocuments: kDonorRequirements,
                ),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 38),
                  padding: const EdgeInsets.symmetric(
                    horizontal: TabangSpace.md,
                  ),
                ),
                icon: const Icon(Icons.request_page_outlined, size: 16),
                label: const Text('Request documents'),
              ),
              TextButton.icon(
                onPressed: () => _showApplicationDetails(context, application),
                icon: const Icon(Icons.article_outlined, size: 16),
                label: const Text('View form'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _decideApplication(
    BuildContext context,
    DonorApplication application,
    DonorApplicationStatus status, {
    String? note,
    List<String>? requestedDocuments,
  }) {
    _repo.setDonorApplicationStatus(
      application.userId,
      status,
      note: note,
      requestedDocuments: requestedDocuments,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          status == DonorApplicationStatus.verified
              ? 'Donor verified. They can donate from their next eligible date.'
              : 'Applicant notified: ${status.label.toLowerCase()}.',
        ),
      ),
    );
  }

  void _showApplicationDetails(
    BuildContext context,
    DonorApplication application,
  ) {
    final user = _repo.userById(application.userId);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Donor form ${application.id}'),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _applicationDetail(
                  dialogContext,
                  'Applicant',
                  user?.fullName ?? application.userId,
                ),
                _applicationDetail(dialogContext, 'Alias', user?.alias ?? '—'),
                _applicationDetail(
                  dialogContext,
                  'Barangay',
                  user?.barangay ?? '—',
                ),
                _applicationDetail(
                  dialogContext,
                  'Blood type',
                  user?.bloodType?.label ?? 'Not known yet',
                ),
                _applicationDetail(
                  dialogContext,
                  'Donor card',
                  application.hasExistingCard
                      ? 'Has a card'
                            '${application.cardNumber == null ? '' : ' · ${application.cardNumber}'}'
                      : 'Needs a new card',
                ),
                _applicationDetail(
                  dialogContext,
                  'Planned visit',
                  application.preferredVisit == null
                      ? 'Not set'
                      : formatDate(application.preferredVisit!),
                ),
                if (application.note != null && application.note!.isNotEmpty)
                  _applicationDetail(
                    dialogContext,
                    'Applicant note',
                    application.note!,
                  ),
                _applicationDetail(
                  dialogContext,
                  'Submitted',
                  formatRelative(application.submittedAt),
                ),
                _applicationDetail(
                  dialogContext,
                  'Status',
                  application.status.label,
                ),
                const SizedBox(height: 8),
                Text(
                  'Medical data is collected on the PRC interview sheet at the '
                  'chapter — the app deliberately does not store it.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: dialogContext.textMuted,
                  ),
                ),
                if (application.requestedDocuments.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Requested documents',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: dialogContext.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  for (final document in application.requestedDocuments)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 3),
                      child: Text(
                        '• $document',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.4,
                          color: dialogContext.textMuted,
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _decideApplication(
                context,
                application,
                DonorApplicationStatus.rejected,
                note: 'Not accepted at this time.',
              );
            },
            child: const Text(
              'Not accepted',
              style: TextStyle(color: TabangColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  Widget _applicationDetail(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: context.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, AppUser user) {
    final eligibility = EligibilityEngine.evaluate(user);
    final isDonor = user.role == UserRole.donor;

    return SurfaceCard(
      onTap: () => _showUserDetails(context, user),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipOval(
                child: SizedBox(
                  width: 38,
                  height: 38,
                  child: TabangPhoto(
                    user.photoAsset,
                    semanticLabel: '${user.alias} profile photo',
                    creditLabel: user.alias,
                    fallbackIcon: Icons.person_outline,
                    fallbackIconSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: TabangSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Wrap, not Row: on a phone the pills drop to the next
                    // line instead of squeezing the name to one character.
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          user.fullName,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textColor,
                          ),
                        ),
                        StatusPill(
                          user.status.label,
                          tone: toneForAccount(user.status),
                          dense: true,
                        ),
                        StatusPill(
                          user.role.label,
                          tone: Tone.neutral,
                          dense: true,
                        ),
                        if (user.warningCount > 0)
                          StatusPill(
                            '${user.warningCount} warning'
                            '${user.warningCount == 1 ? '' : 's'}',
                            tone: Tone.warning,
                            dense: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${user.alias} · ${user.email} · ${user.barangay}',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                    if (isDonor) ...[
                      const SizedBox(height: 3),
                      Wrap(
                        spacing: TabangSpace.sm,
                        runSpacing: 2,
                        children: [
                          if (user.bloodType != null)
                            Text(
                              user.bloodType!.label,
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: TabangColors.crimson,
                              ),
                            ),
                          if (user.weightKg != null)
                            Text(
                              '${user.weightKg!.toStringAsFixed(0)} kg',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textMuted,
                              ),
                            ),
                          Text(
                            '${user.totalDonations} donations · '
                            'RBC: ${eligibility.summary}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: eligibility.isEligible
                                  ? TabangColors.success
                                  : context.textMuted,
                            ),
                          ),
                          if (user.lastDonationComponent != null)
                            Text(
                              'last: ${user.lastDonationComponent!.label}',
                              style: TextStyle(
                                fontSize: 11,
                                color: context.textMuted,
                              ),
                            ),
                        ],
                      ),
                    ],
                    if (user.suspensionReason != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        'Reason: ${user.suspensionReason}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: TabangColors.danger,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          _buildActions(context, user),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context, AppUser user) {
    if (user.id == widget.currentUser.id) {
      return const StatusPill('This is you', tone: Tone.neutral, dense: true);
    }

    final protected = _protectedLabel(user);
    final isDonor = user.role == UserRole.donor;
    final canRecord =
        isDonor &&
        user.status != AccountStatus.suspended &&
        user.status != AccountStatus.unverified;

    final actions = <Widget>[
      _messageButton(context, user),
      if (protected != null)
        StatusPill(protected, tone: Tone.neutral, dense: true)
      else ...[
        if (canRecord)
          OutlinedButton.icon(
            onPressed: () => _recordDonation(context, user),
            icon: const Icon(Icons.bloodtype_outlined, size: 14),
            label: const Text('Record donation'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: TabangSpace.md,
                vertical: TabangSpace.sm,
              ),
            ),
          ),
        if (isDonor)
          OutlinedButton.icon(
            onPressed: () => _editDonationWindow(context, user),
            icon: const Icon(Icons.event_repeat_outlined, size: 14),
            label: const Text('Donation window'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: TabangSpace.md,
                vertical: TabangSpace.sm,
              ),
            ),
          ),
        if (user.status == AccountStatus.unverified)
          ElevatedButton.icon(
            onPressed: () => _repo.verifyUser(user.id),
            icon: const Icon(Icons.verified_outlined, size: 14),
            label: const Text('Verify'),
            style: ElevatedButton.styleFrom(
              backgroundColor: TabangColors.success,
              padding: const EdgeInsets.symmetric(
                horizontal: TabangSpace.md,
                vertical: TabangSpace.sm,
              ),
            ),
          ),
        if (user.status != AccountStatus.suspended)
          OutlinedButton.icon(
            onPressed: () => _confirmWarn(context, user),
            icon: const Icon(Icons.flag_outlined, size: 14),
            label: const Text('Warn'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: TabangSpace.md,
                vertical: TabangSpace.sm,
              ),
            ),
          ),
        if (user.status == AccountStatus.suspended)
          ElevatedButton.icon(
            onPressed: () =>
                _repo.setUserStatus(user.id, AccountStatus.verified),
            icon: const Icon(Icons.lock_open, size: 14),
            label: const Text('Reinstate'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: TabangSpace.md,
                vertical: TabangSpace.sm,
              ),
            ),
          )
        else
          OutlinedButton.icon(
            onPressed: () => _confirmSuspend(context, user),
            icon: const Icon(Icons.block, size: 14),
            label: const Text('Suspend'),
            style: OutlinedButton.styleFrom(
              foregroundColor: TabangColors.danger,
              padding: const EdgeInsets.symmetric(
                horizontal: TabangSpace.md,
                vertical: TabangSpace.sm,
              ),
            ),
          ),
      ],
    ];

    return Wrap(
      spacing: TabangSpace.sm,
      runSpacing: TabangSpace.sm,
      children: actions,
    );
  }

  Widget _messageButton(BuildContext context, AppUser user) {
    return OutlinedButton.icon(
      onPressed: () => _openConversation(context, user),
      icon: const Icon(Icons.chat_bubble_outline, size: 14),
      label: const Text('Message'),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: TabangSpace.md,
          vertical: TabangSpace.sm,
        ),
      ),
    );
  }

  void _openConversation(BuildContext context, AppUser user) {
    final thread = _repo.startConversation(
      initiatorId: widget.currentUser.id,
      otherId: user.id,
    );
    if (thread == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'That conversation cannot be opened. The account may be blocked.',
          ),
        ),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text('Message ${user.alias}'),
            leading: const BackButton(),
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(gradient: TabangGradients.page(context)),
            child: ChatPage(
              user: widget.currentUser,
              allowNewConversation: true,
              initialThreadId: thread.id,
            ),
          ),
        ),
      ),
    );
  }

  /// Staff-only detail sheet. Shows the full account record, including contact
  /// details and the live donation window, without exposing it to the directory.
  void _showUserDetails(BuildContext context, AppUser user) {
    final eligibility = EligibilityEngine.evaluate(user);
    final isDonor = user.role == UserRole.donor;
    final other = user.id == widget.currentUser.id;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            ClipOval(
              child: SizedBox(
                width: 38,
                height: 38,
                child: TabangPhoto(
                  user.photoAsset,
                  semanticLabel: '${user.alias} profile photo',
                  creditLabel: user.alias,
                  fallbackIcon: Icons.person_outline,
                  fallbackIconSize: 18,
                ),
              ),
            ),
            const SizedBox(width: TabangSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: const TextStyle(fontSize: 15)),
                  Text(
                    '${user.alias} · ${user.role.label}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w400,
                      color: dialogContext.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 460),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    StatusPill(
                      user.status.label,
                      tone: toneForAccount(user.status),
                      dense: true,
                    ),
                    StatusPill(
                      user.role.label,
                      tone: Tone.neutral,
                      dense: true,
                    ),
                    if (user.warningCount > 0)
                      StatusPill(
                        '${user.warningCount} warning'
                        '${user.warningCount == 1 ? '' : 's'}',
                        tone: Tone.warning,
                        dense: true,
                      ),
                  ],
                ),
                const SizedBox(height: TabangSpace.md),
                _detailRow(dialogContext, 'Email', user.email),
                _detailRow(dialogContext, 'Phone', user.phone),
                _detailRow(dialogContext, 'Barangay', user.barangay),
                _detailRow(
                  dialogContext,
                  'Registered',
                  formatDate(user.registeredOn),
                ),
                if (isDonor) ...[
                  const Divider(height: TabangSpace.xl),
                  _detailRow(
                    dialogContext,
                    'Blood type',
                    user.bloodType?.label ?? 'Not recorded',
                  ),
                  _detailRow(
                    dialogContext,
                    'Birth date',
                    user.birthDate == null
                        ? 'Not recorded'
                        : formatDate(user.birthDate!),
                  ),
                  _detailRow(
                    dialogContext,
                    'Weight',
                    user.weightKg == null
                        ? 'Not recorded'
                        : '${user.weightKg!.toStringAsFixed(0)} kg',
                  ),
                  _detailRow(
                    dialogContext,
                    'Donations',
                    '${user.totalDonations}',
                  ),
                  _detailRow(
                    dialogContext,
                    'Last donation',
                    user.lastDonationDate == null
                        ? 'None recorded'
                        : formatDate(user.lastDonationDate!),
                  ),
                  _detailRow(
                    dialogContext,
                    'Component',
                    user.lastDonationComponent?.label ?? 'Not recorded',
                  ),
                  _detailRow(
                    dialogContext,
                    'Blood card',
                    user.bloodCardVerified ? 'Verified' : 'Not verified',
                  ),
                  _detailRow(
                    dialogContext,
                    'Directory',
                    user.isAvailable ? 'Visible' : 'Hidden by donor',
                  ),
                  _detailRow(dialogContext, 'Eligibility', eligibility.summary),
                ],
                if (user.suspensionReason != null) ...[
                  const Divider(height: TabangSpace.xl),
                  _detailRow(
                    dialogContext,
                    'Suspension reason',
                    user.suspensionReason!,
                  ),
                ],
                const Divider(height: TabangSpace.xl),
                Text(
                  'Recent activity',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: dialogContext.textColor,
                  ),
                ),
                const SizedBox(height: TabangSpace.sm),
                ..._activityLines(dialogContext, user),
                const SizedBox(height: TabangSpace.md),
                Text(
                  'Contact details and this record are visible to chapter '
                  'staff and administrators only.',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.45,
                    color: dialogContext.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
          if (!other) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _openConversation(context, user);
              },
              icon: const Icon(Icons.chat_bubble_outline, size: 15),
              label: const Text('Message'),
            ),
            if (isDonor)
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(dialogContext);
                  _editDonationWindow(context, user);
                },
                icon: const Icon(Icons.event_repeat_outlined, size: 15),
                label: const Text('Donation window'),
              ),
          ],
        ],
      ),
    );
  }

  List<Widget> _activityLines(BuildContext context, AppUser user) {
    final events = _repo.activityFor(user.id).take(4).toList(growable: false);
    if (events.isEmpty) {
      return [
        Text(
          'No recorded activity yet.',
          style: TextStyle(fontSize: 12, color: context.textMuted),
        ),
      ];
    }
    return [
      for (final event in events)
        Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.history, size: 13, color: context.textMuted),
              const SizedBox(width: 6),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: event.summary,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: context.textColor,
                        ),
                      ),
                      TextSpan(
                        text: ' · ${formatRelative(event.at)}',
                        style: TextStyle(
                          fontSize: 11.5,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
    ];
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 128,
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: context.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _editDonationWindow(BuildContext context, AppUser user) {
    var date = user.lastDonationDate ?? DateTime.now();
    var component = user.lastDonationComponent ?? BloodComponent.packedRbc;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Donation window · ${user.alias}'),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Use this after a transfusion or late data entry. It moves '
                  'the cooldown anchor without counting another donation.',
                  style: TextStyle(fontSize: 12.5, height: 1.5),
                ),
                const SizedBox(height: TabangSpace.md),
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: dialogContext,
                      initialDate: date,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                      setDialogState(() => date = picked);
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text('Last donation: ${formatDate(date)}'),
                ),
                const SizedBox(height: TabangSpace.sm),
                DropdownButtonFormField<BloodComponent>(
                  initialValue: component,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Component donated',
                  ),
                  items: BloodComponent.values
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => component = value ?? component),
                ),
                const SizedBox(height: TabangSpace.sm),
                Text(
                  '${EligibilityEngine.cooldownFor(component)}-day cooldown '
                  'applies to ${component.label.toLowerCase()}.',
                  style: TextStyle(
                    fontSize: 11,
                    color: dialogContext.textMuted,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _repo.updateDonationWindow(
                  user.id,
                  lastDonationDate: date,
                  component: component,
                );
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Donation window updated for ${user.alias}.'),
                  ),
                );
              },
              child: const Text('Update window'),
            ),
          ],
        ),
      ),
    );
  }

  void _recordDonation(BuildContext context, AppUser user) {
    var component = BloodComponent.packedRbc;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text('Record donation for ${user.fullName}?'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'This records a completed donation today, increments the '
                  'donation count and starts the component-specific cooldown. '
                  'It does not change blood-bank inventory; add the unit '
                  'separately in inventory management.',
                  style: TextStyle(fontSize: 12.5, height: 1.55),
                ),
                const SizedBox(height: TabangSpace.md),
                DropdownButtonFormField<BloodComponent>(
                  initialValue: component,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Component donated',
                  ),
                  items: BloodComponent.values
                      .map(
                        (c) => DropdownMenuItem(value: c, child: Text(c.label)),
                      )
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => component = v ?? component),
                ),
                const SizedBox(height: TabangSpace.sm),
                Text(
                  '${EligibilityEngine.cooldownFor(component)}-day cooldown '
                  'will apply to ${component.label.toLowerCase()}.',
                  style: const TextStyle(fontSize: 11),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                _repo.recordDonation(user.id, component: component);
                Navigator.pop(dialogContext);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Donation recorded for ${user.alias}. Cooldown updated.',
                    ),
                  ),
                );
              },
              child: const Text('Record donation'),
            ),
          ],
        ),
      ),
    );
  }

  /// A warning is a recorded moderation decision, not a repeatable tap.
  /// Staff enter the reason, the count is capped at three, and the account is
  /// suspended automatically on the third. Suspended accounts cannot be warned
  /// again until they are reinstated, which resets the count.
  void _confirmWarn(BuildContext context, AppUser user) {
    final reasonController = TextEditingController();
    final next = (user.warningCount + 1).clamp(1, 3);
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Warn ${user.fullName}?'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                next >= 3
                    ? 'This is warning 3 of 3. The account is suspended '
                          'automatically.'
                    : 'This adds warning $next of 3. The warning is recorded '
                          'on the account and shown to staff.',
                style: const TextStyle(fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: TabangSpace.md),
              TextField(
                controller: reasonController,
                autofocus: true,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (recorded on the account)',
                  hintText: 'e.g. Asked for payment in a coordination thread',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final ok = _repo.warnUser(user.id, reason: reasonController.text);
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    ok
                        ? 'Warning $next issued to ${user.alias}.'
                        : 'That account can no longer be warned.',
                  ),
                ),
              );
            },
            child: const Text('Issue warning'),
          ),
        ],
      ),
    );
  }

  void _confirmSuspend(BuildContext context, AppUser user) {
    final reasonController = TextEditingController();

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Suspend ${user.fullName}?'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A suspended account cannot sign in, appear in the donor '
                'directory, or respond to requests.',
                style: TextStyle(fontSize: 12.5, height: 1.5),
              ),
              const SizedBox(height: TabangSpace.md),
              TextField(
                controller: reasonController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Reason (recorded on the account)',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              _repo.setUserStatus(
                user.id,
                AccountStatus.suspended,
                reason: reasonController.text.trim().isEmpty
                    ? 'Suspended by chapter staff.'
                    : reasonController.text.trim(),
              );
              Navigator.pop(dialogContext);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: TabangColors.danger,
            ),
            child: const Text('Suspend account'),
          ),
        ],
      ),
    );
  }
}
