import 'package:flutter/material.dart';

import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/blood_request_dialog.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';

/// Blood request board.
///
/// This is the request half of the workflow described on p.21 of the paper.
/// Recipients post a need; the app checks whether compatible stock exists and
/// offers a blood-bank submission or a donor-network post. Donors see only
/// donor-network requests they are component-compatible with and eligible to
/// serve. A response is an offer, not a fulfilled unit: the requester selects a
/// donor, a private coordination thread is created, and only staff can mark the
/// request fulfilled after the donation is recorded.
class RequestsPage extends StatefulWidget {
  const RequestsPage({super.key, required this.user});

  final AppUser user;

  @override
  State<RequestsPage> createState() => _RequestsPageState();
}

class _RequestsPageState extends State<RequestsPage> {
  final TabangRepository _repo = TabangRepository.instance;

  RequestUrgency? _urgencyFilter;

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
  bool get _isRecipient => _user.role == UserRole.recipient;

  List<BloodRequest> get _visible {
    final donorType = _user.bloodType;

    var list = _isDonor
        ? _repo.donorNetworkRequests.where((r) {
            if (donorType == null) return false;
            return Compatibility.canDonateComponentTo(
              donorType,
              r.bloodType,
              r.component,
            );
          }).toList()
        : _repo.requests
            .where((r) => r.requesterId == _user.id)
            .toList();

    if (_urgencyFilter != null) {
      list = list.where((r) => r.urgency == _urgencyFilter).toList();
    }

    final urgencyRank = {
      RequestUrgency.critical: 0,
      RequestUrgency.urgent: 1,
      RequestUrgency.routine: 2,
    };

    return [...list]..sort((a, b) {
        final aOpen = a.status == RequestStatus.open ? 0 : 1;
        final bOpen = b.status == RequestStatus.open ? 0 : 1;
        if (aOpen != bOpen) return aOpen.compareTo(bOpen);
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
                      ? 'Open donor-network requests your blood type and '
                          'component can serve.'
                      : 'Your requests, donor responses and fulfilment '
                          'progress.',
                  actions: [
                    if (_isRecipient)
                      OutlinedButton.icon(
                        onPressed: () => _showNewRequestDialog(context),
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('New request'),
                      ),
                  ],
                ),
                const SizedBox(height: TabangSpace.xl),

                if (_isDonor) ...[
                  Wrap(
                    spacing: TabangSpace.sm,
                    runSpacing: TabangSpace.sm,
                    children: [
                      _urgencyChip(context, null, 'All'),
                      ...RequestUrgency.values.map(
                        (u) => _urgencyChip(context, u, u.label),
                      ),
                    ],
                  ),
                  const SizedBox(height: TabangSpace.lg),
                ],
              ],
            ),
          ),
        ),
        if (requests.isEmpty)
          SliverPadding(
            padding: context.pagePadding,
            sliver: SliverToBoxAdapter(
              child: EmptyState(
                art: TabangArt.requests,
                title: _isDonor ? 'No matching requests' : 'No requests yet',
                message: _isDonor
                    ? 'Nothing compatible is open right now. Check back '
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
        fontSize: 11,
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
    final compatibleDonors =
        _repo.compatibleDonorsForRequest(request).length;
    final compatibleUnits = _repo
        .compatibleUnitsFor(
          recipientType: request.bloodType,
          component: request.component,
        )
        .length;

    return SurfaceCard(
      highlighted: request.urgency == RequestUrgency.critical &&
          request.status == RequestStatus.open,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BloodTypeChip(request.bloodType, size: 40),
              const SizedBox(width: TabangSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 4,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          request.patientAlias,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: context.textColor,
                          ),
                        ),
                        StatusPill(
                          request.urgency.label,
                          tone: toneForUrgency(request.urgency),
                          dense: true,
                        ),
                        StatusPill(
                          request.status.label,
                          tone: request.status == RequestStatus.open
                              ? Tone.info
                              : Tone.neutral,
                          dense: true,
                        ),
                        StatusPill(
                          request.source.label,
                          tone: request.source == RequestSource.bloodBank
                              ? Tone.brand
                              : Tone.neutral,
                          dense: true,
                        ),
                        if (isOwn)
                          const StatusPill(
                            'YOURS',
                            tone: Tone.brand,
                            dense: true,
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${request.component.label} · ${request.unitsNeeded} '
                      'unit${request.unitsNeeded == 1 ? '' : 's'} · '
                      '${request.hospital}',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Wrap(
                      spacing: TabangSpace.md,
                      runSpacing: 2,
                      children: [
                        _meta(
                          context,
                          Icons.place_outlined,
                          request.barangay,
                        ),
                        _meta(
                          context,
                          Icons.schedule,
                          formatRelative(request.createdAt),
                        ),
                        _meta(
                          context,
                          Icons.check_circle_outline,
                          '${request.unitsFulfilled} of '
                              '${request.unitsNeeded} fulfilled',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (request.note != null) ...[
            const SizedBox(height: TabangSpace.md),
            Container(
              padding: const EdgeInsets.all(TabangSpace.sm),
              decoration: BoxDecoration(
                color: context.surfaceAlt,
                borderRadius: BorderRadius.circular(TabangRadius.xs),
              ),
              child: Text(
                request.note!,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.5,
                  color: context.textMuted,
                ),
              ),
            ),
          ],
          const SizedBox(height: TabangSpace.md),
          if (request.source == RequestSource.bloodBank)
            _sourceNotice(
              context,
              Icons.local_hospital_outlined,
              '$compatibleUnits compatible unit'
                  '${compatibleUnits == 1 ? '' : 's'} in stock. '
                  'Chapter staff will process this request.',
            )
          else
            _sourceNotice(
              context,
              Icons.people_outline,
              '$compatibleDonors compatible eligible donor'
                  '${compatibleDonors == 1 ? '' : 's'} can still respond.',
            ),
          if (isOwn && responses.isNotEmpty) ...[
            const SizedBox(height: TabangSpace.md),
            Divider(color: context.border),
            const SizedBox(height: TabangSpace.sm),
            Text(
              'Donor responses (${responses.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: context.textMuted,
                letterSpacing: 0.4,
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
                      SnackBar(
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

  Widget _meta(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: context.textMuted),
        const SizedBox(width: 3),
        Text(
          text,
          style: TextStyle(fontSize: 11, color: context.textMuted),
        ),
      ],
    );
  }

  Widget _sourceNotice(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 13, color: context.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 11, color: context.textMuted),
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
    final eligibility = donor == null
        ? null
        : EligibilityEngine.evaluate(donor, component: request.component);
    final donorType = donor?.bloodType;
    final stillCompatible = donorType != null &&
        Compatibility.canDonateComponentTo(
          donorType,
          request.bloodType,
          request.component,
        );
    final canSelect = response.status == ResponseStatus.pending &&
        request.status == RequestStatus.open &&
        stillCompatible &&
        (eligibility?.isEligible ?? false);

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
            child: Text(
              response.donorAlias.isEmpty
                  ? '?'
                  : response.donorAlias.substring(0, 1).toUpperCase(),
              style: const TextStyle(
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
                      response.donorAlias,
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
                  eligibility == null
                      ? 'Donor record unavailable'
                      : eligibility.isEligible
                          ? 'Eligible now · responded '
                              '${formatRelative(response.createdAt)}'
                          : '${eligibility.summary} · responded '
                              '${formatRelative(response.createdAt)}',
                  style: TextStyle(
                    fontSize: 10.5,
                    color: eligibility != null &&
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
          else if (canSelect)
            TextButton(
              onPressed: () => _selectResponse(context, response),
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
                'Your alias "${_user.alias}" is shared first. The '
                'requester may select you; a private coordination thread is '
                'created only after selection. Real names stay hidden until '
                'both sides agree to reveal them.',
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
                SnackBar(
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

  void _selectResponse(BuildContext context, RequestResponse response) {
    final thread = _repo.selectResponse(
      responseId: response.id,
      selectedById: _user.id,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
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
