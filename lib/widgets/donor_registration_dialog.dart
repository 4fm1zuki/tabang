import 'package:flutter/material.dart';

import '../core/eligibility.dart';
import '../core/models.dart';
import '../core/repository.dart';
import '../theme.dart';
import 'common.dart';

/// Donor registration interest.
///
/// Registration is finished face-to-face: the chapter fills in the PRC Blood
/// Donor Interview Sheet, runs the physical examination, blood typing and
/// screening, and only then issues (or renews) the donor card. So this dialog
/// does not ask the medical questions — it only tells the chapter who is
/// coming, whether they already hold a card, and when they plan to visit.
Future<bool> showDonorRegistrationDialog(
  BuildContext context,
  AppUser user,
) async {
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _DonorRegistrationDialog(user: user),
  );
  return result ?? false;
}

class _DonorRegistrationDialog extends StatefulWidget {
  const _DonorRegistrationDialog({required this.user});

  final AppUser user;

  @override
  State<_DonorRegistrationDialog> createState() =>
      _DonorRegistrationDialogState();
}

class _DonorRegistrationDialogState extends State<_DonorRegistrationDialog> {
  final _cardNumber = TextEditingController();
  final _note = TextEditingController();
  final _weight = TextEditingController();

  /// Null until the applicant picks one of the two paths.
  bool? _hasCard;
  BloodType? _bloodType;
  DateTime? _birthDate;
  DateTime? _preferredVisit;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _bloodType = widget.user.bloodType;
    _birthDate = widget.user.birthDate;
    _weight.text = widget.user.weightKg?.toString() ?? '';
  }

  @override
  void dispose() {
    _cardNumber.dispose();
    _note.dispose();
    _weight.dispose();
    super.dispose();
  }

  /// Birth date and weight are the two eligibility inputs the chapter cannot
  /// verify remotely; collecting them here means a donor verified from the
  /// queue can actually be matched instead of failing on missing weight.
  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 66, 1, 1),
      lastDate: now,
      helpText: 'Your date of birth',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  int? get _age {
    final dob = _birthDate;
    if (dob == null) return null;
    final now = DateTime.now();
    var years = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      years--;
    }
    return years;
  }

  Future<void> _pickVisit() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _preferredVisit ?? now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 120)),
      helpText: 'When do you plan to visit the chapter?',
    );
    if (picked != null) setState(() => _preferredVisit = picked);
  }

  Future<void> _submit() async {
    if (_hasCard == null) {
      setState(() => _error = 'Choose whether you already have a donor card.');
      return;
    }
    final age = _age;
    if (age == null) {
      setState(() => _error = 'Add your date of birth.');
      return;
    }
    if (age < EligibilityEngine.minimumAge ||
        age > EligibilityEngine.maximumAge) {
      setState(
        () => _error =
            'Donors must be between ${EligibilityEngine.minimumAge} and '
            '${EligibilityEngine.maximumAge} years old.',
      );
      return;
    }
    final weight = double.tryParse(_weight.text.trim());
    if (weight == null) {
      setState(() => _error = 'Add your weight in kilograms.');
      return;
    }
    if (weight < EligibilityEngine.minimumWeightKg) {
      setState(
        () => _error =
            'Donors must weigh at least '
            '${EligibilityEngine.minimumWeightKg.toStringAsFixed(0)} kg.',
      );
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });

    final application = TabangRepository.instance.submitDonorApplication(
      userId: widget.user.id,
      hasExistingCard: _hasCard!,
      cardNumber: (_hasCard! && _cardNumber.text.trim().isNotEmpty)
          ? _cardNumber.text.trim()
          : null,
      bloodType: _bloodType,
      birthDate: _birthDate,
      weightKg: weight,
      preferredVisit: _preferredVisit,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );

    if (!mounted) return;
    if (application == null) {
      setState(() {
        _submitting = false;
        _error = 'This account cannot register as a donor right now.';
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final hasCard = _hasCard;

    return AlertDialog(
      title: const Text('Register as a blood donor'),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Donor registration is completed in person at the Philippine '
                'Red Cross — Davao del Sur Chapter in Digos City. The '
                'interview, physical examination, blood typing and screening '
                'all happen there, and the chapter issues or renews your donor '
                'card afterwards.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.55,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(height: TabangSpace.lg),
              Text(
                'Do you already have a PRC donor card?',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w800,
                  color: context.textColor,
                ),
              ),
              const SizedBox(height: TabangSpace.sm),
              _choice(
                context,
                selected: hasCard == true,
                icon: Icons.badge_outlined,
                title: 'Yes, I have a donor card',
                subtitle: 'Staff verifies the card and your details on site.',
                onTap: () => setState(() => _hasCard = true),
              ),
              const SizedBox(height: TabangSpace.sm),
              _choice(
                context,
                selected: hasCard == false,
                icon: Icons.person_add_alt_1_outlined,
                title: 'No, I need a new donor card',
                subtitle:
                    'The chapter walks you through the first-time process.',
                onTap: () => setState(() => _hasCard = false),
              ),
              if (hasCard == true) ...[
                const SizedBox(height: TabangSpace.md),
                TextField(
                  controller: _cardNumber,
                  decoration: const InputDecoration(
                    labelText: 'Donor card number (if you know it)',
                    prefixIcon: Icon(Icons.numbers_outlined, size: 18),
                    helperText: 'Found on the front of your PRC card',
                    isDense: true,
                  ),
                ),
              ],
              const SizedBox(height: TabangSpace.md),
              DropdownButtonFormField<BloodType?>(
                initialValue: _bloodType,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Blood type (if you know it)',
                  helperText:
                      'The chapter types your blood during screening if not',
                  prefixIcon: Icon(Icons.water_drop_outlined, size: 18),
                  isDense: true,
                ),
                items: [
                  const DropdownMenuItem<BloodType?>(
                    value: null,
                    child: Text("I don't know yet"),
                  ),
                  ...BloodType.values.map(
                    (t) => DropdownMenuItem<BloodType?>(
                      value: t,
                      child: Text(t.label),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _bloodType = v),
              ),
              const SizedBox(height: TabangSpace.md),
              InkWell(
                borderRadius: BorderRadius.circular(TabangRadius.sm),
                onTap: _pickBirthDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Date of birth',
                    helperText: 'Donors must be 18–65 years old',
                    prefixIcon: Icon(Icons.cake_outlined, size: 18),
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                    isDense: true,
                  ),
                  child: Text(
                    _birthDate == null
                        ? 'Pick your birth date'
                        : '${formatDate(_birthDate!)}'
                              '${_age == null ? '' : ' · $_age years old'}',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: _birthDate == null
                          ? context.textMuted
                          : context.textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: TabangSpace.md),
              TextField(
                controller: _weight,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(
                  labelText: 'Weight in kilograms',
                  helperText: 'Donors must weigh at least 50 kg',
                  prefixIcon: Icon(Icons.monitor_weight_outlined, size: 18),
                  isDense: true,
                ),
              ),
              const SizedBox(height: TabangSpace.md),
              InkWell(
                borderRadius: BorderRadius.circular(TabangRadius.sm),
                onTap: _pickVisit,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Planned visit (optional)',
                    helperText: 'Tells the chapter which day to expect you',
                    prefixIcon: Icon(Icons.event_available_outlined, size: 18),
                    suffixIcon: Icon(Icons.calendar_today_outlined, size: 16),
                    isDense: true,
                  ),
                  child: Text(
                    _preferredVisit == null
                        ? 'Pick a day'
                        : formatDate(_preferredVisit!),
                    style: TextStyle(
                      fontSize: 13.5,
                      color: _preferredVisit == null
                          ? context.textMuted
                          : context.textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: TabangSpace.md),
              TextField(
                controller: _note,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Note for chapter staff (optional)',
                  hintText: 'Anything they should know before you arrive',
                  isDense: true,
                ),
              ),
              const SizedBox(height: TabangSpace.lg),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(TabangSpace.md),
                decoration: BoxDecoration(
                  color: context.surfaceAlt,
                  borderRadius: BorderRadius.circular(TabangRadius.sm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bring these to the chapter',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: context.textColor,
                      ),
                    ),
                    const SizedBox(height: 6),
                    for (final requirement in kDonorRequirements)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 4),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.check_circle_outline,
                              size: 15,
                              color: TabangColors.crimson,
                            ),
                            const SizedBox(width: 7),
                            Expanded(
                              child: Text(
                                requirement,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  height: 1.4,
                                  color: context.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: TabangSpace.md),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: TabangColors.danger,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.send_outlined, size: 17),
          label: Text(_submitting ? 'Sending…' : 'Send to chapter'),
        ),
      ],
    );
  }

  Widget _choice(
    BuildContext context, {
    required bool selected,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(TabangRadius.sm),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(TabangSpace.md),
        decoration: BoxDecoration(
          color: selected
              ? (context.isDark
                    ? TabangColors.crimson.withValues(alpha: 0.14)
                    : TabangColors.crimsonSoft.withValues(alpha: 0.6))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          border: Border.all(
            color: selected ? TabangColors.crimson : context.border,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? TabangColors.crimson : context.textMuted,
            ),
            const SizedBox(width: TabangSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: context.textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              size: 18,
              color: selected ? TabangColors.crimson : context.textMuted,
            ),
          ],
        ),
      ),
    );
  }
}
