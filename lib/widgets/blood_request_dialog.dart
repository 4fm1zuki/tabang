import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repository.dart';
import '../theme.dart';

/// Shared recipient request dialog.
///
/// Submission is a formal request, not an instant reservation: the requester
/// declares the documents the chapter reviews, books one of the published
/// blood-bank slots, and decides whether the request may also be posted to the
/// donor network. Chapter staff then verify or reject it before any donor is
/// asked to respond. Keeping the dialog in one place means the Blood Bank and
/// Requests surfaces cannot drift apart.

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

  // Required documents are pre-declared because the requester is submitting
  // them to the chapter; staff confirm the physical copies at verification.
  final documents = <String>{
    RequestDocuments.doctorsForm,
    RequestDocuments.transfusionSlip,
    RequestDocuments.patientId,
  };
  var typingResultReady = false;
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
          documents.contains,
        );
        final needsDonorNetwork = !hasStock;
        final canSubmit =
            hasRequiredDocuments &&
            scheduledFor != null &&
            (!needsDonorNetwork || postToDonors);

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
            documents: [
              ...documents,
              if (typingResultReady) RequestDocuments.typingResult,
            ],
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
                      'Document checklist',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: dialogContext.textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Chapter staff verify these before the request reaches '
                      'the blood bank or the donor network.',
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.45,
                        color: dialogContext.textMuted,
                      ),
                    ),
                    for (final document in RequestDocuments.all)
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        value: document == RequestDocuments.typingResult
                            ? typingResultReady
                            : documents.contains(document),
                        onChanged: (value) => setDialogState(() {
                          if (document == RequestDocuments.typingResult) {
                            typingResultReady = value ?? false;
                          } else if (value ?? false) {
                            documents.add(document);
                          } else {
                            documents.remove(document);
                          }
                        }),
                        title: Text(
                          document,
                          style: const TextStyle(fontSize: 12.5),
                        ),
                        subtitle: document == RequestDocuments.typingResult
                            ? const Text(
                                'Optional — only when the hospital asks for it',
                                style: TextStyle(fontSize: 10.5),
                              )
                            : null,
                      ),
                    if (!hasRequiredDocuments)
                      const Text(
                        'All three required documents must be on hand before '
                        'submitting.',
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
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<DateTime>(
                              initialValue: selectedDay,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Day',
                              ),
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
                          const SizedBox(width: TabangSpace.md),
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<int>(
                              initialValue: scheduledFor?.hour,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Time',
                              ),
                              items: hours
                                  .map(
                                    (hour) => DropdownMenuItem(
                                      value: hour,
                                      child: Text(_formatSlotHour(hour)),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (hour) => setDialogState(() {
                                if (hour == null || selectedDay == null) return;
                                scheduledFor = DateTime(
                                  selectedDay.year,
                                  selectedDay.month,
                                  selectedDay.day,
                                  hour,
                                );
                              }),
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
