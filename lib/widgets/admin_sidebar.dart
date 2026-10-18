import 'package:flutter/material.dart';

class AdminSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isExpanded;

  const AdminSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isExpanded,
  });

  @override
  State<AdminSidebar> createState() => _AdminSidebarState();
}

class _AdminSidebarState extends State<AdminSidebar> {
  bool showText = false;

  final String adminName = "Iverson D. Briones";
  final String adminEmail = "briones.iverson@admin.tabang";
  final String adminInitials = "IB";

  // Admin Navigation Items (Indices 0 to 4)
  static const List<String> menuItems = [
    'System\nOverview',
    'Inventory &\nRequests',
    'User\nManagement',
    'Chat\nModeration',
    'Settings',
  ];

  static const List<IconData> menuIcons = [
    Icons.dashboard_outlined,
    Icons.bloodtype_outlined,
    Icons.people_alt_outlined,
    Icons.mark_chat_read_outlined,
    Icons.tune_outlined,
  ];

  @override
  void initState() {
    super.initState();
    showText = widget.isExpanded;
  }

  @override
  void didUpdateWidget(covariant AdminSidebar oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.isExpanded && !oldWidget.isExpanded) {
      Future.delayed(const Duration(milliseconds: 240), () {
        if (mounted && widget.isExpanded) {
          setState(() {
            showText = true;
          });
        }
      });
    }

    if (!widget.isExpanded && oldWidget.isExpanded) {
      setState(() {
        showText = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Admin Deep Crimson & Dark Tones
    final sidebarColor = isDark
        ? const Color(0xFF1E1E1E)
        : const Color(0xFF7A1C1E);

    final selectedColor = isDark
        ? const Color(0xFF2C2C2C)
        : const Color(0xFF5D1214);

    final textColor = Colors.white;

    final borderColor = isDark
        ? const Color(0xFF333333)
        : const Color(0xFF8E2124);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: widget.isExpanded ? 240 : 70,
      color: sidebarColor,
      child: Column(
        children: [
          // ==================================================
          // HEADER / ADMIN LOGO
          // ==================================================
          SizedBox(
            height: 70,
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Center(
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white24, width: 1),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                if (showText)
                  Expanded(
                    child: Row(
                      children: [
                        const Text(
                          'TABANG',
                          maxLines: 1,
                          overflow: TextOverflow.clip,
                          style: TextStyle(
                            fontFamily: 'Georgia',
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'ADMIN',
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

          // ==================================================
          // NAVIGATION MENU LIST
          // ==================================================
          Expanded(
            child: ListView.builder(
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final selected = widget.selectedIndex == index;

                return GestureDetector(
                  onTap: () {
                    widget.onItemSelected(index);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    height: 58,
                    decoration: BoxDecoration(
                      color: selected ? selectedColor : sidebarColor,
                      border: Border(
                        bottom: BorderSide(
                          color: borderColor,
                          width: 1,
                        ),
                        left: selected
                            ? const BorderSide(color: Colors.white, width: 4)
                            : BorderSide.none,
                      ),
                    ),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 70,
                          child: Center(
                            child: Icon(
                              menuIcons[index],
                              size: 22,
                              color: selected ? Colors.white : Colors.white.withOpacity(0.75),
                            ),
                          ),
                        ),
                        if (showText)
                          Expanded(
                            child: Text(
                              menuItems[index],
                              maxLines: 2,
                              overflow: TextOverflow.clip,
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 12.5,
                                fontWeight: selected ? FontWeight.bold : FontWeight.normal,
                                color: textColor,
                                height: 1.15,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // ==================================================
          // BOTTOM PROFILE TILE (INDEX 5 / ADMIN PROFILE)
          // ==================================================
          Padding(
            padding: EdgeInsets.all(widget.isExpanded ? 10.0 : 6.0),
            child: GestureDetector(
              onTap: () => widget.onItemSelected(5), // Index 5 for Admin Profile
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 52,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF292929) : const Color(0xFF5D1214),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.selectedIndex == 5
                        ? Colors.white
                        : (isDark ? const Color(0xFF383838) : const Color(0xFF8E2124)),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          adminInitials,
                          style: const TextStyle(
                            color: Color(0xFF7A1C1E),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ),
                    if (showText) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              adminName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              adminEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 9.5,
                                color: Colors.white.withOpacity(0.7),
                              ),
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
        ],
      ),
    );
  }
}