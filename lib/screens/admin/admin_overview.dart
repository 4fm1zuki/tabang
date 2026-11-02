import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';

/// Administrative analytics overview.
///
/// Every figure here is computed from the repository by
/// [TabangRepository.summary] and friends, so the numbers always agree with
/// the tables on the other admin pages. The previous build showed hardcoded
/// literals under a badge reading "Live Data Engine"; the badge now says what
/// the data actually is.
class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key});

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

  @override
  Widget build(BuildContext context) {
    final summary = _repo.summary();
    final typeStats = _repo.bloodTypeStats();
    final barangayStats = _repo.barangayStats();
    final expiring = _repo.expiringSoon(days: 7);
    final openRequests = _repo.openRequests;

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          PageHeader(
            title: 'System overview',
            subtitle:
                'Blood supply, donor engagement and barangay statistics for Digos City.',
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
                    const Icon(Icons.science_outlined,
                        size: 12, color: TabangColors.info),
                    const SizedBox(width: 5),
                    Text(
                      'SIMULATED DATA',
                      style: TextStyle(
                        fontSize: 9.5,
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
          const SizedBox(height: TabangSpace.xl),

          // KPI row
          LayoutBuilder(
            builder: (context, constraints) {
              // Two tiles on phones, four from small-tablet width up. A fixed
              // four-column split turned each label into a vertical sliver.
              final columns = constraints.maxWidth < 560
                  ? 2
                  : constraints.maxWidth < 900
                      ? 3
                      : 4;
              final width =
                  (constraints.maxWidth - TabangSpace.md * (columns - 1)) /
                      columns;
              return Wrap(
                spacing: TabangSpace.md,
                runSpacing: TabangSpace.md,
                children: [
                  SizedBox(
                    width: width,
                    child: MetricTile(
                      label: 'Units available',
                      value: '${summary.unitsAvailable}',
                      icon: Icons.inventory_2_outlined,
                      tone: Tone.brand,
                      footnote: 'Across all components',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: MetricTile(
                      label: 'Active donors',
                      value: '${summary.activeDonors}',
                      icon: Icons.people_outline,
                      tone: Tone.success,
                      footnote: 'Eligible right now',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: MetricTile(
                      label: 'Open requests',
                      value: '${summary.openRequests}',
                      icon: Icons.campaign_outlined,
                      tone: summary.openRequests > 0 ? Tone.warning : Tone.neutral,
                      footnote: 'Awaiting fulfilment',
                    ),
                  ),
                  SizedBox(
                    width: width,
                    child: MetricTile(
                      label: 'Registered users',
                      value: '${summary.registeredUsers}',
                      icon: Icons.badge_outlined,
                      tone: Tone.info,
                      footnote: '${summary.donationsThisMonth} donations this month',
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: TabangSpace.xl),

          // Blood type balance + barangay distribution
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

          // Expiring units + open requests
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked = constraints.maxWidth < 1000;
              final expiringCard = _buildExpiringCard(context, expiring);
              final requestsCard = _buildOpenRequestsCard(context, openRequests);

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
        ],
      ),
    );
  }

  Widget _buildBloodTypeCard(
    BuildContext context,
    List<BloodTypeStat> stats,
  ) {
    final maxValue = stats.fold<int>(
      1,
      (m, s) => s.donated > m ? s.donated : (s.requested > m ? s.requested : m),
    );

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'Donations vs. requests by blood type',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textColor,
                ),
              ),
              const Spacer(),
              _legendDot(context, TabangColors.crimson, 'Donated'),
              const SizedBox(width: TabangSpace.md),
              _legendDot(context, TabangColors.info, 'Requested'),
            ],
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
                        fontSize: 10.5,
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
                      stat.balance >= 0 ? '+${stat.balance}' : '${stat.balance}',
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
        Text(
          label,
          style: TextStyle(fontSize: 9.5, color: context.textMuted),
        ),
      ],
    );
  }

  Widget _buildBarangayCard(
    BuildContext context,
    List<BarangayStat> stats,
  ) {
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
            'By recorded donation count',
            style: TextStyle(fontSize: 10.5, color: context.textMuted),
          ),
          const SizedBox(height: TabangSpace.lg),
          if (top.isEmpty)
            Text(
              'No donation records yet.',
              style: TextStyle(fontSize: 11.5, color: context.textMuted),
            )
          else
            ...top.map((stat) {
              return Padding(
                padding: const EdgeInsets.only(bottom: TabangSpace.sm),
                child: Row(
                  children: [
                    SizedBox(
                      width: 92,
                      child: Text(
                        stat.barangay,
                        style: TextStyle(
                          fontSize: 11,
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
                      ),
                    ),
                    const SizedBox(width: TabangSpace.sm),
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${stat.donationCount}',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 10.5,
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

  Widget _buildExpiringCard(BuildContext context, List<BloodUnit> units) {
    final now = DateTime.now();

    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 15, color: TabangColors.warning),
              const SizedBox(width: 6),
              Text(
                'Expiring within 7 days',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textColor,
                ),
              ),
              const Spacer(),
              StatusPill('${units.length}', tone: Tone.warning, dense: true),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          if (units.isEmpty)
            Text(
              'No units are close to expiry.',
              style: TextStyle(fontSize: 11.5, color: context.textMuted),
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
                          fontSize: 11,
                          fontFamily: 'monospace',
                          color: context.textColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      unit.timeLeft(now),
                      style: const TextStyle(
                        fontSize: 10.5,
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
              Text(
                'Open blood requests',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: context.textColor,
                ),
              ),
              const Spacer(),
              StatusPill('${requests.length}', tone: Tone.info, dense: true),
            ],
          ),
          const SizedBox(height: TabangSpace.md),
          if (requests.isEmpty)
            Text(
              'No open requests.',
              style: TextStyle(fontSize: 11.5, color: context.textMuted),
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
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: context.textColor,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            '${request.hospital} · ${request.unitsNeeded} units',
                            style: TextStyle(
                              fontSize: 10,
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
