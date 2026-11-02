import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';
import '../../widgets/onboarding.dart';

/// Settings.
///
/// Notification and privacy preferences are stored on the signed-in user
/// record, so they survive page changes and are visible to the rest of the app.
/// The donor-directory switch is the same `isAvailable` flag used by
/// eligibility and request matching; the barangay switch controls whether the
/// donor's barangay is shown in the directory. Push delivery is outside this
/// simulated build, so the notification switches drive in-app summaries.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.user,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final AppUser user;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final TabangRepository _repo = TabangRepository.instance;

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

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Settings',
            subtitle: 'Appearance, notifications and privacy controls.',
          ),
          const SizedBox(height: TabangSpace.xl),

          _section(
            context,
            'Appearance',
            'Choose how TABANG displays.',
            [
              _themeOption(context, ThemeMode.system, Icons.brightness_auto,
                  'System', 'Follow your device setting'),
              _themeOption(context, ThemeMode.light, Icons.light_mode_outlined,
                  'Light', 'Always use the light theme'),
              _themeOption(context, ThemeMode.dark, Icons.dark_mode_outlined,
                  'Dark', 'Always use the dark theme'),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          _section(
            context,
            'Guides & help',
            'New here, or want a refresher?',
            [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.school_outlined, size: 18),
                title: const Text(
                  'Show the welcome guide',
                  style: TextStyle(fontSize: 13),
                ),
                subtitle: const Text(
                  'A short walkthrough of the three things to do first',
                  style: TextStyle(fontSize: 10.5),
                ),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => showWelcomeGuide(context, user, markSeen: false),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          _section(
            context,
            'Notifications',
            'What TABANG should alert you about.',
            [
              _switchRow(
                context,
                'Blood request alerts',
                'Show compatible requests and donor responses in my summary',
                user.notifyRequests,
                (v) => _repo.updateUser(
                  user.copyWith(notifyRequests: v),
                ),
              ),
              _switchRow(
                context,
                'Chat messages',
                'Show conversation updates in my summary',
                user.notifyChat,
                (v) => _repo.updateUser(
                  user.copyWith(notifyChat: v),
                ),
              ),
              _switchRow(
                context,
                'News and drives',
                'Show upcoming blood drives and campaigns in my summary',
                user.notifyNews,
                (v) => _repo.updateUser(
                  user.copyWith(notifyNews: v),
                ),
              ),
              const SizedBox(height: TabangSpace.sm),
              Text(
                'This simulated build shows in-app summaries only. Push '
                'notifications require a deployed backend and are listed as a '
                'known gap in the README.',
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.5,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          _section(
            context,
            'Privacy & data',
            'Controls aligned with RA 10173 (Data Privacy Act).',
            [
              if (user.role == UserRole.donor) ...[
                _switchRow(
                  context,
                  'Show my barangay to other users',
                  'Exact addresses are never shown; turn this off to hide '
                      'your barangay in the donor directory',
                  user.shareBarangay,
                  (v) => _repo.updateUser(
                    user.copyWith(shareBarangay: v),
                  ),
                ),
                _switchRow(
                  context,
                  'List me in the public donor directory',
                  'When off, you are hidden from the directory and marked '
                      'unavailable for request matching',
                  user.isAvailable,
                  (v) => _repo.setDonorAvailability(user.id, v),
                ),
              ],
              const SizedBox(height: TabangSpace.sm),
              Container(
                padding: const EdgeInsets.all(TabangSpace.md),
                decoration: BoxDecoration(
                  color: context.surfaceAlt,
                  borderRadius: BorderRadius.circular(TabangRadius.sm),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.shield_outlined,
                        size: 15, color: context.textMuted),
                    const SizedBox(width: TabangSpace.sm),
                    Expanded(
                      child: Text(
                        'Your real name and exact address are never shown to '
                        'other users. Donors and recipients appear as aliases '
                        'until both sides agree to reveal their identity.',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.6,
                          color: context.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          _section(
            context,
            'Account',
            'Session and data controls.',
            [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.logout, size: 18),
                title: const Text('Sign out',
                    style: TextStyle(fontSize: 13)),
                trailing: const Icon(Icons.chevron_right, size: 18),
                onTap: () => _repo.signOut(),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.xl),
          Center(
            child: Text(
              'TABANG · Cor Jesu College · Digos City · 2026\n'
              'Simulated data build — not connected to live blood services.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                height: 1.7,
                color: context.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    String subtitle,
    List<Widget> children,
  ) {
    return SurfaceCard(
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
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11.5, color: context.textMuted),
          ),
          const SizedBox(height: TabangSpace.lg),
          ...children,
        ],
      ),
    );
  }

  Widget _themeOption(
    BuildContext context,
    ThemeMode mode,
    IconData icon,
    String title,
    String subtitle,
  ) {
    final selected = widget.themeMode == mode;
    return InkWell(
      borderRadius: BorderRadius.circular(TabangRadius.sm),
      onTap: () => widget.onThemeModeChanged(mode),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: TabangSpace.sm),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? TabangColors.crimson : context.textMuted,
            ),
            const SizedBox(width: TabangSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: context.textColor,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 10.5, color: context.textMuted),
                  ),
                ],
              ),
            ),
            RadioGroup<ThemeMode>(
              groupValue: widget.themeMode,
              onChanged: (v) {
                if (v != null) widget.onThemeModeChanged(v);
              },
              child: Radio<ThemeMode>(
                value: mode,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _switchRow(
    BuildContext context,
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10.5, color: context.textMuted),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}
