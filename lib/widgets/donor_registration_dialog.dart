import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/repository.dart';
import '../theme.dart';
import 'common.dart';

/// Volunteer-donor registration form.
///
/// Mirrors the parts of the PRC Blood Donor Interview Sheet a person can
/// answer on their own: personal data, the medical-history checklist and the
/// donor's declaration. The interview, physical examination, blood typing and
/// screening happen at the chapter, and staff verifies the account afterwards
/// — the form says so instead of pretending the applicant is already a donor.
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
  final _formKey = GlobalKey<FormState>();
  final _weight = TextEditingController();
  final _contact = TextEditingController();
  final _idNumber = TextEditingController();

  DateTime? _birthDate;
  BloodType? _bloodType;
  String? _sex;
  String? _idType;
  final Set<String> _flags = {};
  bool _declaration = false;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    if (user.weightKg != null) _weight.text = user.weightKg!.toStringAsFixed(0);
    if (user.phone.isNotEmpty) _contact.text = user.phone;
  }

  @override
  void dispose() {
    _weight.dispose();
    _contact.dispose();
    _idNumber.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Select your birth date',
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_birthDate == null || _sex == null || _idType == null) {
      setState(() => _error = 'Fill in your birth date, sex and ID type.');
      return;
    }
    if (!_declaration) {
      setState(() => _error = 'Accept the donor declaration to continue.');
      return;
    }

    setState(() {
      _submitting = true;
      _error = null;
    });

    final application = TabangRepository.instance.submitDonorApplication(
      userId: widget.user.id,
      bloodType: _bloodType ?? widget.user.bloodType,
      birthDate: _birthDate!,
      weightKg: double.tryParse(_weight.text.trim()) ?? 0,
      sex: _sex!,
      contact: _contact.text.trim(),
      idType: _idType!,
      idNumber: _idNumber.text.trim(),
      medicalFlags: _flags.toList(growable: false),
      declarationAccepted: true,
    );

    if (!mounted) return;
    if (application == null) {
      setState(() {
        _submitting = false;
        _error =
            'Check your birth date and weight: donors must be 18–65 and at '
            'least 50 kg.';
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Register as a blood donor'),
      content: SizedBox(
        width: 560,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _intro(context),
                const SizedBox(height: TabangSpace.lg),
                _sectionLabel(context, 'I. Personal data'),
                const SizedBox(height: TabangSpace.sm),
                InkWell(
                  borderRadius: BorderRadius.circular(TabangRadius.sm),
                  onTap: _pickBirthDate,
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Birth date',
                      helperText: 'Whole-blood donors must be 18–65 years old',
                      prefixIcon: Icon(Icons.cake_outlined, size: 18),
                      suffixIcon:
                          Icon(Icons.calendar_today_outlined, size: 16),
                      isDense: true,
                    ),
                    child: Text(
                      _birthDate == null
                          ? 'Select your birth date'
                          : formatDate(_birthDate!),
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
                DropdownButtonFormField<BloodType?>(
                  initialValue: _bloodType,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Blood type (if you know it)',
                    helperText:
                        'Leave as "I don\'t know yet" — the chapter types '
                        'your blood during screening',
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
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _sex,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Sex',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Female', child: Text('Female')),
                          DropdownMenuItem(value: 'Male', child: Text('Male')),
                          DropdownMenuItem(
                            value: 'Prefer not to say',
                            child: Text('Prefer not to say'),
                          ),
                        ],
                        onChanged: (v) => setState(() => _sex = v),
                      ),
                    ),
                    const SizedBox(width: TabangSpace.md),
                    Expanded(
                      child: TextFormField(
                        controller: _weight,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Weight (kg)',
                          helperText: 'At least 50 kg',
                          isDense: true,
                        ),
                        validator: (v) =>
                            (double.tryParse(v?.trim() ?? '') ?? 0) < 50
                                ? 'At least 50 kg is required'
                                : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TabangSpace.md),
                TextFormField(
                  controller: _contact,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Contact number',
                    helperText: 'Used by chapter staff for your screening',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                    isDense: true,
                  ),
                  validator: (v) => (v == null || v.trim().length < 7)
                      ? 'Enter a reachable number'
                      : null,
                ),
                const SizedBox(height: TabangSpace.md),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _idType,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'ID you will present',
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'School ID', child: Text('School ID')),
                          DropdownMenuItem(
                              value: 'Company ID', child: Text('Company ID')),
                          DropdownMenuItem(
                              value: "Driver's license",
                              child: Text("Driver's license")),
                          DropdownMenuItem(value: 'PRC ID', child: Text('PRC ID')),
                          DropdownMenuItem(
                              value: 'SSS / GSIS / UMID',
                              child: Text('SSS / GSIS / UMID')),
                          DropdownMenuItem(
                              value: 'Postal ID', child: Text('Postal ID')),
                          DropdownMenuItem(value: 'Others', child: Text('Others')),
                        ],
                        onChanged: (v) => setState(() => _idType = v),
                      ),
                    ),
                    const SizedBox(width: TabangSpace.md),
                    Expanded(
                      child: TextFormField(
                        controller: _idNumber,
                        decoration: const InputDecoration(
                          labelText: 'ID number',
                          helperText: 'Checked at the chapter, not stored '
                              'publicly',
                          isDense: true,
                        ),
                        validator: (v) => (v == null || v.trim().length < 4)
                            ? 'Enter the ID number'
                            : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: TabangSpace.lg),
                _sectionLabel(context, 'II. Medical history'),
                const SizedBox(height: 2),
                Text(
                  'Tick anything that applies to you. A tick is not an '
                  'automatic refusal — it tells the interviewer what to ask '
                  'about privately.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.45,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: TabangSpace.sm),
                for (final question in kDonorMedicalQuestions)
                  InkWell(
                    borderRadius: BorderRadius.circular(TabangRadius.xs),
                    onTap: () => setState(() {
                      if (!_flags.add(question)) _flags.remove(question);
                    }),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          SizedBox(
                            width: 30,
                            height: 30,
                            child: Checkbox(
                              value: _flags.contains(question),
                              onChanged: (_) => setState(() {
                                if (!_flags.add(question)) {
                                  _flags.remove(question);
                                }
                              }),
                              visualDensity: VisualDensity.compact,
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              question,
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.35,
                                color: context.textColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: TabangSpace.lg),
                _sectionLabel(context, 'III. Donor declaration'),
                const SizedBox(height: TabangSpace.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(TabangSpace.md),
                  decoration: BoxDecoration(
                    color: context.surfaceAlt,
                    borderRadius: BorderRadius.circular(TabangRadius.sm),
                  ),
                  child: Text(
                    'I volunteer to donate blood without payment. I understand '
                    'that my blood will be screened for malaria, syphilis, '
                    'hepatitis B and C and HIV, and that a reactive screening '
                    'result is referred to the chapter for counselling. I '
                    'consent to TABANG using these answers under the Data '
                    'Privacy Act of 2012.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      color: context.textColor,
                    ),
                  ),
                ),
                const SizedBox(height: TabangSpace.sm),
                InkWell(
                  borderRadius: BorderRadius.circular(TabangRadius.xs),
                  onTap: () =>
                      setState(() => _declaration = !_declaration),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 30,
                        height: 30,
                        child: Checkbox(
                          value: _declaration,
                          onChanged: (_) => setState(
                              () => _declaration = !_declaration),
                          visualDensity: VisualDensity.compact,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'I have read and accept the declaration above.',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: context.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(TabangSpace.md),
                  decoration: BoxDecoration(
                    color: context.infoBg,
                    borderRadius: BorderRadius.circular(TabangRadius.sm),
                  ),
                  child: Text(
                    'What happens next: chapter staff reviews this form, then '
                    'asks you to present your ID and complete the interview, '
                    'physical examination, blood typing and screening. You '
                    'appear in the donor directory only after that '
                    'verification.',
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.5,
                      color: context.textColor,
                    ),
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
      ),
      actions: [
        TextButton(
          onPressed:
              _submitting ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.favorite_outline, size: 17),
          label: Text(_submitting ? 'Submitting…' : 'Submit registration'),
        ),
      ],
    );
  }

  Widget _intro(BuildContext context) {
    return Text(
      'This is the part of the PRC Blood Donor Interview Sheet you can '
      'answer here. The interview, examination, blood typing and screening '
      'are done in person at the chapter.',
      style: TextStyle(
        fontSize: 12.5,
        height: 1.5,
        color: context.textMuted,
      ),
    );
  }

  Widget _sectionLabel(BuildContext context, String text) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 13.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.2,
        color: context.textColor,
      ),
    );
  }
}
