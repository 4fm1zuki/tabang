import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import 'drive_management_page.dart';
import 'inventory_management.dart';
import 'operations_map_page.dart';

/// Unified staff operations workspace.
///
/// Map and Inventory used to sit side by side in the top-level staff sidebar,
/// which made both look like separate reporting destinations and crowded the
/// rail. They are two views of the same job, so they share one destination.
/// A single segmented control sits above the content at every width: an inner
/// left sidebar on desktop duplicated the top-level navigation and pushed the
/// map into a narrower column for no benefit.
class OperationsWorkspacePage extends StatefulWidget {
  const OperationsWorkspacePage({
    super.key,
    required this.user,
    this.initialSection = 0,
    this.onOpenUsers,
    this.onOpenMessages,
  });

  final AppUser user;

  /// 0 = map, 1 = inventory. The Overview drill-through opens inventory here
  /// rather than adding a second top-level destination.
  final int initialSection;

  final VoidCallback? onOpenUsers;

  /// Opens Messages on a conversation with the given user id (staff donor list).
  final ValueChanged<String>? onOpenMessages;

  @override
  State<OperationsWorkspacePage> createState() =>
      _OperationsWorkspacePageState();
}

class _OperationsWorkspacePageState extends State<OperationsWorkspacePage> {
  late int _section = widget.initialSection.clamp(0, 2);

  /// The Map / Inventory / Drives switch takes a full row above the content.
  /// Staff who are staying in one section can fold it away and give the map or
  /// queue that height back; a compact "Show sections" control remains so the
  /// switch is never lost.
  bool _sectionsVisible = true;

  /// Bumped when the map asks to land on the Inventory Requests tab.
  int _requestsTabToken = 0;

  /// The request the Requests tab should scroll to, set by the map card.
  String? _focusRequestId;

  @override
  void didUpdateWidget(OperationsWorkspacePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialSection != oldWidget.initialSection) {
      _section = widget.initialSection.clamp(0, 2);
    }
  }

  void _select(int section) {
    if (_section == section) return;
    setState(() => _section = section);
  }

  /// The map's request card calls this: switch to Inventory, land on its
  /// Requests tab and scroll to that specific request.
  void _openRequests(String requestId) {
    setState(() {
      _section = 1;
      _focusRequestId = requestId;
      _requestsTabToken++;
    });
  }

  @override
  Widget build(BuildContext context) {
    final pad = context.pagePadding;
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(
            pad.left,
            pad.top,
            pad.right,
            TabangSpace.md,
          ),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: _sectionsVisible
                ? Row(
                    children: [
                      Expanded(
                        child: _SectionBar(
                          section: _section,
                          onSelect: _select,
                        ),
                      ),
                      const SizedBox(width: TabangSpace.sm),
                      IconButton(
                        key: const ValueKey('hideOperationSections'),
                        onPressed: () =>
                            setState(() => _sectionsVisible = false),
                        tooltip: 'Hide section tabs',
                        icon: const Icon(Icons.keyboard_arrow_up, size: 18),
                        style: IconButton.styleFrom(
                          foregroundColor: context.textMuted,
                          side: BorderSide(color: context.border),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              TabangRadius.sm,
                            ),
                          ),
                          padding: const EdgeInsets.all(8),
                          minimumSize: const Size(38, 38),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                    ],
                  )
                : Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      key: const ValueKey('showOperationSections'),
                      onPressed: () => setState(() => _sectionsVisible = true),
                      icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                      label: const Text('Show sections'),
                      style: TextButton.styleFrom(
                        foregroundColor: context.textMuted,
                        visualDensity: VisualDensity.compact,
                        padding: const EdgeInsets.symmetric(
                          horizontal: TabangSpace.md,
                          vertical: 4,
                        ),
                      ),
                    ),
                  ),
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _section,
            children: [
              OperationsMapPage(
                user: widget.user,
                embedded: true,
                onOpenRequests: _openRequests,
                onOpenUsers: widget.onOpenUsers,
                onOpenMessages: widget.onOpenMessages,
              ),
              InventoryManagementPage(
                currentUser: widget.user,
                embedded: true,
                openRequestsToken: _requestsTabToken,
                focusRequestId: _focusRequestId,
              ),
              DriveManagementPage(currentUser: widget.user, embedded: true),
            ],
          ),
        ),
      ],
    );
  }
}

/// Map / Inventory switch shared by phones and desktop windows.
class _SectionBar extends StatelessWidget {
  const _SectionBar({required this.section, required this.onSelect});

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
          ButtonSegment(
            value: 2,
            icon: Icon(Icons.event_outlined, size: 15),
            label: Text('Drives', softWrap: false),
          ),
        ],
        selected: {section},
        showSelectedIcon: false,
        onSelectionChanged: (selection) => onSelect(selection.first),
      ),
    );
  }
}
