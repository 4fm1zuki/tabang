import 'package:flutter/material.dart';

class TabangSidebar extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemSelected;
  final bool isExpanded;

  const TabangSidebar({
    super.key,
    required this.selectedIndex,
    required this.onItemSelected,
    required this.isExpanded,
  });

  @override
  State<TabangSidebar> createState() => _TabangSidebarState();
}

class _TabangSidebarState extends State<TabangSidebar> {
  bool showText = false;

  final String userName = "Iverson D. Briones";
  final String userEmail = "briones.iverson@guest.com";
  final String userInitials = "IB";

  // Navigation Items (Indices 0 to 4)
  static const List<String> menuItems = [
    'Discover',
    'Blood Bank\nInventory',
    'Find Donor',
    'Chat',
    'Settings',
    'About & Help',
  ];

  static const List<IconData> menuIcons = [
    Icons.explore_outlined,
    Icons.bloodtype_outlined,
    Icons.location_on_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.settings_outlined,
    Icons.info_outline,
  ];

  @override
  void initState() {
    super.initState();
    showText = widget.isExpanded;
  }

  @override
  void didUpdateWidget(covariant TabangSidebar oldWidget) {
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

    final sidebarColor = isDark
        ? const Color(0xFF202020)
        : const Color(0xFFE9E9E9);

    final selectedColor = isDark
        ? const Color(0xFF333333)
        : Colors.white;

    final textColor = theme.colorScheme.onSurface;

    final borderColor = isDark
        ? const Color(0xFF444444)
        : const Color(0xFFBBBBBB);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
      width: widget.isExpanded ? 240 : 70,
      color: sidebarColor,
      child: Column(
        children: [
          // ==================================================
          // HEADER / LOGO
          // ==================================================
          SizedBox(
            height: 70,
            child: Row(
              children: [
                SizedBox(
                  width: 70,
                  child: Center(
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        color: Color(0xFFD32F2F),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.water_drop,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                if (showText)
                  Expanded(
                    child: Text(
                      'TABANG',
                      maxLines: 1,
                      overflow: TextOverflow.clip,
                      style: TextStyle(
                        fontFamily: 'Georgia',
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: textColor,
                      ),
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
                    height: 55,
                    decoration: BoxDecoration(
                      color: selected ? selectedColor : sidebarColor,
                      border: Border(
                        bottom: BorderSide(
                          color: borderColor,
                          width: 1,
                        ),
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
                              color: textColor.withOpacity(.75),
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
                                fontSize: 13,
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
          // BOTTOM PROFILE TILE (INDEX 6 / PROFILE)
          // ==================================================
          Padding(
            padding: EdgeInsets.all(widget.isExpanded ? 10.0 : 6.0),
            child: GestureDetector(
              onTap: () => widget.onItemSelected(6), // Index 6 for Profile
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF292929) : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.selectedIndex == 6
                        ? const Color(0xFFD32F2F)
                        : (isDark ? const Color(0xFF383838) : const Color(0xFFE0E0E0)),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 34,
                      height: 34,
                      decoration: const BoxDecoration(
                        color: Color(0xFF4A1212),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          userInitials,
                          style: const TextStyle(
                            color: Color(0xFFD32F2F),
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
                              userName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontFamily: 'Georgia',
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            Text(
                              userEmail,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                color: textColor.withOpacity(0.55),
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