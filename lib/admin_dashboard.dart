import 'package:flutter/material.dart';

import 'widgets/admin_sidebar.dart';

import 'admin_pages/admin_overview.dart';
import 'admin_pages/user_management_page.dart';
import 'admin_pages/inventory_management.dart'; // Make sure this exports AdminBloodBankPage or InventoryManagementPage
import 'admin_pages/chat_moderation_page.dart';
import 'admin_pages/admin_settings.dart';
import 'admin_pages/admin_profile_page.dart';

class AdminDashboard extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const AdminDashboard({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool sidebarOpen = false;
  int selectedIndex = 0;

  Widget getCurrentPage() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    switch (selectedIndex) {
      case 0:
        return const AdminOverviewPage();

      case 1:
      // Index 1 = Inventory & Requests
        return const AdminBloodBankPage(); // Or InventoryManagementPage() depending on your class name inside inventory_management.dart

      case 2:
      // Index 2 = User Management
        return const UserManagementPage();

      case 3:
      // Index 3 = Chat Moderation
        return ChatModerationPage(isDark: isDark);

      case 4:
      // Index 4 = Settings
        return AdminSettingsPage(
          themeMode: widget.themeMode,
          onThemeChanged: widget.onThemeChanged,
        );

      case 5:
      // Index 5 = Admin Profile
        return AdminProfilePage(isDark: isDark);

      default:
        return const AdminOverviewPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SizedBox.expand(
        child: Row(
          children: [
            // ==================================================
            // ADMIN HOVER SIDEBAR
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
              child: AdminSidebar(
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
            // PAGE CONTENT AREA
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