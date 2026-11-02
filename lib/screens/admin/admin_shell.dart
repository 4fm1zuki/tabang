import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/onboarding.dart';
import '../shared/about_help_page.dart';
import '../shared/profile_page.dart';
import '../shared/settings_page.dart';
import 'admin_overview.dart';
import 'chat_moderation_page.dart';
import 'inventory_management.dart';
import 'user_management_page.dart';

/// Navigation shell for clinical staff and administrators.
class AdminShell extends StatefulWidget {
  const AdminShell({
    super.key,
    required this.user,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final AppUser user;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;
  bool _hovering = false;
  bool _pinned = true;

  /// Pages created so far, kept alive across tab switches so filters, scroll
  /// positions and form state survive navigation.
  final Map<int, Widget> _pages = {};

  @override
  void initState() {
    super.initState();
    _pages[0] = _buildPage(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user =
          TabangRepository.instance.userById(widget.user.id) ?? widget.user;
      if (!user.onboardingCompleted) showWelcomeGuide(context, user);
    });
  }

  @override
  void didUpdateWidget(AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (shellUserChanged(oldWidget.user, widget.user)) {
      _pages
        ..clear()
        ..[_index] = _buildPage(_index);
    } else if (oldWidget.themeMode != widget.themeMode &&
        _pages.containsKey(5)) {
      _pages[5] = _buildPage(5);
    }
  }

  void _select(int index) {
    setState(() {
      _index = index;
      _pages.putIfAbsent(index, () => _buildPage(index));
    });
  }

  static const _destinations = <_Destination>[
    _Destination('Overview', Icons.dashboard_outlined, Icons.dashboard),
    _Destination('Inventory', Icons.inventory_2_outlined, Icons.inventory_2),
    _Destination('Users', Icons.people_outline, Icons.people),
    _Destination('Moderation', Icons.gavel_outlined, Icons.gavel),
    _Destination('Profile', Icons.person_outline, Icons.person),
    _Destination('Settings', Icons.settings_outlined, Icons.settings),
    _Destination('About & Help', Icons.help_outline, Icons.help),
  ];

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 1000;
    final expanded = wide && (_pinned || _hovering);

    return Scaffold(
      body: Row(
        children: [
          MouseRegion(
            onEnter: (_) => setState(() => _hovering = true),
            onExit: (_) => setState(() => _hovering = false),
            child: _AdminSidebar(
              user: widget.user,
              destinations: _destinations,
              selectedIndex: _index,
              expanded: expanded,
              pinned: _pinned,
              onSelect: _select,
              onTogglePin: () => setState(() => _pinned = !_pinned),
            ),
          ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: List<Widget>.generate(
                _destinations.length,
                (i) => _pages[i] ?? const SizedBox.shrink(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return const AdminOverviewPage();
      case 1:
        return InventoryManagementPage(currentUser: widget.user);
      case 2:
        return UserManagementPage(currentUser: widget.user);
      case 3:
        return const ChatModerationPage();
      case 4:
        return ProfilePage(user: widget.user);
      case 5:
        return SettingsPage(
          user: widget.user,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        );
      case 6:
        return const AboutHelpPage();
      default:
        return const AdminOverviewPage();
    }
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.user,
    required this.destinations,
    required this.selectedIndex,
    required this.expanded,
    required this.pinned,
    required this.onSelect,
    required this.onTogglePin,
  });

  final AppUser user;
  final List<_Destination> destinations;
  final int selectedIndex;
  final bool expanded;
  final bool pinned;
  final ValueChanged<int> onSelect;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: expanded ? 232 : 68,
      decoration: BoxDecoration(
        color: context.isDark
            ? TabangColors.darkSurface
            : TabangColors.crimsonDark,
        border: Border(right: BorderSide(color: context.border)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TabangSpace.lg,
              TabangSpace.lg,
              TabangSpace.sm,
              TabangSpace.sm,
            ),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(TabangRadius.xs),
                  ),
                  child: const Icon(Icons.health_and_safety,
                      color: Colors.white, size: 18),
                ),
                if (expanded) ...[
                  const SizedBox(width: TabangSpace.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TABANG',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Chapter console',
                          style: TextStyle(
                            fontSize: 9.5,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: pinned ? 'Unpin sidebar' : 'Pin sidebar',
                    icon: Icon(
                      pinned ? Icons.push_pin : Icons.push_pin_outlined,
                      size: 15,
                      color: Colors.white70,
                    ),
                    onPressed: onTogglePin,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: TabangSpace.sm),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: TabangSpace.sm,
                vertical: TabangSpace.xs,
              ),
              itemCount: destinations.length,
              itemBuilder: (context, i) {
                final destination = destinations[i];
                final selected = i == selectedIndex;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Material(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.16)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(TabangRadius.sm),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(TabangRadius.sm),
                      onTap: () => onSelect(i),
                      child: Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: expanded ? TabangSpace.md : 0,
                          vertical: 10,
                        ),
                        child: Row(
                          mainAxisAlignment: expanded
                              ? MainAxisAlignment.start
                              : MainAxisAlignment.center,
                          children: [
                            Icon(
                              selected
                                  ? destination.activeIcon
                                  : destination.icon,
                              size: 19,
                              color: selected ? Colors.white : Colors.white70,
                            ),
                            if (expanded) ...[
                              const SizedBox(width: TabangSpace.md),
                              Expanded(
                                child: Text(
                                  destination.label,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                    color: selected
                                        ? Colors.white
                                        : Colors.white70,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TabangSpace.sm),
            child: Material(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(TabangRadius.sm),
              child: InkWell(
                borderRadius: BorderRadius.circular(TabangRadius.sm),
                onTap: () => _showAdminMenu(context),
                child: Padding(
                  padding: const EdgeInsets.all(TabangSpace.sm),
                  child: Row(
                    mainAxisAlignment: expanded
                        ? MainAxisAlignment.start
                        : MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 15,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          user.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (expanded) ...[
                        const SizedBox(width: TabangSpace.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user.alias,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              Text(
                                user.role.label,
                                style: const TextStyle(
                                  fontSize: 9,
                                  color: Colors.white70,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showAdminMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.surface,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(TabangRadius.lg)),
      ),
      builder: (context) => Padding(
        padding: context.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              user.fullName,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: context.textColor,
              ),
            ),
            Text(
              '${user.role.label} · ${user.email}',
              style: TextStyle(fontSize: 11.5, color: context.textMuted),
            ),
            const SizedBox(height: TabangSpace.lg),
            const Divider(),
            const SizedBox(height: TabangSpace.md),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  TabangRepository.instance.signOut();
                },
                icon: const Icon(Icons.logout, size: 16),
                label: const Text('Sign out'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
