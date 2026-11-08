import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import 'inventory_management.dart';
import 'operations_map_page.dart';

/// Unified staff operations workspace.
///
/// Map and Inventory used to sit side by side in the top-level staff sidebar,
/// which made both look like separate reporting destinations and crowded the
/// rail. They are two views of the same job, so they now share one destination
/// with a small, collapsible inner sidebar. Phones and narrow windows get the
/// same pair as a segmented control instead of a second navigation rail.
class OperationsWorkspacePage extends StatefulWidget {
  const OperationsWorkspacePage({
    super.key,
    required this.user,
    this.initialSection = 0,
    this.onOpenUsers,
  });

  final AppUser user;

  /// 0 = map, 1 = inventory. The Overview drill-through opens inventory here
  /// rather than adding a second top-level destination.
  final int initialSection;

  final VoidCallback? onOpenUsers;

  @override
  State<OperationsWorkspacePage> createState() =>
      _OperationsWorkspacePageState();
}

class _OperationsWorkspacePageState extends State<OperationsWorkspacePage> {
  final TabangRepository _repo = TabangRepository.instance;

  late int _section = widget.initialSection.clamp(0, 1);
  bool _collapsed = false;

  @override
  void didUpdateWidget(OperationsWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSection != oldWidget.initialSection) {
      _section = widget.initialSection.clamp(0, 1);
    }
  }

  void _select(int section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final pad = context.pagePadding;
    final body = IndexedStack(
      index: _section,
      children: [
        OperationsMapPage(
          user: widget.user,
          embedded: true,
          onOpenUsers: widget.onOpenUsers,
        ),
        InventoryManagementPage(currentUser: widget.user, embedded: true),
      ],
    );

    if (!wide) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              TabangSpace.lg,
              TabangSpace.md,
              TabangSpace.lg,
              0,
            ),
            child: _MobileSectionBar(section: _section, onSelect: _select),
          ),
          Expanded(child: body),
        ],
      );
    }

    return Row(
      children: [
        AnimatedContainer(
          key: const ValueKey('operationsSidebar'),
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          width: _collapsed ? 64 : 208,
          decoration: BoxDecoration(
            color: context.surface,
            border: Border(right: BorderSide(color: context.border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TabangSpace.md,
                  TabangSpace.md,
                  TabangSpace.xs,
                  TabangSpace.sm,
                ),
                child: Row(
                  children: [
                    if (!_collapsed) ...[
                      Icon(
                        Icons.space_dashboard_outlined,
                        size: 17,
                        color: context.textMuted,
                      ),
                      const SizedBox(width: TabangSpace.sm),
                      Expanded(
                        child: Text(
                          'OPERATIONS',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1,
                            color: context.textMuted,
                          ),
                        ),
                      ),
                    ] else
                      const Spacer(),
                    IconButton(
                      tooltip: _collapsed
                          ? 'Expand operations sidebar'
                          : 'Collapse operations sidebar',
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        _collapsed
                            ? Icons.keyboard_double_arrow_right
                            : Icons.keyboard_double_arrow_left,
                        size: 17,
                      ),
                      onPressed: () => setState(() => _collapsed = !_collapsed),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: TabangSpace.xs),
              _sectionTile(
                context,
                icon: Icons.map_outlined,
                activeIcon: Icons.map,
                label: 'Map',
                description: 'Requests & coverage',
                count: _repo.openRequests.length,
                selected: _section == 0,
                onTap: () => _select(0),
              ),
              _sectionTile(
                context,
                icon: Icons.inventory_2_outlined,
                activeIcon: Icons.inventory_2,
                label: 'Inventory',
                description: 'Units & appointments',
                count: _repo.units.length,
                selected: _section == 1,
                onTap: () => _select(1),
              ),
              const Spacer(),
              if (!_collapsed)
                Padding(
                  padding: const EdgeInsets.all(TabangSpace.md),
                  child: Text(
                    'One workspace for the live queue, blood units and '
                    'appointments.',
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.45,
                      color: context.textMuted,
                    ),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  pad.left,
                  pad.top,
                  pad.right,
                  TabangSpace.md,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _section == 0
                                ? 'Operations map'
                                : 'Inventory & requests',
                            style: TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: context.textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _section == 0
                                ? 'Requests, donors and registrations '
                                      'across the 26 barangays.'
                                : 'Manage blood units, monitor expiry, and '
                                      'work the request queue.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (widget.onOpenUsers != null) ...[
                      const SizedBox(width: TabangSpace.md),
                      OutlinedButton.icon(
                        onPressed: widget.onOpenUsers,
                        icon: const Icon(Icons.people_outline, size: 15),
                        label: const Text('Users'),
                      ),
                    ],
                  ],
                ),
              ),
              Expanded(child: body),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionTile(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String description,
    required int count,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final foreground = selected ? Colors.white : context.textColor;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: TabangSpace.sm,
        vertical: 2,
      ),
      child: Material(
        color: selected ? TabangColors.crimson : Colors.transparent,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(TabangRadius.sm),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: _collapsed ? 0 : TabangSpace.md,
              vertical: 9,
            ),
            child: Row(
              mainAxisAlignment: _collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  selected ? activeIcon : icon,
                  size: 18,
                  color: selected ? Colors.white : context.textMuted,
                ),
                if (!_collapsed) ...[
                  const SizedBox(width: TabangSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: foreground,
                          ),
                        ),
                        Text(
                          description,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: selected
                                ? Colors.white.withValues(alpha: 0.78)
                                : context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 1,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? Colors.white.withValues(alpha: 0.22)
                          : context.surfaceAlt,
                      borderRadius: BorderRadius.circular(TabangRadius.pill),
                    ),
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: selected ? Colors.white : context.textMuted,
                      ),
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

/// Segmented fallback for phones and narrow windows.
class _MobileSectionBar extends StatelessWidget {
  const _MobileSectionBar({required this.section, required this.onSelect});

  final int section;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<int>(
        segments: const [
          ButtonSegment(
            value: 0,
            icon: Icon(Icons.map_outlined, size: 15),
            label: Text('Map', softWrap: false),
          ),
          ButtonSegment(
            value: 1,
            icon: Icon(Icons.inventory_2_outlined, size: 15),
            label: Text('Inventory', softWrap: false),
          ),
        ],
        selected: {section},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onSelect(selection.first),
      ),
    );
  }
}
