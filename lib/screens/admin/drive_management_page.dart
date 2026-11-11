import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/layout.dart';

/// Blood-drive management for the chapter.
///
/// Staff propose a drive; an admin approves or rejects it; an admin can cancel a
/// drive that is already scheduled. Only approved drives reach the donor-facing
/// surfaces, and every decision in here reports itself through a snackbar whose
/// Undo puts the drive back where it was — so a mis-tap never silently drops a
/// scheduled drive or publishes an unreviewed one.
class DriveManagementPage extends StatefulWidget {
  const DriveManagementPage({
    super.key,
    required this.currentUser,
    this.embedded = false,
  });

  final AppUser currentUser;

  /// Inside [OperationsWorkspacePage] the page supplies no header of its own.
  final bool embedded;

  @override
  State<DriveManagementPage> createState() => _DriveManagementPageState();
}

class _DriveManagementPageState extends State<DriveManagementPage> {
  final TabangRepository _repo = TabangRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Only an admin approves, rejects or cancels; staff can propose.
  bool get _isAdmin => widget.currentUser.role.canManageStaff;

  /// Chapter staff and admins may propose; only admins decide.
  bool get _canPropose => widget.currentUser.role.isAdminSide;

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    final pending = _repo.pendingDrives;
    final scheduled = _repo.allDrives
        .where((d) => d.approval == DriveApproval.approved)
        .toList()
      ..sort((a, b) => a.startsAt.compareTo(b.startsAt));
    final cancelled = _repo.cancelledDrives;
    final rejected = _repo.allDrives
        .where((d) => d.approval == DriveApproval.rejected)
        .toList();

    return SingleChildScrollView(
      padding: widget.embedded
          ? EdgeInsets.fromLTRB(pad.left, 0, pad.right, pad.bottom)
          : pad,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!widget.embedded)
            PageHeader(
              title: 'Blood drives',
              subtitle:
                  'Propose a drive for approval, and manage the schedule once '
                  'it is approved.',
              actions: [
                if (_canPropose)
                  FilledButton.icon(
                    onPressed: () => _openAddDrive(),
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Add drive'),
                  ),
              ],
            )
          else
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Propose a drive, then track it here until an admin '
                    'approves it.',
                    style: TextStyle(fontSize: 12.5, color: context.textMuted),
                  ),
                ),
                if (_canPropose)
                  FilledButton.icon(
                    onPressed: () => _openAddDrive(),
                    icon: const Icon(Icons.add, size: 15),
                    label: const Text('Add drive'),
                  ),
              ],
            ),
          const SizedBox(height: TabangSpace.lg),

          if (pending.isNotEmpty) ...[
            _sectionLabel(context, 'Awaiting approval'),
            for (final drive in pending) _pendingCard(context, drive),
            const SizedBox(height: TabangSpace.lg),
          ],

          _sectionLabel(context, 'Scheduled'),
          if (scheduled.isEmpty)
            const EmptyState(
              art: TabangArt.inventory,
              title: 'No drives scheduled',
              message: 'Approved drives appear here and on the donor Home page.',
            )
          else
            for (final drive in scheduled) _scheduledCard(context, drive),

          if (rejected.isNotEmpty) ...[
            const SizedBox(height: TabangSpace.lg),
            _sectionLabel(context, 'Rejected'),
            for (final drive in rejected) _rejectedCard(context, drive),
          ],

          if (cancelled.isNotEmpty) ...[
            const SizedBox(height: TabangSpace.lg),
            _sectionLabel(context, 'Cancelled'),
            for (final drive in cancelled) _cancelledCard(context, drive),
          ],
        ],
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.sm),
      child: SectionLabel(text),
    );
  }

  // ------------------------------------------------------------------ cards

  Widget _pendingCard(BuildContext context, BloodDrive drive) {
    final proposer = _repo.userById(drive.proposedById ?? '');
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.all(TabangSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _driveTitle(context, drive)),
                StatusPill(drive.approval.label, tone: Tone.warning, dense: true),
              ],
            ),
            _driveFacts(context, drive),
            if (proposer != null)
              Text(
                'Proposed by ${proposer.alias}',
                style: TextStyle(fontSize: 11.5, color: context.textMuted),
              ),
            if (drive.reviewNote != null)
              Text(
                'Note: ${drive.reviewNote}',
                style: TextStyle(fontSize: 11.5, color: context.textMuted),
              ),
            const SizedBox(height: TabangSpace.sm),
            Wrap(
              spacing: TabangSpace.sm,
              runSpacing: TabangSpace.sm,
              children: [
                if (_isAdmin) ...[
                  FilledButton(
                    onPressed: () => _approve(drive),
                    child: const Text('Approve'),
                  ),
                  TextButton(
                    onPressed: () => _reject(drive),
                    child: const Text('Reject'),
                  ),
                ] else
                  Text(
                    'An admin must approve this before it is published.',
                    style: TextStyle(fontSize: 11.5, color: context.textMuted),
                  ),
                if (_isAdmin || drive.proposedById == widget.currentUser.id)
                  TextButton(
                    onPressed: () => _withdraw(drive),
                    child: const Text('Withdraw'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _scheduledCard(BuildContext context, BloodDrive drive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.all(TabangSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _driveTitle(context, drive)),
                StatusPill(
                  drive.status,
                  tone: drive.status == 'Ongoing' ? Tone.success : Tone.info,
                  dense: true,
                ),
              ],
            ),
            _driveFacts(context, drive),
            if (_isAdmin) ...[
              const SizedBox(height: TabangSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _cancel(drive),
                  icon: const Icon(Icons.event_busy_outlined, size: 16),
                  label: const Text('Cancel drive'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _rejectedCard(BuildContext context, BloodDrive drive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.all(TabangSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _driveTitle(context, drive)),
                const StatusPill('Rejected', tone: Tone.danger, dense: true),
              ],
            ),
            if (drive.reviewNote != null)
              Text(
                drive.reviewNote!,
                style: TextStyle(fontSize: 11.5, color: context.textMuted),
              ),
            if (_isAdmin) ...[
              const SizedBox(height: TabangSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _undoRejection(drive),
                  child: const Text('Back to the queue'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _cancelledCard(BuildContext context, BloodDrive drive) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.sm),
      child: SurfaceCard(
        padding: const EdgeInsets.all(TabangSpace.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: _driveTitle(context, drive)),
                const StatusPill('Cancelled', tone: Tone.neutral, dense: true),
              ],
            ),
            _driveFacts(context, drive),
            if (_isAdmin) ...[
              const SizedBox(height: TabangSpace.sm),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _restore(drive),
                  child: const Text('Restore drive'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _driveTitle(BuildContext context, BloodDrive drive) {
    return Text(
      drive.title,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: context.textColor,
      ),
    );
  }

  Widget _driveFacts(BuildContext context, BloodDrive drive) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Text(
        '${drive.venue} · ${drive.barangay} · '
        '${formatDateTime(drive.startsAt)} to '
        '${formatDateTime(drive.endsAt)} · '
        '${drive.expectedDonors} expected',
        style: TextStyle(fontSize: 11.5, color: context.textMuted),
      ),
    );
  }

  // ---------------------------------------------------------------- actions

  Future<void> _approve(BloodDrive drive) async {
    final ok = await confirmAction(
      context,
      title: 'Approve this drive?',
      message:
          '${drive.title} will be published to donors on the Home page and the '
          'map as soon as it is approved.',
      confirmLabel: 'Approve',
    );
    if (!ok || !mounted) return;
    final approved = _repo.approveDrive(
      drive.id,
      actorId: widget.currentUser.id,
    );
    _report(
      context,
      approved ? '${drive.title} is scheduled.' : 'That drive is no longer pending.',
      undo: approved
          ? () => _repo.undoDriveApproval(
              drive.id,
              actorId: widget.currentUser.id,
            )
          : null,
      undone: 'Approval undone; the drive is back in the queue.',
    );
  }

  Future<void> _reject(BloodDrive drive) async {
    final reason = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject this drive?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The proposer sees your reason.',
              style: TextStyle(fontSize: 12.5, color: dialogContext.textMuted),
            ),
            const SizedBox(height: TabangSpace.sm),
            TextField(
              controller: reason,
              autofocus: true,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Reason (optional)',
                isDense: true,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final rejected = _repo.rejectDriveProposal(
      drive.id,
      actorId: widget.currentUser.id,
      reason: reason.text,
    );
    _report(
      context,
      rejected ? '${drive.title} was rejected.' : 'That drive is no longer pending.',
      undo: rejected
          ? () => _repo.undoDriveRejection(
              drive.id,
              actorId: widget.currentUser.id,
            )
          : null,
      undone: 'Rejection undone; the drive is back in the queue.',
    );
  }

  Future<void> _cancel(BloodDrive drive) async {
    final ok = await confirmAction(
      context,
      title: 'Cancel this drive?',
      message:
          '${drive.title} will be removed from the donor Home page and the map. '
          'You can restore it from here, or with Undo.',
      confirmLabel: 'Cancel drive',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final cancelled = _repo.cancelBloodDrive(
      drive.id,
      actorId: widget.currentUser.id,
    );
    _report(
      context,
      cancelled ? '${drive.title} was cancelled.' : 'That drive is not scheduled.',
      undo: cancelled
          ? () => _repo.undoDriveCancellation(
              drive.id,
              actorId: widget.currentUser.id,
            )
          : null,
      undone: 'Cancellation undone; the drive is scheduled again.',
    );
  }

  Future<void> _withdraw(BloodDrive drive) async {
    final ok = await confirmAction(
      context,
      title: 'Withdraw this proposal?',
      message: '${drive.title} will be removed from the approval queue.',
      confirmLabel: 'Withdraw',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final withdrawn = _repo.withdrawDriveProposal(
      drive.id,
      actorId: widget.currentUser.id,
    );
    _report(
      context,
      withdrawn ? 'Proposal withdrawn.' : 'That proposal cannot be withdrawn.',
    );
  }

  void _undoRejection(BloodDrive drive) {
    final restored = _repo.undoDriveRejection(
      drive.id,
      actorId: widget.currentUser.id,
    );
    if (restored) setState(() {});
  }

  void _restore(BloodDrive drive) {
    final restored = _repo.undoDriveCancellation(
      drive.id,
      actorId: widget.currentUser.id,
    );
    if (restored) setState(() {});
  }

  /// Reports the outcome of a decision and, when it worked, offers Undo.
  void _report(
    BuildContext context,
    String message, {
    VoidCallback? undo,
    String? undone,
  }) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
        action: undo == null
            ? null
            : SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  undo();
                  if (undone != null) {
                    messenger.showSnackBar(SnackBar(content: Text(undone)));
                  }
                },
              ),
      ),
    );
  }

  Future<void> _openAddDrive() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => _AddDriveDialog(
        onSubmit: (draft) {
          final drive = _repo.proposeBloodDrive(
            actorId: widget.currentUser.id,
            title: draft.title,
            venue: draft.venue,
            barangay: draft.barangay,
            startsAt: draft.startsAt,
            endsAt: draft.endsAt,
            expectedDonors: draft.expectedDonors,
            note: draft.note,
          );
          if (drive == null) return false;
          _report(
            context,
            '${drive.title} was sent for approval.',
            undo: () =>
                _repo.withdrawDriveProposal(drive.id, actorId: widget.currentUser.id),
            undone: 'Proposal withdrawn.',
          );
          return true;
        },
      ),
    );
  }
}

/// What the add-drive form produces.
class _DriveDraft {
  const _DriveDraft({
    required this.title,
    required this.venue,
    required this.barangay,
    required this.startsAt,
    required this.endsAt,
    required this.expectedDonors,
    this.note,
  });

  final String title;
  final String venue;
  final String barangay;
  final DateTime startsAt;
  final DateTime endsAt;
  final int expectedDonors;
  final String? note;
}

/// Venue, barangay, window and headcount for a proposed drive.
class _AddDriveDialog extends StatefulWidget {
  const _AddDriveDialog({required this.onSubmit});

  /// Returns true when the drive was accepted, so the dialog can close.
  final bool Function(_DriveDraft draft) onSubmit;

  @override
  State<_AddDriveDialog> createState() => _AddDriveDialogState();
}

class _AddDriveDialogState extends State<_AddDriveDialog> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _donors = TextEditingController(text: '60');
  final _note = TextEditingController();

  String? _barangay;
  DateTime _startDate = DateTime.now().add(const Duration(days: 7));
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 15, minute: 0);

  DateTime get _startsAt => DateTime(
    _startDate.year,
    _startDate.month,
    _startDate.day,
    _startTime.hour,
    _startTime.minute,
  );
  DateTime get _endsAt => DateTime(
    _startDate.year,
    _startDate.month,
    _startDate.day,
    _endTime.hour,
    _endTime.minute,
  );

  @override
  void dispose() {
    _title.dispose();
    _venue.dispose();
    _donors.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add a blood drive'),
      content: SizedBox(
        width: 420,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'The drive is sent to the chapter admin for approval before '
                  'donors see it.',
                  style: TextStyle(fontSize: 12.5, color: context.textMuted),
                ),
                const SizedBox(height: TabangSpace.md),
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(
                    labelText: 'Drive title',
                    hintText: 'e.g. Barangay Ruparan Health Drive',
                    isDense: true,
                  ),
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Give the drive a title'
                      : null,
                ),
                const SizedBox(height: TabangSpace.sm),
                TextFormField(
                  controller: _venue,
                  decoration: const InputDecoration(
                    labelText: 'Venue',
                    hintText: 'e.g. Ruparan Covered Court',
                    isDense: true,
                  ),
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Where is it held?' : null,
                ),
                const SizedBox(height: TabangSpace.sm),
                DropdownButtonFormField<String>(
                  initialValue: _barangay,
                  isDense: true,
                  decoration: const InputDecoration(
                    labelText: 'Barangay',
                    isDense: true,
                  ),
                  items: [
                    for (final name in DigosBarangays.all)
                      DropdownMenuItem(value: name, child: Text(name)),
                  ],
                  onChanged: (value) => setState(() => _barangay = value),
                  validator: (value) =>
                      value == null ? 'Which barangay hosts it?' : null,
                ),
                const SizedBox(height: TabangSpace.sm),
                Row(
                  children: [
                    Expanded(
                      child: _picker(
                        context,
                        label: 'Date',
                        value: formatDate(_startDate),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _startDate,
                            firstDate: DateTime.now(),
                            lastDate: DateTime.now().add(
                              const Duration(days: 365),
                            ),
                          );
                          if (picked != null) {
                            setState(() => _startDate = picked);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: TabangSpace.sm),
                    Expanded(
                      child: _picker(
                        context,
                        label: 'Starts',
                        value: _startTime.format(context),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _startTime,
                          );
                          if (picked != null) setState(() => _startTime = picked);
                        },
                      ),
                    ),
                    const SizedBox(width: TabangSpace.sm),
                    Expanded(
                      child: _picker(
                        context,
                        label: 'Ends',
                        value: _endTime.format(context),
                        onTap: () async {
                          final picked = await showTimePicker(
                            context: context,
                            initialTime: _endTime,
                          );
                          if (picked != null) setState(() => _endTime = picked);
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TabangSpace.sm),
                TextFormField(
                  controller: _donors,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Expected donors',
                    isDense: true,
                  ),
                  validator: (value) {
                    final parsed = int.tryParse((value ?? '').trim());
                    if (parsed == null || parsed <= 0) {
                      return 'How many donors do you expect?';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: TabangSpace.sm),
                TextFormField(
                  controller: _note,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Note for the admin (optional)',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_formKey.currentState?.validate() != true) return;
            final accepted = widget.onSubmit(
              _DriveDraft(
                title: _title.text,
                venue: _venue.text,
                barangay: _barangay!,
                startsAt: _startsAt,
                endsAt: _endsAt,
                expectedDonors: int.parse(_donors.text.trim()),
                note: _note.text,
              ),
            );
            if (!accepted) {
              // The window is the only thing the form cannot validate inline.
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('The drive must end after it starts.'),
                ),
              );
              return;
            }
            Navigator.pop(context);
          },
          child: const Text('Send for approval'),
        ),
      ],
    );
  }

  Widget _picker(
    BuildContext context, {
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(TabangRadius.sm),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, isDense: true),
        child: Text(value, style: const TextStyle(fontSize: 13)),
      ),
    );
  }
}
