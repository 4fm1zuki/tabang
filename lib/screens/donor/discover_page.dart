import 'package:flutter/material.dart';

import '../../core/eligibility.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';
import '../../widgets/illustrations.dart';
import '../../widgets/onboarding.dart';
import '../../widgets/photo.dart';

/// Discover / home feed.
///
/// Preserves the original category chips, search, hero card and card grid,
/// but the content now carries a real body so tapping a card opens something
/// instead of dead-ending on an empty `onPressed`.
class DiscoverPage extends StatefulWidget {
  const DiscoverPage({
    super.key,
    required this.user,
    this.onNavigate,
  });

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
          .where((c) =>
              c.title.toLowerCase().contains(q) ||
              c.subtitle.toLowerCase().contains(q) ||
              c.tag.toLowerCase().contains(q))
          .toList();
    }
    if (_category == ContentCategory.explore) return all;
    return all.where((c) => c.category == _category).toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    final items = _filtered;
    final hero = _repo.content.first;
    final upcoming = _repo.drives
        .where((d) => d.status != 'Completed')
        .take(2)
        .toList();

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Discover',
            subtitle:
                'Updates, donation guidance and upcoming drives across Digos City.',
            actions: [
              SizedBox(
                width: context.isPhone ? double.infinity : 240,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _query = v),
                  style: const TextStyle(fontSize: 12.5),
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

          _buildQuickActions(context, user),
          const SizedBox(height: TabangSpace.lg),

          if (_repo.criticalShortageTypes.isNotEmpty) ...[
            _buildShortageBanner(context),
            const SizedBox(height: TabangSpace.lg),
          ],
          _buildNotificationSummary(context, user),
          const SizedBox(height: TabangSpace.lg),

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
                  fontSize: 11.5,
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
            SectionLabel('${items.length} result${items.length == 1 ? '' : 's'} for "$_query"'),
            if (items.isEmpty)
              const EmptyState(
                art: TabangArt.search,
                title: 'No results found',
                message: 'Try a different term or browse a category.',
              )
            else
              _buildGrid(items),
          ] else if (_category == ContentCategory.explore) ...[
            _buildHero(context, hero),
            const SizedBox(height: TabangSpace.xl),
            if (upcoming.isNotEmpty) ...[
              const SectionLabel('Upcoming drives'),
              _buildDriveStrip(context, upcoming),
              const SizedBox(height: TabangSpace.xl),
            ],
            const SectionLabel('Featured updates'),
            _buildGrid(
              _repo.content
                  .where((c) => c.category != ContentCategory.explore)
                  .toList(),
            ),
          ] else ...[
            SectionLabel(_category.label),
            if (items.isEmpty)
              const EmptyState(
                art: TabangArt.search,
                title: 'Nothing here yet',
              )
            else
              _buildGrid(items),
          ],
        ],
      ),
    );
  }

  /// The four obvious actions, always at the top of the feed. This is the
  /// mobile entry point and works the same on a phone, tablet or desktop.
  Widget _buildQuickActions(BuildContext context, AppUser user) {
    final isDonor = user.role == UserRole.donor;
    return Wrap(
      spacing: TabangSpace.sm,
      runSpacing: TabangSpace.sm,
      children: [
        _quickAction(
          context,
          icon: isDonor
              ? Icons.volunteer_activism_outlined
              : Icons.bloodtype_outlined,
          label: isDonor ? 'Donate blood' : 'Request blood',
          onTap: () => widget.onNavigate?.call(3),
        ),
        _quickAction(
          context,
          icon: Icons.map_outlined,
          label: 'Find donation sites',
          onTap: () => widget.onNavigate?.call(2),
        ),
        _quickAction(
          context,
          icon: Icons.forum_outlined,
          label: 'Messages',
          onTap: () => widget.onNavigate?.call(4),
        ),
        _quickAction(
          context,
          icon: Icons.school_outlined,
          label: 'Quick guide',
          onTap: () => showWelcomeGuide(context, user, markSeen: false),
        ),
      ],
    );
  }

  Widget _quickAction(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: TabangSpace.md,
          vertical: TabangSpace.sm,
        ),
        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildShortageBanner(BuildContext context) {
    final types = _repo.criticalShortageTypes;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(TabangSpace.lg),
      decoration: BoxDecoration(
        color: context.warningBg,
        borderRadius: BorderRadius.circular(TabangRadius.md),
        border: Border.all(
          color: TabangColors.warning.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: TabangColors.warning,
            size: 20,
          ),
          const SizedBox(width: TabangSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Urgent blood shortage',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${types.map((t) => t.label).join(', ')} '
                  '${types.length == 1 ? 'has' : 'have'} no usable units in '
                  'the public inventory. If you are eligible, check open '
                  'donor-network requests or the next blood drive.',
                  style: const TextStyle(fontSize: 11.5, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationSummary(BuildContext context, AppUser user) {
    final openCompatible = user.role == UserRole.donor &&
            user.bloodType != null
        ? _repo.donorNetworkRequests.where((r) {
            return Compatibility.canDonateComponentTo(
              user.bloodType!,
              r.bloodType,
              r.component,
            );
          }).length
        : 0;
    final myRequests = _repo.requests
        .where((r) =>
            r.requesterId == user.id &&
            (r.status == RequestStatus.open ||
                r.status == RequestStatus.matched))
        .toList();
    final myRequestIds = myRequests.map((r) => r.id).toSet();
    final responses = _repo.responses
        .where((r) => myRequestIds.contains(r.requestId))
        .length;
    final threads = _repo.threadsFor(user.id).length;
    final drives = _repo.drives.where((d) => d.status != 'Completed').length;
    final eligibility = EligibilityEngine.evaluate(user);

    final items = <Widget>[
      if (user.role == UserRole.donor && user.notifyRequests)
        _summaryItem(
          context,
          Icons.campaign_outlined,
          '$openCompatible',
          'Compatible requests',
        ),
      if (user.role == UserRole.recipient && user.notifyRequests) ...[
        _summaryItem(
          context,
          Icons.assignment_outlined,
          '${myRequests.length}',
          'Active requests',
        ),
        _summaryItem(
          context,
          Icons.volunteer_activism_outlined,
          '$responses',
          'Donor responses',
        ),
      ],
      if (user.notifyChat)
        _summaryItem(
          context,
          Icons.forum_outlined,
          '$threads',
          'Conversations',
        ),
      if (user.notifyNews)
        _summaryItem(
          context,
          Icons.event_outlined,
          '$drives',
          'Upcoming drives',
        ),
      if (user.role == UserRole.donor)
        _summaryItem(
          context,
          eligibility.isEligible
              ? Icons.check_circle_outline
              : Icons.schedule,
          eligibility.isEligible ? 'Eligible' : 'Cooldown',
          'Donation status',
          tone: toneForEligibility(eligibility),
        ),
    ];

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.notifications_none,
                  size: 16, color: context.textMuted),
              const SizedBox(width: 6),
              Text(
                'Your summary',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: context.textColor,
                ),
              ),
              const Spacer(),
              Text(
                'In-app only',
                style: TextStyle(fontSize: 10, color: context.textMuted),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.sm),
          if (items.isEmpty)
            Text(
              'Notifications are off. Turn them on in Settings to see '
              'request, chat and drive summaries here.',
              style: TextStyle(fontSize: 11.5, color: context.textMuted),
            )
          else if (context.isPhone)
            LayoutBuilder(
              builder: (context, constraints) {
                const gap = TabangSpace.md;
                final width = (constraints.maxWidth - gap) / 2;
                return Wrap(
                  spacing: gap,
                  runSpacing: TabangSpace.sm,
                  children: [
                    for (final item in items)
                      SizedBox(width: width, child: item),
                  ],
                );
              },
            )
          else
            Wrap(
              spacing: TabangSpace.md,
              runSpacing: TabangSpace.sm,
              children: items,
            ),
        ],
      ),
    );
  }

  Widget _summaryItem(
    BuildContext context,
    IconData icon,
    String value,
    String label, {
    Tone tone = Tone.brand,
  }) {
    final color = switch (tone) {
      Tone.success => TabangColors.success,
      Tone.warning => TabangColors.warning,
      Tone.danger => TabangColors.danger,
      Tone.info => TabangColors.info,
      Tone.brand => TabangColors.crimson,
      Tone.neutral => context.textMuted,
    };
    return Container(
      width: 150,
      padding: const EdgeInsets.all(TabangSpace.sm),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(TabangRadius.xs),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: context.textColor,
                  ),
                ),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
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

  Widget _buildHero(BuildContext context, ContentItem item) {
    return Container(
      // Content-sized with a minimum, so a long headline wraps instead of
      // overflowing the card at narrow widths.
      constraints: BoxConstraints(minHeight: context.isPhone ? 300 : 260),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(TabangRadius.lg),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [TabangColors.crimsonDark, TabangColors.crimson],
        ),
      ),
      child: Stack(
        alignment: Alignment.bottomLeft,
        children: [
          Positioned.fill(
            child: TabangPhoto(
              item.imageAsset,
              alignment: const Alignment(0.35, -0.1),
              semanticLabel: item.title,
              fallbackIcon: _iconFor(item.category),
              fallbackIconSize: 56,
            ),
          ),
          // A strong bottom-left scrim keeps white copy legible on every
          // photo while the top-right corner still shows the photograph.
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomLeft,
                  end: Alignment.topRight,
                  colors: [
                    TabangColors.crimsonDark.withValues(alpha: 0.97),
                    TabangColors.crimsonDark.withValues(alpha: 0.80),
                    TabangColors.crimson.withValues(alpha: 0.42),
                  ],
                  stops: const [0, 0.62, 1],
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
                  Text(
                    item.title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      height: 1.2,
                      letterSpacing: -0.6,
                    ),
                  ),
                  const SizedBox(height: TabangSpace.sm),
                  Text(
                    item.subtitle,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 12.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: TabangSpace.lg),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ElevatedButton.icon(
                      onPressed: () => _openContent(context, item),
                      icon: const Icon(Icons.arrow_forward, size: 15),
                      label: const Text('Read more'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: TabangColors.crimson,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriveStrip(BuildContext context, List<BloodDrive> drives) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // One card per row on phones; side-by-side from tablet width up.
        final columns = constraints.maxWidth < 520 ? 1 : 2;
        const gap = TabangSpace.md;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < drives.length; i++)
              SizedBox(
                width: width,
                child: _buildDriveCard(context, drives[i], i),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDriveCard(BuildContext context, BloodDrive drive, int index) {
    final photo = index.isEven
        ? 'assets/images/drive_community.jpg'
        : 'assets/images/content_drive.jpg';

    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(TabangRadius.md - 1),
            ),
            child: SizedBox(
              height: 96,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TabangPhoto(
                    photo,
                    semanticLabel: drive.title,
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
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.people_outline,
                        size: 12, color: context.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      '${drive.expectedDonors} expected',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: context.textMuted,
                      ),
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
        Icon(icon, size: 12, color: context.textMuted),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 10.5, color: context.textMuted),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(List<ContentItem> items) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 1180
            ? 3
            : constraints.maxWidth > 760
                ? 2
                : 1;
        const gap = TabangSpace.lg;
        final width =
            (constraints.maxWidth - gap * (columns - 1)) / columns;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: items
              .map((item) => SizedBox(
                    width: width,
                    child: _buildCard(context, item),
                  ))
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
              height: 132,
              width: double.infinity,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  TabangPhoto(
                    item.imageAsset,
                    semanticLabel: item.title,
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                    color: context.textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
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

  void _openContent(BuildContext context, ContentItem item) {
    showDialog<void>(
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
                const SizedBox(height: TabangSpace.md),
                Text(
                  item.body,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.65,
                    color: context.textColor,
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                Text(
                  'Photo: public-domain / CC0 source. Credits are listed in '
                  'About & Help.',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.4,
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
        ],
      ),
    );
  }
}
