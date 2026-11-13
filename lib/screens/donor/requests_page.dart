import 'package:flutter/material.dart';

import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/blood_request_dialog.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/request_document_list.dart';

/// Blood request board.
///
/// This is the request half of the workflow described on p.21 of the paper.
/// Recipients post a need; the app checks whether compatible stock exists and
/// offers a blood-bank submission or a donor-network post. Donors see only
/// donor-network requests they are component-compatible with and eligible to
/// serve. A response is an offer, not a fulfilled unit: the requester selects a
/// donor, a private coordination thread is created, and only staff can mark the
/// request fulfilled after the donation is recorded.
/// Donors need both sides of the board: requests they can serve, the requests
/// they posted themselves, and the donation side.
enum _DonorRequestsTab { serve, mine, donate }

class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key, required this.user, this.onOpenDonorHub});

  final AppUser user;

  /// Opens Donor Hub, where the donor form and verification live.
  final VoidCallback? onOpenDonorHub;

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  final TabangRepository _repo = TabangRepository.instance;

  RequestUrgency? _urgencyFilter;

  /// Donors get three tabs: requests they can serve, requests they posted
  /// themselves, and the donation side (drives, eligibility, what to bring).
  _DonorRequestsTab _donorTab = _DonorRequestsTab.serve;

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

  AppUser get _user => _repo.userById(widget.user.id) ?? widget.user;

  bool get _isDonor => _user.role == UserRole.donor;

  List<BloodRequest> get _visible {
    var list = _isDonor
        ? _donorTab == _DonorRequestsTab.mine
              ? _repo.requests.where((r) => r.requesterId == _user.id).toList()
              // The serve tab shows the same community requests the map lists,
              // minus the donor's own (those live on the Mine tab). Whether the
              // donor can actually respond is decided per card, so the two
              // surfaces show the same count.
              : _repo.communityRequests
                    .where((r) => r.requesterId != _user.id)
                    .toList()
        : _repo.requests.where((r) => r.requesterId == _user.id).toList();

    if (_urgencyFilter != null) {
      list = list.where((r) => r.urgency == _urgencyFilter).toList();
    }

    final urgencyRank = {
      RequestUrgency.critical: 0,
      RequestUrgency.urgent: 1,
      RequestUrgency.routine: 2,
    };

    int rank(BloodRequest request) => switch (request.status) {
      RequestStatus.pendingReview => 0,
      RequestStatus.open => 1,
      RequestStatus.matched => 2,
      _ => 3,
    };

    return [...list]..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      if (byRank != 0) return byRank;
      final ur = urgencyRank[a.urgency]!.compareTo(urgencyRank[b.urgency]!);
      if (ur != 0) return ur;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  @override
  Widget build(BuildContext context) {
    final requests = _visible;

    // A sliver list builds only the cards that are actually on screen. The
    // previous eager Column built every card (and each card runs repository
    // lookups and eligibility checks) before the first frame.
    return CustomScrollView(
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            TabangSpace.xl,
            TabangSpace.xl,
            TabangSpace.xl,
            0,
          ),
          sliver: SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PageHeader(
                  title: 'Blood requests',
                  subtitle: _isDonor
                      ? _donorTab == _DonorRequestsTab.donate
                            ? 'Attend a drive, check your eligibility and see '
                                  'what staff asks for before a donation.'
                            : _donorTab == _DonorRequestsTab.mine
                            ? 'Requests you posted, with donor responses and '
                                  'fulfilment progress.'
                            : 'Community requests across Digos City. Respond '
                                  'to the ones your blood type and component '
                                  'can serve.'
                      : 'Your requests, donor responses and fulfilment '
                            'progress.',
                  actions: [
                    // Donors can need blood too: the same request form is
                    // available to every signed-in role.
                    OutlinedButton.icon(
                      onPressed: () => _showNewRequestDialog(context),
                      icon: const Icon(Icons.add, size: 15),
                      label: const Text('New request'),
                    ),
                  ],
                ),
                const SizedBox(height: TabangSpace.lg),

                if (_isDonor)
                  SegmentedButton<_DonorRequestsTab>(
                    segments: const [
                      ButtonSegment(
                        value: _DonorRequestsTab.serve,
                        icon: Icon(Icons.campaign_outlined, size: 16),
                        label: Text('Requests'),
                      ),
                      ButtonSegment(
                        value: _DonorRequestsTab.mine,
                        icon: Icon(Icons.assignment_ind_outlined, size: 16),
                        label: Text('Mine'),
                      ),
                      ButtonSegment(
                        value: _DonorRequestsTab.donate,
                        icon: Icon(Icons.volunteer_activism_outlined, size: 16),
                        label: Text('Donate'),
                      ),
                    ],
                    selected: {_donorTab},
                    showSelectedIcon: false,
                    onSelectionChanged: (selection) =>
                        setState(() => _donorTab = selection.first),
                  ),
                const SizedBox(height: TabangSpace.lg),

                if (_isDonor && _donorTab != _DonorRequestsTab.donate)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: TabangSpace.sm,
                          runSpacing: TabangSpace.sm,
                          children: [
                            _urgencyChip(context, null, 'All'),
                            ...RequestUrgency.values.map(
                              (u) => _urgencyChip(context, u, u.label),
                            ),
                          ],
                        ),
                      ),
                      const HelpTip(
                        title: 'Urgency levels',
                        message:
                            'Critical — the patient needs units now; the '
                            'request is released as soon as a compatible unit '
                            'or donor is confirmed (minutes to a few hours).\n\n'
                            'Urgent — needed within 24–48 hours; the chapter '
                            'schedules the next available slot or drive.\n\n'
                            'Routine — planned use (for example before '
                            'surgery), usually three or more days out.\n\n'
                            'Urgency is chosen when the request is posted and '
                            'chapter staff can adjust it.',
                      ),
                    ],
                  ),
                if (_isDonor && _donorTab != _DonorRequestsTab.donate)
                  const SizedBox(height: TabangSpace.lg),
              ],
            ),
          ),
        ),
        if (_isDonor && _donorTab == _DonorRequestsTab.donate)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              TabangSpace.xl,
              0,
              TabangSpace.xl,
              TabangSpace.xl,
            ),
            sliver: SliverToBoxAdapter(child: _buildDonateTab(context)),
          )
        else if (requests.isEmpty)
          SliverPadding(
            padding: context.pagePadding,
            sliver: SliverToBoxAdapter(
              child: EmptyState(
                art: TabangArt.requests,
                title: _isDonor
                    ? _donorTab == _DonorRequestsTab.mine
                          ? 'No requests yet'
                          : 'No matching requests'
                    : 'No requests yet',
                message: _isDonor
                    ? _donorTab == _DonorRequestsTab.mine
                          ? 'Create a request to check blood-bank stock and, '
                                'if needed, post to the donor network.'
                          : 'Nothing compatible is open right now. Check back '
                                'later.'
                    : 'Create a request to check blood-bank stock and, if '
                          'needed, post to the donor network.',
              ),
            ),
          )
        else
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(
              TabangSpace.xl,
              0,
              TabangSpace.xl,
              TabangSpace.xl,
            ),
            sliver: SliverList.builder(
              itemCount: requests.length,
              itemBuilder: (context, i) => Padding(
                padding: const EdgeInsets.only(bottom: TabangSpace.md),
                child: _buildRequestCard(
                  context,
                  requests[i],
                  isOwn: requests[i].requesterId == _user.id,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The donor side of the Requests page: drives to attend, eligibility
  /// timing, and what staff asks for before a donation.
  Widget _buildDonateTab(BuildContext context) {
    final user = _user;
    final eligibility = EligibilityEngine.evaluate(user);
    final drives = _repo.drives
        .where((d) => d.status != 'Completed')
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!user.bloodCardVerified)
          SurfaceCard(
            highlighted: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.verified_user_outlined,
                      size: 18,
                      color: TabangColors.crimson,
                    ),
                    const SizedBox(width: TabangSpace.sm),
                    Expanded(
                      child: Text(
                        'Finish donor verification first',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: context.textColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'You can join a drive list now, but the chapter verifies '
                  'your blood card before you donate. Bring your ID and finish '
                  'the interview, examination and screening.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                if (widget.onOpenDonorHub != null)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: widget.onOpenDonorHub,
                      icon: const Icon(Icons.edit_note_outlined, size: 17),
                      label: const Text('Open Donor hub'),
                    ),
                  ),
              ],
            ),
          )
        else
          SurfaceCard(
            child: Row(
              children: [
                Icon(
                  eligibility.isEligible
                      ? Icons.check_circle_outline
                      : Icons.schedule,
                  size: 20,
                  color: eligibility.isEligible
                      ? TabangColors.success
                      : TabangColors.warning,
                ),
                const SizedBox(width: TabangSpace.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eligibility.isEligible
                            ? 'You are eligible to donate'
                            : 'Not yet eligible',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.textColor,
                        ),
                      ),
                      Text(
                        eligibility.isEligible
                            ? 'Whole blood, platelets and plasma can all be '
                                  'accepted at the chapter today.'
                            : eligibility.daysRemaining > 0
                            ? 'Next window opens in '
                                  '${eligibility.daysRemaining} day'
                                  '${eligibility.daysRemaining == 1 ? '' : 's'}.'
                            : 'Chapter staff will confirm your next '
                                  'donation window.',
                        style: TextStyle(
                          fontSize: 12.5,
                          height: 1.45,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: TabangSpace.xl),
        const SectionLabel('Blood drives you can join'),
        if (drives.isEmpty)
          const EmptyState(
            art: TabangArt.inventory,
            title: 'No drives scheduled',
          )
        else
          for (final drive in drives)
            Padding(
              padding: const EdgeInsets.only(bottom: TabangSpace.md),
              child: _buildDonateDriveCard(context, drive),
            ),
        const SizedBox(height: TabangSpace.lg),
        const SectionLabel('What to bring'),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final requirement in kDonorRequirements)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline,
                        size: 16,
                        color: TabangColors.crimson.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          requirement,
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: context.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDonateDriveCard(BuildContext context, BloodDrive drive) {
    final interested = _repo.isInterestedInDrive(drive.id, _user.id);
    final attending = _repo.driveInterestCount(drive.id);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.place, size: 18, color: TabangColors.crimson),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Text(
                  drive.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                ),
              ),
              StatusPill(
                drive.status,
                tone: drive.status == 'Ongoing' ? Tone.success : Tone.info,
                dense: true,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            '${drive.venue} · ${formatDateTime(drive.startsAt)}',
            style: TextStyle(fontSize: 12.5, color: context.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            '$attending donor${attending == 1 ? '' : 's'} on the chapter list · '
            'around ${drive.expectedDonors} expected',
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
          const SizedBox(height: TabangSpace.sm),
          SizedBox(
            width: double.infinity,
            child: interested
                ? OutlinedButton.icon(
                    onPressed: () async {
                      // Leaving the list is easy to do by accident and the
                      // button sits under a thumb, so confirm first.
                      final leave = await confirmAction(
                        context,
                        title: 'Leave this drive?',
                        message:
                            'You will be taken off the chapter list for '
                            '${drive.title}. You can join again any time before '
                            'the drive ends.',
                        confirmLabel: 'Leave',
                        destructive: true,
                      );
                      if (!leave || !mounted) return;
                      setState(
                        () => _repo.toggleDriveInterest(drive.id, _user.id),
                      );
                    },
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('On the list — tap to leave'),
                  )
                : FilledButton.tonalIcon(
                    onPressed: () => setState(
                      () => _repo.toggleDriveInterest(drive.id, _user.id),
                    ),
                    icon: const Icon(
                      Icons.volunteer_activism_outlined,
                      size: 16,
                    ),
                    label: const Text('Join this drive'),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _urgencyChip(
    BuildContext context,
    RequestUrgency? urgency,
    String label,
  ) {
    final selected = _urgencyFilter == urgency;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      selectedColor: TabangColors.crimson,
      labelStyle: TextStyle(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: selected ? Colors.white : context.textColor,
      ),
      onSelected: (_) => setState(() => _urgencyFilter = urgency),
    );
  }

  Widget _buildRequestCard(
    BuildContext context,
    BloodRequest request, {
    required bool isOwn,
  }) {
    final responses = _repo.responsesFor(request.id);
    final myResponse = _isDonor
        ? _repo.responseForDonor(request.id, _user.id)
        : null;
    final compatibleDonors = _repo.compatibleDonorsForRequest(request).length;
    final compatibleUnits = _repo
        .compatibleUnitsFor(
          recipientType: request.bloodType,
          component: request.component,
        )
        .length;

    final open = request.status == RequestStatus.open;
    final progress = request.unitsNeeded == 0
        ? 0.0
        : (request.unitsFulfilled / request.unitsNeeded).clamp(0.0, 1.0);

    return SurfaceCard(
      highlighted: request.urgency == RequestUrgency.critical && open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: one chip, one title, one urgency marker. The old row packed
          // up to four pills next to the patient alias and read as noise.
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BloodTypeChip(request.bloodType, size: 44),
              const SizedBox(width: TabangSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            request.patientAlias,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.2,
                              color: context.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isOwn) ...[
                          const SizedBox(width: 6),
                          Text(
                            '· your request',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request.component.label} · '
                      '${request.unitsNeeded} unit'
                      '${request.unitsNeeded == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TabangSpace.sm),
              StatusPill(
                request.urgency.label,
                tone: toneForUrgency(request.urgency),
                dense: true,
              ),
              // Details live behind the three-dot menu so the card stays
              // scannable; the menu is the only place the full record and the
              // cancel action are repeated.
              PopupMenuButton<String>(
                tooltip: 'Request options',
                icon: Icon(Icons.more_vert, size: 19, color: context.textMuted),
                onSelected: (value) {
                  if (value == 'details') {
                    _showRequestDetails(context, request, isOwn: isOwn);
                  } else if (value == 'cancel') {
                    final ok = _repo.cancelRequest(
                      request.id,
                      actorId: _user.id,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      TabangSnackBar(
                        content: Text(
                          ok
                              ? 'Request cancelled.'
                              : 'This request can no longer be cancelled.',
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'details',
                    child: Text('View details'),
                  ),
                  if (isOwn &&
                      request.status != RequestStatus.fulfilled &&
                      request.status != RequestStatus.cancelled)
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel request'),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.md),

          // Location and time get their own quiet line.
          Row(
            children: [
              Expanded(
                child: _meta(
                  context,
                  Icons.local_hospital_outlined,
                  request.hospital,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Wrap(
            spacing: TabangSpace.lg,
            runSpacing: 4,
            children: [
              _meta(context, Icons.place_outlined, request.barangay),
              // A reviewed request reads "Verified" so staff approval is
              // visible inside the list, not only in the full record.
              if (request.reviewedById != null &&
                  request.status != RequestStatus.pendingReview &&
                  request.status != RequestStatus.rejected &&
                  request.status != RequestStatus.cancelled)
                const StatusPill(
                  'Verified',
                  tone: Tone.success,
                  icon: Icons.verified_outlined,
                  dense: true,
                ),
              if (request.scheduledFor != null)
                _meta(
                  context,
                  Icons.event_available_outlined,
                  'Slot ${formatDateTime(request.scheduledFor!)}',
                )
              else
                _meta(
                  context,
                  Icons.schedule,
                  formatRelative(request.createdAt),
                ),
            ],
          ),

          // The requester sees where the review stands: waiting for staff, or
          // rejected with the reason staff entered.
          if (isOwn && request.isAwaitingReview) ...[
            const SizedBox(height: TabangSpace.md),
            _reviewNotice(
              context,
              icon: Icons.pending_actions_outlined,
              color: TabangColors.warning,
              text:
                  'Awaiting chapter verification. Staff are checking the '
                  'documents and the booked slot before this request is '
                  'posted or held from stock.',
            ),
          ] else if (isOwn && request.status == RequestStatus.rejected) ...[
            const SizedBox(height: TabangSpace.md),
            _reviewNotice(
              context,
              icon: Icons.assignment_late_outlined,
              color: TabangColors.danger,
              text:
                  'Rejected by chapter staff: '
                  '${request.reviewNote ?? 'No reason recorded.'}',
            ),
          ] else if (isOwn &&
              (request.status == RequestStatus.matched ||
                  request.status == RequestStatus.open ||
                  request.status == RequestStatus.fulfilled)) ...[
            // The requester must be able to tell verification happened, not
            // just notice that the pending notice vanished.
            const SizedBox(height: TabangSpace.md),
            _reviewNotice(
              context,
              icon: Icons.verified_outlined,
              color: TabangColors.success,
              text: request.status == RequestStatus.fulfilled
                  ? 'Verified and fulfilled by chapter staff. Thank you — '
                        'this donation is recorded in the chapter activity log.'
                  : request.source == RequestSource.bloodBank
                  ? 'Verified by chapter staff — your slot is confirmed and '
                        'compatible units are held for you. '
                        '${request.assignedUnitIds.isEmpty ? '' : '${request.assignedUnitIds.length} unit${request.assignedUnitIds.length == 1 ? '' : 's'} on hold. '}'
                        'Staff will notify you when the units are released.'
                  : 'Verified by chapter staff — your slot is confirmed and '
                        'the request is visible to compatible donors. New '
                        'responses appear on this card.',
            ),
          ],

          if (request.note != null) ...[
            const SizedBox(height: TabangSpace.md),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(TabangSpace.md),
              decoration: BoxDecoration(
                color: context.surfaceAlt,
                borderRadius: BorderRadius.circular(TabangRadius.sm),
              ),
              child: Text(
                request.note!,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: context.textColor,
                ),
              ),
            ),
          ],

          const SizedBox(height: TabangSpace.md),
          // Fulfilment is one line with a bar instead of a third meta pill.
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(TabangRadius.pill),
                  child: LinearProgressIndicator(
                    minHeight: 6,
                    value: progress,
                    color: progress >= 1
                        ? TabangColors.success
                        : TabangColors.crimson,
                  ),
                ),
              ),
              const SizedBox(width: TabangSpace.sm),
              Text(
                '${request.unitsFulfilled} of ${request.unitsNeeded} fulfilled',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          // Status and source read as a single sentence, not two pills.
          Text(
            '${request.status.label} · '
            '${request.source == RequestSource.bloodBank ? 'Blood bank' : 'Donor network'}'
            '${request.source == RequestSource.bloodBank ? ' · $compatibleUnits compatible unit${compatibleUnits == 1 ? '' : 's'} in stock, processed by chapter staff' : ' · $compatibleDonors compatible eligible donor${compatibleDonors == 1 ? '' : 's'} can respond'}',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: context.textMuted,
            ),
          ),
          if (isOwn && responses.isNotEmpty) ...[
            const SizedBox(height: TabangSpace.md),
            Divider(color: context.border),
            const SizedBox(height: TabangSpace.sm),
            Text(
              'Donor responses (${responses.length})',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: context.textColor,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: TabangSpace.sm),
            ...responses.map(
              (response) => _buildResponseRow(context, request, response),
            ),
          ],
          const SizedBox(height: TabangSpace.md),
          // Wrap, not Row: on a phone the respond and cancel buttons stack
          // instead of overflowing their card.
          Wrap(
            spacing: TabangSpace.sm,
            runSpacing: TabangSpace.sm,
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (myResponse != null)
                StatusPill(
                  myResponse.status == ResponseStatus.pending
                      ? 'Response sent'
                      : myResponse.status.label,
                  tone: myResponse.status == ResponseStatus.selected
                      ? Tone.success
                      : Tone.info,
                  dense: true,
                )
              else if (_isDonor &&
                  !isOwn &&
                  request.status == RequestStatus.open &&
                  request.source == RequestSource.donorNetwork)
                ElevatedButton.icon(
                  onPressed: _canRespond(request)
                      ? () => _respondToRequest(context, request)
                      : null,
                  icon: const Icon(Icons.volunteer_activism, size: 14),
                  label: Text(_respondLabel(request)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TabangSpace.lg,
                      vertical: TabangSpace.sm,
                    ),
                  ),
                ),
              if (isOwn &&
                  request.status != RequestStatus.fulfilled &&
                  request.status != RequestStatus.cancelled)
                OutlinedButton(
                  onPressed: () {
                    final ok = _repo.cancelRequest(
                      request.id,
                      actorId: _user.id,
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      TabangSnackBar(
                        content: Text(
                          ok
                              ? 'Request cancelled.'
                              : 'This request can no longer be cancelled.',
                        ),
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: TabangSpace.lg,
                      vertical: TabangSpace.sm,
                    ),
                  ),
                  child: const Text('Cancel request'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _reviewNotice(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TabangSpace.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: TabangSpace.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: context.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Full record for one request, opened from the card's three-dot menu.
  void _showRequestDetails(
    BuildContext context,
    BloodRequest request, {
    required bool isOwn,
  }) {
    final responses = _repo.responsesFor(request.id);
    final compatibleDonors = _repo.compatibleDonorsForRequest(request).length;
    final compatibleUnits = _repo
        .compatibleUnitsFor(
          recipientType: request.bloodType,
          component: request.component,
        )
        .length;
    final myResponse = _isDonor
        ? _repo.responseForDonor(request.id, _user.id)
        : null;
    final canRespond =
        _isDonor &&
        !isOwn &&
        request.acceptsDonorResponses &&
        _canRespond(request);

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Row(
          children: [
            BloodTypeChip(request.bloodType, size: 32),
            const SizedBox(width: TabangSpace.md),
            Expanded(
              child: Text(
                request.patientAlias,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            StatusPill(
              request.urgency.label,
              tone: toneForUrgency(request.urgency),
              dense: true,
            ),
          ],
        ),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _detail(dialogContext, 'Request ID', request.id),
                _detail(dialogContext, 'Component', request.component.label),
                _detail(
                  dialogContext,
                  'Units',
                  '${request.unitsFulfilled} of ${request.unitsNeeded} '
                      'fulfilled',
                ),
                _detail(dialogContext, 'Patient facility', request.hospital),
                _detail(dialogContext, 'Barangay', request.barangay),
                _detail(
                  dialogContext,
                  'Urgency',
                  '${request.urgency.label} · ${request.urgency.detail}',
                ),
                _detail(dialogContext, 'Status', request.status.label),
                if (request.scheduledFor != null)
                  _detail(
                    dialogContext,
                    'Blood-bank slot',
                    formatDateTime(request.scheduledFor!),
                  ),
                _detail(
                  dialogContext,
                  'Posted',
                  formatRelative(request.createdAt),
                ),
                if (request.documents.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Documents',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: dialogContext.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  RequestDocumentList(
                    documents: request.documents,
                    dense: true,
                  ),
                ],
                if (request.reviewNote != null &&
                    request.reviewNote!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Chapter review note',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: dialogContext.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(TabangSpace.md),
                    decoration: BoxDecoration(
                      color: TabangColors.danger.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(TabangRadius.sm),
                    ),
                    child: Text(
                      request.reviewNote!,
                      style: const TextStyle(fontSize: 12.5, height: 1.5),
                    ),
                  ),
                ],
                _detail(
                  dialogContext,
                  'Channel',
                  request.source == RequestSource.bloodBank
                      ? 'Blood bank · $compatibleUnits compatible unit'
                            '${compatibleUnits == 1 ? '' : 's'} in stock'
                      : 'Donor network · $compatibleDonors compatible '
                            'eligible donor'
                            '${compatibleDonors == 1 ? '' : 's'}',
                ),
                if (request.note != null && request.note!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Clinical note',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: dialogContext.textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(TabangSpace.md),
                    decoration: BoxDecoration(
                      color: dialogContext.surfaceAlt,
                      borderRadius: BorderRadius.circular(TabangRadius.sm),
                    ),
                    child: Text(
                      request.note!,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.5,
                        color: dialogContext.textColor,
                      ),
                    ),
                  ),
                ],
                if (isOwn && responses.isNotEmpty) ...[
                  const SizedBox(height: TabangSpace.md),
                  Text(
                    'Donor responses (${responses.length})',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: dialogContext.textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...responses.map(
                    (response) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '• ${_repo.userById(response.donorId)?.mapHandle ?? 'Donor'}'
                        ' · ${response.status.label} · '
                        '${formatRelative(response.createdAt)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: dialogContext.textMuted,
                        ),
                      ),
                    ),
                  ),
                ],
                if (myResponse != null) ...[
                  const SizedBox(height: TabangSpace.md),
                  Text(
                    'Your response: ${myResponse.status.label}',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: dialogContext.textColor,
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
          if (canRespond)
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(dialogContext);
                _respondToRequest(context, request);
              },
              icon: const Icon(Icons.volunteer_activism, size: 16),
              label: Text(_respondLabel(request)),
            ),
        ],
      ),
    );
  }

  Widget _detail(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 118,
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

  Widget _meta(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: context.textMuted),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: context.textMuted),
          ),
        ),
      ],
    );
  }

  Widget _buildResponseRow(
    BuildContext context,
    BloodRequest request,
    RequestResponse response,
  ) {
    final donor = _repo.userById(response.donorId);
    final donorLabel = donor?.mapHandle ?? 'Donor';
    final eligibility = donor == null
        ? null
        : EligibilityEngine.evaluate(donor, component: request.component);
    final donorType = donor?.bloodType;
    final stillCompatible =
        donorType != null &&
        Compatibility.canDonateComponentTo(
          donorType,
          request.bloodType,
          request.component,
        );
    // A donor selected by another requester stays listed so the requester can
    // see what happened, but cannot be reserved twice from this queue.
    final commitment = _repo.commitmentForDonor(
      response.donorId,
      excludingRequestId: request.id,
    );
    final canSelect =
        response.status == ResponseStatus.pending &&
        request.status == RequestStatus.open &&
        stillCompatible &&
        (eligibility?.isEligible ?? false) &&
        commitment == null;

    return Container(
      margin: const EdgeInsets.only(bottom: TabangSpace.sm),
      padding: const EdgeInsets.all(TabangSpace.sm),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(TabangRadius.xs),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: TabangColors.crimson.withValues(alpha: 0.12),
            child: const Text(
              '#',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: TabangColors.crimson,
              ),
            ),
          ),
          const SizedBox(width: TabangSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      donorLabel,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(width: 6),
                    if (donor?.bloodType != null)
                      Text(
                        donor!.bloodType!.label,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textMuted,
                        ),
                      ),
                    if (donor?.shareBarangay ?? false) ...[
                      const SizedBox(width: 6),
                      Text(
                        donor!.barangay,
                        style: TextStyle(
                          fontSize: 11,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
                if (response.message != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    response.message!,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: context.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 2),
                Text(
                  commitment != null
                      ? 'Coordinating request ${commitment.requestId} · still '
                            'visible, but cannot be selected twice'
                      : eligibility == null
                      ? 'Donor record unavailable'
                      : eligibility.isEligible
                      ? 'Eligible now · responded '
                            '${formatRelative(response.createdAt)}'
                      : '${eligibility.summary} · responded '
                            '${formatRelative(response.createdAt)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: commitment != null
                        ? TabangColors.info
                        : eligibility != null &&
                              !eligibility.isEligible &&
                              eligibility.blocker == EligibilityBlocker.cooldown
                        ? TabangColors.warning
                        : context.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: TabangSpace.sm),
          if (response.status == ResponseStatus.selected)
            const StatusPill('Selected', tone: Tone.success, dense: true)
          else if (response.status == ResponseStatus.declined)
            const StatusPill('Declined', tone: Tone.neutral, dense: true)
          else if (commitment != null)
            const StatusPill('Coordinating', tone: Tone.info, dense: true)
          else if (canSelect)
            TextButton(
              onPressed: () => _selectResponse(context, request, response),
              child: const Text('Select donor'),
            ),
        ],
      ),
    );
  }

  bool _canRespond(BloodRequest request) {
    final type = _user.bloodType;
    if (type == null) return false;
    if (!Compatibility.canDonateComponentTo(
      type,
      request.bloodType,
      request.component,
    )) {
      return false;
    }
    return EligibilityEngine.evaluate(
      _user,
      component: request.component,
    ).isEligible;
  }

  String _respondLabel(BloodRequest request) {
    final type = _user.bloodType;
    if (type == null) return 'Blood type missing';
    if (!Compatibility.canDonateComponentTo(
      type,
      request.bloodType,
      request.component,
    )) {
      return 'Not compatible';
    }
    final eligibility = EligibilityEngine.evaluate(
      _user,
      component: request.component,
    );
    if (!eligibility.isEligible) {
      if (eligibility.blocker == EligibilityBlocker.cooldown) {
        return 'In cooldown';
      }
      return 'Not eligible';
    }
    return 'Respond';
  }

  void _respondToRequest(BuildContext context, BloodRequest request) {
    final eligibility = EligibilityEngine.evaluate(
      _user,
      component: request.component,
    );
    if (!eligibility.isEligible) {
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Not eligible right now'),
          content: Text(
            '${eligibility.summary}.\n\n'
            '${eligibility.eligibleFrom != null ? 'You can donate '
                      '${request.component.label.toLowerCase()} again from '
                      '${formatDate(eligibility.eligibleFrom!)}. ' : ''}'
            'TABANG enforces component-specific donation intervals to protect '
            'donor health.',
            style: const TextStyle(fontSize: 13, height: 1.6),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Understood'),
            ),
          ],
        ),
      );
      return;
    }

    final message = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Respond to request'),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Your anonymous handle "${_user.mapHandle}" is shared first. '
                'The requester may select you; a private coordination thread '
                'is created only after selection. Real names stay hidden '
                'until both sides agree to reveal them.',
                style: const TextStyle(fontSize: 13, height: 1.6),
              ),
              const SizedBox(height: TabangSpace.md),
              TextField(
                controller: message,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Message to requester (optional)',
                  hintText: 'Availability, preferred schedule, questions',
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
              final response = _repo.respondToRequest(
                requestId: request.id,
                donorId: _user.id,
                message: message.text,
              );
              Navigator.pop(dialogContext);
              ScaffoldMessenger.of(context).showSnackBar(
                TabangSnackBar(
                  content: Text(
                    response == null
                        ? 'Could not send response. The request may have '
                              'closed or your eligibility changed.'
                        : 'Response sent. The requester will be notified and '
                              'may select you.',
                  ),
                ),
              );
            },
            child: const Text('Send response'),
          ),
        ],
      ),
    );
  }

  void _selectResponse(
    BuildContext context,
    BloodRequest request,
    RequestResponse response,
  ) {
    final donor = _repo.userById(response.donorId);
    final commitment = _repo.commitmentForDonor(
      response.donorId,
      excludingRequestId: request.id,
    );
    if (commitment != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        TabangSnackBar(
          content: Text(
            '${donor?.mapHandle ?? 'This donor'} is already coordinating '
            'request ${commitment.requestId}. They stay visible here, but '
            'cannot be reserved for a second active request.',
          ),
        ),
      );
      return;
    }
    if (donor != null && !_repo.hasReciprocalChat(_user.id, donor.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        TabangSnackBar(
          content: Text(
            'Message ${donor.mapHandle} first. Both of you need to exchange at '
            'least one message before a donor can be selected.',
          ),
        ),
      );
      return;
    }

    final thread = _repo.selectResponse(
      responseId: response.id,
      selectedById: _user.id,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      TabangSnackBar(
        content: Text(
          thread == null
              ? 'Could not select this donor. They may no longer be eligible, '
                    'or the request may have closed.'
              : 'Donor selected. A private coordination thread is ready in '
                    'Messages.',
        ),
      ),
    );
  }

  void _showNewRequestDialog(BuildContext context) {
    showBloodRequestDialog(context, _user);
  }
}
