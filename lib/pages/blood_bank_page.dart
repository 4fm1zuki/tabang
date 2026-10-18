import 'package:flutter/material.dart';

// Blood Bag Components
enum BloodComponent { all, wholeBlood, packedRbc, platelets, plasma }

// Blood Group Types
enum BloodType { all, oNeg, oPos, aNeg, aPos, bNeg, bPos, abNeg, abPos }

// Inventory Unit Model
class BloodUnit {
  final String barcode;
  final String bloodType;
  final String product;
  final BloodComponent component;
  final String timeLeft;
  final String storageBay;
  final String status;

  BloodUnit({
    required this.barcode,
    required this.bloodType,
    required this.product,
    required this.component,
    required this.timeLeft,
    required this.storageBay,
    required this.status,
  });
}

class BloodBankPage extends StatefulWidget {
  const BloodBankPage({super.key});

  @override
  State<BloodBankPage> createState() => _BloodBankPageState();
}

class _BloodBankPageState extends State<BloodBankPage> {
  // Selected Filters
  BloodType _selectedRecipientType = BloodType.all;
  BloodComponent _selectedComponent = BloodComponent.all;
  String _selectedStatus = 'All';
  String _searchQuery = '';

  // Inventory Data
  final List<BloodUnit> _inventory = [
    BloodUnit(
      barcode: 'RBC-8849-O-',
      bloodType: 'O-',
      product: 'Packed red blood cells',
      component: BloodComponent.packedRbc,
      timeLeft: '18 hours',
      storageBay: 'Cold room R-02 (4 °C)',
      status: 'Available',
    ),
    BloodUnit(
      barcode: 'RBC-8850-O-',
      bloodType: 'O-',
      product: 'Packed red blood cells',
      component: BloodComponent.packedRbc,
      timeLeft: '3 days',
      storageBay: 'Cold room R-02 (4 °C)',
      status: 'Available',
    ),
    BloodUnit(
      barcode: 'PLT-4019-A+',
      bloodType: 'A+',
      product: 'Platelets (apheresis)',
      component: BloodComponent.platelets,
      timeLeft: '48 hours',
      storageBay: 'Agitator A-01 (22 °C)',
      status: 'Available',
    ),
    BloodUnit(
      barcode: 'FFP-7712-B+',
      bloodType: 'B+',
      product: 'Fresh frozen plasma',
      component: BloodComponent.plasma,
      timeLeft: '180 days',
      storageBay: 'Freezer F-03 (-30 °C)',
      status: 'Available',
    ),
    BloodUnit(
      barcode: 'RBC-9014-AB-',
      bloodType: 'AB-',
      product: 'Packed red blood cells',
      component: BloodComponent.packedRbc,
      timeLeft: '14 days',
      storageBay: 'Bay 03 (4 °C)',
      status: 'Reserved',
    ),
    BloodUnit(
      barcode: 'RBC-6612-O+',
      bloodType: 'O+',
      product: 'Packed red blood cells',
      component: BloodComponent.packedRbc,
      timeLeft: '22 days',
      storageBay: 'Cold room R-01 (4 °C)',
      status: 'Available',
    ),
    BloodUnit(
      barcode: 'WB-1092-A-',
      bloodType: 'A-',
      product: 'Whole blood',
      component: BloodComponent.wholeBlood,
      timeLeft: '4 days',
      storageBay: 'Cold room R-03 (4 °C)',
      status: 'Quarantined',
    ),
    BloodUnit(
      barcode: 'RBC-3391-B-',
      bloodType: 'B-',
      product: 'Packed red blood cells',
      component: BloodComponent.packedRbc,
      timeLeft: '28 days',
      storageBay: 'Cold room R-02 (4 °C)',
      status: 'Available',
    ),
    BloodUnit(
      barcode: 'FFP-9912-AB+',
      bloodType: 'AB+',
      product: 'Fresh frozen plasma',
      component: BloodComponent.plasma,
      timeLeft: '160 days',
      storageBay: 'Freezer F-01 (-30 °C)',
      status: 'Available',
    ),
  ];

  // Medical Blood Compatibility Rules (Red Cells/Whole Blood)
  bool _isCompatible(String donorType, BloodType recipientType) {
    if (recipientType == BloodType.all) return true;

    switch (recipientType) {
      case BloodType.oNeg:
        return donorType == 'O-';
      case BloodType.oPos:
        return donorType == 'O-' || donorType == 'O+';
      case BloodType.aNeg:
        return donorType == 'O-' || donorType == 'A-';
      case BloodType.aPos:
        return donorType == 'O-' ||
            donorType == 'O+' ||
            donorType == 'A-' ||
            donorType == 'A+';
      case BloodType.bNeg:
        return donorType == 'O-' || donorType == 'B-';
      case BloodType.bPos:
        return donorType == 'O-' ||
            donorType == 'O+' ||
            donorType == 'B-' ||
            donorType == 'B+';
      case BloodType.abNeg:
        return donorType == 'O-' ||
            donorType == 'A-' ||
            donorType == 'B-' ||
            donorType == 'AB-';
      case BloodType.abPos:
        return true;
      default:
        return true;
    }
  }

  // Operating Hours Status Logic
  bool _isOpenNow() {
    final now = DateTime.now();
    final isWeekend =
        now.weekday == DateTime.saturday || now.weekday == DateTime.sunday;
    final hour = now.hour;

    if (isWeekend) {
      return hour >= 8 && hour < 17; // 8 AM - 5 PM
    } else {
      return hour >= 8 && hour < 20; // 8 AM - 8 PM
    }
  }

  void _showRequestBloodDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Submit Blood Request'),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fill out the patient details below to broadcast an urgent request to compatible donors and local chapter staff.',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Patient Full Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Hospital Name & Ward',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Units Needed (e.g. 2 bags)',
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
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Blood request submitted successfully!')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );
  }

  void _showUnitDetailsDialog(BuildContext context, ThemeData theme, BloodUnit unit) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.verified_outlined, color: Colors.green, size: 22),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Unit Details: ${unit.barcode}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow('Blood Type / ABO:', unit.bloodType, theme),
              _buildDetailRow('Product Component:', unit.product, theme),
              _buildDetailRow('Current Status:', unit.status, theme),
              _buildDetailRow('Storage Location:', unit.storageBay, theme),
              _buildDetailRow('Expiration Countdown:', unit.timeLeft, theme),
              const Divider(height: 24),
              const Text(
                'Safety & Compliance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 6),
              const Text(
                '• Fully screened for transfusion-transmitted infections.\n• Cross-match testing required prior to hospital transfusion.',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Unit ${unit.barcode} added to your request list.')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE53935),
              foregroundColor: Colors.white,
            ),
            child: const Text('Reserve / Select Unit'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
          Text(value, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isOpen = _isOpenNow();

    // Filter Logic
    final filteredUnits = _inventory.where((unit) {
      final matchesSearch = unit.barcode
          .toLowerCase()
          .contains(_searchQuery.toLowerCase()) ||
          unit.product.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          unit.storageBay.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesComponent = _selectedComponent == BloodComponent.all ||
          unit.component == _selectedComponent;

      final matchesStatus =
          _selectedStatus == 'All' || unit.status == _selectedStatus;

      final matchesCompatibility =
      _isCompatible(unit.bloodType, _selectedRecipientType);

      return matchesSearch &&
          matchesComponent &&
          matchesStatus &&
          matchesCompatibility;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chapter Banner Header
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.bloodtype,
                            color: Color(0xFFE53935),
                            size: 28,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              'Philippine Red Cross - Davao del Sur Chapter',
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Chapter Address
                      Row(
                        children: [
                          Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Q943+R5M, Quezon Avenue, Davao - Cotabato Rd, Digos, Davao del Sur',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface
                                    .withOpacity(0.7),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Chapter Operating Hours
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_outlined,
                            size: 16,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Weekdays: 8:00 AM – 8:00 PM  •  Weekends: 8:00 AM – 5:00 PM',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color:
                              theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Live Open/Closed Indicator Badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: isOpen
                                  ? const Color(0xFFE8F5E9)
                                  : const Color(0xFFFFEBEE),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              isOpen ? 'OPEN NOW' : 'CLOSED NOW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: isOpen
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFFC62828),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                ElevatedButton.icon(
                  onPressed: () => _showRequestBloodDialog(context, theme),
                  icon: const Icon(Icons.sos, size: 18),
                  label: const Text('Request Blood'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFE53935),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Filter Bar
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                // Search Input
                SizedBox(
                  width: 240,
                  height: 40,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Unit barcode, storage...',
                      hintStyle: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withOpacity(0.4),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 18,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0),
                      filled: true,
                      fillColor: isDark
                          ? theme.colorScheme.surface
                          : Colors.grey.shade100,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),

                // Recipient Blood Type Compatibility Filter
                _buildDropdownFilter<BloodType>(
                  theme: theme,
                  value: _selectedRecipientType,
                  items: const [
                    DropdownMenuItem(
                      value: BloodType.all,
                      child: Text('Recipient: Any Type'),
                    ),
                    DropdownMenuItem(
                      value: BloodType.oNeg,
                      child: Text('Recipient: O-'),
                    ),
                    DropdownMenuItem(
                      value: BloodType.oPos,
                      child: Text('Recipient: O+'),
                    ),
                    DropdownMenuItem(
                      value: BloodType.aNeg,
                      child: Text('Recipient: A-'),
                    ),
                    DropdownMenuItem(
                      value: BloodType.aPos,
                      child: Text('Recipient: A+'),
                    ),
                    DropdownMenuItem(
                      value: BloodType.bNeg,
                      child: Text('Recipient: B-'),
                    ),
                    DropdownMenuItem(
                      value: BloodType.bPos,
                      child: Text('Recipient: B+'),
                    ),
                    DropdownMenuItem(
                      value: BloodType.abNeg,
                      child: Text('Recipient: AB-'),
                    ),
                    DropdownMenuItem(
                      value: BloodType.abPos,
                      child: Text('Recipient: AB+'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) {
                      setState(() => _selectedRecipientType = val);
                    }
                  },
                ),

                // Component Filter
                _buildDropdownFilter<BloodComponent>(
                  theme: theme,
                  value: _selectedComponent,
                  items: const [
                    DropdownMenuItem(
                      value: BloodComponent.all,
                      child: Text('All components'),
                    ),
                    DropdownMenuItem(
                      value: BloodComponent.wholeBlood,
                      child: Text('Whole Blood'),
                    ),
                    DropdownMenuItem(
                      value: BloodComponent.packedRbc,
                      child: Text('Packed Red Blood Cells'),
                    ),
                    DropdownMenuItem(
                      value: BloodComponent.platelets,
                      child: Text('Platelets'),
                    ),
                    DropdownMenuItem(
                      value: BloodComponent.plasma,
                      child: Text('Fresh Frozen Plasma'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedComponent = val);
                  },
                ),

                // Status Filter
                _buildDropdownFilter<String>(
                  theme: theme,
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(
                      value: 'All',
                      child: Text('All statuses'),
                    ),
                    DropdownMenuItem(
                      value: 'Available',
                      child: Text('Available'),
                    ),
                    DropdownMenuItem(
                      value: 'Reserved',
                      child: Text('Reserved'),
                    ),
                    DropdownMenuItem(
                      value: 'Quarantined',
                      child: Text('Quarantined'),
                    ),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedStatus = val);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Inventory Data Table
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: theme.dividerColor.withOpacity(0.15),
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: DataTable(
                  horizontalMargin: 20,
                  columnSpacing: 24,
                  headingRowHeight: 48,
                  dataRowMaxHeight: 52,
                  headingRowColor: WidgetStateProperty.all(
                    isDark
                        ? theme.colorScheme.surface
                        : Colors.grey.shade50,
                  ),
                  columns: [
                    _headerColumn('Unit Barcode', theme),
                    _headerColumn('ABO/Rh', theme),
                    _headerColumn('Product Component', theme),
                    _headerColumn('Time Left', theme),
                    _headerColumn('Storage Bay', theme),
                    _headerColumn('Status', theme),
                    _headerColumn('', theme),
                  ],
                  rows: filteredUnits.map((unit) {
                    return DataRow(
                      cells: [
                        DataCell(
                          Text(
                            unit.barcode,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            unit.bloodType,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            unit.product,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.8),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            unit.timeLeft,
                            style: TextStyle(
                              fontSize: 12,
                              color: unit.timeLeft.contains('hours')
                                  ? Colors.orange.shade700
                                  : theme.colorScheme.onSurface
                                  .withOpacity(0.7),
                            ),
                          ),
                        ),
                        DataCell(
                          Text(
                            unit.storageBay,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface
                                  .withOpacity(0.7),
                            ),
                          ),
                        ),
                        DataCell(_buildStatusBadge(unit.status)),
                        DataCell(
                          InkWell(
                            onTap: () => _showUnitDetailsDialog(context, theme, unit),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Inspect',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.primary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.arrow_forward,
                                  size: 14,
                                  color: theme.colorScheme.primary,
                                ),
                              ],
                            ),
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
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: theme.colorScheme.onSurface.withOpacity(0.6),
        ),
      ),
    );
  }

  Widget _buildDropdownFilter<T>({
    required ThemeData theme,
    required T value,
    required List<DropdownMenuItem<T>> items,
    required ValueChanged<T?> onChanged,
  }) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          items: items,
          onChanged: onChanged,
          icon: Icon(
            Icons.keyboard_arrow_down,
            size: 18,
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
          style: TextStyle(
            fontSize: 12,
            color: theme.colorScheme.onSurface,
          ),
          dropdownColor: theme.cardColor,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    IconData icon;

    switch (status) {
      case 'Available':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        icon = Icons.check_circle_outline;
        break;
      case 'Reserved':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        icon = Icons.access_time;
        break;
      case 'Quarantined':
      default:
        bgColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFC62828);
        icon = Icons.warning_amber_rounded;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: textColor),
          const SizedBox(width: 4),
          Text(
            status,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}