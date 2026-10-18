import 'package:flutter/material.dart';

class SettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const SettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // Notification Toggle States
  bool _overallNotifications = true;
  bool _newsNotifications = true;
  bool _chatNotifications = true;

  // Privacy & Data Sharing Toggle States
  bool _shareLocationWithBloodBank = true;
  bool _publicDonorDirectory = false;
  bool _analyticsCollection = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardColor = isDark ? const Color(0xFF292929) : Colors.white;
    final textColor = theme.colorScheme.onSurface;

    return Container(
      color: theme.scaffoldBackgroundColor,
      padding: const EdgeInsets.all(25),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Settings',
              style: TextStyle(
                fontSize: 25,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 25),

            // ==============================================
            // APPEARANCE
            // ==============================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Appearance',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how TABANG should display.',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(.6),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _themeOption(
                    context,
                    ThemeMode.system,
                    Icons.settings_suggest,
                    'System',
                    'Follow your computer settings.',
                  ),
                  _themeOption(
                    context,
                    ThemeMode.light,
                    Icons.light_mode,
                    'Light',
                    'Always use light mode.',
                  ),
                  _themeOption(
                    context,
                    ThemeMode.dark,
                    Icons.dark_mode,
                    'Dark',
                    'Always use dark mode.',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==============================================
            // NOTIFICATIONS
            // ==============================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Notifications',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage what alerts and updates you receive.',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _notificationSwitch(
                    title: 'Overall Notifications',
                    subtitle: 'Master switch to pause or enable all alerts.',
                    value: _overallNotifications,
                    onChanged: (val) {
                      setState(() => _overallNotifications = val);
                    },
                    textColor: textColor,
                    theme: theme,
                  ),
                  const Divider(height: 24),
                  _notificationSwitch(
                    title: 'News & Announcements',
                    subtitle: 'Blood drives, chapter updates, and community news.',
                    value: _newsNotifications,
                    onChanged: _overallNotifications
                        ? (val) => setState(() => _newsNotifications = val)
                        : null,
                    textColor: textColor,
                    theme: theme,
                  ),
                  const SizedBox(height: 12),
                  _notificationSwitch(
                    title: 'Chat Messages',
                    subtitle: 'Direct notifications when donors or recipients message you.',
                    value: _chatNotifications,
                    onChanged: _overallNotifications
                        ? (val) => setState(() => _chatNotifications = val)
                        : null,
                    textColor: textColor,
                    theme: theme,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ==============================================
            // PRIVACY & DATA SHARING
            // ==============================================
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Privacy & Data Sharing',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Manage your data safety, visibility, and information sharing compliance.',
                    style: TextStyle(
                      fontSize: 12,
                      color: textColor.withOpacity(.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _notificationSwitch(
                    title: 'Share Location with Blood Bank',
                    subtitle: 'Allow local chapter coordinators to view your general vicinity during critical blood shortages.',
                    value: _shareLocationWithBloodBank,
                    onChanged: (val) => setState(() => _shareLocationWithBloodBank = val),
                    textColor: textColor,
                    theme: theme,
                  ),
                  const Divider(height: 24),
                  _notificationSwitch(
                    title: 'Public Donor Directory Profile',
                    subtitle: 'Allow other verified users to view your blood type and contact handles for quick outreach.',
                    value: _publicDonorDirectory,
                    onChanged: (val) => setState(() => _publicDonorDirectory = val),
                    textColor: textColor,
                    theme: theme,
                  ),
                  const Divider(height: 24),
                  _notificationSwitch(
                    title: 'Diagnostic & Usage Analytics',
                    subtitle: 'Share anonymous crash data and app telemetry to help improve platform stability.',
                    value: _analyticsCollection,
                    onChanged: (val) => setState(() => _analyticsCollection = val),
                    textColor: textColor,
                    theme: theme,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _themeOption(
      BuildContext context,
      ThemeMode mode,
      IconData icon,
      String title,
      String description,
      ) {
    final theme = Theme.of(context);
    final selected = widget.themeMode == mode;
    final textColor = theme.colorScheme.onSurface;

    return GestureDetector(
      onTap: () {
        widget.onThemeChanged(mode);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? theme.colorScheme.primary.withOpacity(.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected
                  ? theme.colorScheme.primary
                  : textColor.withOpacity(.7),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    description,
                    style: TextStyle(
                      fontSize: 11,
                      color: textColor.withOpacity(.6),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(
                Icons.check_circle,
                color: theme.colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _notificationSwitch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
    required Color textColor,
    required ThemeData theme,
  }) {
    final bool isEnabled = onChanged != null;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: isEnabled ? textColor : textColor.withOpacity(0.4),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: isEnabled
                      ? textColor.withOpacity(0.6)
                      : textColor.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(
          value: value,
          onChanged: onChanged,
          activeColor: theme.colorScheme.primary,
        ),
      ],
    );
  }
}