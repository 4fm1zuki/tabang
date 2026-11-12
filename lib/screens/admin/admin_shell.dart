import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/layout.dart';
import '../../widgets/onboarding.dart';
import '../../widgets/photo.dart';
import '../donor/donor_shell.dart' show accountMenuItems;
import '../shared/about_help_page.dart';
import '../shared/profile_page.dart';
import '../shared/settings_page.dart';
import '../donor/chat_page.dart';
import 'admin_overview.dart';
import 'operations_workspace_page.dart';
import 'user_management_page.dart';

/// Navigation shell for clinical staff and administrators.
class AdminShell extends StatefulWidget {
  const AdminShell({
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
  /// stays at icon width. The sidebar pin exits slim rails and reopens the
  /// full labelled rail, so the pin always works.
  final bool compactNav;
  final ValueChanged<bool>? onCompactNavChanged;

  /// Whether the desktop rail stays pinned open. Owned by the root app.
  final bool railPinned;
  final ValueChanged<bool>? onRailPinnedChanged;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  final TabangRepository _repo = TabangRepository.instance;

  int _index = 0;
  bool _hovering = false;

  /// Mirrors [AdminShell.railPinned] when the shell is embedded without a
  /// preference owner.
  late bool _pinned = widget.railPinned;

  /// Which inner Operations section the next visit should show. Reset when the
  /// user picks Operations directly; set to 1 for the Overview drill-through.
  int _operationsSection = 0;

  /// The bottom bar slides away while the page scrolls toward its end and
  /// comes back on the first scroll up or tab change.
  bool _navHidden = false;

  /// Staff can pin the phone bar open when they swipe through long lists.
  bool _navPinned = false;

  /// Horizontal scroll for the phone bar. Material only auto-adds scrollbars
  /// to vertical lists, so the bar owns a visible one.
  final ScrollController _navScroll = ScrollController();

  /// Downward travel accumulates before the bar hides, so tiny settling
  /// deltas cannot toggle it.
  double _navDownTravel = 0;

  void _toggleNavPin() {
    setState(() {
      _navPinned = !_navPinned;
      if (_navPinned) {
        _navHidden = false;
        _navDownTravel = 0;
      }
    });
  }

  /// Opens an account-menu page that is deliberately not a rail destination.
  void _pushPage(String title, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (context) => Scaffold(
          appBar: AppBar(title: Text(title), leading: const BackButton()),
          body: DecoratedBox(
            decoration: BoxDecoration(gradient: TabangGradients.page(context)),
            child: page,
          ),
        ),
      ),
    );
  }

  void _openProfile() => _pushPage('Profile', ProfilePage(user: widget.user));

  void _openSettings() {
    _pushPage(
      'Settings',
      SettingsPage(
        user: widget.user,
        themeMode: widget.themeMode,
        onThemeModeChanged: widget.onThemeModeChanged,
        compactNav: widget.compactNav,
        onCompactNavChanged: widget.onCompactNavChanged,
        railPinned: _pinned,
        onRailPinnedChanged: (value) {
          setState(() => _pinned = value);
          widget.onRailPinnedChanged?.call(value);
        },
      ),
    );
  }

  void _openHelp() {
    _pushPage(
      'About & Help',
      AboutHelpPage(onOpenMessages: _openMessagesFromPushedPage),
    );
  }

  /// About & Help is pushed *above* the shell, so re-selecting a rail entry only
  /// swaps the IndexedStack underneath it and the visible page never changes.
  /// Pop back to the shell first, then select Messages.
  void _openMessagesFromPushedPage() {
    final navigator = Navigator.of(context);
    navigator.popUntil((route) => route.isFirst);
    _openMessages();
  }

  /// Switches to the Messages tab, optionally opening one conversation. The
  /// Users page sends staff here instead of pushing its own chat screen, so the
  /// Messages tab and the User row share a single UI.
  void _openMessages({String? threadId}) {
    _repo.markTabSeen(widget.user.id, 'messages');
    setState(() {
      _index = 2;
      _navHidden = false;
      // A fresh key forces a new ChatPage state, so the deep link reliably
      // selects the thread even if the tab was already open.
      _chatKey = UniqueKey();
      _pages[2] = ChatPage(
        key: _chatKey,
        user: widget.user,
        allowNewConversation: true,
        initialThreadId: threadId,
      );
    });
  }

  /// Opens Messages on the conversation with [otherUserId], starting one if
  /// there is none yet. Used by the staff donor list and the Users page.
  void _openMessagesWith(String otherUserId) {
    final thread = _repo.startConversation(
      initiatorId: widget.user.id,
      otherId: otherUserId,
    );
    if (thread == null) return;
    _openMessages(threadId: thread.id);
  }

  /// Key of the live Messages page; replaced on every deep link.
  Key _chatKey = UniqueKey();

  /// Labels are only built after the rail finishes sliding, so the wordmark
  /// and nav labels never wrap inside a narrow, mid-animation rail.
  bool _railSettled = true;

  /// Pages created so far, kept alive across tab switches so filters, scroll
  /// positions and form state survive navigation.
  final Map<int, Widget> _pages = {};

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
    _pages[0] = _buildPage(0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Overview is already on screen at startup, so its dot would never
      // clear otherwise.
      _repo.markTabSeen(widget.user.id, 'overview');
      final user = _repo.userById(widget.user.id) ?? widget.user;
      if (!user.onboardingCompleted) showWelcomeGuide(context, user);
    });
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    _navScroll.dispose();
    super.dispose();
  }

  /// Keeps the unread badges current while the user stays on another page.
  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(AdminShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (shellUserChanged(oldWidget.user, widget.user)) {
      _pages
        ..clear()
        ..[_index] = _buildPage(_index);
    } else {
      if (oldWidget.railPinned != widget.railPinned) {
        _pinned = widget.railPinned;
      }
      // Slim rails force the icon-only rail, so an unpinned state is the only
      // one that can be true while they are on.
      if (oldWidget.compactNav != widget.compactNav && widget.compactNav) {
        _pinned = false;
      }
    }
  }

  void _select(int index) {
    final tabKey = _tabKeys[index];
    if (tabKey != null) _repo.markTabSeen(widget.user.id, tabKey);
    setState(() {
      _index = index;
      _navHidden = false;
      if (index == 1 && _operationsSection != 0) {
        _operationsSection = 0;
        _pages.remove(1);
      }
      _pages.putIfAbsent(index, () => _buildPage(index));
    });
  }

  /// Opens Operations directly on the inventory section, without adding a
  /// second top-level Inventory destination to the staff sidebar.
  void _openOperationsInventory() {
    _repo.markTabSeen(widget.user.id, 'operations');
    setState(() {
      _operationsSection = 1;
      _pages.remove(1);
      _index = 1;
      _navHidden = false;
      _pages[1] = _buildPage(1);
    });
  }

  /// Slides the phone bottom bar away when the page scrolls toward its end
  /// and brings it back on scroll up. The bar is pinned automatically at the
  /// top or the bottom, and it needs real room left to scroll before it will
  /// hide again, so it never bounces up and down at the end of a list.
  bool _handleScrollNotification(ScrollNotification notification) {
    if (notification.metrics.axis != Axis.vertical) return false;
    if (_navPinned) return false;
    final metrics = notification.metrics;
    final atTop = metrics.pixels <= metrics.minScrollExtent + 4;
    final atBottom = metrics.extentAfter <= 4;
    final atEdge = atTop || atBottom;

    void showBar() {
      _navDownTravel = 0;
      if (_navHidden) setState(() => _navHidden = false);
    }

    if (notification is ScrollUpdateNotification) {
      if (atEdge) {
        showBar();
        return false;
      }
      final delta = notification.scrollDelta ?? 0;
      if (delta > 0) {
        _navDownTravel += delta;
        if (_navDownTravel > 72 && metrics.extentAfter > 140 && !_navHidden) {
          setState(() => _navHidden = true);
          _navDownTravel = 0;
        }
      } else if (delta < -2) {
        showBar();
      }
    } else if (notification is ScrollEndNotification) {
      if (atEdge) showBar();
      _navDownTravel = 0;
    } else if (notification is OverscrollNotification) {
      if (atEdge || notification.overscroll > 0) showBar();
    }
    return false;
  }

  // Profile, Settings and About & Help live in the account menu only; the
  // rail is limited to the five work destinations staff actually switch
  // between.
  static const _destinations = <_Destination>[
    _Destination('Overview', Icons.dashboard_outlined, Icons.dashboard),
    _Destination('Operations', Icons.map_outlined, Icons.map),
    _Destination('Messages', Icons.forum_outlined, Icons.forum),
    // Moderation is a tab inside Users, so staff warn or suspend an account
    // where they see it instead of in a second sidebar destination.
    _Destination('Users', Icons.people_outline, Icons.people),
  ];

  /// Bottom-bar slots on phones and small tablets.
  static const _phoneIndices = <int>[0, 1, 2, 3];

  /// Repository "new activity" surface behind each destination. Messages keep
  /// their own unread counter instead.
  static const Map<int, String> _tabKeys = {
    0: 'overview',
    1: 'operations',
    3: 'users',
  };

  bool _hasNewFor(int index) {
    final key = _tabKeys[index];
    if (key == null) return false;
    return _repo.tabActivityCount(widget.user.id, key) > 0;
  }

  Set<int> get _newIndices => {
    for (final index in _tabKeys.keys)
      if (_hasNewFor(index)) index,
  };

  Widget _destinationIcon(
    int index, {
    required bool active,
    required int unreadMessages,
    required Set<int> newIndices,
  }) {
    final icon = Icon(
      active ? _destinations[index].activeIcon : _destinations[index].icon,
    );
    if (index == 2) {
      return _UnreadBadge(count: unreadMessages, child: icon);
    }
    if (newIndices.contains(index)) return _NewDot(child: icon);
    return icon;
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < TabangBreakpoints.navigationRail;
    final wide = !compact;
    // Slim rails keep the rail collapsed and ignore hover; the rail pin exits
    // slim instead of being hidden.
    final slim = widget.compactNav;
    final railExpanded = wide && !slim && (_pinned || _hovering);
    final showLabels = railExpanded && _railSettled;
    final unreadMessages = _repoUnreadCount;
    final newIndices = _newIndices;

    final content = IndexedStack(
      index: _index,
      children: List<Widget>.generate(
        _destinations.length,
        (i) => _pages[i] ?? const SizedBox.shrink(),
      ),
    );

    // Staff and admins on a phone get the same bottom-bar shell as community
    // users; the 68 px icon rail was unusable on a 390 px screen.
    if (compact) {
      return Scaffold(
        body: DecoratedBox(
          decoration: BoxDecoration(gradient: TabangGradients.page(context)),
          child: SafeArea(
            child: Column(
              children: [
                _AdminPhoneHeader(
                  user: widget.user,
                  navPinned: _navPinned,
                  onToggleNavPin: _toggleNavPin,
                  onOpenProfile: _openProfile,
                  onOpenSettings: _openSettings,
                  onOpenHelp: _openHelp,
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
                    height: _navHidden && !_navPinned ? 0 : 80,
                    child: OverflowBox(
                      alignment: Alignment.topCenter,
                      minHeight: 80,
                      maxHeight: 80,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final minBarWidth = _phoneIndices.length * 84.0;
                          final barWidth = constraints.maxWidth < minBarWidth
                              ? minBarWidth
                              : constraints.maxWidth;
                          final bar = SingleChildScrollView(
                            controller: _navScroll,
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
                                      icon: _destinationIcon(
                                        index,
                                        active: false,
                                        unreadMessages: unreadMessages,
                                        newIndices: newIndices,
                                      ),
                                      selectedIcon: _destinationIcon(
                                        index,
                                        active: true,
                                        unreadMessages: unreadMessages,
                                        newIndices: newIndices,
                                      ),
                                      label: _destinations[index].label,
                                      tooltip: _destinations[index].label,
                                    ),
                                ],
                              ),
                            ),
                          );
                          if (barWidth <= constraints.maxWidth) return bar;
                          return Scrollbar(
                            key: const ValueKey('adminPhoneNavScrollbar'),
                            controller: _navScroll,
                            thumbVisibility: true,
                            scrollbarOrientation: ScrollbarOrientation.top,
                            thickness: 3,
                            radius: const Radius.circular(3),
                            child: bar,
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
        child: Row(
          children: [
            MouseRegion(
              onEnter: wide && !slim
                  ? (_) => setState(() => _hovering = true)
                  : null,
              onExit: wide && !slim
                  ? (_) => setState(() {
                      _hovering = false;
                      if (!_pinned) _railSettled = false;
                    })
                  : null,
              child: _AdminSidebar(
                user: widget.user,
                unreadMessages: unreadMessages,
                newIndices: newIndices,
                destinations: _destinations,
                selectedIndex: _index,
                railExpanded: railExpanded,
                expanded: showLabels,
                showPinControl: wide,
                pinned: _pinned,
                onSlideEnd: () {
                  if (!mounted) return;
                  if (_railSettled != railExpanded) {
                    setState(() => _railSettled = railExpanded);
                  }
                },
                onSelect: _select,
                onOpenProfile: _openProfile,
                onOpenSettings: _openSettings,
                onOpenHelp: _openHelp,
                onTogglePin: () {
                  final wasSlim = widget.compactNav;
                  setState(() {
                    // Only drop the labels when the width actually animates;
                    // otherwise onSlideEnd never fires and they stay hidden.
                    final wasExpanded =
                        wide && !wasSlim && (_pinned || _hovering);
                    _pinned = !_pinned;
                    final willExpand =
                        wide && !wasSlim && (_pinned || _hovering);
                    _railSettled = willExpand == wasExpanded;
                  });
                  widget.onRailPinnedChanged?.call(_pinned);
                  // Pinning while slim rails are on exits slim, which is what
                  // makes the pin visibly reopen the full sidebar.
                  if (_pinned && wasSlim) {
                    widget.onCompactNavChanged?.call(false);
                    setState(() => _railSettled = false);
                  }
                },
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }

  int get _repoUnreadCount =>
      TabangRepository.instance.unreadMessageCountFor(widget.user.id);

  Widget _buildPage(int index) {
    switch (index) {
      case 0:
        return AdminOverviewPage(
          user: widget.user,
          onOpenInventory: _openOperationsInventory,
        );
      case 1:
        return OperationsWorkspacePage(
          user: widget.user,
          initialSection: _operationsSection,
          onOpenUsers: () => _select(3),
          onOpenMessages: _openMessagesWith,
        );
      case 2:
        return ChatPage(
          key: _chatKey,
          user: widget.user,
          allowNewConversation: true,
        );
      case 3:
        return UserManagementPage(
          currentUser: widget.user,
          onOpenMessages: (threadId) => _openMessages(threadId: threadId),
        );
      default:
        return AdminOverviewPage(
          user: widget.user,
          onOpenInventory: _openOperationsInventory,
        );
    }
  }
}

class _Destination {
  const _Destination(this.label, this.icon, this.activeIcon);
  final String label;
  final IconData icon;
  final IconData activeIcon;
}

/// Small unread counter shared by the staff rail and bottom bar.
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

/// A small dot marking a destination with unseen activity.
class _NewDot extends StatelessWidget {
  const _NewDot({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Badge(
      smallSize: 7,
      backgroundColor: TabangColors.crimson,
      child: child,
    );
  }
}

/// Compact identity bar for staff on phones: brand, identity and the account
/// menu, matching the community shell's header.
class _AdminPhoneHeader extends StatelessWidget {
  const _AdminPhoneHeader({
    required this.user,
    required this.navPinned,
    required this.onToggleNavPin,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onOpenHelp,
  });

  final AppUser user;
  final bool navPinned;
  final VoidCallback onToggleNavPin;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;

  @override
  Widget build(BuildContext context) {
    return Container(
      // A 58 px baseline, not a hard height: the identity is one scaled line
      // now, and the 52 px mark plus its dark-mode white plate is 60 px tall,
      // so the bar grows by a couple of pixels instead of clipping the plate.
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: TabangSpace.md),
      decoration: BoxDecoration(
        color: context.surface,
        border: Border(bottom: BorderSide(color: context.border)),
      ),
      child: Row(
        children: [
          // 52 reads properly beside the wordmark; the plate keeps the red and
          // blue artwork legible when the header sits on the dark surface.
          TabangLogo(size: 52, plate: context.isDark),
          const SizedBox(width: TabangSpace.sm),
          // The identity never widens the row: the alias and position share a
          // single scaled line, so the role stays readable in full on a phone.
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TABANG',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: context.textColor,
                  ),
                ),
                // The alias and the position share one line. A scale-down
                // FittedBox shrinks the pair on a 360 px phone instead of
                // ellipsising it or wrapping to a second line, so the full
                // position ("System Administrator") still reads.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${user.alias} · ${user.role.label}',
                    maxLines: 1,
                    softWrap: false,
                    style: TextStyle(fontSize: 11.5, color: context.textMuted),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            key: const ValueKey('phoneNavPinButton'),
            tooltip: navPinned
                ? 'Allow the bottom bar to hide'
                : 'Keep the bottom bar visible',
            visualDensity: VisualDensity.compact,
            onPressed: onToggleNavPin,
            icon: Icon(
              navPinned ? Icons.push_pin : Icons.push_pin_outlined,
              size: 19,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: 'Account',
            position: PopupMenuPosition.under,
            onSelected: (value) async {
              switch (value) {
                case 'profile':
                  onOpenProfile();
                case 'settings':
                  onOpenSettings();
                case 'help':
                  onOpenHelp();
                case 'signout':
                  if (await confirmAction(
                    context,
                    title: 'Sign out?',
                    message:
                        'You will need to sign in again to continue.',
                    confirmLabel: 'Sign out',
                    destructive: true,
                  )) {
                    TabangRepository.instance.signOut();
                  }
              }
            },
            itemBuilder: (context) => accountMenuItems(context, user),
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
        ],
      ),
    );
  }
}

class _AdminSidebar extends StatelessWidget {
  const _AdminSidebar({
    required this.user,
    required this.unreadMessages,
    required this.newIndices,
    required this.destinations,
    required this.selectedIndex,
    required this.railExpanded,
    required this.expanded,
    required this.showPinControl,
    required this.pinned,
    required this.onSlideEnd,
    required this.onSelect,
    required this.onOpenProfile,
    required this.onOpenSettings,
    required this.onOpenHelp,
    required this.onTogglePin,
  });

  final AppUser user;
  final int unreadMessages;
  final Set<int> newIndices;
  final List<_Destination> destinations;
  final int selectedIndex;
  final VoidCallback onOpenProfile;
  final VoidCallback onOpenSettings;
  final VoidCallback onOpenHelp;

  /// Width target of the slide animation.
  final bool railExpanded;

  /// Labels are laid out only once the slide has finished.
  final bool expanded;

  /// Pin control for the wide rail. Pressing it exits slim rails, so the
  /// full labelled rail can always be reopened from the collapsed state.
  final bool showPinControl;
  final bool pinned;
  final VoidCallback onSlideEnd;
  final ValueChanged<int> onSelect;
  final VoidCallback onTogglePin;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOutCubic,
      width: railExpanded ? 232 : 68,
      onEnd: onSlideEnd,
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
                  child: const Icon(
                    Icons.health_and_safety,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                if (expanded) ...[
                  const SizedBox(width: TabangSpace.md),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'TABANG',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Chapter console',
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                  if (showPinControl)
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
          // Keep the pin reachable after the rail collapses. Previously the
          // control only existed in the expanded brand row, so an unpinned
          // rail could not be pinned open again without hovering.
          if (!expanded && showPinControl)
            IconButton(
              tooltip: pinned ? 'Unpin sidebar' : 'Pin sidebar',
              visualDensity: VisualDensity.compact,
              icon: Icon(
                pinned ? Icons.push_pin : Icons.push_pin_outlined,
                size: 16,
                color: Colors.white70,
              ),
              onPressed: onTogglePin,
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
                final icon = Icon(
                  selected ? destination.activeIcon : destination.icon,
                  size: 19,
                  color: selected ? Colors.white : Colors.white70,
                );

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
                            i == 2
                                ? _UnreadBadge(
                                    count: unreadMessages,
                                    child: icon,
                                  )
                                : newIndices.contains(i)
                                ? _NewDot(child: icon)
                                : icon,
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
                      ClipOval(
                        child: SizedBox(
                          width: 30,
                          height: 30,
                          child: TabangPhoto(
                            user.photoAsset,
                            semanticLabel: '${user.alias} profile photo',
                            creditLabel: user.alias,
                            fallbackIcon: Icons.person_outline,
                            fallbackIconSize: 15,
                          ),
                        ),
                      ),
                      if (expanded) ...[
                        const SizedBox(width: TabangSpace.sm),
                        // Alias and position share one scaled line, matching
                        // the phone header. The FittedBox keeps the whole
                        // position readable in the 232 px rail.
                        Expanded(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '${user.alias} · ${user.role.label}',
                              maxLines: 1,
                              softWrap: false,
                              style: const TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
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
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(TabangRadius.lg),
        ),
      ),
      builder: (context) => Padding(
        padding: context.pagePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // The identity row itself opens Profile, replacing the separate
            // Profile entry that used to sit below the divider.
            InkWell(
              borderRadius: BorderRadius.circular(TabangRadius.xs),
              onTap: () {
                Navigator.pop(context);
                onOpenProfile();
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
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
                            user.role.label,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: context.textMuted,
                            ),
                          ),
                          Text(
                            user.email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: context.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: TabangSpace.sm),
            const Divider(),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_outlined, size: 19),
              title: const Text('Settings', style: TextStyle(fontSize: 13.5)),
              onTap: () {
                Navigator.pop(context);
                onOpenSettings();
              },
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.help_outline, size: 19),
              title: const Text(
                'About & Help',
                style: TextStyle(fontSize: 13.5),
              ),
              onTap: () {
                Navigator.pop(context);
                onOpenHelp();
              },
            ),
            const Divider(),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout, size: 19),
              title: const Text('Sign out', style: TextStyle(fontSize: 13.5)),
              onTap: () async {
                Navigator.pop(context);
                if (await confirmAction(
                  context,
                  title: 'Sign out?',
                  message:
                      'You will need to sign in again to continue.',
                  confirmLabel: 'Sign out',
                  destructive: true,
                )) {
                  TabangRepository.instance.signOut();
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
