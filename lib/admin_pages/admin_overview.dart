import 'package:flutter/material.dart';
import 'admin_data/admin_data_models.dart';

class AdminOverviewPage extends StatefulWidget {
  const AdminOverviewPage({super.key});

  @override
  State<AdminOverviewPage> createState() => _AdminOverviewPageState();
}

class _AdminOverviewPageState extends State<AdminOverviewPage> {
  late AnalyticsSummary _summary;
  late List<BloodTypeStat> _bloodTypeStats;
  late List<BarangayStat> _barangayStats;
  late List<BloodDriveInfo> _bloodDrives;

  @override
  void initState() {
    super.initState();
    // Load Dummy Analytics Data
    _summary = AdminAnalyticsRepository.getSummaryData();
    _bloodTypeStats = AdminAnalyticsRepository.getBloodTypeStats();
    _barangayStats = AdminAnalyticsRepository.getBarangayStats();
    _bloodDrives = AdminAnalyticsRepository.getBloodDrives();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Page Header
            _buildHeader(theme),
            const SizedBox(height: 24),

            // Top Quick Stat Metrics Grid
            _buildStatCardsGrid(theme),
            const SizedBox(height: 28),

            // Middle Section: Blood Type Analytics & Top Barangays Split View
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Blood Type Donated vs Requested Table/Bars
                Expanded(
                  flex: 6,
                  child: _buildBloodTypeAnalyticsCard(theme, isDark),
                ),
                const SizedBox(width: 20),

                // Top Donating Barangays List
                Expanded(
                  flex: 4,
                  child: _buildBarangayDistributionCard(theme, isDark),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Bottom Section: Active Blood Letting Drives
            _buildBloodDrivesCard(theme, isDark),
          ],
        ),
      ),
    );
  }

  // Header Title with Action Indicator
  Widget _buildHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Analytics Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Live metrics on blood supply, donor engagement, and local barangay statistics.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF7A1C1E).withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF7A1C1E).withOpacity(0.3)),
          ),
          child: const Row(
            children: [
              CircleAvatar(radius: 4, backgroundColor: Color(0xFF2E7D32)),
              SizedBox(width: 8),
              Text(
                'Live Data Engine',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7A1C1E),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Row of 4 KPI Metric Cards
  Widget _buildStatCardsGrid(ThemeData theme) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 48) / 4;
        return Row(
          children: [
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                theme: theme,
                title: 'Donations Today',
                value: '${_summary.totalDonationsToday}',
                subtitle: 'Units received today',
                icon: Icons.today_rounded,
                iconColor: Colors.redAccent,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                theme: theme,
                title: 'Donations This Month',
                value: '${_summary.totalDonationsThisMonth}',
                subtitle: 'Monthly accumulated units',
                icon: Icons.calendar_month_rounded,
                iconColor: Colors.orangeAccent,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                theme: theme,
                title: 'Registered Users',
                value: '${_summary.totalRegisteredUsers}',
                subtitle: '${_summary.totalActiveDonors} active donors',
                icon: Icons.people_alt_rounded,
                iconColor: Colors.blueAccent,
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: cardWidth,
              child: _buildMetricTile(
                theme: theme,
                title: 'Blood Letting Drives',
                value: '${_summary.activeBloodDrives}',
                subtitle: 'Upcoming scheduled drives',
                icon: Icons.event_available_rounded,
                iconColor: Colors.green,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildMetricTile({
    required ThemeData theme,
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withOpacity(0.6),
                ),
              ),
              Icon(icon, size: 20, color: iconColor),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10.5,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  // Card 1: Blood Type Donated vs Requested Ratio
  Widget _buildBloodTypeAnalyticsCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Most Donated vs. Requested Blood Types',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              Row(
                children: [
                  _legendDot(const Color(0xFF7A1C1E), 'Donated'),
                  const SizedBox(width: 12),
                  _legendDot(Colors.blueGrey, 'Requested'),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          ..._bloodTypeStats.map((stat) {
            final maxVal = 180;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Type ${stat.bloodType}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        '${stat.totalDonated} Donated / ${stat.totalRequested} Requested',
                        style: TextStyle(
                          fontSize: 10.5,
                          color: theme.colorScheme.onSurface.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      Container(
                        height: 8,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: theme.dividerColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Donated Progress Bar
                      FractionallySizedBox(
                        widthFactor: (stat.totalDonated / maxVal).clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFF7A1C1E),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _legendDot(Color color, String label) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w500)),
      ],
    );
  }

  // Card 2: Most Frequently Donated Barangays
  Widget _buildBarangayDistributionCard(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Donating Barangays',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Highest donor participation by area',
            style: TextStyle(
              fontSize: 11,
              color: theme.colorScheme.onSurface.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 20),
          ..._barangayStats.map((bgy) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: const Color(0xFF7A1C1E).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Icon(Icons.location_on, size: 16, color: Color(0xFF7A1C1E)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bgy.barangayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${bgy.donationCount} total donations',
                          style: TextStyle(
                            fontSize: 10.5,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${(bgy.percentage * 100).toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7A1C1E),
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

  // Card 3: Blood Letting Drives Table
  Widget _buildBloodDrivesCard(ThemeData theme, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Active & Scheduled Blood Letting Drives',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add, size: 14),
                label: const Text('Add New Drive'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF7A1C1E),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(3),
              1: FlexColumnWidth(3),
              2: FlexColumnWidth(2),
              3: FlexColumnWidth(1.5),
              4: FlexColumnWidth(1),
            },
            children: [
              TableRow(
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.2))),
                ),
                children: const [
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('DRIVE TITLE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('LOCATION', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('DATE & TIME', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('EXPECTED DONORS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                  Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('STATUS', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey))),
                ],
              ),
              ..._bloodDrives.map((drive) {
                return TableRow(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: theme.dividerColor.withOpacity(0.08))),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(drive.title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(drive.location, style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withOpacity(0.7))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(drive.date, style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withOpacity(0.7))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text('${drive.expectedDonors} Target', style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withOpacity(0.7))),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          drive.status,
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                    ),
                  ],
                );
              }),
            ],
          ),
        ],
      ),
    );
  }
}