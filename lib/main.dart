import 'package:flutter/material.dart';

import 'core/auth.dart';
import 'core/models.dart';
import 'core/repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/donor/donor_shell.dart';
import 'screens/admin/admin_shell.dart';
import 'theme.dart';

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
  ThemeMode _themeMode = ThemeMode.system;

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

  @override
  Widget build(BuildContext context) {
    final user = _repo.currentUser;

    return MaterialApp(
      title: 'TABANG',
      debugShowCheckedModeBanner: false,
      theme: TabangTheme.light,
      darkTheme: TabangTheme.dark,
      themeMode: _themeMode,
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
      return AdminShell(
        user: user,
        themeMode: _themeMode,
        onThemeModeChanged: _setThemeMode,
      );
    }

    return DonorShell(
      user: user,
      themeMode: _themeMode,
      onThemeModeChanged: _setThemeMode,
    );
  }
}
