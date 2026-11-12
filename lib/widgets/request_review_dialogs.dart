import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repository.dart';
import '../theme.dart';
import 'common.dart';
import 'request_document_list.dart';

/// Staff verification for a submitted blood request.
///
/// This is also where a booked slot is confirmed: the request's
/// `scheduledFor` is the appointment now, so verification opens the request
/// and (for a blood-bank request) holds compatible units.
Future<void> showVerifyRequestDialog(
  BuildContext context,
  BloodRequest request, {
  required AppUser actor,
}) {
  final repo = TabangRepository.instance;
  final assignable = request.source == RequestSource.bloodBank
      ? repo
            .compatibleUnitsFor(
              recipientType: request.bloodType,
              component: request.component,
            )
            .take(request.unitsNeeded)
            .toList(growable: false)
      : const <BloodUnit>[];

  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Verify request ${request.id}'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Open the attached files and check the booked slot. Donors are '
                'never asked before verification.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.5,
                  color: dialogContext.textMuted,
                ),
              ),
              const SizedBox(height: TabangSpace.md),
              Text(
                'Attached documents',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: dialogContext.textColor,
                ),
              ),
              const SizedBox(height: 4),
              RequestDocumentList(documents: request.documents, dense: true),
              if (request.scheduledFor != null) ...[
                const SizedBox(height: TabangSpace.sm),
                Text(
                  'Booked slot: ${formatDateTime(request.scheduledFor!)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              if (assignable.isNotEmpty) ...[
                const SizedBox(height: TabangSpace.sm),
                Text(
                  'Holds attached on approval: '
                  '${assignable.map((unit) => unit.barcode).join(', ')}',
                  style: const TextStyle(fontSize: 12.5),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final ok = repo.verifyRequest(
              request.id,
              actorId: actor.id,
              unitIds: assignable.map((unit) => unit.barcode).toList(),
            );
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(
              TabangSnackBar(
                content: Text(
                  ok
                      ? 'Request ${request.id} verified and opened.'
                      : 'Could not verify ${request.id}.',
                ),
                // Verifying also confirms the booked slot; the undo returns
                // the request to the review queue and releases any holds.
                action: ok
                    ? SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          final reverted = repo.revertRequestVerification(
                            request.id,
                            actorId: actor.id,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            TabangSnackBar(
                              content: Text(
                                reverted
                                    ? 'Verification undone; ${request.id} is '
                                          'back in review.'
                                    : 'Could not undo the verification; '
                                          'fulfilment may have started.',
                              ),
                            ),
                          );
                        },
                      )
                    : null,
              ),
            );
          },
          child: const Text('Verify and open'),
        ),
      ],
    ),
  );
}

/// Reject a submitted request with a reason the requester can read.
Future<void> showRejectRequestDialog(
  BuildContext context,
  BloodRequest request, {
  required AppUser actor,
}) {
  final repo = TabangRepository.instance;
  final reasonController = TextEditingController();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('Reject request ${request.id}'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The requester sees this reason, so be specific about the '
              'document or detail that needs fixing.',
              style: TextStyle(fontSize: 12.5, height: 1.5),
            ),
            const SizedBox(height: TabangSpace.md),
            TextField(
              controller: reasonController,
              autofocus: true,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason for rejection',
                hintText: 'e.g. No transfusion slip attached yet',
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
        FilledButton(
          onPressed: () {
            final ok = repo.rejectRequest(
              request.id,
              actorId: actor.id,
              reason: reasonController.text,
            );
            Navigator.pop(dialogContext);
            ScaffoldMessenger.of(context).showSnackBar(
              TabangSnackBar(
                content: Text(
                  ok
                      ? 'Request ${request.id} rejected with a reason.'
                      : 'Enter a reason before rejecting.',
                ),
                duration: const Duration(seconds: 6),
                action: ok
                    ? SnackBarAction(
                        label: 'Undo',
                        onPressed: () {
                          final undone = repo.undoRejectRequest(
                            request.id,
                            actorId: actor.id,
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            TabangSnackBar(
                              content: Text(
                                undone
                                    ? 'Request ${request.id} is back in the '
                                          'review queue.'
                                    : 'That rejection can no longer be undone.',
                              ),
                            ),
                          );
                        },
                      )
                    : null,
              ),
            );
          },
          child: const Text('Reject request'),
        ),
      ],
    ),
  );
}
