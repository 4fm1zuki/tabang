import 'package:flutter/material.dart';

import '../../core/auth.dart';
import '../../theme.dart';
import '../../widgets/photo.dart';
import 'register_screen.dart';

/// Sign-in screen.
///
/// Replaces the previous role dropdown, which navigated to the admin
/// dashboard on the strength of a selected string. Credentials are now
/// verified by [AuthService] before any session exists.
class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    // Small delay so the button state is visible and the check feels real.
    await Future<void>.delayed(const Duration(milliseconds: 220));

    final result = AuthService.instance.signIn(
      email: _emailController.text,
      password: _passwordController.text,
    );

    if (!mounted) return;

    if (!result.ok) {
      setState(() {
        _busy = false;
        _error = result.error;
      });
      return;
    }

    // The root widget listens to the repository and swaps in the dashboard.
    setState(() => _busy = false);
  }

  void _fillDemo(String email, String password) {
    setState(() {
      _emailController.text = email;
      _passwordController.text = password;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          // Brand panel — hidden on narrow layouts.
          if (MediaQuery.sizeOf(context).width >= 900)
            const Expanded(flex: 5, child: _BrandPanel()),
          Expanded(
            flex: 4,
            child: Container(
              color: context.surface,
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(TabangSpace.xxl),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 380),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _buildHeader(context),
                          const SizedBox(height: TabangSpace.xl),
                          if (_error != null) ...[
                            _buildError(context, _error!),
                            const SizedBox(height: TabangSpace.lg),
                          ],
                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            decoration: const InputDecoration(
                              labelText: 'Email address',
                              prefixIcon: Icon(Icons.alternate_email, size: 18),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Enter your email address';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: TabangSpace.md),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscure,
                            autofillHints: const [AutofillHints.password],
                            onFieldSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              labelText: 'Password',
                              prefixIcon: const Icon(Icons.lock_outline, size: 18),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_outlined
                                      : Icons.visibility_off_outlined,
                                  size: 18,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Enter your password';
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: TabangSpace.xl),
                          SizedBox(
                            height: 46,
                            child: ElevatedButton(
                              onPressed: _busy ? null : _submit,
                              child: _busy
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text('Sign in'),
                            ),
                          ),
                          const SizedBox(height: TabangSpace.md),
                          Row(
                            children: [
                              const Expanded(child: Divider()),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: TabangSpace.md,
                                ),
                                child: Text(
                                  'or',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: context.textMuted,
                                  ),
                                ),
                              ),
                              const Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: TabangSpace.md),
                          SizedBox(
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: () => _showOAuthNotice(context),
                              icon: const Icon(Icons.g_mobiledata, size: 22),
                              label: const Text('Continue with Google'),
                            ),
                          ),
                          const SizedBox(height: TabangSpace.xl),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'No account yet?',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: context.textMuted,
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute<void>(
                                      builder: (_) => const RegisterScreen(),
                                    ),
                                  );
                                },
                                child: const Text('Create one'),
                              ),
                            ],
                          ),
                          const SizedBox(height: TabangSpace.lg),
                          _buildDemoAccounts(context),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(TabangRadius.sm),
              child: const SizedBox(
                width: 40,
                height: 40,
                child: TabangPhoto(
                  'assets/branding/app_icon.png',
                  semanticLabel: 'TABANG app icon',
                  fallbackIcon: Icons.water_drop,
                  fallbackIconSize: 22,
                ),
              ),
            ),
            const SizedBox(width: TabangSpace.md),
            Text(
              'TABANG',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.4,
                color: context.textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: TabangSpace.xl),
        Text(
          'Sign in',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.6,
            color: context.textColor,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Centralized donor management for Digos City.',
          style: TextStyle(fontSize: 12.5, color: context.textMuted),
        ),
      ],
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.all(TabangSpace.md),
      decoration: BoxDecoration(
        color: context.dangerBg,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        border: Border.all(color: TabangColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 16, color: TabangColors.danger),
          const SizedBox(width: TabangSpace.sm),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                color: TabangColors.danger,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDemoAccounts(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(TabangSpace.md),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        border: Border.all(color: context.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.science_outlined, size: 13, color: context.textMuted),
              const SizedBox(width: 6),
              Text(
                'SIMULATED DATA — DEMO ACCOUNTS',
                style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          _demoRow(context, 'Donor', 'iverson.briones@tabang.app', 'donor1234'),
          _demoRow(context, 'Recipient', 'maria.santos@tabang.app', 'recipient1234'),
          _demoRow(context, 'Staff', 'staff@tabang.app', 'staff1234'),
          _demoRow(context, 'Admin', 'admin@tabang.app', 'admin1234'),
        ],
      ),
    );
  }

  Widget _demoRow(
    BuildContext context,
    String role,
    String email,
    String password,
  ) {
    return InkWell(
      onTap: () => _fillDemo(email, password),
      borderRadius: BorderRadius.circular(TabangRadius.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 2),
        child: Row(
          children: [
            SizedBox(
              width: 62,
              child: Text(
                role,
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w700,
                  color: context.textMuted,
                ),
              ),
            ),
            Expanded(
              child: Text(
                email,
                style: TextStyle(fontSize: 10.5, color: context.textColor),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              password,
              style: TextStyle(fontSize: 10.5, color: context.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  void _showOAuthNotice(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Google sign-in not configured'),
        content: const Text(
          'Google OAuth 2.0 requires a provisioned OAuth client for this '
          'build. The credential flow above is fully functional. OAuth is '
          'listed in the system requirements and remains a deployment '
          'prerequisite rather than a shipped feature.',
          style: TextStyle(fontSize: 13, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Understood'),
          ),
        ],
      ),
    );
  }
}

/// Left-hand brand panel.
class _BrandPanel extends StatelessWidget {
  const _BrandPanel();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            TabangColors.crimsonDark,
            TabangColors.crimson,
            Color(0xFF6E1512),
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          const TabangPhoto(
            'assets/images/hero_donation.jpg',
            alignment: Alignment.centerRight,
            semanticLabel: 'A donor giving blood at a community drive',
            fallbackIcon: Icons.volunteer_activism_outlined,
            fallbackIconSize: 96,
          ),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomLeft,
                end: Alignment.topRight,
                colors: [
                  TabangColors.crimsonDark.withValues(alpha: 0.98),
                  TabangColors.crimsonDark.withValues(alpha: 0.88),
                  TabangColors.crimson.withValues(alpha: 0.58),
                ],
                stops: const [0, 0.55, 1],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TabangSpace.xxxl),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Spacer(),
                const Icon(Icons.water_drop, color: Colors.white, size: 46),
                const SizedBox(height: TabangSpace.xl),
                const Text(
                  'Your single bag of blood\ncan save up to three lives.',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.22,
                    letterSpacing: -0.8,
                  ),
                ),
                const SizedBox(height: TabangSpace.lg),
                Text(
                  'TABANG connects voluntary donors with patients across the 26 '
                  'barangays of Digos City — with tokenized identities, enforced '
                  'donation cooldowns, and ABO/Rh compatibility matching.',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 13,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: TabangSpace.xxl),
                const Row(
                  children: [
                    _Stat(value: '26', label: 'Barangays'),
                    SizedBox(width: TabangSpace.xxl),
                    _Stat(value: '8', label: 'Blood types'),
                    SizedBox(width: TabangSpace.xxl),
                    _Stat(value: '12 wk', label: 'Cooldown'),
                  ],
                ),
                const Spacer(),
                Text(
                  'Cor Jesu College · Digos City · 2026',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.62),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Photography: public domain / CC0 · credits in About & Help',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 9.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
