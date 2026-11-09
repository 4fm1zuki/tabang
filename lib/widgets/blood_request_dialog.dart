import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repository.dart';
import '../theme.dart';

/// Shared recipient request dialog.
///
/// Submission is a formal request, not an instant reservation: the requester
/// uploads the documents the chapter reviews, books one of the published
/// blood-bank slots, and decides whether the request may also be posted to the
/// donor network. Chapter staff then verify or reject it before any donor is
/// asked to respond. Keeping the dialog in one place means the Blood Bank and
/// Requests surfaces cannot drift apart, and there is no separate appointment
/// flow — the booked slot is part of this request.

/// Plain-language meaning of each urgency level, shown under the selector.
String _urgencyBlurb(RequestUrgency urgency) {
  switch (urgency) {
    case RequestUrgency.critical:
      return 'Critical — the patient needs units now. The chapter releases '
          'stock or confirms a donor as soon as possible, usually within '
          'minutes to a few hours.';
    case RequestUrgency.urgent:
      return 'Urgent — needed within 24–48 hours. The chapter schedules the '
          'next available slot or drive for this patient.';
    case RequestUrgency.routine:
      return 'Routine — planned use, usually three or more days away, such as '
          'a scheduled surgery.';
  }
}

Future<void> showBloodRequestDialog(
  BuildContext context,
  AppUser user, {
  BloodComponent? initialComponent,
  BloodType? initialBloodType,
}) async {
  final repo = TabangRepository.instance;
  final formKey = GlobalKey<FormState>();
  final patientController = TextEditingController();
  final unitsController = TextEditingController(text: '1');
  final noteController = TextEditingController();

  var bloodType = initialBloodType ?? user.bloodType ?? BloodType.oPos;
  var component = initialComponent ?? BloodComponent.packedRbc;
  var urgency = RequestUrgency.urgent;
  var barangay =
      DigosBarangays.canonical(user.barangay) ?? DigosBarangays.all.first;
  var hospital = DigosFacilities.names.first;

  // Actual files attached by the requester, keyed by document kind. Nothing
  // is pre-ticked: a checkbox is not evidence, so every required document
  // starts empty and submission waits for the real upload.
  final documents = <String, RequestDocument>{};
  var postToDonors = true;

  final slots = repo.bloodBankSlots(days: 14);
  DateTime? scheduledFor = slots.isEmpty ? null : slots.first;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final unitsNeeded = int.tryParse(unitsController.text.trim()) ?? 1;
        final availableUnits = repo
            .compatibleUnitsFor(recipientType: bloodType, component: component)
            .length;
        final hasStock = availableUnits > 0;

        final slotDays = <DateTime>[];
        for (final slot in slots) {
          final day = DateTime(slot.year, slot.month, slot.day);
          if (!slotDays.any(
            (existing) =>
                existing.year == day.year &&
                existing.month == day.month &&
                existing.day == day.day,
          )) {
            slotDays.add(day);
          }
        }
        final selectedDay = scheduledFor == null
            ? null
            : DateTime(
                scheduledFor!.year,
                scheduledFor!.month,
                scheduledFor!.day,
              );
        final hours = slots
            .where(
              (slot) =>
                  selectedDay != null &&
                  slot.year == selectedDay.year &&
                  slot.month == selectedDay.month &&
                  slot.day == selectedDay.day,
            )
            .map((slot) => slot.hour)
            .toList(growable: false);

        final hasRequiredDocuments = RequestDocuments.required.every(
          (kind) => documents[kind]?.hasFile ?? false,
        );
        final needsDonorNetwork = !hasStock;
        final canSubmit =
            hasRequiredDocuments &&
            scheduledFor != null &&
            (!needsDonorNetwork || postToDonors);

        /// Opens the platform file picker and stores the chosen file for
        /// [kind]. Kept inside the builder so it can call [setDialogState].
        Future<void> pickDocument(String kind) async {
          try {
            final file = await FilePicker.pickFile(
              type: FileType.custom,
              allowedExtensions: const ['pdf', 'jpg', 'jpeg', 'png'],
            );
            if (file == null) return;
            final length = await file.length() ?? 0;
            if (length > 8 * 1024 * 1024) {
              if (!dialogContext.mounted) return;
              ScaffoldMessenger.of(dialogContext).showSnackBar(
                const SnackBar(
                  content: Text('Attachments must be 8 MB or smaller.'),
                ),
              );
              return;
            }
            final bytes = await file.readAsBytes();
            if (!dialogContext.mounted) return;
            setDialogState(() {
              documents[kind] = RequestDocument(
                kind: kind,
                fileName: file.name,
                bytes: bytes,
                sizeBytes: bytes.length,
              );
            });
          } catch (_) {
            if (!dialogContext.mounted) return;
            ScaffoldMessenger.of(dialogContext).showSnackBar(
              const SnackBar(
                content: Text(
                  'The file picker could not be opened on this device.',
                ),
              ),
            );
          }
        }

        void submit() {
          if (!formKey.currentState!.validate()) return;
          if (!canSubmit) return;
          final created = repo.addRequest(
            requesterId: user.id,
            patientAlias: patientController.text.trim(),
            bloodType: bloodType,
            component: component,
            unitsNeeded: int.parse(unitsController.text.trim()),
            hospital: hospital,
            barangay: barangay,
            urgency: urgency,
            source: hasStock
                ? RequestSource.bloodBank
                : RequestSource.donorNetwork,
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
            documents: documents.values.toList(growable: false),
            scheduledFor: scheduledFor,
            postToDonorNetwork: postToDonors,
          );
          if (created == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'That submission is incomplete. Check the documents and the '
                  'blood-bank slot.',
                ),
              ),
            );
            return;
          }
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Request ${created.id} submitted. Chapter staff will verify '
                'the documents before it is posted.',
              ),
            ),
          );
        }

        return AlertDialog(
          title: const Text('Post a blood request'),
          content: SizedBox(
            width: 480,
            child: Form(
              key: formKey,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: patientController,
                      decoration: const InputDecoration(
                        labelText: 'Patient reference',
                        helperText: 'Use a token, not the real patient name',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Enter a patient reference'
                          : null,
                    ),
                    const SizedBox(height: TabangSpace.md),
                    DropdownButtonFormField<String>(
                      initialValue: hospital,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Participating facility',
                      ),
                      items: DigosFacilities.names
                          .map(
                            (h) => DropdownMenuItem(
                              value: h,
                              child: Text(h, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => hospital = v ?? hospital),
                    ),
                    const SizedBox(height: TabangSpace.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<BloodType>(
                            initialValue: bloodType,
                            isExpanded: true,
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
                            onChanged: (v) => setDialogState(
                              () => bloodType = v ?? bloodType,
                            ),
                          ),
                        ),
                        const SizedBox(width: TabangSpace.md),
                        Expanded(
                          child: TextFormField(
                            controller: unitsController,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'Units',
                            ),
                            onChanged: (_) => setDialogState(() {}),
                            validator: (v) {
                              final n = int.tryParse(v ?? '');
                              if (n == null || n < 1) return 'Min 1';
                              if (n > 20) return 'Max 20';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TabangSpace.md),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<BloodComponent>(
                            initialValue: component,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Component',
                            ),
                            items: BloodComponent.values
                                .map(
                                  (c) => DropdownMenuItem(
                                    value: c,
                                    child: Text(
                                      c.label,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) => setDialogState(
                              () => component = v ?? component,
                            ),
                          ),
                        ),
                        const SizedBox(width: TabangSpace.md),
                        Expanded(
                          child: DropdownButtonFormField<RequestUrgency>(
                            initialValue: urgency,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Urgency',
                            ),
                            items: RequestUrgency.values
                                .map(
                                  (u) => DropdownMenuItem(
                                    value: u,
                                    child: Text(u.label),
                                  ),
                                )
                                .toList(),
                            onChanged: (v) =>
                                setDialogState(() => urgency = v ?? urgency),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _urgencyBlurb(urgency),
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: dialogContext.textMuted,
                      ),
                    ),
                    const SizedBox(height: TabangSpace.md),
                    DropdownButtonFormField<String>(
                      initialValue: barangay,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Barangay'),
                      items: DigosBarangays.all
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => barangay = v ?? barangay),
                    ),
                    const SizedBox(height: TabangSpace.lg),
                    Text(
                      'Required documents',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: dialogContext.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Attach the actual files — PDF or photo, up to 8 MB each. '
                      'Chapter staff check these before the request reaches the '
                      'blood bank or the donor network.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: dialogContext.textMuted,
                      ),
                    ),
                    const SizedBox(height: TabangSpace.sm),
                    for (final document in RequestDocuments.all)
                      _DocumentUploadTile(
                        kind: document,
                        required: document != RequestDocuments.typingResult,
                        document: documents[document],
                        onPick: () => pickDocument(document),
                        onRemove: () =>
                            setDialogState(() => documents.remove(document)),
                      ),
                    if (!hasRequiredDocuments)
                      const Text(
                        'Attach all three required files before submitting.',
                        style: TextStyle(
                          fontSize: 11,
                          color: TabangColors.danger,
                        ),
                      ),
                    const SizedBox(height: TabangSpace.lg),
                    Text(
                      'Blood-bank schedule',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: dialogContext.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Slots follow the chapter schedule: Mon–Fri '
                      '8–11 AM and 1–3 PM, Sat 8–11 AM. Staff can adjust the '
                      'slot when they verify the request.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: dialogContext.textMuted,
                      ),
                    ),
                    const SizedBox(height: TabangSpace.sm),
                    if (slotDays.isEmpty)
                      const Text(
                        'No published slots are open right now.',
                        style: TextStyle(
                          fontSize: 12,
                          color: TabangColors.danger,
                        ),
                      )
                    else
                      // Plain dropdowns, not form fields: both values derive
                      // from `scheduledFor`, so picking a new day must
                      // immediately rebuild the Time list for that day (a
                      // FormField keeps its old value and could offer an hour
                      // that day does not publish).
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Day',
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<DateTime>(
                                  value: selectedDay,
                                  isExpanded: true,
                                  isDense: true,
                                  items: slotDays
                                      .map(
                                        (day) => DropdownMenuItem(
                                          value: day,
                                          child: Text(
                                            _formatSlotDay(day),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (day) => setDialogState(() {
                                    if (day == null) return;
                                    final firstHour = slots.firstWhere(
                                      (slot) =>
                                          slot.year == day.year &&
                                          slot.month == day.month &&
                                          slot.day == day.day,
                                    );
                                    scheduledFor = firstHour;
                                  }),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: TabangSpace.md),
                          Expanded(
                            flex: 2,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Time',
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  value:
                                      scheduledFor != null &&
                                          hours.contains(scheduledFor!.hour)
                                      ? scheduledFor!.hour
                                      : null,
                                  isExpanded: true,
                                  isDense: true,
                                  items: hours
                                      .map(
                                        (hour) => DropdownMenuItem(
                                          value: hour,
                                          child: Text(_formatSlotHour(hour)),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (hour) => setDialogState(() {
                                    if (hour == null || selectedDay == null) {
                                      return;
                                    }
                                    scheduledFor = DateTime(
                                      selectedDay.year,
                                      selectedDay.month,
                                      selectedDay.day,
                                      hour,
                                    );
                                  }),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: TabangSpace.lg),
                    Container(
                      padding: const EdgeInsets.all(TabangSpace.sm),
                      decoration: BoxDecoration(
                        color: hasStock
                            ? TabangColors.success.withValues(alpha: 0.08)
                            : TabangColors.warning.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(TabangRadius.xs),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            hasStock
                                ? Icons.inventory_2_outlined
                                : Icons.people_outline,
                            size: 15,
                            color: hasStock
                                ? TabangColors.success
                                : TabangColors.warning,
                          ),
                          const SizedBox(width: TabangSpace.sm),
                          Expanded(
                            child: Text(
                              hasStock
                                  ? '$availableUnits compatible '
                                        '${component.label.toLowerCase()} unit'
                                        '${availableUnits == 1 ? '' : 's'} '
                                        'in stock. The blood bank can process '
                                        'this request after verification.'
                                  : 'No compatible '
                                        '${component.label.toLowerCase()} stock '
                                        'right now. The request must be posted '
                                        'to the donor network.',
                              style: const TextStyle(
                                fontSize: 11.5,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (hasStock && availableUnits < unitsNeeded) ...[
                      const SizedBox(height: TabangSpace.xs),
                      Text(
                        'Only $availableUnits of $unitsNeeded requested units '
                        'are in stock; the donor network can cover the rest.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: dialogContext.textMuted,
                        ),
                      ),
                    ],
                    const SizedBox(height: TabangSpace.sm),
                    CheckboxListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: postToDonors,
                      onChanged: (value) =>
                          setDialogState(() => postToDonors = value ?? false),
                      title: const Text(
                        'Post to the donor network too',
                        style: TextStyle(fontSize: 12.5),
                      ),
                      subtitle: const Text(
                        'If the blood bank cannot cover it, eligible donors '
                        'can offer to donate. Turn this off for a blood-bank '
                        'request only.',
                        style: TextStyle(fontSize: 10.5),
                      ),
                    ),
                    const SizedBox(height: TabangSpace.md),
                    TextFormField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Clinical note (optional)',
                      ),
                    ),
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
            ElevatedButton.icon(
              onPressed: canSubmit ? submit : null,
              icon: const Icon(Icons.fact_check_outlined, size: 16),
              label: const Text('Submit for verification'),
            ),
          ],
        );
      },
    ),
  );
}

/// One attachment row in the request dialog.
///
/// Shows the file actually chosen, not a checkbox: the requester can attach,
/// replace or remove each document before submitting.
class _DocumentUploadTile extends StatelessWidget {
  const _DocumentUploadTile({
    required this.kind,
    required this.required,
    required this.document,
    required this.onPick,
    required this.onRemove,
  });

  final String kind;
  final bool required;
  final RequestDocument? document;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final document = this.document;
    final attached = document?.hasFile ?? false;
    final isImage = attached && _isImageName(document!.fileName);

    return Container(
      margin: const EdgeInsets.only(bottom: TabangSpace.xs),
      padding: const EdgeInsets.symmetric(
        horizontal: TabangSpace.sm,
        vertical: 7,
      ),
      decoration: BoxDecoration(
        color: attached
            ? TabangColors.success.withValues(alpha: 0.06)
            : Colors.transparent,
        border: Border.all(
          color: attached
              ? TabangColors.success.withValues(alpha: 0.45)
              : context.border,
        ),
        borderRadius: BorderRadius.circular(TabangRadius.xs),
      ),
      child: Row(
        children: [
          if (isImage)
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                document.bytes!,
                width: 34,
                height: 34,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  Icons.broken_image_outlined,
                  size: 18,
                  color: context.textMuted,
                ),
              ),
            )
          else
            Icon(
              attached
                  ? Icons.description_outlined
                  : Icons.upload_file_outlined,
              size: 18,
              color: attached ? TabangColors.success : context.textMuted,
            ),
          const SizedBox(width: TabangSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  kind,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  attached
                      ? '${document!.fileName}'
                            '${document.sizeLabel.isEmpty ? '' : ' · ${document.sizeLabel}'}'
                      : required
                      ? 'Required — attach a PDF or photo'
                      : 'Optional — only when the hospital asks for it',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: attached ? TabangColors.success : context.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (attached)
            IconButton(
              tooltip: 'Remove attachment',
              visualDensity: VisualDensity.compact,
              onPressed: onRemove,
              icon: const Icon(Icons.close, size: 16),
            ),
          TextButton(
            onPressed: onPick,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              attached ? 'Replace' : 'Attach',
              style: const TextStyle(fontSize: 11.5),
            ),
          ),
        ],
      ),
    );
  }
}

bool _isImageName(String fileName) {
  final lower = fileName.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png');
}

String _formatSlotDay(DateTime day) {
  const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${weekdays[day.weekday - 1]}, ${months[day.month - 1]} ${day.day}';
}

String _formatSlotHour(int hour) {
  final period = hour >= 12 ? 'PM' : 'AM';
  final display = hour > 12 ? hour - 12 : hour;
  return '$display:00 $period';
}
