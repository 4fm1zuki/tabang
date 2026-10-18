import 'package:flutter/material.dart';
import 'admin_data/user_management_service.dart';

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  late List<AppUser> _users;
  String _selectedFilter = 'ALL';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _users = UserManagementService.getInitialUsers();
  }

  // ===========================================================================
  // 1. BLOOD CARD VERIFICATION MODAL
  // ===========================================================================
  void _showBloodCardVerificationModal(AppUser user) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Verify Blood Card: ${user.fullName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 420,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'User Email: ${user.email} • Blood Type: ${user.bloodType}',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),

              // Blood Card Image Container
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  user.bloodCardUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 180,
                      color: Colors.grey.shade300,
                      alignment: Alignment.center,
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.badge_outlined, size: 40, color: Colors.grey),
                          SizedBox(height: 6),
                          Text('No blood card uploaded', style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Verify if the uploaded blood donor card matches the declared blood type and user identity.',
                style: TextStyle(fontSize: 11.5, color: Colors.black87),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          if (user.status == AccountStatus.unverified)
            ElevatedButton(
              onPressed: () {
                setState(() => user.status = AccountStatus.verified);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${user.fullName} is now VERIFIED!'),
                    backgroundColor: const Color(0xFF2E7D32),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
              ),
              child: const Text('Approve & Verify User'),
            ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. WARNING / RED FLAG MODAL
  // ===========================================================================
  void _showAddWarningModal(AppUser user) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Issue Warning: ${user.fullName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Current Warnings: ${user.warningCount}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.orange),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: reasonController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Reason for Warning / Red Flag',
                  hintText: 'e.g., Unresponsive to emergency blood request, misconduct in chat...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (reasonController.text.trim().isEmpty) return;

              setState(() {
                user.warningCount += 1;
                if (user.status != AccountStatus.suspended) {
                  user.status = AccountStatus.warned;
                }
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Warning issued to ${user.fullName}. Total: ${user.warningCount}')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade800,
              foregroundColor: Colors.white,
            ),
            child: const Text('Issue Warning'),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. SUSPENSION ENFORCEMENT MODAL
  // ===========================================================================
  void _showSuspensionModal(AppUser user) {
    final reasonController = TextEditingController(text: user.suspensionReason ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          user.status == AccountStatus.suspended
              ? 'Lift Suspension: ${user.fullName}'
              : 'Suspend Account: ${user.fullName}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (user.status != AccountStatus.suspended) ...[
                const Text(
                  'Suspending this user will restrict them from responding to blood requests, booking donations, or chatting with recipients.',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Suspension Reason',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    isDense: true,
                  ),
                ),
              ] else ...[
                Text(
                  'Current Reason: ${user.suspensionReason ?? "N/A"}',
                  style: const TextStyle(fontSize: 12),
                ),
                const SizedBox(height: 8),
                const Text('Are you sure you want to lift the suspension for this account?'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                if (user.status == AccountStatus.suspended) {
                  user.status = AccountStatus.verified;
                  user.suspensionReason = null;
                } else {
                  user.status = AccountStatus.suspended;
                  user.suspensionReason = reasonController.text.trim().isEmpty
                      ? 'Policy Violation'
                      : reasonController.text.trim();
                }
              });

              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    user.status == AccountStatus.suspended
                        ? '${user.fullName} has been SUSPENDED.'
                        : 'Suspension lifted for ${user.fullName}.',
                  ),
                  backgroundColor: user.status == AccountStatus.suspended
                      ? const Color(0xFFC62828)
                      : const Color(0xFF2E7D32),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: user.status == AccountStatus.suspended
                  ? const Color(0xFF2E7D32)
                  : const Color(0xFFC62828),
              foregroundColor: Colors.white,
            ),
            child: Text(user.status == AccountStatus.suspended ? 'Lift Suspension' : 'Confirm Suspension'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Filter Logic
    final filteredUsers = _users.where((user) {
      final matchesSearch = user.fullName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.alias.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          user.barangay.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesFilter = _selectedFilter == 'ALL' ||
          (_selectedFilter == 'UNVERIFIED' && user.status == AccountStatus.unverified) ||
          (_selectedFilter == 'VERIFIED' && user.status == AccountStatus.verified) ||
          (_selectedFilter == 'WARNED' && user.status == AccountStatus.warned) ||
          (_selectedFilter == 'SUSPENDED' && user.status == AccountStatus.suspended);

      return matchesSearch && matchesFilter;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Title
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'User Management Console',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Verify donor blood cards, issue red flag warnings, and enforce account suspensions.',
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search and Filter Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SizedBox(
                  width: 280,
                  height: 40,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search name, email, barangay...',
                      hintStyle: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                      prefixIcon: Icon(Icons.search, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: isDark ? theme.colorScheme.surface : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                Row(
                  children: [
                    Text('Filter Status: ', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface)),
                    const SizedBox(width: 8),
                    DropdownButton<String>(
                      value: _selectedFilter,
                      style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                      underline: const SizedBox.shrink(),
                      items: ['ALL', 'UNVERIFIED', 'VERIFIED', 'WARNED', 'SUSPENDED'].map((f) {
                        return DropdownMenuItem(value: f, child: Text(f));
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) setState(() => _selectedFilter = val);
                      },
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),

            // User Management Data Table
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withOpacity(0.15)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DataTable(
                  horizontalMargin: 20,
                  columnSpacing: 20,
                  headingRowHeight: 48,
                  dataRowMaxHeight: 56,
                  headingRowColor: WidgetStateProperty.all(isDark ? theme.colorScheme.surface : Colors.grey.shade50),
                  columns: [
                    _headerColumn('User Info', theme),
                    _headerColumn('Blood Type', theme),
                    _headerColumn('Barangay', theme),
                    _headerColumn('Account Status', theme),
                    _headerColumn('Red Flags', theme),
                    _headerColumn('Blood Card', theme),
                    _headerColumn('Admin Actions', theme),
                  ],
                  rows: filteredUsers.map((user) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(user.fullName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                              Text('${user.alias} • ${user.email}', style: TextStyle(fontSize: 10.5, color: theme.colorScheme.onSurface.withOpacity(0.5))),
                            ],
                          ),
                        ),
                        DataCell(Text(user.bloodType, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF7A1C1E)))),
                        DataCell(Text(user.barangay, style: TextStyle(fontSize: 11.5, color: theme.colorScheme.onSurface.withOpacity(0.8)))),
                        DataCell(_buildStatusBadge(user.status)),
                        DataCell(
                          Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text('${user.warningCount}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                        DataCell(
                          ElevatedButton.icon(
                            onPressed: () => _showBloodCardVerificationModal(user),
                            icon: const Icon(Icons.badge_outlined, size: 12),
                            label: Text(user.status == AccountStatus.unverified ? 'Verify Card' : 'View Card'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: user.status == AccountStatus.unverified ? const Color(0xFF7A1C1E) : Colors.grey.shade700,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              textStyle: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                          ),
                        ),
                        DataCell(
                          Row(
                            children: [
                              IconButton(
                                icon: const Icon(Icons.add_alert_outlined, color: Colors.orange, size: 20),
                                tooltip: 'Add Warning / Red Flag',
                                onPressed: () => _showAddWarningModal(user),
                              ),
                              IconButton(
                                icon: Icon(
                                  user.status == AccountStatus.suspended ? Icons.lock_open : Icons.block,
                                  color: user.status == AccountStatus.suspended ? Colors.green : Colors.red,
                                  size: 20,
                                ),
                                tooltip: user.status == AccountStatus.suspended ? 'Lift Suspension' : 'Suspend User',
                                onPressed: () => _showSuspensionModal(user),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  DataColumn _headerColumn(String label, ThemeData theme) {
    return DataColumn(
      label: Text(
        label,
        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.6)),
      ),
    );
  }

  Widget _buildStatusBadge(AccountStatus status) {
    Color color;
    String label;

    switch (status) {
      case AccountStatus.verified:
        color = const Color(0xFF2E7D32);
        label = 'VERIFIED';
        break;
      case AccountStatus.warned:
        color = Colors.orange.shade800;
        label = 'WARNED';
        break;
      case AccountStatus.suspended:
        color = const Color(0xFFC62828);
        label = 'SUSPENDED';
        break;
      case AccountStatus.unverified:
      default:
        color = Colors.blueGrey;
        label = 'UNVERIFIED';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
      child: Text(label, style: TextStyle(color: color, fontSize: 9.5, fontWeight: FontWeight.bold)),
    );
  }
}