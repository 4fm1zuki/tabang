import 'package:flutter/material.dart';

import '../../core/auth.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/photo.dart';
import '../../widgets/tabang_dropdown.dart';

/// Registration screen.
///
/// Collects the fields specified on p.22 of the paper (full name, nickname,
/// email, contact number, birth date, blood type, weight, city address) and
/// actually persists them. The previous build validated the form, showed a
/// success snackbar, and discarded everything.
///
/// Role selection is limited to Donor and Recipient. Administrative accounts
/// are provisioned, not self-registered — [AuthService.register] enforces this
/// even if the UI were bypassed.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _aliasController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _phoneController = TextEditingController();
  final _birthDateController = TextEditingController();

  String? _barangay;
  DateTime? _birthDate;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  /// 0 = who you are, 1 = contact & health details, 2 = password & review.
  int _step = 0;

  @override
  void dispose() {
    _fullNameController.dispose();
    _aliasController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    _phoneController.dispose();
    _birthDateController.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(now.year - 100),
      lastDate: now,
      helpText: 'Select your birth date',
    );
    if (picked != null) {
      setState(() {
        _birthDate = picked;
        _birthDateController.text = formatDate(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (_barangay == null) {
      setState(() => _error = 'Select your barangay.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 220));

    final result = AuthService.instance.register(
      fullName: _fullNameController.text,
      alias: _aliasController.text,
      email: _emailController.text,
      password: _passwordController.text,
      phone: _phoneController.text,
      barangay: _barangay!,
      birthDate: _birthDate,
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.error;
      });
      return;
    }

    // Session is live; pop back so the root router shows the dashboard.
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.surface,
      appBar: AppBar(
        backgroundColor: context.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, size: 20),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Create account',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(TabangSpace.xxl),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TabangLogo(size: 48, plate: context.isDark),
                      const SizedBox(width: TabangSpace.md),
                      Expanded(
                        child: Text(
                          _step == 0
                              ? 'Join TABANG'
                              : _step == 1
                              ? 'Your details'
                              : 'Secure your account',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                            color: context.textColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: PhotoCredit('assets/branding/app_icon.png'),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _step == 0
                        ? 'First, tell us who you are. Your real name is '
                              'never shown to other users.'
                        : _step == 1
                        ? 'A few details so we can match you safely.'
                        : 'Review everything, then choose a password.',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: context.textMuted,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: TabangSpace.lg),
                  _stepIndicator(context),
                  const SizedBox(height: TabangSpace.lg),

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(TabangSpace.md),
                      decoration: BoxDecoration(
                        color: context.dangerBg,
                        borderRadius: BorderRadius.circular(TabangRadius.sm),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 16,
                            color: TabangColors.danger,
                          ),
                          const SizedBox(width: TabangSpace.sm),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: TabangColors.danger,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: TabangSpace.lg),
                  ],

                  if (_step == 0) ...[
                    Container(
                      padding: const EdgeInsets.all(TabangSpace.md),
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? TabangColors.crimson.withValues(alpha: 0.16)
                            : TabangColors.crimsonSoft,
                        borderRadius: BorderRadius.circular(TabangRadius.md),
                        border: Border.all(
                          color: TabangColors.crimson.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.groups_2_outlined,
                            size: 20,
                            color: TabangColors.crimson,
                          ),
                          const SizedBox(width: TabangSpace.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Community account',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w700,
                                    color: context.textColor,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  'You can request blood, browse donors and '
                                  'chat right away. You can register as a '
                                  'volunteer donor later from your profile.',
                                  style: TextStyle(
                                    fontSize: 11,
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
                    _label(context, 'Personal details'),
                    const SizedBox(height: TabangSpace.sm),
                    TextFormField(
                      controller: _fullNameController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Full name',
                        prefixIcon: Icon(Icons.person_outline, size: 18),
                      ),
                      validator: (v) => (v == null || v.trim().length < 3)
                          ? 'Enter your full name'
                          : null,
                    ),
                    const SizedBox(height: TabangSpace.md),
                    TextFormField(
                      controller: _aliasController,
                      decoration: const InputDecoration(
                        labelText: 'Nickname (shown to other users)',
                        prefixIcon: Icon(Icons.badge_outlined, size: 18),
                        helperText:
                            'Unique, and never your real name — e.g. "JuanDC"',
                      ),
                      validator: (v) {
                        final alias = v?.trim() ?? '';
                        if (alias.length < 2) return 'Choose a nickname';
                        if (alias.toLowerCase() ==
                            _fullNameController.text.trim().toLowerCase()) {
                          return 'Use a nickname, not your full name';
                        }
                        if (TabangRepository.instance.isAliasTaken(alias)) {
                          return 'That nickname is already taken';
                        }
                        return null;
                      },
                    ),
                  ],
                  if (_step == 1) ...[
                    _label(context, 'Contact & location'),
                    const SizedBox(height: TabangSpace.sm),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.alternate_email, size: 18),
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Enter your email';
                              }
                              if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                  .hasMatch(v.trim())) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: TabangSpace.md),
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Contact number',
                              prefixIcon: Icon(Icons.phone_outlined, size: 18),
                            ),
                            validator: (v) => (v == null || v.trim().length < 7)
                                ? 'Enter a contact number'
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: TabangSpace.md),
                    TextFormField(
                      controller: _birthDateController,
                      readOnly: true,
                      onTap: _pickBirthDate,
                      decoration: const InputDecoration(
                        labelText: 'Birth date',
                        prefixIcon: Icon(Icons.cake_outlined, size: 18),
                        suffixIcon: Icon(
                          Icons.calendar_today_outlined,
                          size: 16,
                        ),
                      ),
                      validator: (_) =>
                          _birthDate == null ? 'Select your birth date' : null,
                    ),
                    const SizedBox(height: TabangSpace.md),
                    TabangDropdown<String>(
                      initialValue: _barangay,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Barangay',
                        prefixIcon: Icon(Icons.location_on_outlined, size: 18),
                      ),
                      items: DigosBarangays.all
                          .map(
                            (b) => DropdownMenuItem(value: b, child: Text(b)),
                          )
                          .toList(),
                      onChanged: (v) => setState(() => _barangay = v),
                      validator: (v) =>
                          v == null ? 'Select your barangay' : null,
                    ),
                  ],

                  if (_step == 2) ...[
                    _label(context, 'Security'),
                    const SizedBox(height: TabangSpace.sm),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline, size: 18),
                        helperText: 'At least 8 characters',
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            size: 18,
                          ),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) => (v == null || v.length < 8)
                          ? 'Use at least 8 characters'
                          : null,
                    ),
                    const SizedBox(height: TabangSpace.md),
                    TextFormField(
                      controller: _confirmController,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                        labelText: 'Confirm password',
                        prefixIcon: Icon(Icons.lock_reset_outlined, size: 18),
                        helperText: 'Type the same password again',
                      ),
                      validator: (v) => v != _passwordController.text
                          ? 'Passwords do not match'
                          : null,
                    ),

                    const SizedBox(height: TabangSpace.lg),
                    _reviewCard(context),
                  ],

                  const SizedBox(height: TabangSpace.xl),
                  Row(
                    children: [
                      if (_step > 0) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _busy ? null : _prevStep,
                            child: const Text('Back'),
                          ),
                        ),
                        const SizedBox(width: TabangSpace.md),
                      ],
                      Expanded(
                        flex: _step > 0 ? 2 : 1,
                        child: SizedBox(
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _busy
                                ? null
                                : (_step < 2 ? _nextStep : _submit),
                            child: _busy
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    _step < 2 ? 'Continue' : 'Create account',
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_step == 2) ...[
                    const SizedBox(height: TabangSpace.md),
                    Text(
                      'By registering you agree that TABANG stores your blood '
                      'type and donation history to enforce eligibility rules, '
                      'in line with RA 10173.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.textMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _nextStep() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_step == 1 && _barangay == null) {
      setState(() => _error = 'Select your barangay.');
      return;
    }
    if (_birthDate == null && _step == 1) {
      setState(() => _error = 'Select your birth date.');
      return;
    }
    setState(() {
      _step = (_step + 1).clamp(0, 2);
      _error = null;
    });
  }

  void _prevStep() {
    setState(() {
      _step = (_step - 1).clamp(0, 2);
      _error = null;
    });
  }

  Widget _stepIndicator(BuildContext context) {
    const labels = ['You', 'Details', 'Secure'];
    return Row(
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: i <= _step ? TabangColors.crimson : context.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${i + 1}. ${labels[i]}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: i == _step ? FontWeight.w700 : FontWeight.w500,
                    color: i <= _step
                        ? TabangColors.crimson
                        : context.textMuted,
                  ),
                ),
              ],
            ),
          ),
          if (i != labels.length - 1) const SizedBox(width: TabangSpace.sm),
        ],
      ],
    );
  }

  Widget _reviewCard(BuildContext context) {
    String value(String? raw) => (raw == null || raw.isEmpty) ? '—' : raw;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'REVIEW',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: TabangSpace.sm),
          _reviewRow(context, 'Account type', UserRole.user.label),
          _reviewRow(context, 'Full name', value(_fullNameController.text)),
          _reviewRow(
            context,
            'Nickname (public)',
            value(_aliasController.text.trim()),
          ),
          _reviewRow(context, 'Email', value(_emailController.text.trim())),
          _reviewRow(context, 'Contact', value(_phoneController.text.trim())),
          _reviewRow(context, 'Barangay', value(_barangay)),
          _reviewRow(
            context,
            'Birth date',
            _birthDate == null ? '—' : formatDate(_birthDate!),
          ),
        ],
      ),
    );
  }

  Widget _reviewRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(fontSize: 11.5, color: context.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: context.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(BuildContext context, String text) {
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: context.textMuted,
      ),
    );
  }
}
