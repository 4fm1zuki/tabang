import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';

/// Administrative analytics overview.
///
/// Structured like a KIN-SCORE dashboard: one primary readiness score at the
/// top, four supporting indicators with bars, then supply/community detail and
/// finally operational exceptions. Every figure is computed from the repository
/// by [TabangRepository.summary] and friends, so the numbers always agree with
/// the tables on the other admin pages.
class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key, this.user, this.onOpenInventory});

  /// The signed-in staff/admin, used to show that account's capabilities.
  final AppUser? user;

  /// Jumps to the Inventory & requests page; wired by [AdminShell] so the
  /// exception cards are a drill-through, not a dead end.
  final VoidCallback? onOpenInventory;

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  final TabangRepository _repo = TabangRepository.instance;

  @override
  void initState() {
    super.initState();
    _repo.addListener(_refresh);
  }

  @override
  void dispose() {
    _repo.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  /// Makes the staff/admin split visible instead of implicit: the two roles
  /// share day-to-day chapter work, and only an admin manages accounts.
  Widget _buildPermissionsCard(BuildContext context) {
    final role = widget.user?.role ?? UserRole.staff;
    final other = role == UserRole.admin ? UserRole.staff : UserRole.admin;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionLabel('Roles & permissions'),
          const SizedBox(height: 4),
          Text(
            'You are signed in as ${role.label}. Clinical Personnel run the '
            'day-to-day chapter work; System Administrators add everything on '
            'top, including account and staff management.',
            style: TextStyle(
              fontSize: 12,
              height: 1.45,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: TabangSpace.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = [
                _permissionColumn(context, role, highlight: true),
                _permissionColumn(context, other, highlight: false),
              ];
              if (constraints.maxWidth >= 640) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: columns[0]),
                    const SizedBox(width: TabangSpace.lg),
                    Expanded(child: columns[1]),
                  ],
                );
              }
              return Column(
                children: [
                  columns[0],
                  const SizedBox(height: TabangSpace.md),
                  columns[1],
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _permissionColumn(
    BuildContext context,
    UserRole role, {
    required bool highlight,
  }) {
    return Container(
      padding: const EdgeInsets.all(TabangSpace.md),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
        border: Border.all(
          color: highlight
              ? TabangColors.crimson.withValues(alpha: 0.45)
              : context.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                role == UserRole.admin
                    ? Icons.admin_panel_settings_outlined
                    : Icons.medical_services_outlined,
                size: 16,
                color: highlight ? TabangColors.crimson : context.textMuted,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  role.label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: context.textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final line in role.capabilities)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.check,
                    size: 13,
                    color: TabangColors.success,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      line,
                      style: TextStyle(
                        fontSize: 11.5,
                        height: 1.4,
                        color: context.textMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summary = _repo.summary();
    final typeStats = _repo.bloodTypeStats();
    final barangayStats = _repo.barangayStats();
    final expiring = _repo.expiringSoon(days: 7);
    final openRequests = _repo.openRequests;

    final score = _ReadinessScore.compute(
      summary: summary,
      expiringCount: expiring.length,
    );

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'Statistics',
            subtitle: 'Supply, donor engagement and barangay coverage for Digos City.',
            actions: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: TabangSpace.md,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: context.infoBg,
                  borderRadius: BorderRadius.circular(TabangRadius.pill),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.science_outlined,
                      size: 12,
                      color: TabangColors.info,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'SIMULATED DATA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                        color: context.isDark
                            ? const Color(0xFF8FB8E8)
                            : TabangColors.info,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          _buildPermissionsCard(context),
          const SizedBox(height: TabangSpace.xl),

          _buildScoreHero(context, score, summary),
          const SizedBox(height: TabangSpace.xl),

          _buildSectionTitle(
            context,
            'Primary indicators',
            'The four measures that drive the readiness score.',
          ),
          const SizedBox(height: TabangSpace.md),
          _buildKpiGrid(context, summary, score),

          const SizedBox(height: TabangSpace.xl),
          _buildSectionTitle(
            context,
            'Supply and community',
            'Where stock and donors are concentrated.',
          ),
          const SizedBox(height: TabangSpace.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 1000;
              final balance = _buildBloodTypeCard(context, typeStats);
              final barangay = _buildBarangayCard(context, barangayStats);
              if (stacked) {
                return Column(
                  children: [
                    balance,
                    const SizedBox(height: TabangSpace.lg),
                    barangay,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 6, child: balance),
                  const SizedBox(width: TabangSpace.lg),
                  Expanded(flex: 4, child: barangay),
                ],
              );
            },
          ),

          const SizedBox(height: TabangSpace.xl),
          _buildSectionTitle(
            context,
            'Supporting detail',
            'Exceptions that need a staff decision this week.',
          ),
          const SizedBox(height: TabangSpace.md),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 1000;
              final expiringCard = _buildExpiringCard(context, expiring);
              final requestsCard = _buildOpenRequestsCard(
                context,
                openRequests,
              );
              if (stacked) {
                return Column(
                  children: [
                    expiringCard,
                    const SizedBox(height: TabangSpace.lg),
                    requestsCard,
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: expiringCard),
                  const SizedBox(width: TabangSpace.lg),
                  Expanded(child: requestsCard),
                ],
              );
            },
          ),
          const SizedBox(height: TabangSpace.lg),
        ],
      ),
    );
  }

  /// One-line section label. The descriptions moved into a tooltip: four
  /// heading + grey-paragraph pairs in a row read as a wall of text on a
  /// dashboard nobody reads top to bottom.
  Widget _buildSectionTitle(
    BuildContext context,
    String title,
    String subtitle,
  ) {
    return Tooltip(
      message: subtitle,
      waitDuration: const Duration(milliseconds: 400),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 15.5,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
          color: context.textColor,
        ),
      ),
    );
  }

  // -------------------------------------------------------------- score hero

  Widget _buildScoreHero(
    BuildContext context,
    _ReadinessScore score,
    AnalyticsSummary summary,
  ) {
    final statusTone = score.value >= 75
        ? Tone.success
        : score.value >= 50
        ? Tone.warning
        : Tone.danger;
    final statusLabel = score.value >= 75
        ? 'Stable'
        : score.value >= 50
        ? 'Watch'
        : 'Constrained';

    return Container(
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        // Deep maroon, not the full brand crimson: the score card already
        // carries the number and tone badge, so a saturated red field only
        // added weight to an already dense dashboard.
        gradient: TabangGradients.donorHero,
        borderRadius: BorderRadius.circular(TabangRadius.lg),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -50,
            top: -70,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            right: 40,
            bottom: -90,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.04),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(
              context.isPhone ? TabangSpace.lg : TabangSpace.xl,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 720;
                final gauge = _buildGauge(context, score);
                final subscores = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'READINESS SCORE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.3,
                        color: Colors.white.withValues(alpha: 0.72),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: TabangSpace.sm,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          _statusLabelFor(score.value),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                            color: Colors.white,
                          ),
                        ),
                        StatusPill(
                          statusLabel,
                          tone: statusTone,
                          dense: true,
                          onImage: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Weighted from supply coverage, donor capacity, request '
                      'pressure and shelf-life health.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.45,
                        color: Colors.white.withValues(alpha: 0.78),
                      ),
                    ),
                    const SizedBox(height: TabangSpace.lg),
                    for (final item in score.components)
                      _buildSubscore(context, item),
                  ],
                );

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          gauge,
                          const SizedBox(width: TabangSpace.lg),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${summary.unitsAvailable} units ready',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${summary.activeDonors} eligible donors · '
                                  '${summary.openRequests} open requests',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    height: 1.4,
                                    color: Colors.white.withValues(alpha: 0.78),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: TabangSpace.lg),
                      subscores,
                    ],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    gauge,
                    const SizedBox(width: TabangSpace.xl),
                    Expanded(child: subscores),
                    const SizedBox(width: TabangSpace.xl),
                    SizedBox(
                      width: 190,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _heroFact(
                            context,
                            Icons.inventory_2_outlined,
                            '${summary.unitsAvailable}',
                            'usable units',
                          ),
                          const SizedBox(height: TabangSpace.md),
                          _heroFact(
                            context,
                            Icons.people_outline,
                            '${summary.activeDonors}',
                            'eligible donors',
                          ),
                          const SizedBox(height: TabangSpace.md),
                          _heroFact(
                            context,
                            Icons.campaign_outlined,
                            '${summary.openRequests}',
                            'open requests',
                          ),
                          const SizedBox(height: TabangSpace.md),
                          _heroFact(
                            context,
                            Icons.event_outlined,
                            '${summary.activeDrives}',
                            'active drives',
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _statusLabelFor(int value) {
    if (value >= 75) return 'Chapter is ready';
    if (value >= 50) return 'Needs attention';
    return 'Supply is constrained';
  }

  Widget _buildGauge(BuildContext context, _ReadinessScore score) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: score.value / 100),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => SizedBox(
        width: context.isPhone ? 118 : 148,
        height: context.isPhone ? 118 : 148,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size.infinite,
              painter: _ScoreGaugePainter(
                value: value,
                track: Colors.white.withValues(alpha: 0.16),
                color: Colors.white,
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${(value * 100).round()}',
                  style: TextStyle(
                    fontSize: context.isPhone ? 30 : 38,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.4,
                    height: 1,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'out of 100',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.72),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubscore(BuildContext context, _ScoreComponent item) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: Row(
        children: [
          SizedBox(
            width: 116,
            child: Text(
              item.label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: Colors.white.withValues(alpha: 0.88),
              ),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(TabangRadius.pill),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: item.fraction,
                backgroundColor: Colors.white.withValues(alpha: 0.16),
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: TabangSpace.sm),
          SizedBox(
            width: 32,
            child: Text(
              '${(item.fraction * 100).round()}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
                color: Colors.white.withValues(alpha: 0.82),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroFact(
    BuildContext context,
    IconData icon,
    String value,
    String label,
  ) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(TabangRadius.xs),
          ),
          child: Icon(icon, size: 16, color: Colors.white),
        ),
        const SizedBox(width: TabangSpace.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  color: Colors.white,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------- KPI cards

  Widget _buildKpiGrid(
    BuildContext context,
    AnalyticsSummary summary,
    _ReadinessScore score,
  ) {
    final verified = _repo.users
        .where((u) => u.status == AccountStatus.verified)
        .length;
    final totalUsers = summary.registeredUsers;

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth < 560
            ? 2
            : constraints.maxWidth < 900
            ? 2
            : 4;
        final width =
            (constraints.maxWidth - TabangSpace.md * (columns - 1)) / columns;
        final cards = [
          _KpiCard(
            label: 'Units available',
            value: '${summary.unitsAvailable}',
            icon: Icons.inventory_2_outlined,
            tone: Tone.brand,
            footnote: 'Across all components',
            progress: score.valueFor('Supply coverage'),
          ),
          _KpiCard(
            label: 'Active donors',
            value: '${summary.activeDonors}',
            icon: Icons.people_outline,
            tone: Tone.success,
            footnote: 'Eligible right now',
            progress: score.valueFor('Donor capacity'),
          ),
          _KpiCard(
            label: 'Open requests',
            value: '${summary.openRequests}',
            icon: Icons.campaign_outlined,
            tone: summary.openRequests > 0 ? Tone.warning : Tone.neutral,
            footnote: 'Awaiting fulfilment',
            progress: score.valueFor('Request pressure'),
          ),
          _KpiCard(
            label: 'Registered users',
            value: '$verified / $totalUsers',
            icon: Icons.badge_outlined,
            tone: Tone.info,
            footnote: '${summary.donationsThisMonth} donations this month',
            progress: totalUsers == 0 ? 0 : verified / totalUsers,
          ),
        ];
        return Wrap(
          spacing: TabangSpace.md,
          runSpacing: TabangSpace.md,
          children: [
            for (final card in cards) SizedBox(width: width, child: card),
          ],
        );
      },
    );
  }

  // ------------------------------------------------------------ supply cards

  Widget _buildBloodTypeCard(BuildContext context, List<BloodTypeStat> stats) {
    final maxValue = stats.fold<int>(
      1,
      (m, s) => s.donated > m ? s.donated : (s.requested > m ? s.requested : m),
    );
    final withDemand = stats.where((s) => s.requested > 0).toList();
    final covered = withDemand.where((s) => s.donated >= s.requested).length;

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Donations vs. requests by blood type',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                ),
              ),
              _legendDot(context, TabangColors.crimson, 'Donated'),
              const SizedBox(width: TabangSpace.md),
              _legendDot(context, TabangColors.info, 'Requested'),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            withDemand.isEmpty
                ? 'No demand recorded yet.'
                : '$covered of ${withDemand.length} blood types meet recorded demand.',
            style: TextStyle(fontSize: 12.5, color: context.textMuted),
          ),
          const SizedBox(height: TabangSpace.lg),
          ...stats.map((stat) {
            return Padding(
              padding: const EdgeInsets.only(bottom: TabangSpace.md),
              child: Row(
                children: [
                  BloodTypeChip(stat.bloodType, size: 28),
                  const SizedBox(width: TabangSpace.md),
                  Expanded(
                    child: Column(
                      children: [
                        ProportionBar(
                          value: stat.donated.toDouble(),
                          max: maxValue.toDouble(),
                          height: 7,
                        ),
                        const SizedBox(height: 3),
                        ProportionBar(
                          value: stat.requested.toDouble(),
                          max: maxValue.toDouble(),
                          color: TabangColors.info,
                          height: 7,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: TabangSpace.md),
                  SizedBox(
                    width: 78,
                    child: Text(
                      '${stat.donated} / ${stat.requested}',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        fontFamily: 'monospace',
                        color: context.textMuted,
                      ),
                    ),
                  ),
                  const SizedBox(width: TabangSpace.sm),
                  SizedBox(
                    width: 46,
                    child: StatusPill(
                      stat.balance >= 0
                          ? '+${stat.balance}'
                          : '${stat.balance}',
                      tone: stat.balance >= 0 ? Tone.success : Tone.danger,
                      dense: true,
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _legendDot(BuildContext context, Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12, color: context.textMuted)),
      ],
    );
  }

  Widget _buildBarangayCard(BuildContext context, List<BarangayStat> stats) {
    final top = stats.take(8).toList();
    final maxCount = top.isEmpty
        ? 1
        : top.map((s) => s.donationCount).reduce((a, b) => a > b ? a : b);

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top donating barangays',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            '${stats.length} barangays with recorded donors · by donation count',
            style: TextStyle(fontSize: 12.5, color: context.textMuted),
          ),
          const SizedBox(height: TabangSpace.lg),
          if (top.isEmpty)
            Text(
              'No donation records yet.',
              style: TextStyle(fontSize: 12.5, color: context.textMuted),
            )
          else
            ...top.asMap().entries.map((entry) {
              final stat = entry.value;
              final rank = entry.key + 1;
              return Padding(
                padding: const EdgeInsets.only(bottom: TabangSpace.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 20,
                      child: Text(
                        '$rank',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'monospace',
                          color: rank <= 3
                              ? TabangColors.crimson
                              : context.textMuted,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 84,
                      child: Text(
                        stat.barangay,
                        style: TextStyle(
                          fontSize: 12,
                          color: context.textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Expanded(
                      child: ProportionBar(
                        value: stat.donationCount.toDouble(),
                        max: maxCount.toDouble(),
                        height: 6,
                        color: rank <= 3
                            ? TabangColors.crimson
                            : context.textMuted,
                      ),
                    ),
                    const SizedBox(width: TabangSpace.sm),
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${stat.donationCount}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: context.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  // --------------------------------------------------------- support details

  Widget _buildExpiringCard(BuildContext context, List<BloodUnit> units) {
    final now = DateTime.now();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.warning_amber_rounded,
                size: 15,
                color: TabangColors.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Expiring within 7 days',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              StatusPill('${units.length}', tone: Tone.warning, dense: true),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          if (units.isEmpty)
            Text(
              'No units are close to expiry.',
              style: TextStyle(fontSize: 12.5, color: context.textMuted),
            )
          else
            ...units.take(6).map((unit) {
              return Padding(
                padding: const EdgeInsets.only(bottom: TabangSpace.sm),
                child: Row(
                  children: [
                    BloodTypeChip(unit.bloodType, size: 24),
                    const SizedBox(width: TabangSpace.sm),
                    Expanded(
                      child: Text(
                        unit.barcode,
                        style: TextStyle(
                          fontSize: 12,
                          fontFamily: 'monospace',
                          color: context.textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      unit.timeLeft(now),
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: TabangColors.danger,
                      ),
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildOpenRequestsCard(
    BuildContext context,
    List<BloodRequest> requests,
  ) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Open blood requests',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              StatusPill('${requests.length}', tone: Tone.info, dense: true),
              if (widget.onOpenInventory != null)
                IconButton(
                  tooltip: 'Open inventory queue',
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.open_in_new,
                    size: 16,
                    color: context.textMuted,
                  ),
                  onPressed: widget.onOpenInventory,
                ),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          if (requests.isEmpty)
            Text(
              'No open requests.',
              style: TextStyle(fontSize: 12.5, color: context.textMuted),
            )
          else
            ...requests.take(6).map((request) {
              return Padding(
                padding: const EdgeInsets.only(bottom: TabangSpace.sm),
                child: Row(
                  children: [
                    BloodTypeChip(request.bloodType, size: 24),
                    const SizedBox(width: TabangSpace.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            request.patientAlias,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: context.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${request.hospital} · ${request.unitsNeeded} units',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    StatusPill(
                      request.urgency.label,
                      tone: toneForUrgency(request.urgency),
                      dense: true,
                    ),
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

/// The headline score and its four weighted components.
class _ReadinessScore {
  const _ReadinessScore(this.value, this.components);

  final int value;
  final List<_ScoreComponent> components;

  double valueFor(String label) {
    for (final component in components) {
      if (component.label == label) return component.fraction;
    }
    return 0;
  }

  /// Supply coverage and shelf-life are weighted most heavily because they are
  /// the two things a chapter can act on today. Donor capacity is the leading
  /// indicator; request pressure is deliberately inverted (fewer open requests
  /// is better).
  static _ReadinessScore compute({
    required AnalyticsSummary summary,
    required int expiringCount,
  }) {
    final supply = (summary.unitsAvailable / 32).clamp(0.0, 1.0);
    final donors = (summary.activeDonors / 20).clamp(0.0, 1.0);
    final requestPressure = summary.openRequests == 0
        ? 1.0
        : (1 - summary.openRequests / 16).clamp(0.0, 1.0);
    final total = summary.unitsAvailable + expiringCount;
    final shelfLife = total == 0
        ? 1.0
        : (1 - expiringCount / total).clamp(0.0, 1.0);

    final components = [
      _ScoreComponent('Supply coverage', supply, 0.35),
      _ScoreComponent('Donor capacity', donors, 0.25),
      _ScoreComponent('Request pressure', requestPressure, 0.20),
      _ScoreComponent('Shelf-life health', shelfLife, 0.20),
    ];
    final weighted = components.fold<double>(
      0,
      (sum, c) => sum + c.fraction * c.weight,
    );
    return _ReadinessScore((weighted * 100).round(), components);
  }
}

class _ScoreComponent {
  const _ScoreComponent(this.label, this.fraction, this.weight);

  final String label;
  final double fraction;
  final double weight;
}

class _ScoreGaugePainter extends CustomPainter {
  const _ScoreGaugePainter({
    required this.value,
    required this.track,
    required this.color,
  });

  final double value;
  final Color track;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = size.width * 0.085;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: (math.min(size.width, size.height) - stroke) / 2,
    );
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, -math.pi / 2, math.pi * 2, false, trackPaint);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value.clamp(0.0, 1.0),
      false,
      valuePaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreGaugePainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.color != color ||
      oldDelegate.track != track;
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.tone,
    required this.footnote,
    required this.progress,
  });

  final String label;
  final String value;
  final IconData icon;
  final Tone tone;
  final String footnote;
  final double progress;

  Color get _color => switch (tone) {
    Tone.success => TabangColors.success,
    Tone.warning => TabangColors.warning,
    Tone.danger => TabangColors.danger,
    Tone.info => TabangColors.info,
    Tone.brand => TabangColors.crimson,
    Tone.neutral => TabangColors.info,
  };

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _color.withValues(alpha: context.isDark ? 0.18 : 0.10),
                  borderRadius: BorderRadius.circular(TabangRadius.xs),
                ),
                child: Icon(icon, size: 16, color: _color),
              ),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.6,
              height: 1.1,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            footnote,
            style: TextStyle(fontSize: 12, color: context.textMuted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: TabangSpace.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(TabangRadius.pill),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: progress.clamp(0.0, 1.0),
              color: _color,
            ),
          ),
        ],
      ),
    );
  }
}
