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
import 'donor_hub_page.dart';
import 'find_donor_page.dart';
import 'requests_page.dart';

/// Navigation shell for community users, donors and recipients.
///
/// Layout rules:
///  * phones and small tablets get a Material 3 bottom navigation bar plus a
///    compact identity header;
///  * wider windows get a rail that opens on hover and can be pinned;
///  * mid-size windows can expand the rail with an explicit control, so the
///    navigation never depends on a mouse hovering.
///
/// The previous build used a hover-only sidebar that collapsed to 72 px. That
/// was invisible on touch and awkward on a trackpad. Every destination remains
/// reachable by tap.
class DonorShell extends StatefulWidget {
  const DonorShell({
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

  /// Slim rails: labels hidden on the phone bottom bar, and the side rail
  /// stays at icon width instead of expanding on hover or pin.
  final bool compactNav;
  final ValueChanged<bool>? onCompactNavChanged;

  /// Whether the desktop rail stays pinned open. Owned by the root app so the
  /// preference is shared with Settings and survives role changes.
  final bool railPinned;
  final ValueChanged<bool>? onRailPinnedChanged;

  @override
  State<DonorShell> createState() => _DonorShellState();
}

class _DonorShellState extends State<DonorShell> {
  final TabangRepository _repo = TabangRepository.instance;

  int _index = 0;
  bool _hovering = false;

  /// Mirrors [DonorShell.railPinned] so the control still works when the shell
  /// is embedded without a preference owner (widget tests, previews).
  late bool _pinned = widget.railPinned;

  /// The bottom bar slides away while the page scrolls toward its end and
  /// comes back on the first scroll up or tab change.
  bool _navHidden = false;

  /// True once the rail has finished sliding to its target width. Labels are
  /// only laid out then, so the "TABANG" wordmark and nav labels can never be
  /// squeezed into a narrow, wrapping column while the rail animates.
  bool _railSettled = true;

  final Map<int, Widget> _pages = {};

  static const _destinations = <_Destination>[
    _Destination('Home', Icons.home_outlined, Icons.home),
    _Destination('Blood Bank', Icons.inventory_2_outlined, Icons.inventory_2),
    _Destination('Find Donor', Icons.map_outlined, Icons.map),
    _Destination('Requests', Icons.campaign_outlined, Icons.campaign),
    _Destination('Messages', Icons.forum_outlined, Icons.forum),
    _Destination(
      'Donor Hub',
      Icons.volunteer_activism_outlined,
      Icons.volunteer_activism,
    ),
    _Destination('Profile', Icons.person_outline, Icons.person),
    _Destination('Settings', Icons.settings_outlined, Icons.settings),
    _Destination('About & Help', Icons.help_outline, Icons.help),
  ];

  /// Destinations shown in the phone bottom bar. Profile, Settings and About
  /// stay in the identity menu so the bar keeps a manageable five-to-six items.
  static const _phoneIndices = <int>[0, 1, 2, 3, 4, 5];

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
    _pages[0] = _buildPage(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final user = _repo.userById(widget.user.id) ?? widget.user;
      if (!user.onboardingCompleted) showWelcomeGuide(context, user);
    });
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    super.dispose();
  }

  /// Keeps the unread badges current while the user stays on another page.
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(DonorShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (shellUserChanged(oldWidget.user, widget.user)) {
      _pages
        ..clear()
        ..[_index] = _buildPage(_index);
    } else if (oldWidget.themeMode != widget.themeMode ||
        oldWidget.compactNav != widget.compactNav ||
        oldWidget.railPinned != widget.railPinned) {
      if (oldWidget.railPinned != widget.railPinned) {
        _pinned = widget.railPinned;
      }
      if (_pages.containsKey(7)) _pages[7] = _buildPage(7);
    }
  }

  void _select(int index) {
    if (index < 0 || index >= _destinations.length) return;
    final compact =
        MediaQuery.sizeOf(context).width < TabangBreakpoints.navigationRail;
    if (compact && !_phoneIndices.contains(index)) {
      _pushStandalone(index);
      return;
    }
    setState(() {
      _index = index;
      _navHidden = false;
      _pages.putIfAbsent(index, () => _buildPage(index));
    });
  }

  /// Slides the phone bottom bar away when the page scrolls toward its end
  /// and brings it back when the user scrolls up (or hits the top). Only the
  /// vertical page scroll counts: the horizontal Home rails must not hide it.
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      if (delta > 2 && !_navHidden) {
        setState(() => _navHidden = true);
      } else if (delta < -2 && _navHidden) {
        setState(() => _navHidden = false);
      }
    } else if (notification is ScrollEndNotification) {
      final metrics = notification.metrics;
      if (_navHidden && metrics.pixels <= metrics.minScrollExtent + 4) {
        setState(() => _navHidden = false);
      }
    }
    return false;
  }

  void _pushStandalone(int index) {
    final page = _buildPage(index);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(_destinations[index].label),
            leading: const BackButton(),
          ),
          body: DecoratedBox(
            decoration: BoxDecoration(gradient: TabangGradients.page(context)),
            child: page,
          ),
        ),
      ),
    );
  }

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return DiscoverPage(user: widget.user, onNavigate: _select);
      case 1:
        return BloodBankPage(
          user: widget.user,
          onOpenMap: () => _select(2),
          onOpenRequests: () => _select(3),
        );
      case 2:
        return FindDonorPage(
          user: widget.user,
          onOpenRequests: () => _select(3),
          onOpenChat: () => _select(4),
          onOpenDiscover: () => _select(0),
          onOpenBloodBank: () => _select(1),
        );
      case 3:
        return RequestsPage(
          user: widget.user,
          onOpenDonorHub: () => _select(5),
        );
      case 4:
        return ChatPage(user: widget.user);
      case 5:
        return DonorHubPage(
          user: widget.user,
          onOpenRequests: () => _select(3),
          onOpenMessages: () => _select(4),
        );
      case 6:
        return ProfilePage(user: widget.user);
      case 7:
        return SettingsPage(
          user: widget.user,
          themeMode: widget.themeMode,
          onThemeModeChanged: widget.onThemeModeChanged,
          compactNav: widget.compactNav,
          onCompactNavChanged: widget.onCompactNavChanged,
          railPinned: _pinned,
          onRailPinnedChanged: (value) {
            setState(() {
              _pinned = value;
              if (_pages.containsKey(7)) _pages[7] = _buildPage(7);
            });
            widget.onRailPinnedChanged?.call(value);
          },
        );
      case 8:
        return AboutHelpPage(onOpenMessages: () => _select(4));
      default:
        return DiscoverPage(user: widget.user, onNavigate: _select);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    // Phones, portrait tablets and small laptops get the bottom bar. The rail
    // only appears when there is room for its labels plus a usable content
    // column; hover-open and pinning remain for desktop.
    final compact = width < TabangBreakpoints.navigationRail;
    final wide = !compact;
    // `railExpanded` is the width target; `showLabels` waits for the slide to
    // finish before labels are built. Slim rails keep the rail collapsed and
    // ignore hover and pin.
    final slim = widget.compactNav;
    final railExpanded = wide && !slim && (_pinned || _hovering);
    final showLabels = railExpanded && _railSettled;
    final unreadMessages = _repoUnreadCount;

    final content = IndexedStack(
      index: _index,
      children: List<Widget>.generate(
        _destinations.length,
        (i) => _pages[i] ?? const SizedBox.shrink(),
      ),
    );

    if (compact) {
      return Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: TabangGradients.page(context)),
          child: SafeArea(
            child: Column(
              children: [
                _PhoneHeader(
                  user: widget.user,
                  unreadMessages: unreadMessages,
                  onOpenProfile: () => _pushStandalone(6),
                  onOpenSettings: () => _pushStandalone(7),
                  onOpenHelp: () => _pushStandalone(8),
                  onOpenChat: () => _select(4),
                ),
                Expanded(
                  child: NotificationListener<ScrollNotification>(
                    onNotification: _handleScrollNotification,
                    child: content,
                  ),
                ),
                // The bar slides down while the page scrolls toward its end
                // and returns on scroll up. It scrolls horizontally when the
                // labels need more room than the phone has.
                ClipRect(
                  child: AnimatedContainer(
                    key: const ValueKey('phoneNavigationBar'),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    height: _navHidden ? 0 : 80,
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: 80,
                      maxHeight: 80,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // 84 px keeps a full label readable; a narrow phone
                          // scrolls the bar instead of squeezing every name.
                          final minBarWidth = _phoneIndices.length * 84.0;
                          final barWidth = constraints.maxWidth < minBarWidth
                              ? minBarWidth
                              : constraints.maxWidth;
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: SizedBox(
                              width: barWidth,
                              height: 80,
                              child: NavigationBar(
                                height: 80,
                                labelBehavior: widget.compactNav
                                    ? NavigationDestinationLabelBehavior
                                          .alwaysHide
                                    : NavigationDestinationLabelBehavior
                                          .alwaysShow,
                                selectedIndex: _phoneIndices.contains(_index)
                                    ? _phoneIndices.indexOf(_index)
                                    : 0,
                                onDestinationSelected: (slot) =>
                                    _select(_phoneIndices[slot]),
                                destinations: [
                                  for (final index in _phoneIndices)
                                    NavigationDestination(
                                      icon: index == 4
                                          ? _UnreadBadge(
                                              count: unreadMessages,
                                              child: Icon(
                                                _destinations[index].icon,
                                              ),
                                            )
                                          : Icon(_destinations[index].icon),
                                      selectedIcon: index == 4
                                          ? _UnreadBadge(
                                              count: unreadMessages,
                                              child: Icon(
                                                _destinations[index].activeIcon,
                                              ),
                                            )
                                          : Icon(
                                              _destinations[index].activeIcon,
                                            ),
                                      label: _destinations[index].label,
                                      tooltip: _destinations[index].label,
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: TabangGradients.page(context)),
        child: SafeArea(
          child: Row(
            children: [
              MouseRegion(
                onEnter: wide && !slim
                    ? (_) => setState(() => _hovering = true)
                    : null,
                onExit: wide && !slim
                    ? (_) => setState(() {
                        _hovering = false;
                        // Collapse: drop the labels first, then slide in.
                        if (!_pinned) _railSettled = false;
                      })
                    : null,
                child: _Sidebar(
                  user: widget.user,
                  unreadMessages: unreadMessages,
                  destinations: _destinations,
                  selectedIndex: _index,
                  railExpanded: railExpanded,
                  expanded: showLabels,
                  wide: wide,
                  showPinControl: !slim,
                  pinned: _pinned,
                  onSlideEnd: () {
                    if (!mounted) return;
                    if (_railSettled != railExpanded) {
                      setState(() => _railSettled = railExpanded);
                    }
                  },
                  onSelect: _select,
                  onTogglePin: () {
                    setState(() {
                      // If pinning does not change the rail's width (for
                      // example while it is already open because of hover),
                      // no slide animation runs and onSlideEnd never fires —
                      // so the labels must not be hidden in that case.
                      final wasExpanded = wide && (_pinned || _hovering);
                      _pinned = !_pinned;
                      final willExpand = wide && (_pinned || _hovering);
                      _railSettled = willExpand == wasExpanded;
                    });
                    widget.onRailPinnedChanged?.call(_pinned);
                  },
                  onToggleExpand: null,
                ),
              ),
              Expanded(child: content),
            ],
          ),
        ),
      ),
    );
  }

  int get _repoUnreadCount =>
      TabangRepository.instance.unreadMessageCountFor(widget.user.id);
}

class _Destination {
  const _Destination(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Small unread counter used by the rail, phone header and bottom bar.
class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      isLabelVisible: count > 0,
      backgroundColor: TabangColors.crimson,
      label: Text(
        count > 99 ? '99+' : '$count',
        style: const TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
      child: child,
    );
  }
}

/// Compact identity bar shown above the phone layout. It is deliberately not a
/// second page header: pages already own their titles, so this only carries
/// brand, help and account actions.
class _PhoneHeader extends StatelessWidget {
  const _PhoneHeader({
    required this.user,
    required this.unreadMessages,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onOpenHelp,
    required this.onOpenChat,
  });

  final AppUser user;
  final int unreadMessages;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;
  final VoidCallback onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: TabangSpace.md),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(bottom: BorderSide(color: context.border)),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(TabangRadius.xs),
            child: const SizedBox(
              width: 30,
              height: 30,
              child: TabangPhoto(
                'assets/branding/app_icon.png',
                semanticLabel: 'TABANG',
                creditLabel: 'TABANG launcher icon',
                fallbackIcon: Icons.water_drop,
                fallbackIconSize: 16,
              ),
            ),
          ),
          const SizedBox(width: TabangSpace.sm),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'TABANG',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                  color: context.textColor,
                ),
              ),
              Text(
                user.alias,
                style: TextStyle(fontSize: 12, color: context.textMuted),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            tooltip: 'Messages',
            onPressed: onOpenChat,
            icon: _UnreadBadge(
              count: unreadMessages,
              child: const Icon(Icons.forum_outlined, size: 20),
            ),
          ),
          IconButton(
            tooltip: 'Guides & help',
            onPressed: onOpenHelp,
            icon: const Icon(Icons.help_outline, size: 20),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            position: PopupMenuPosition.under,
            onSelected: (value) {
              switch (value) {
                case 'profile':
                  onOpenProfile();
                case 'settings':
                  onOpenSettings();
                case 'help':
                  onOpenHelp();
                case 'signout':
                  TabangRepository.instance.signOut();
              }
            },
            itemBuilder: (context) => accountMenuItems(context, user),
            child: Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ClipOval(
                child: SizedBox(
                  width: 32,
                  height: 32,
                  child: TabangPhoto(
                    user.photoAsset,
                    semanticLabel: '${user.alias} profile illustration',
                    creditLabel: user.alias,
                    fallbackIcon: Icons.person_outline,
                    fallbackIconSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.user,
    required this.unreadMessages,
    required this.destinations,
    required this.selectedIndex,
    required this.railExpanded,
    required this.expanded,
    required this.wide,
    required this.showPinControl,
    required this.pinned,
    required this.onSlideEnd,
    required this.onSelect,
    required this.onTogglePin,
    required this.onToggleExpand,
  });

  final AppUser user;
  final int unreadMessages;
  final List<_Destination> destinations;
  final int selectedIndex;

  /// Width target of the slide animation.
  final bool railExpanded;

  /// Whether the wide labels should be laid out — true only after the slide
  /// finishes, which is what keeps text out of the squeezed mid-animation
  /// state.
  final bool expanded;
  final bool wide;

  /// Slim rails hide the pin: the setting, not hover, controls the width.
  final bool showPinControl;
  final bool pinned;
  final VoidCallback onSlideEnd;
  final ValueChanged<int> onSelect;
  final VoidCallback onTogglePin;
  final VoidCallback? onToggleExpand;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 190),
      curve: Curves.easeOutCubic,
      width: railExpanded ? 236 : 74,
      onEnd: onSlideEnd,
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(right: BorderSide(color: context.border)),
      ),
      child: Column(
        children: [
          _buildBrand(context),
          // The pin is the only way back from an unpinned, collapsed rail.
          // It used to live inside the expanded brand row, so collapsing the
          // rail removed the control that could pin it open again. Keep a
          // compact copy under the logo whenever the labels are hidden.
          if (!expanded && wide && showPinControl)
            IconButton(
              tooltip: pinned ? 'Unpin sidebar' : 'Pin sidebar',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                pinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 16,
                color: pinned ? TabangColors.crimson : context.textMuted,
              ),
              onPressed: onTogglePin,
            ),
          const SizedBox(height: TabangSpace.xs),
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
          _buildQuickLinks(context),
          _buildProfile(context),
        ],
      ),
    );
  }

  Widget _buildBrand(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        expanded ? TabangSpace.md : 0,
        TabangSpace.md,
        expanded ? TabangSpace.xs : 0,
        TabangSpace.sm,
      ),
      child: Row(
        // The logo centres in the collapsed rail instead of hugging the left
        // edge, matching the centred icons below it.
        mainAxisAlignment: expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Container(
            decoration: BoxDecoration(
              gradient: TabangGradients.brand,
              borderRadius: BorderRadius.circular(TabangRadius.xs),
            ),
            padding: const EdgeInsets.all(2),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: const SizedBox(
                width: 30,
                height: 30,
                child: TabangPhoto(
                  'assets/branding/app_icon.png',
                  semanticLabel: 'TABANG',
                  creditLabel: 'TABANG launcher icon',
                  fallbackIcon: Icons.water_drop,
                  fallbackIconSize: 16,
                ),
              ),
            ),
          ),
          if (expanded) ...[
            const SizedBox(width: TabangSpace.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TABANG',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.2,
                      color: context.textColor,
                    ),
                  ),
                  Text(
                    'Digos City',
                    maxLines: 1,
                    softWrap: false,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11.5, color: context.textMuted),
                  ),
                ],
              ),
            ),
            if (wide && showPinControl)
              IconButton(
                tooltip: pinned ? 'Unpin sidebar' : 'Pin sidebar',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  pinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 16,
                  color: pinned ? TabangColors.crimson : context.textMuted,
                ),
                onPressed: onTogglePin,
              )
            else if (onToggleExpand != null)
              IconButton(
                tooltip: 'Collapse navigation',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  Icons.chevron_left,
                  size: 18,
                  color: context.textMuted,
                ),
                onPressed: onToggleExpand,
              ),
          ] else if (!wide && onToggleExpand != null)
            IconButton(
              tooltip: 'Expand navigation',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                Icons.chevron_right,
                size: 18,
                color: context.textMuted,
              ),
              onPressed: onToggleExpand,
            ),
        ],
      ),
    );
  }

  Widget _buildItem(BuildContext context, int index) {
    final destination = destinations[index];
    final selected = index == selectedIndex;
    final primary = Theme.of(context).colorScheme.primary;
    final foreground = selected ? primary : context.textMuted;

    final item = Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Material(
        color: selected
            ? (context.isDark
                  ? const Color(0xFF4A1C18)
                  : TabangColors.crimsonSoft)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          onTap: () => onSelect(index),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: expanded ? TabangSpace.md : 0,
              vertical: expanded ? 10 : 11,
            ),
            // Collapsed rail: just the icon, dead-centre in its pill. The
            // accent bar belongs to the labelled layout — leaving it in at
            // 74 px pushed the icon off-centre and drew a stray red sliver.
            child: expanded
                ? Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        width: 3,
                        height: 20,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: selected ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      index == 4
                          ? _UnreadBadge(
                              count: unreadMessages,
                              child: Icon(
                                selected
                                    ? destination.activeIcon
                                    : destination.icon,
                                size: 19,
                                color: foreground,
                              ),
                            )
                          : Icon(
                              selected
                                  ? destination.activeIcon
                                  : destination.icon,
                              size: 19,
                              color: foreground,
                            ),
                      const SizedBox(width: TabangSpace.sm),
                      Expanded(
                        child: Text(
                          destination.label,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: selected ? primary : context.textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: index == 4
                        ? _UnreadBadge(
                            count: unreadMessages,
                            child: Icon(
                              selected
                                  ? destination.activeIcon
                                  : destination.icon,
                              size: 21,
                              color: foreground,
                            ),
                          )
                        : Icon(
                            selected
                                ? destination.activeIcon
                                : destination.icon,
                            size: 21,
                            color: foreground,
                          ),
                  ),
          ),
        ),
      ),
    );
    return expanded ? item : Tooltip(message: destination.label, child: item);
  }

  Widget _buildQuickLinks(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: TabangSpace.sm),
      child: Column(
        children: [
          if (expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(TabangSpace.sm),
              decoration: BoxDecoration(
                gradient: TabangGradients.forContext(context),
                borderRadius: BorderRadius.circular(TabangRadius.sm),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.tips_and_updates_outlined,
                    size: 16,
                    color: TabangColors.crimson,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Need a guide? Open About & Help.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: TabangSpace.sm),
        ],
      ),
    );
  }

  Widget _buildProfile(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(TabangSpace.sm),
      child: PopupMenuButton<String>(
        tooltip: 'Account',
        position: PopupMenuPosition.under,
        onSelected: (value) {
          switch (value) {
            case 'profile':
              onSelect(6);
            case 'settings':
              onSelect(7);
            case 'help':
              onSelect(8);
            case 'signout':
              TabangRepository.instance.signOut();
          }
        },
        itemBuilder: (context) => accountMenuItems(context, user),
        child: Material(
          color: context.surfaceAlt,
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          child: Padding(
            padding: const EdgeInsets.all(TabangSpace.sm),
            child: Row(
              mainAxisAlignment: expanded
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                ClipOval(
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: TabangPhoto(
                      user.photoAsset,
                      semanticLabel: '${user.alias} profile illustration',
                      creditLabel: user.alias,
                      fallbackIcon: Icons.person_outline,
                      fallbackIconSize: 16,
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
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: context.textColor,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          user.role.label,
                          style: TextStyle(
                            fontSize: 11.5,
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

/// Account menu shared by the phone header and the sidebar profile card.
///
/// The old popup was four bare text rows, so it never showed *who* was signed
/// in. This opens with the identity, then keeps one icon + label per action and
/// ends with a destructive sign-out separated by a divider.
List<PopupMenuEntry<String>> accountMenuItems(
  BuildContext context,
  AppUser user,
) {
  return [
    PopupMenuItem<String>(
      enabled: false,
      height: 72,
      child: Row(
        children: [
          ClipOval(
            child: SizedBox(
              width: 42,
              height: 42,
              child: TabangPhoto(
                user.photoAsset,
                semanticLabel: '${user.alias} profile illustration',
                creditLabel: user.alias,
                fallbackIcon: Icons.person_outline,
                fallbackIconSize: 20,
              ),
            ),
          ),
          const SizedBox(width: TabangSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                ),
                Text(
                  '${user.email} · ${user.role.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: context.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
    const PopupMenuDivider(),
    _accountItem(
      context,
      value: 'profile',
      icon: Icons.person_outline,
      label: 'Profile',
    ),
    _accountItem(
      context,
      value: 'settings',
      icon: Icons.settings_outlined,
      label: 'Settings',
    ),
    _accountItem(
      context,
      value: 'help',
      icon: Icons.help_outline,
      label: 'Guides & help',
    ),
    const PopupMenuDivider(),
    _accountItem(
      context,
      value: 'signout',
      icon: Icons.logout,
      label: 'Sign out',
      danger: true,
    ),
  ];
}

PopupMenuItem<String> _accountItem(
  BuildContext context, {
  required String value,
  required IconData icon,
  required String label,
  bool danger = false,
}) {
  final color = danger ? TabangColors.danger : context.textColor;
  return PopupMenuItem<String>(
    value: value,
    height: 44,
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    ),
  );
}
