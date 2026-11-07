import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repository.dart';
import '../theme.dart';

/// Shared recipient request dialog.
///
/// The paper's recipient flow (p.21) first checks participating facilities for
/// compatible stock. This dialog shows the live component-aware stock count and
/// lets the recipient either submit to the blood bank for processing or post to
/// the donor network. Keeping the dialog in one place means the Blood Bank and
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
  AppUser user,
) async {
  final repo = TabangRepository.instance;
  final formKey = GlobalKey<FormState>();
  final patientController = TextEditingController();
  final unitsController = TextEditingController(text: '1');
  final noteController = TextEditingController();

  var bloodType = user.bloodType ?? BloodType.oPos;
  var component = BloodComponent.packedRbc;
  var urgency = RequestUrgency.urgent;
  var barangay =
      DigosBarangays.canonical(user.barangay) ?? DigosBarangays.all.first;
  var hospital = DigosFacilities.names.first;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setDialogState) {
        final unitsNeeded = int.tryParse(unitsController.text.trim()) ?? 1;
        final availableUnits = repo
            .compatibleUnitsFor(
              recipientType: bloodType,
              component: component,
            )
            .length;
        final hasStock = availableUnits > 0;

        void submit(RequestSource source) {
          if (!formKey.currentState!.validate()) return;
          repo.addRequest(
            requesterId: user.id,
            patientAlias: patientController.text.trim(),
            bloodType: bloodType,
            component: component,
            unitsNeeded: int.parse(unitsController.text.trim()),
            hospital: hospital,
            barangay: barangay,
            urgency: urgency,
            source: source,
            note: noteController.text.trim().isEmpty
                ? null
                : noteController.text.trim(),
          );
          Navigator.pop(dialogContext);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                source == RequestSource.bloodBank
                    ? 'Request submitted to the blood bank for processing.'
                    : 'Request posted to the donor network.',
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
                          .map((h) => DropdownMenuItem(
                                value: h,
                                child: Text(
                                  h,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ))
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
                                .map((t) => DropdownMenuItem(
                                      value: t,
                                      child: Text(t.label),
                                    ))
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
                                .map((c) => DropdownMenuItem(
                                      value: c,
                                      child: Text(
                                        c.label,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ))
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
                                .map((u) => DropdownMenuItem(
                                      value: u,
                                      child: Text(u.label),
                                    ))
                                .toList(),
                            onChanged: (v) => setDialogState(
                              () => urgency = v ?? urgency,
                            ),
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
                          .map((b) => DropdownMenuItem(
                                value: b,
                                child: Text(b),
                              ))
                          .toList(),
                      onChanged: (v) =>
                          setDialogState(() => barangay = v ?? barangay),
                    ),
                    const SizedBox(height: TabangSpace.md),
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
                                      'in stock. Submit to the blood bank for '
                                      'processing, or post to the donor '
                                      'network.'
                                  : 'No compatible '
                                      '${component.label.toLowerCase()} stock '
                                      'right now. Post to the donor network so '
                                      'eligible donors can respond.',
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
                        'are in stock.',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: dialogContext.textMuted,
                        ),
                      ),
                    ],
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
            if (hasStock)
              OutlinedButton(
                onPressed: () => submit(RequestSource.donorNetwork),
                child: const Text('Post to donors'),
              ),
            ElevatedButton(
              onPressed: () => submit(
                hasStock
                    ? RequestSource.bloodBank
                    : RequestSource.donorNetwork,
              ),
              child: Text(
                hasStock ? 'Submit to blood bank' : 'Post to donors',
              ),
            ),
          ],
        );
      },
    ),
  );
}
