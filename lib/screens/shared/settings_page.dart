import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';

/// Settings.
///
/// Notification and privacy preferences are stored on the signed-in user
/// record, so they survive page changes and are visible to the rest of the app.
/// The donor-directory switch is the same `isAvailable` flag used by
/// eligibility and request matching; the barangay switch controls whether the
/// donor's barangay is shown in the directory. The notification switches drive
/// the in-app summaries shown on the Home dashboard.
///
/// Guides and About live in their own destination (About & Help). They are not
/// buried here as a single "Show the welcome guide" tile.
class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.user,
    required this.themeMode,
    required this.onThemeModeChanged,
    this.compactNav = false,
    this.onCompactNavChanged,
    this.railPinned = true,
    this.onRailPinnedChanged,
  });

  final AppUser user;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  /// Slim rails preference, owned by the root app so both shells share it.
  final bool compactNav;
  final ValueChanged<bool>? onCompactNavChanged;

  /// Whether desktop sidebars stay expanded instead of opening on hover.
  final bool railPinned;
  final ValueChanged<bool>? onRailPinnedChanged;

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
            subtitle:
                'Appearance, notifications, privacy and account controls.',
            actions: [
              HelpTip(
                title: 'About these settings',
                message:
                    'Preferences are saved on your TABANG account and apply '
                    'immediately. Guides, FAQs and image credits are available '
                    'under About & Help in the navigation.',
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.xl),

          _section(
            context,
            'Appearance',
            'Choose how TABANG displays on this device.',
            help:
                'Light is the default. Dark pins the darker theme on this '
                'session. The map follows the active theme too, with a '
                'per-visit override from the map style button on desktop.',
            children: [
              _themeOption(
                context,
                ThemeMode.light,
                Icons.light_mode_outlined,
                'Light',
                'Default · warm surfaces and dark text',
              ),
              _themeOption(
                context,
                ThemeMode.dark,
                Icons.dark_mode_outlined,
                'Dark',
                'Always use the dark theme',
              ),
              const SizedBox(height: TabangSpace.md),
              _switchRow(
                context,
                'Slim navigation rails',
                'Hide the names under icons on the bottom bar, and keep the '
                    'side rail at icon width',
                widget.compactNav,
                (value) => widget.onCompactNavChanged?.call(value),
              ),
              _switchRow(
                context,
                'Keep the sidebar pinned open',
                'Desktop sidebars stay expanded. When off, they open on hover '
                    'and collapse when the pointer leaves.',
                widget.railPinned,
                (value) => widget.onRailPinnedChanged?.call(value),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          _section(
            context,
            'Notifications',
            'What TABANG should summarise for you.',
            help:
                'Choose which updates appear in your Home summary. Turning a '
                'category off hides it immediately.',
            children: [
              _switchRow(
                context,
                'Blood request alerts',
                'Show compatible requests and donor responses in my summary',
                user.notifyRequests,
                (v) => _repo.updateUser(user.copyWith(notifyRequests: v)),
              ),
              _switchRow(
                context,
                'Chat messages',
                'Show conversation updates in my summary',
                user.notifyChat,
                (v) => _repo.updateUser(user.copyWith(notifyChat: v)),
              ),
              _switchRow(
                context,
                'News and drives',
                'Show upcoming blood drives and campaigns in my summary',
                user.notifyNews,
                (v) => _repo.updateUser(user.copyWith(notifyNews: v)),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          if (user.role == UserRole.donor) ...[
            _section(
              context,
              'Donor availability',
              'Control whether the donor directory can show you.',
              help:
                  'TABANG hides you automatically during a donation cooldown '
                  'even when the directory switch is on. Exact addresses are '
                  'never shown; the barangay switch controls the only location '
                  'other users see.',
              children: [
                _switchRow(
                  context,
                  'List me in the public donor directory',
                  'When off, you are hidden from the directory and marked '
                      'unavailable for request matching',
                  user.isAvailable,
                  (v) => _repo.setDonorAvailability(user.id, v),
                ),
                _switchRow(
                  context,
                  'Show my barangay to other users',
                  'Exact addresses are never shown; turn this off to hide '
                      'your barangay in the donor directory',
                  user.shareBarangay,
                  (v) => _repo.updateUser(user.copyWith(shareBarangay: v)),
                ),
              ],
            ),
            const SizedBox(height: TabangSpace.lg),
          ],

          _section(
            context,
            'Privacy & data',
            'Controls aligned with RA 10173 (Data Privacy Act).',
            help:
                'Your real name and exact address are never shown to other '
                'users. Donors and recipients appear as aliases until both '
                'sides agree to reveal their identity. Staff can see real names '
                'only for verified care coordination.',
            children: [
              _note(
                context,
                Icons.shield_outlined,
                'Your real name and exact address are never shown to other '
                'users. Donors and recipients appear as aliases until both '
                'sides agree to reveal their identity.',
              ),
              const SizedBox(height: TabangSpace.sm),
              _dataRow(context, 'Public identity', user.alias),
              _dataRow(context, 'Account type', user.role.label),
              _dataRow(context, 'Account status', user.status.label),
              _dataRow(context, 'Barangay', user.barangay),
              if (user.bloodType != null)
                _dataRow(context, 'Blood type', user.bloodType!.label),
              const SizedBox(height: TabangSpace.sm),
              Text(
                'TABANG stores simulated records on this device only. No real '
                'hospital, Red Cross or EHR system is connected. You can sign '
                'out at any time to clear the active session.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.55,
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          _section(
            context,
            'Account',
            'Session and identity details.',
            children: [
              _dataRow(context, 'Email', user.email),
              _dataRow(context, 'Registered', formatDate(user.registeredOn)),
              const SizedBox(height: TabangSpace.sm),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmSignOut(context),
                  icon: const Icon(Icons.logout, size: 17),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: TabangColors.danger,
                    side: BorderSide(
                      color: TabangColors.danger.withValues(alpha: 0.4),
                    ),
                  ),
                ),
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
                fontSize: 11,
                height: 1.7,
                color: context.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmSignOut(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sign out?'),
        content: Text(
          'Your simulated records stay on this device. You can sign back in '
          'with the same account.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.5,
            color: context.textMuted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _repo.signOut();
            },
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
  }

  Widget _section(
    BuildContext context,
    String title,
    String subtitle, {
    required List<Widget> children,
    String? help,
  }) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: context.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (help != null) HelpTip(title: title, message: help),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),
          ...children,
        ],
      ),
    );
  }

  Widget _note(BuildContext context, IconData icon, String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TabangSpace.md),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: context.textMuted),
          const SizedBox(width: TabangSpace.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: context.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, color: context.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: context.textColor,
              ),
            ),
          ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(
          horizontal: TabangSpace.sm,
          vertical: TabangSpace.sm,
        ),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: selected
              ? (context.isDark
                    ? TabangColors.crimson.withValues(alpha: 0.16)
                    : TabangColors.crimsonSoft)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          border: Border.all(
            color: selected
                ? TabangColors.crimson.withValues(alpha: 0.35)
                : Colors.transparent,
          ),
        ),
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
                    style: TextStyle(fontSize: 11.5, color: context.textMuted),
                  ),
                ],
              ),
            ),
            RadioGroup<ThemeMode>(
              groupValue: widget.themeMode,
              onChanged: (v) {
                if (v != null) widget.onThemeModeChanged(v);
              },
              child: Radio<ThemeMode>(value: mode),
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
                  style: TextStyle(fontSize: 11.5, color: context.textMuted),
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
