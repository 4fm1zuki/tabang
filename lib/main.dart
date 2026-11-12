import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemNavigator;

import 'core/auth.dart';
import 'core/models.dart';
import 'core/repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/donor/donor_shell.dart';
import 'screens/admin/admin_shell.dart';
import 'theme.dart';
import 'widgets/common.dart';
import 'widgets/layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AuthService.instance.bootstrap();
  runApp(const TabangApp());
}

/// Root widget.
///
/// Routing is driven by the repository's session state, not by a dropdown.
/// When [TabangRepository.currentUser] is null the login screen is shown; when
/// it is set, the correct dashboard is chosen from the user's role. Signing out
/// clears the session and the router falls back to login automatically.
class TabangApp extends StatefulWidget {
  const TabangApp({super.key});

  @override
  State<TabangApp> createState() => _TabangAppState();
}

class _TabangAppState extends State<TabangApp> {
  final TabangRepository _repo = TabangRepository.instance;

  /// Light is the default. Dark remains an explicit choice in Settings; the
  /// operating-system theme is deliberately not followed so the community
  /// surfaces keep their warm, high-contrast presentation.
  ThemeMode _themeMode = ThemeMode.light;

  /// Slim rails: hide the bottom-bar labels and keep the side rail at icon
  /// width. Chosen in Settings; off by default so the first run shows the
  /// labelled navigation, and the sidebar pin stays in charge of the rail.
  bool _compactNav = false;

  /// Whether desktop sidebars stay pinned open. Chosen in Settings and shared
  /// by both shells so the preference survives role changes.
  bool _railPinned = true;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_onRepoChanged);
  }

  @override
  void dispose() {
    _repo.removeListener(_onRepoChanged);
    super.dispose();
  }

  void _onRepoChanged() {
    if (mounted) setState(() {});
  }

  void _setThemeMode(ThemeMode mode) {
    setState(() => _themeMode = mode);
  }

  void _setCompactNav(bool value) {
    setState(() => _compactNav = value);
  }

  void _setRailPinned(bool value) {
    setState(() => _railPinned = value);
  }

  @override
  Widget build(BuildContext context) {
    final user = _repo.currentUser;

    return MaterialApp(
      title: 'TABANG',
      debugShowCheckedModeBanner: false,
      theme: TabangTheme.light,
      darkTheme: TabangTheme.dark,
      themeMode: _themeMode,
      // Flutter's default web scroll behaviour only accepts touch drags. That
      // left every horizontal rail impossible to move with a mouse, which is
      // the "can't scroll" failure users hit on desktop.
      scrollBehavior: const TabangScrollBehavior(),
      // Non-edge-to-edge by design: reserve the system status and gesture/nav
      // insets around the whole navigator. Text never sits under the clock,
      // and the bottom bar never collides with gesture navigation.
      builder: (context, child) => DecoratedBox(
        // A barely-there wash keeps large empty pages from reading as flat
        // sheets of grey without competing with cards and the map.
        decoration: BoxDecoration(
          gradient: TabangGradients.page(context),
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: SafeArea(child: child ?? const SizedBox.shrink()),
      ),
      home: _buildHome(user),
    );
  }

  Widget _buildHome(AppUser? user) {
    if (user == null) {
      return LoginScreen(
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      );
    }

    // Staff and admins share the administrative shell; donors and recipients
    // share the community shell. This is the only place role routing happens.
    if (user.role.isAdminSide) {
      return _guardExit(
        AdminShell(
          user: user,
          themeMode: _themeMode,
          onThemeModeChanged: _setThemeMode,
          compactNav: _compactNav,
          onCompactNavChanged: _setCompactNav,
          railPinned: _railPinned,
          onRailPinnedChanged: _setRailPinned,
        ),
      );
    }

    return _guardExit(
      DonorShell(
        user: user,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
        compactNav: _compactNav,
        onCompactNavChanged: _setCompactNav,
        railPinned: _railPinned,
        onRailPinnedChanged: _setRailPinned,
      ),
    );
  }

  /// On a phone the system back gesture would otherwise drop the user straight
  /// out of the app, so ask first. Web and desktop keep the default behaviour:
  /// the browser back button has to keep working on the web build.
  Widget _guardExit(Widget shell) {
    if (kIsWeb ||
        MediaQuery.sizeOf(context).width >= TabangBreakpoints.navigationRail) {
      return shell;
    }
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final leave = await confirmAction(
          context,
          title: 'Exit app?',
          message:
              'You are about to close the app. You stay signed in on this '
              'device and can pick up where you left off.',
          confirmLabel: 'Leave',
        );
        if (leave) await SystemNavigator.pop();
      },
      child: shell,
    );
  }
}

/// Allows click-and-drag scrolling with a mouse or trackpad on every
/// scrollable, including the horizontal Discover rails. Flutter only enables
/// touch drags by default on web.
class TabangScrollBehavior extends MaterialScrollBehavior {
  const TabangScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.invertedStylus,
  };
}
