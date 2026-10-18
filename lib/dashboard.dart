import 'package:flutter/material.dart';

import 'widgets/sidebar.dart';

import 'pages/discover_page.dart';
import 'pages/blood_bank_page.dart';
import 'pages/find_donor_page.dart';
import 'pages/chat_page.dart';
import 'pages/settings_page.dart';
import 'pages/about_help_page.dart';
import 'pages/profile_page.dart';

class Dashboard extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const Dashboard({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<Dashboard> {
  bool sidebarOpen = false;

  int selectedIndex = 0;

  Widget getCurrentPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (selectedIndex) {
      case 0:
        return const DiscoverPage();

      case 1:
        return const BloodBankPage();

      case 2:
        return FindDonorPage(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
        );

      case 3:
        return ChatPage(isDark: isDark);

      case 4:
        return SettingsPage(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
        );

      case 5:
        return AboutHelpPage(isDark: isDark);

      case 6:
        return ProfilePage(isDark: isDark);

      default:
        return const DiscoverPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Row(
          children: [
            // ==================================================
            // HOVER SIDEBAR
            // ==================================================

            MouseRegion(
              onEnter: (_) {
                setState(() {
                  sidebarOpen = true;
                });
              },

              onExit: (_) {
                setState(() {
                  sidebarOpen = false;
                });
              },

              child: TabangSidebar(
                selectedIndex: selectedIndex,

                onItemSelected: (index) {
                  setState(() {
                    selectedIndex = index;
                  });
                },

                isExpanded: sidebarOpen,
              ),
            ),

            // ==================================================
            // PAGE
            // ==================================================

            Expanded(
              child: getCurrentPage(),
            ),
          ],
        ),
      ),
    );
  }
}