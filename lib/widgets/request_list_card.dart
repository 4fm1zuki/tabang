import 'package:flutter/material.dart';

import '../core/models.dart';
import '../theme.dart';
import 'common.dart';
import 'photo.dart';

/// One blood-request card, shared by the community map's Requests list and any
/// other board that lists requests.
///
/// It mirrors [DonorListCard]: a photo, the blood-type chip, the name and a
/// status pill on the first line, the hospital and the key facts beneath, then
/// the caller's actions. The community map used to draw a bare text card next
/// to the rich donor cards, so the two lists looked like different products.
class RequestListCard extends StatelessWidget {
  const RequestListCard({
    super.key,
    required this.request,
    this.requester,
    this.actions = const [],
    this.onTap,
    this.onTapHint,
    this.highlighted = false,
  });

  final BloodRequest request;

  /// The account that posted the request. Their illustration is shown as the
  /// card's avatar; it is fictional artwork, never a real photo.
  final AppUser? requester;

  /// Trailing action buttons, supplied by the surface that shows the card.
  final List<Widget> actions;

  final VoidCallback? onTap;

  /// Tooltip for the card tap, when [onTap] is set.
  final String? onTapHint;

  /// Outlines the card as the transient jump target after an "Open in
  /// Requests" hand-off.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final units =
        '${request.unitsNeeded} unit${request.unitsNeeded == 1 ? '' : 's'}';
    final card = SurfaceCard(
      padding: const EdgeInsets.all(TabangSpace.lg),
      onTap: onTap,
      highlighted: highlighted,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: TabangPhoto(
                    requester?.photoAsset,
                    semanticLabel:
                        '${request.patientAlias} request illustration',
                    creditLabel: request.patientAlias,
                    fallbackIcon: Icons.person_outline,
                    fallbackIconSize: 20,
                  ),
                ),
              ),
              const SizedBox(width: TabangSpace.sm),
              BloodTypeChip(request.bloodType, size: 30),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.patientAlias,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    Text(
                      '${request.component.label} · $units',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: TabangSpace.sm),
              // Status and urgency sit together at the top right, where they
              // read as the card's headline state instead of being buried in
              // the facts row. The width cap keeps a long lifecycle label
              // ("Awaiting verification") from squeezing out the patient name.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 132),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    StatusPill(
                      request.status.label,
                      tone: toneForRequest(request.status),
                      dense: true,
                    ),
                    const SizedBox(height: 4),
                    StatusPill(
                      request.urgency.label,
                      tone: toneForUrgency(request.urgency),
                      dense: true,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          Row(
            children: [
              Icon(
                Icons.local_hospital_outlined,
                size: 14,
                color: context.textMuted,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  request.hospital,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: context.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: TabangSpace.md,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _fact(context, Icons.place_outlined, request.barangay),
              if (request.scheduledFor != null)
                _fact(
                  context,
                  Icons.event_outlined,
                  formatDateTime(request.scheduledFor!),
                ),
            ],
          ),
          if (actions.isNotEmpty) ...[
            const SizedBox(height: TabangSpace.sm),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );

    final hint = onTapHint;
    if (hint == null || onTap == null) return card;
    return Tooltip(message: hint, child: card);
  }

  Widget _fact(BuildContext context, IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: context.textMuted),
        const SizedBox(width: 4),
        Text(text, style: TextStyle(fontSize: 11.5, color: context.textMuted)),
      ],
    );
  }
}
