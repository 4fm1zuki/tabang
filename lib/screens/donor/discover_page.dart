import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/photo.dart';

/// Discover / home feed.
///
/// The feed is organised into horizontal rails: announcements and featured
/// updates, upcoming blood drives, and educational content. Horizontal rails
/// keep each section scannable on a phone without turning the page into one
/// endless vertical column, and they let a desktop window show more than a
/// grid of identical cards.
///
/// The urgent-shortage callout deliberately lives in Blood Bank and on the map,
/// not here: Discover is for orientation and education, while stock alerts
/// belong beside the inventory they describe.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({super.key, required this.user, this.onNavigate});

  final AppUser user;

  /// Lets the simple home jump straight to another shell destination
  /// (Requests, Find Donor, Messages, Profile) without duplicating pages.
  final ValueChanged<int>? onNavigate;

  @override
  State<DiscoverPage> createState() => _DiscoverPageState();
}

class _DiscoverPageState extends State<DiscoverPage> {
  final TabangRepository _repo = TabangRepository.instance;
  final TextEditingController _searchController = TextEditingController();

  /// Anchor for the "Find a drive" quick action.
  final GlobalKey _drivesSectionKey = GlobalKey();

  ContentCategory _category = ContentCategory.explore;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    _searchController.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  AppUser get _user => _repo.userById(widget.user.id) ?? widget.user;

  List<ContentItem> get _filtered {
    final all = _repo.content;
    if (_query.trim().isNotEmpty) {
      final q = _query.toLowerCase();
      return all
          .where(
            (c) =>
                c.title.toLowerCase().contains(q) ||
                c.subtitle.toLowerCase().contains(q) ||
                c.tag.toLowerCase().contains(q),
          )
          .toList();
    }
    if (_category == ContentCategory.explore) return all;
    return all.where((c) => c.category == _category).toList();
  }

  List<BloodDrive> get _upcomingDrives => _repo.drives
      .where((d) => d.status != 'Completed')
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final items = _filtered;
    // The hero is evergreen encouragement, never the shortage alert. Stock
    // alerts belong beside the inventory in Blood Bank.
    final hero = _repo.content.firstWhere(
      (c) => c.id == 'CNT-001',
      orElse: () => _repo.content.first,
    );
    final announcements = _repo.content
        .where(
          (c) =>
              c.id != hero.id &&
              (c.category == ContentCategory.explore ||
                  c.category == ContentCategory.stories),
        )
        .toList(growable: false);
    final learning = _repo.content
        .where(
          (c) =>
              c.category == ContentCategory.tips ||
              c.category == ContentCategory.eligibility,
        )
        .toList(growable: false);

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Home',
            subtitle: 'Updates, donation guidance and upcoming drives across Digos City.',
            actions: [
              SizedBox(
                width: context.isPhone ? double.infinity : 240,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Search updates and tips',
                    isDense: true,
                    prefixIcon: const Icon(Icons.search, size: 17),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close, size: 15),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          _buildHero(context, hero),
          const SizedBox(height: TabangSpace.lg),
          _buildQuickActions(context, user),
          const SizedBox(height: TabangSpace.xl),

          // Category chips
          Wrap(
            spacing: TabangSpace.sm,
            runSpacing: TabangSpace.sm,
            children: ContentCategory.values.map((c) {
              final selected = _category == c && _query.isEmpty;
              return ChoiceChip(
                label: Text(c.label),
                selected: selected,
                showCheckmark: false,
                selectedColor: TabangColors.crimson,
                labelStyle: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : context.textColor,
                ),
                onSelected: (_) {
                  _searchController.clear();
                  setState(() {
                    _category = c;
                    _query = '';
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: TabangSpace.xl),

          if (_query.isNotEmpty) ...[
            SectionLabel(
              '${items.length} result${items.length == 1 ? '' : 's'} for "$_query"',
            ),
            if (items.isEmpty)
              const EmptyState(
                art: TabangArt.search,
                title: 'No results found',
                message: 'Try a different term or browse a category.',
              )
            else
              _buildGrid(items),
          ] else if (_category == ContentCategory.explore) ...[
            KeyedSubtree(
              key: _drivesSectionKey,
              child: _buildSectionHeader(
                context,
                'Upcoming blood drives',
                subtitle:
                    'Walk in or book an appointment at a participating site.',
                action: _sectionAction(
                  context,
                  'Blood Bank',
                  () => widget.onNavigate?.call(1),
                ),
              ),
            ),
            if (_upcomingDrives.isEmpty)
              const EmptyState(
                art: TabangArt.inventory,
                title: 'No drives scheduled',
                message:
                    'The chapter publishes the next mobile drive here as soon '
                    'as the schedule is confirmed.',
              )
            else
              _buildRail(context, [
                for (var i = 0; i < _upcomingDrives.length; i++)
                  _buildDriveCard(context, _upcomingDrives[i], i),
              ]),
            const SizedBox(height: TabangSpace.xxl),

            _buildSectionHeader(
              context,
              'Announcements & stories',
              subtitle:
                  'Updates from the donor network and the people it helps.',
              action: _sectionAction(
                context,
                'Stories',
                () => setState(() => _category = ContentCategory.stories),
              ),
            ),
            _buildRail(
              context,
              announcements
                  .map((item) => _buildCard(context, item))
                  .toList(growable: false),
            ),
            const SizedBox(height: TabangSpace.xxl),

            _buildSectionHeader(
              context,
              'Learn & prepare',
              subtitle: 'Short, clinically aligned guidance before and after donating.',
              action: _sectionAction(
                context,
                'All guides',
                () => setState(() => _category = ContentCategory.tips),
              ),
            ),
            _buildRail(
              context,
              learning.map((item) => _buildCard(context, item)).toList(),
            ),
            const SizedBox(height: TabangSpace.xxl),
            _buildVisitPlanner(context),
          ] else if (_category == ContentCategory.drives) ...[
            KeyedSubtree(
              key: _drivesSectionKey,
              child: _buildSectionHeader(
                context,
                'Upcoming blood drives',
                subtitle:
                    'Walk in or book an appointment at a participating site.',
                action: _sectionAction(
                  context,
                  'Blood Bank',
                  () => widget.onNavigate?.call(1),
                ),
              ),
            ),
            if (_upcomingDrives.isEmpty)
              const EmptyState(
                art: TabangArt.inventory,
                title: 'No drives scheduled',
                message:
                    'The chapter publishes the next mobile drive here as soon '
                    'as the schedule is confirmed.',
              )
            else
              _buildRail(context, [
                for (var i = 0; i < _upcomingDrives.length; i++)
                  _buildDriveCard(context, _upcomingDrives[i], i),
              ]),
            const SizedBox(height: TabangSpace.xl),
            _buildVisitPlanner(context),
          ] else ...[
            _buildSectionHeader(
              context,
              _category.label,
              subtitle: _category == ContentCategory.stories
                  ? 'Real accounts from donors and recipient families.'
                  : 'Everything the chapter has published in this category.',
            ),
            if (items.isEmpty)
              const EmptyState(art: TabangArt.search, title: 'Nothing here yet')
            else
              _buildRail(
                context,
                items.map((item) => _buildCard(context, item)).toList(),
              ),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------ quick actions

  /// Two primary actions plus a guide. The previous build put four outlined
  /// buttons and a five-tile summary card above the feed, which pushed actual
  /// content below the fold on a phone. Messages now lives in the bottom bar
  /// and the summary duplicates Requests/Messages, so both were removed here.
  Widget _buildQuickActions(BuildContext context, AppUser user) {
    final isDonor = user.role == UserRole.donor;
    return Wrap(
      spacing: TabangSpace.sm,
      runSpacing: TabangSpace.sm,
      children: [
        FilledButton.icon(
          onPressed: () => widget.onNavigate?.call(3),
          icon: Icon(
            isDonor ? Icons.volunteer_activism_outlined : Icons.bloodtype,
            size: 18,
          ),
          label: Text(isDonor ? 'View blood requests' : 'Request blood'),
        ),
        OutlinedButton.icon(
          onPressed: () => widget.onNavigate?.call(2),
          icon: const Icon(Icons.map_outlined, size: 18),
          label: const Text('Find a donor'),
        ),
        // Sits beside "Find a donor" as requested; jumps to the drives rail
        // instead of leaving the page.
        OutlinedButton.icon(
          onPressed: _jumpToDrives,
          icon: const Icon(Icons.event_outlined, size: 18),
          label: const Text('Find a drive'),
        ),
      ],
    );
  }

  /// Brings the blood-drive rail into view.
  ///
  /// The rail only exists in the Explore and Blood Drives categories, so a tap
  /// from Stories, Tips or Eligibility used to return without doing anything.
  /// Switch to the drives view first when needed, then scroll on the next frame
  /// once that section is actually mounted.
  void _jumpToDrives() {
    const railCategories = {ContentCategory.explore, ContentCategory.drives};
    if (!railCategories.contains(_category)) {
      setState(() => _category = ContentCategory.drives);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _drivesSectionKey.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
        alignment: 0.05,
      );
    });
  }

  // --------------------------------------------------------------- hero card

  Widget _buildHero(BuildContext context, ContentItem item) {
    return Container(
      // Content-sized with a minimum, so a long headline wraps instead of
      // overflowing the card at narrow widths.
      constraints: BoxConstraints(minHeight: context.isPhone ? 280 : 250),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TabangRadius.lg),
        color: const Color(0xFF241715),
        // No large coloured shadow: it forced an extra save-layer on every
        // frame and made the feed feel heavier than it is.
        border: Border.all(color: TabangColors.crimson.withValues(alpha: 0.35)),
      ),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Positioned.fill(
            child: TabangPhoto(
              item.imageAsset,
              alignment: const Alignment(0.45, -0.1),
              semanticLabel: item.title,
              creditLabel: item.title,
              fallbackIcon: _iconFor(item.category),
              fallbackIconSize: 56,
            ),
          ),
          // Neutral scrim with a restrained crimson edge. The old 97%-crimson
          // overlay turned the whole hero into a red block and hid the photo.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    const Color(0xFF160F0D).withValues(alpha: 0.96),
                    const Color(0xFF160F0D).withValues(alpha: 0.72),
                    TabangColors.crimsonDark.withValues(alpha: 0.22),
                  ],
                  stops: const [0, 0.58, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: context.pagePadding,
            child: SizedBox(
              width: double.infinity,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StatusPill(item.tag, tone: Tone.neutral, onImage: true),
                  const SizedBox(height: TabangSpace.md),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 620),
                    child: Text(
                      item.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                        letterSpacing: -0.7,
                      ),
                    ),
                  ),
                  const SizedBox(height: TabangSpace.sm),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: Text(
                      item.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: TabangSpace.lg),
                  Wrap(
                    spacing: TabangSpace.sm,
                    runSpacing: TabangSpace.sm,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: () => _openContent(context, item),
                        icon: const Icon(Icons.arrow_forward, size: 17),
                        label: const Text('Read the story'),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: TabangColors.crimsonDark,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- rail pieces

  Widget _buildSectionHeader(
    BuildContext context,
    String title, {
    String? subtitle,
    Widget? action,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.35,
                    color: context.textColor,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (action != null) action,
        ],
      ),
    );
  }

  Widget _sectionAction(
    BuildContext context,
    String label,
    VoidCallback onTap,
  ) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: context.isDark
                  ? const Color(0xFFFFB4A8)
                  : TabangColors.crimson,
            ),
          ),
          const SizedBox(width: 2),
          Icon(
            Icons.chevron_right,
            size: 17,
            color: context.isDark
                ? const Color(0xFFFFB4A8)
                : TabangColors.crimson,
          ),
        ],
      ),
    );
  }

  /// A horizontal rail. Cards keep a readable fixed width on tablet/desktop and
  /// shrink to fit the phone viewport, so the next card peeks in and signals
  /// that the row scrolls. Desktop gets arrow buttons and a scrollbar because
  /// horizontal mouse wheels are uncommon; a mouse can also click-drag the row
  /// thanks to [TabangScrollBehavior].
  Widget _buildRail(BuildContext context, List<Widget> children) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = context.isPhone
            ? math.min(constraints.maxWidth - 36, 286.0)
            : constraints.maxWidth > 1100
            ? 300.0
            : 278.0;
        return _ContentRail(
          cardWidth: cardWidth,
          trailingGap: TabangSpace.md,
          children: children,
        );
      },
    );
  }

  // -------------------------------------------------------------- drive card

  Widget _buildDriveCard(BuildContext context, BloodDrive drive, int index) {
    // Each drive ships its own photograph; the shared community shots remain a
    // fallback if a drive has none.
    final photo = drive.photoAsset ??
        (index.isEven
            ? 'assets/images/drive_community.jpg'
            : 'assets/images/content_drive.jpg');

    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: () => _openDrive(context, drive),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(TabangRadius.md - 1),
            ),
            child: SizedBox(
              height: 112,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TabangPhoto(
                    photo,
                    semanticLabel: drive.title,
                    creditLabel: drive.title,
                    fallbackIcon: Icons.event_outlined,
                    fallbackIconSize: 30,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.34),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    left: TabangSpace.sm,
                    bottom: TabangSpace.sm,
                    child: StatusPill(
                      drive.status,
                      tone: drive.status == 'Ongoing'
                          ? Tone.success
                          : Tone.info,
                      dense: true,
                      onImage: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TabangSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  drive.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                    color: context.textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 14,
                      color: context.textMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${drive.expectedDonors} expected',
                      style: TextStyle(fontSize: 12, color: context.textMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                _driveMeta(context, Icons.place_outlined, drive.venue),
                const SizedBox(height: 2),
                _driveMeta(
                  context,
                  Icons.schedule,
                  formatDateTime(drive.startsAt),
                ),
                const SizedBox(height: TabangSpace.sm),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: () => _openDrive(context, drive),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.info_outline, size: 14),
                      label: const Text(
                        'Drive details',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _driveMeta(BuildContext context, IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: context.textMuted),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: context.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- content card

  Widget _buildGrid(List<ContentItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1180
            ? 3
            : constraints.maxWidth > 760
            ? 2
            : 1;
        const gap = TabangSpace.lg;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map(
                (item) =>
                    SizedBox(width: width, child: _buildCard(context, item)),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildCard(BuildContext context, ContentItem item) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: () => _openContent(context, item),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(TabangRadius.md - 1),
            ),
            child: SizedBox(
              height: 150,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TabangPhoto(
                    item.imageAsset,
                    semanticLabel: item.title,
                    creditLabel: item.title,
                    fallbackIcon: _iconFor(item.category),
                    fallbackIconSize: 34,
                  ),
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.28),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: TabangSpace.sm,
                    right: TabangSpace.sm,
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.92),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconFor(item.category),
                        size: 15,
                        color: TabangColors.crimson,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(TabangSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                StatusPill(item.tag, tone: Tone.brand, dense: true),
                const SizedBox(height: TabangSpace.sm),
                Text(
                  item.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    height: 1.32,
                    color: context.textColor,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- visit planner

  Widget _buildVisitPlanner(BuildContext context) {
    const facts = <_Fact>[
      _Fact(Icons.badge_outlined, 'Bring a valid ID', 'and your donor card'),
      _Fact(Icons.restaurant_outlined, 'Eat a light meal', 'within 4 hours'),
      _Fact(Icons.timer_outlined, 'Allow 45 minutes', 'screening + donation'),
      _Fact(Icons.local_hospital_outlined, 'Book a slot', 'at the blood bank'),
    ];
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_available_outlined,
                size: 18,
                color: TabangColors.crimson,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Plan your donation visit',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: context.textColor,
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: () => widget.onNavigate?.call(1),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text('Blood Bank', style: TextStyle(fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          Wrap(
            spacing: TabangSpace.md,
            runSpacing: TabangSpace.sm,
            children: [
              for (final fact in facts)
                SizedBox(
                  width: context.isPhone ? 140 : 210,
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: context.surfaceAlt,
                          borderRadius: BorderRadius.circular(TabangRadius.xs),
                        ),
                        child: Icon(
                          fact.icon,
                          size: 17,
                          color: TabangColors.crimson,
                        ),
                      ),
                      const SizedBox(width: TabangSpace.sm),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fact.title,
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: context.textColor,
                              ),
                            ),
                            Text(
                              fact.detail,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TabangSpace.sm),
            decoration: BoxDecoration(
              color: context.isDark
                  ? TabangColors.darkSurfaceAlt
                  : TabangColors.lightSurfaceAlt,
              borderRadius: BorderRadius.circular(TabangRadius.xs),
            ),
            child: Text(
              'Blood-bank stock is shown as signed: the public inventory is '
              'read-only, and chapter staff confirm every reservation after '
              'clinical screening. O− is reserved for emergencies first.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: context.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- dialogs

  Future<void> _openDrive(BuildContext context, BloodDrive drive) {
    final index = _upcomingDrives.indexOf(drive);
    final photo = drive.photoAsset ??
        (index.isEven
            ? 'assets/images/drive_community.jpg'
            : 'assets/images/content_drive.jpg');
    final now = DateTime.now();
    final isToday =
        drive.startsAt.year == now.year &&
        drive.startsAt.month == now.month &&
        drive.startsAt.day == now.day;

    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(drive.title),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(TabangRadius.sm),
                  child: AspectRatio(
                    aspectRatio: 16 / 8,
                    child: TabangPhoto(
                      photo,
                      semanticLabel: drive.title,
                      creditLabel: drive.title,
                      fallbackIcon: Icons.event_outlined,
                      fallbackIconSize: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                PhotoCredit(photo, label: drive.title),
                const SizedBox(height: TabangSpace.md),
                Wrap(
                  spacing: TabangSpace.sm,
                  runSpacing: TabangSpace.sm,
                  children: [
                    StatusPill(
                      drive.status,
                      tone: drive.status == 'Ongoing'
                          ? Tone.success
                          : Tone.info,
                      dense: true,
                    ),
                    StatusPill(
                      isToday ? 'Today' : 'Upcoming',
                      tone: isToday ? Tone.warning : Tone.neutral,
                      dense: true,
                    ),
                  ],
                ),
                const SizedBox(height: TabangSpace.md),
                _driveDetail(
                  context,
                  Icons.place_outlined,
                  'Venue',
                  '${drive.venue} · ${drive.barangay}',
                ),
                _driveDetail(
                  context,
                  Icons.schedule,
                  'Schedule',
                  '${formatDateTime(drive.startsAt)} – '
                      '${formatDateTime(drive.endsAt)}',
                ),
                _driveDetail(
                  context,
                  Icons.people_outline,
                  'Expected donors',
                  '${drive.expectedDonors}',
                ),
                const SizedBox(height: TabangSpace.md),
                Text(
                  'Walk-ins are welcome while supplies last. Booking an '
                  'appointment at the blood bank guarantees a screening slot, '
                  'not a specific unit. Donors are screened on site.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          // The venue also carries a pin on the Find Donor map, so a drive can
          // be located without retyping the venue into a search field.
          TextButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onNavigate?.call(2);
            },
            icon: const Icon(Icons.map_outlined, size: 16),
            label: const Text('View drives on map'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              widget.onNavigate?.call(1);
            },
            icon: const Icon(Icons.event_available_outlined, size: 16),
            label: const Text('Book appointment'),
          ),
        ],
      ),
    );
  }

  Widget _driveDetail(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: TabangColors.crimson),
          const SizedBox(width: TabangSpace.sm),
          SizedBox(
            width: 104,
            child: Text(
              label,
              style: TextStyle(fontSize: 12, color: context.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.45,
                fontWeight: FontWeight.w600,
                color: context.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openContent(BuildContext context, ContentItem item) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SizedBox(
          width: 480,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(TabangRadius.sm),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        TabangPhoto(
                          item.imageAsset,
                          semanticLabel: item.title,
                          creditLabel: item.title,
                          fallbackIcon: _iconFor(item.category),
                          fallbackIconSize: 40,
                        ),
                        Positioned(
                          left: TabangSpace.sm,
                          bottom: TabangSpace.sm,
                          child: StatusPill(
                            item.tag,
                            tone: Tone.neutral,
                            dense: true,
                            onImage: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                // Attribution stays visible under the image, but the raw
                // source URL is one tap away instead of being printed inline.
                PhotoCredit(item.imageAsset, label: item.title),
                const SizedBox(height: TabangSpace.md),
                Text(
                  item.body,
                  style: TextStyle(
                    fontSize: 14.5,
                    height: 1.65,
                    color: context.textColor,
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(ContentCategory category) {
    switch (category) {
      case ContentCategory.tips:
        return Icons.lightbulb_outline;
      case ContentCategory.eligibility:
        return Icons.fact_check_outlined;
      case ContentCategory.drives:
        return Icons.event_outlined;
      case ContentCategory.stories:
        return Icons.auto_stories_outlined;
      case ContentCategory.explore:
        return Icons.public;
    }
  }
}

class _Fact {
  const _Fact(this.icon, this.title, this.detail);

  final IconData icon;
  final String title;
  final String detail;
}

/// Horizontally scrolling rail with desktop arrows and a scrollbar.
///
/// The arrows matter on web: a mouse has no horizontal wheel gesture, so
/// without a visible control the second card onwards was effectively
/// unreachable even though the row was technically scrollable. Click-drag and
/// the scrollbar both work as well.
class _ContentRail extends StatefulWidget {
  const _ContentRail({
    required this.cardWidth,
    required this.trailingGap,
    required this.children,
  });

  final double cardWidth;
  final double trailingGap;
  final List<Widget> children;

  @override
  State<_ContentRail> createState() => _ContentRailState();
}

class _ContentRailState extends State<_ContentRail> {
  final ScrollController _controller = ScrollController();
  bool _canBack = false;
  bool _canForward = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_sync);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_sync)
      ..dispose();
    super.dispose();
  }

  void _sync() {
    if (!mounted || !_controller.hasClients) return;
    final position = _controller.position;
    final back = position.pixels > 1;
    final forward = position.pixels < position.maxScrollExtent - 1;
    if (back != _canBack || forward != _canForward) {
      setState(() {
        _canBack = back;
        _canForward = forward;
      });
    }
  }

  void _scrollBy(double delta) {
    if (!_controller.hasClients) return;
    final target = (_controller.offset + delta).clamp(
      0.0,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  Widget _arrow({
    required IconData icon,
    required String tooltip,
    required bool enabled,
    required VoidCallback onPressed,
  }) {
    // Neutral surface, not a teal tonal disc: the old arrows looked like
    // decoration floating on top of card copy. A border and a small shadow
    // make them read as controls while staying out of the content's way.
    return DecoratedBox(
      decoration: BoxDecoration(
        color: context.surface.withValues(alpha: 0.97),
        shape: BoxShape.circle,
        border: Border.all(color: context.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.45 : 0.18),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IconButton(
        onPressed: enabled ? onPressed : null,
        tooltip: tooltip,
        icon: Icon(icon, size: 21),
        color: context.textColor,
        style: IconButton.styleFrom(
          minimumSize: const Size(38, 38),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
      ),
    );
  }

  /// The rail that currently owns the mouse wheel. Clicking a rail focuses it;
  /// clicking anywhere else returns the wheel to normal page scrolling.
  static _ContentRailState? _focusedRail;

  bool _focused = false;

  void _unfocus() {
    if (!mounted) return;
    if (_focused) setState(() => _focused = false);
  }

  void _focus() {
    if (_focusedRail != this) _focusedRail?._unfocus();
    _focusedRail = this;
    if (!_focused) setState(() => _focused = true);
  }

  /// Mouse-wheel scrolls the rail only after it has been clicked ("focused").
  /// Flutter otherwise maps a vertical wheel delta to the nearest vertical
  /// scrollable, so plain hovering used to swallow the page scroll.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (!_focused || event is! PointerScrollEvent) return;
    // The focused rail owns the wheel: consume the event even when the row is
    // already at its end, so the page does not suddenly scroll vertically.
    GestureBinding.instance.pointerSignalResolver.register(event, (_) {});
    if (!_controller.hasClients) return;
    final delta = event.scrollDelta.dy != 0
        ? event.scrollDelta.dy
        : event.scrollDelta.dx;
    if (delta == 0) return;
    final position = _controller.position;
    final target = (_controller.offset + delta).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    if (target == _controller.offset) return;
    _controller.jumpTo(target);
  }

  @override
  Widget build(BuildContext context) {
    // Arrows only while the rail is hovered. Always-on buttons sat on top of
    // the third card's title and made the whole row look busy; touch users
    // swipe the rail instead, and mouse users can still drag it.
    final showArrows =
        !context.isPhone && widget.children.length > 1 && _hovered;
    return TapRegion(
      onTapInside: (_) => _focus(),
      onTapOutside: (_) {
        if (_focusedRail == this) _focusedRail = null;
        _unfocus();
      },
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() {
          _hovered = false;
          // Hovering away releases the wheel focus, so the page scrolls
          // vertically again without needing an extra click.
          if (_focused) _focused = false;
          if (_focusedRail == this) _focusedRail = null;
        }),
        child: Listener(
          onPointerSignal: _handlePointerSignal,
          child: Stack(
            children: [
              Scrollbar(
                controller: _controller,
                scrollbarOrientation: ScrollbarOrientation.bottom,
                child: SingleChildScrollView(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: TabangSpace.md),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < widget.children.length; i++)
                        Padding(
                          padding: EdgeInsets.only(
                            right: i == widget.children.length - 1
                                ? 0
                                : widget.trailingGap,
                          ),
                          child: SizedBox(
                            width: widget.cardWidth,
                            child: widget.children[i],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              if (showArrows && _canBack)
                Positioned(
                  left: 2,
                  top: 0,
                  bottom: TabangSpace.md,
                  child: Center(
                    child: _arrow(
                      icon: Icons.chevron_left,
                      tooltip: 'Scroll left',
                      enabled: true,
                      onPressed: () => _scrollBy(-widget.cardWidth * 1.15),
                    ),
                  ),
                ),
              if (showArrows && _canForward)
                Positioned(
                  right: 2,
                  top: 0,
                  bottom: TabangSpace.md,
                  child: Center(
                    child: _arrow(
                      icon: Icons.chevron_right,
                      tooltip: 'Scroll right',
                      enabled: true,
                      onPressed: () => _scrollBy(widget.cardWidth * 1.15),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
