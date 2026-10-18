import 'package:flutter/material.dart';

class AdminSettingsPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const AdminSettingsPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  // System Emergency Switch
  bool _emergencyBroadcastMode = false;
  bool _autoVerifyDonorCards = false;

  // Moderation Rules
  bool _autoFlagPaymentKeywords = true;
  bool _restrictUnverifiedDonorChat = true;
  final _keywordsController = TextEditingController(
    text: 'payment, GCash, price, per bag, sell, cash upfront',
  );

  // Inventory Thresholds
  double _criticalStockThreshold = 10; // Minimum units before alert
  double _expiryAlertDays = 7; // Days before blood bag expiry warning

  @override
  void dispose() {
    _keywordsController.dispose();
    super.dispose();
  }

  void _saveSettings() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('System configurations updated successfully!'),
        backgroundColor: Color(0xFF2E7D32),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Page Header
            _buildPageHeader(theme),
            const SizedBox(height: 24),

            // Settings Sections Layout
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Column: System & Moderation Settings
                Expanded(
                  flex: 6,
                  child: Column(
                    children: [
                      _buildEmergencyModeCard(theme),
                      const SizedBox(height: 20),
                      _buildModerationSettingsCard(theme),
                      const SizedBox(height: 20),
                      _buildInventoryRulesCard(theme),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // Right Column: Appearance & Security
                Expanded(
                  flex: 4,
                  child: Column(
                    children: [
                      _buildAppearanceCard(theme, isDark),
                      const SizedBox(height: 20),
                      _buildAdminSecurityCard(theme),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageHeader(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'System Settings & Parameters',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Configure global parameters, emergency broadcast flags, chat moderation filters, and security controls.',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.6),
              ),
            ),
          ],
        ),
        ElevatedButton.icon(
          onPressed: _saveSettings,
          icon: const Icon(Icons.save_rounded, size: 16),
          label: const Text('Save Changes'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF7A1C1E),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // 1. EMERGENCY CRISIS BROADCAST MODE
  // ===========================================================================
  Widget _buildEmergencyModeCard(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _emergencyBroadcastMode
              ? Colors.red.withOpacity(0.5)
              : theme.dividerColor.withOpacity(0.15),
          width: _emergencyBroadcastMode ? 1.5 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Color(0xFF7A1C1E), size: 22),
              const SizedBox(width: 8),
              Text(
                'Emergency Crisis Mode',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Enabling Emergency Broadcast Mode will display urgent alert headers across all active donor mobile feeds in Digos City.',
            style: TextStyle(
              fontSize: 11.5,
              color: theme.colorScheme.onSurface.withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text(
              'Activate City-Wide Urgent Blood Shortage Banner',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              _emergencyBroadcastMode ? 'Active: All donors see critical supply alerts.' : 'Inactive: Standard operation.',
              style: TextStyle(
                fontSize: 11,
                color: _emergencyBroadcastMode ? Colors.red : theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            value: _emergencyBroadcastMode,
            activeColor: const Color(0xFF7A1C1E),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) {
              setState(() => _emergencyBroadcastMode = val);
            },
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 2. AUTOMATED CHAT MODERATION RULES
  // ===========================================================================
  Widget _buildModerationSettingsCard(ThemeData theme) {
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
            children: [
              const Icon(Icons.security, color: Color(0xFF7A1C1E), size: 20),
              const SizedBox(width: 8),
              Text(
                'Automated Chat & Safety Rules',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          SwitchListTile(
            title: const Text('Auto-Flag Paid Blood Solicitation', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            subtitle: const Text('Automatically flag messages containing money or payment keywords.', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
            value: _autoFlagPaymentKeywords,
            activeColor: const Color(0xFF7A1C1E),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _autoFlagPaymentKeywords = val),
          ),
          const SizedBox(height: 10),

          TextField(
            controller: _keywordsController,
            style: const TextStyle(fontSize: 12),
            decoration: InputDecoration(
              labelText: 'Filtered Keyword Dictionary (comma-separated)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),

          SwitchListTile(
            title: const Text('Restrict Unverified Donors from Direct Chat', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
            subtitle: const Text('Require donor blood card approval before allowing direct message contact.', style: TextStyle(fontSize: 10.5, color: Colors.grey)),
            value: _restrictUnverifiedDonorChat,
            activeColor: const Color(0xFF7A1C1E),
            contentPadding: EdgeInsets.zero,
            onChanged: (val) => setState(() => _restrictUnverifiedDonorChat = val),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 3. INVENTORY ALERT THRESHOLDS
  // ===========================================================================
  Widget _buildInventoryRulesCard(ThemeData theme) {
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
            children: [
              const Icon(Icons.tune_rounded, color: Color(0xFF7A1C1E), size: 20),
              const SizedBox(width: 8),
              Text(
                'Inventory Alert Thresholds',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Critical Stock Alert Level: ${_criticalStockThreshold.round()} bags',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _criticalStockThreshold,
            min: 1,
            max: 30,
            divisions: 29,
            activeColor: const Color(0xFF7A1C1E),
            label: '${_criticalStockThreshold.round()} bags',
            onChanged: (val) => setState(() => _criticalStockThreshold = val),
          ),
          const SizedBox(height: 12),

          Text(
            'Bag Expiration Warning: ${_expiryAlertDays.round()} days before expiry',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
          ),
          Slider(
            value: _expiryAlertDays,
            min: 1,
            max: 14,
            divisions: 13,
            activeColor: const Color(0xFF7A1C1E),
            label: '${_expiryAlertDays.round()} days',
            onChanged: (val) => setState(() => _expiryAlertDays = val),
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 4. APPEARANCE / THEME TOGGLE
  // ===========================================================================
  Widget _buildAppearanceCard(ThemeData theme, bool isDark) {
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
            'Dashboard Theme & Display',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Dark Mode Interface', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              Switch(
                value: isDark,
                activeColor: const Color(0xFF7A1C1E),
                onChanged: (val) {
                  widget.onThemeChanged(val ? ThemeMode.dark : ThemeMode.light);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // 5. ADMIN ACCOUNT SECURITY
  // ===========================================================================
  Widget _buildAdminSecurityCard(ThemeData theme) {
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
            'Admin Security & Credentials',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 14),

          const TextField(
            obscureText: true,
            style: TextStyle(fontSize: 12),
            decoration: InputDecoration(
              labelText: 'Current Admin Password',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 12),
          const TextField(
            obscureText: true,
            style: TextStyle(fontSize: 12),
            decoration: InputDecoration(
              labelText: 'New Password',
              border: OutlineInputBorder(),
              isDense: true,
            ),
          ),
          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Admin credentials updated.')),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2C2C2C),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
              child: const Text('Update Password', style: TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }
}