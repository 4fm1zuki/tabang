import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/onboarding.dart';
import '../../widgets/photo.dart';
import '../shared/about_help_page.dart';
import '../shared/profile_page.dart';
import '../shared/settings_page.dart';
import 'blood_bank_page.dart';
import 'chat_page.dart';
import 'discover_page.dart';
import 'find_donor_page.dart';
import 'requests_page.dart';

/// Navigation shell for donors and recipients.
///
/// The previous build used a hover-only sidebar that collapsed to 72px and
/// expanded on `MouseRegion.onEnter`. That is unusable on a touch device and
/// awkward on a laptop trackpad. This is a persistent rail that expands on
/// hover but also responds to tap, and collapses to icons below 1000px.
class DonorShell extends StatefulWidget {
  const DonorShell({
    super.key,
    required this.user,
    required this.themeMode,
    required this.onThemeModeChanged,
  });

  final AppUser user;
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeModeChanged;

  @override
  State<DonorShell> createState() => _DonorShellState();
}

class _DonorShellState extends State<DonorShell> {
  int _index = 0;
  bool _hovering = false;
  bool _pinned = true;

  /// Pages created so far, kept alive across tab switches.
  ///
  /// Recreating the current page on every switch discarded its state and
  /// remounted Find Donor's Google Map each visit - expensive on web and the
  /// trigger for repeated platform-view teardown. A lazy stack keeps each
  /// visited page, its scroll position, filters and map intact.
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
  void didUpdateWidget(DonorShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Pages read live data from the repository, so they stay current across
    // notifications. Rebuild the cached widgets only when the signed-in record
    // changes in a way their widget configuration captured.
    if (shellUserChanged(oldWidget.user, widget.user)) {
      _pages
        ..clear()
        ..[_index] = _buildPage(_index);
    } else if (oldWidget.themeMode != widget.themeMode &&
        _pages.containsKey(6)) {
      _pages[6] = _buildPage(6);
    }
  }

  void _select(int index) {
    setState(() {
      _index = index;
      _pages.putIfAbsent(index, () => _buildPage(index));
    });
  }

  static const _destinations = <_Destination>[
    _Destination('Discover', Icons.explore_outlined, Icons.explore),
    _Destination('Blood Bank', Icons.inventory_2_outlined, Icons.inventory_2),
    _Destination('Find Donor', Icons.map_outlined, Icons.map),
    _Destination('Requests', Icons.campaign_outlined, Icons.campaign),
    _Destination('Messages', Icons.forum_outlined, Icons.forum),
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
            child: _Sidebar(
              user: widget.user,
              destinations: _destinations,
              selectedIndex: _index,
              expanded: expanded,
              onSelect: _select,
              onTogglePin: () => setState(() => _pinned = !_pinned),
              pinned: _pinned,
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
        return DiscoverPage(user: widget.user, onNavigate: _select);
      case 1:
        return BloodBankPage(user: widget.user);
      case 2:
        return FindDonorPage(user: widget.user);
      case 3:
        return RequestsPage(user: widget.user);
      case 4:
        return ChatPage(user: widget.user);
      case 5:
        return ProfilePage(user: widget.user);
      case 6:
        return SettingsPage(
          user: widget.user,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
        );
      case 7:
        return const AboutHelpPage();
      default:
        return DiscoverPage(user: widget.user);
    }
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.user,
    required this.destinations,
    required this.selectedIndex,
    required this.expanded,
    required this.onSelect,
    required this.onTogglePin,
    required this.pinned,
  });

  final AppUser user;
  final List<_Destination> destinations;
  final int selectedIndex;
  final bool expanded;
  final ValueChanged<int> onSelect;
  final VoidCallback onTogglePin;
  final bool pinned;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: expanded ? 232 : 68,
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(right: BorderSide(color: context.border)),
      ),
      child: Column(
        children: [
          _buildBrand(context),
          const SizedBox(height: TabangSpace.sm),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: TabangSpace.sm,
                vertical: TabangSpace.xs,
              ),
              itemCount: destinations.length,
              itemBuilder: (context, i) => _buildItem(context, i),
            ),
          ),
          _buildProfile(context),
        ],
      ),
    );
  }

  Widget _buildBrand(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        TabangSpace.lg,
        TabangSpace.lg,
        TabangSpace.sm,
        TabangSpace.sm,
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(TabangRadius.xs),
            child: const SizedBox(
              width: 34,
              height: 34,
              child: TabangPhoto(
                'assets/branding/app_icon.png',
                semanticLabel: 'TABANG',
                fallbackIcon: Icons.water_drop,
                fallbackIconSize: 18,
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: TabangSpace.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TABANG',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: context.textColor,
                    ),
                  ),
                  Text(
                    'Digos City',
                    style: TextStyle(
                      fontSize: 9.5,
                      color: context.textMuted,
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
                color: context.textMuted,
              ),
              onPressed: onTogglePin,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final destination = destinations[index];
    final selected = index == selectedIndex;

    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? (context.isDark ? const Color(0xFF3A1917) : TabangColors.crimsonSoft)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          onTap: () => onSelect(index),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? TabangSpace.md : 0,
              vertical: 10,
            ),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Icon(
                  selected ? destination.activeIcon : destination.icon,
                  size: 19,
                  color: selected ? TabangColors.crimson : context.textMuted,
                ),
                if (expanded) ...[
                  const SizedBox(width: TabangSpace.md),
                  Expanded(
                    child: Text(
                      destination.label,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected
                            ? TabangColors.crimson
                            : context.textColor,
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
  }

  Widget _buildProfile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TabangSpace.sm),
      child: Material(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          onTap: () => showProfileSheet(context, user),
          child: Padding(
            padding: const EdgeInsets.all(TabangSpace.sm),
            child: Row(
              mainAxisAlignment:
                  expanded ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: TabangColors.crimson,
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
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: context.textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.role.label,
                          style: TextStyle(
                            fontSize: 9,
                            color: context.textMuted,
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
    );
  }
}

/// Bottom sheet showing the signed-in user's own details.
Future<void> showProfileSheet(BuildContext context, AppUser user) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TabangRadius.lg)),
    ),
    builder: (context) => Padding(
      padding: context.pagePadding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: TabangColors.crimson,
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: TabangSpace.md),
              Expanded(
                child: Column(
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
                      user.email,
                      style: TextStyle(fontSize: 11.5, color: context.textMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),
          const Divider(),
          const SizedBox(height: TabangSpace.md),
          _row(context, 'Alias shown to others', user.alias),
          _row(context, 'Role', user.role.label),
          _row(context, 'Barangay', user.barangay),
          if (user.bloodType != null)
            _row(context, 'Blood type', user.bloodType!.label),
          _row(context, 'Account status', user.status.label),
          const SizedBox(height: TabangSpace.lg),
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

Widget _row(BuildContext context, String label, String value) {
  return Padding(
    padding: const EdgeInsets.only(bottom: TabangSpace.sm),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(fontSize: 12, color: context.textMuted),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: context.textColor,
          ),
        ),
      ],
    ),
  );
}
