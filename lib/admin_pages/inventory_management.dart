import 'package:flutter/material.dart';
import 'admin_data/blood_bank_service.dart';

class AdminBloodBankPage extends StatefulWidget {
  const AdminBloodBankPage({super.key});

  @override
  State<AdminBloodBankPage> createState() => _AdminBloodBankPageState();
}

class _AdminBloodBankPageState extends State<AdminBloodBankPage> {
  late List<BloodUnit> _inventory;

  // Selected Filters
  BloodType _selectedRecipientType = BloodType.all;
  BloodComponent _selectedComponent = BloodComponent.all;
  String _selectedStatus = 'All';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _inventory = List.from(AdminBloodBankService.initialInventory);
  }

  // ===========================================================================
  // ADMIN ACTIONS (Add Unit, Edit Status, Relocate Unit, Delete Unit)
  // ===========================================================================

  void _showAddUnitDialog() {
    final barcodeController = TextEditingController();
    final bayController = TextEditingController();
    final expiryController = TextEditingController(text: '35 days');

    String selectedType = 'O+';
    BloodComponent selectedComp = BloodComponent.packedRbc;
    String selectedProduct = 'Packed red blood cells';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: const Text('Add New Unit to Inventory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: barcodeController,
                    decoration: const InputDecoration(labelText: 'Unit Barcode (e.g., RBC-9910-O+)', isDense: true),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedType,
                          decoration: const InputDecoration(labelText: 'Blood Group', isDense: true),
                          items: ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'].map((type) {
                            return DropdownMenuItem(value: type, child: Text(type));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setModalState(() => selectedType = val);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: DropdownButtonFormField<BloodComponent>(
                          value: selectedComp,
                          decoration: const InputDecoration(labelText: 'Component', isDense: true),
                          items: const [
                            DropdownMenuItem(value: BloodComponent.packedRbc, child: Text('Packed RBC')),
                            DropdownMenuItem(value: BloodComponent.wholeBlood, child: Text('Whole Blood')),
                            DropdownMenuItem(value: BloodComponent.platelets, child: Text('Platelets')),
                            DropdownMenuItem(value: BloodComponent.plasma, child: Text('Plasma')),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setModalState(() {
                                selectedComp = val;
                                if (val == BloodComponent.packedRbc) selectedProduct = 'Packed red blood cells';
                                if (val == BloodComponent.wholeBlood) selectedProduct = 'Whole blood';
                                if (val == BloodComponent.platelets) selectedProduct = 'Platelets (apheresis)';
                                if (val == BloodComponent.plasma) selectedProduct = 'Fresh frozen plasma';
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bayController,
                    decoration: const InputDecoration(labelText: 'Storage Bay / Unit (e.g., Cold room R-01)', isDense: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: expiryController,
                    decoration: const InputDecoration(labelText: 'Expiration Countdown', isDense: true),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (barcodeController.text.isEmpty || bayController.text.isEmpty) return;

                setState(() {
                  _inventory.insert(
                    0,
                    BloodUnit(
                      barcode: barcodeController.text.trim(),
                      bloodType: selectedType,
                      product: selectedProduct,
                      component: selectedComp,
                      timeLeft: expiryController.text.trim(),
                      storageBay: bayController.text.trim(),
                      status: 'Available',
                    ),
                  );
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unit ${barcodeController.text} added to inventory!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A1C1E), foregroundColor: Colors.white),
              child: const Text('Add Unit'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditUnitModal(BloodUnit unit) {
    String currentStatus = unit.status;
    final bayController = TextEditingController(text: unit.storageBay);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text('Manage Unit: ${unit.barcode}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: 380,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Blood Group: ${unit.bloodType} • ${unit.product}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: currentStatus,
                  decoration: const InputDecoration(labelText: 'Unit Status', isDense: true),
                  items: ['Available', 'Reserved', 'Quarantined', 'Dispatched'].map((status) {
                    return DropdownMenuItem(value: status, child: Text(status));
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setModalState(() => currentStatus = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bayController,
                  decoration: const InputDecoration(labelText: 'Relocate Storage Bay', isDense: true),
                ),
              ],
            ),
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Unit',
              onPressed: () {
                setState(() => _inventory.remove(unit));
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Unit ${unit.barcode} removed from database.')),
                );
              },
            ),
            const Spacer(),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  unit.status = currentStatus;
                  unit.storageBay = bayController.text.trim();
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Updated unit ${unit.barcode} successfully!')),
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF7A1C1E), foregroundColor: Colors.white),
              child: const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  // Compatibility Rule Check
  bool _isCompatible(String donorType, BloodType recipientType) {
    if (recipientType == BloodType.all) return true;
    switch (recipientType) {
      case BloodType.oNeg: return donorType == 'O-';
      case BloodType.oPos: return donorType == 'O-' || donorType == 'O+';
      case BloodType.aNeg: return donorType == 'O-' || donorType == 'A-';
      case BloodType.aPos: return donorType == 'O-' || donorType == 'O+' || donorType == 'A-' || donorType == 'A+';
      case BloodType.bNeg: return donorType == 'O-' || donorType == 'B-';
      case BloodType.bPos: return donorType == 'O-' || donorType == 'O+' || donorType == 'B-' || donorType == 'B+';
      case BloodType.abNeg: return donorType == 'O-' || donorType == 'A-' || donorType == 'B-' || donorType == 'AB-';
      case BloodType.abPos: return true;
      default: return true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final filteredUnits = _inventory.where((unit) {
      final matchesSearch = unit.barcode.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          unit.product.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          unit.storageBay.toLowerCase().contains(_searchQuery.toLowerCase());

      final matchesComponent = _selectedComponent == BloodComponent.all || unit.component == _selectedComponent;
      final matchesStatus = _selectedStatus == 'All' || unit.status == _selectedStatus;
      final matchesCompatibility = _isCompatible(unit.bloodType, _selectedRecipientType);

      return matchesSearch && matchesComponent && matchesStatus && matchesCompatibility;
    }).toList();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Page Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Blood Reserve Inventory Console', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface)),
                    const SizedBox(height: 4),
                    Text('Manage live unit status, intake new blood bags, and reallocate storage bays.', style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  ],
                ),
                ElevatedButton.icon(
                  onPressed: _showAddUnitDialog,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Intake New Unit'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF7A1C1E),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Search & Filters Toolbar
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 40,
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: 'Search barcode, bay...',
                      hintStyle: TextStyle(fontSize: 13, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                      prefixIcon: Icon(Icons.search, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: isDark ? theme.colorScheme.surface : Colors.grey.shade100,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                _buildDropdownFilter<BloodType>(
                  theme: theme,
                  value: _selectedRecipientType,
                  items: const [
                    DropdownMenuItem(value: BloodType.all, child: Text('Recipient: Any Type')),
                    DropdownMenuItem(value: BloodType.oNeg, child: Text('Recipient: O-')),
                    DropdownMenuItem(value: BloodType.oPos, child: Text('Recipient: O+')),
                    DropdownMenuItem(value: BloodType.aNeg, child: Text('Recipient: A-')),
                    DropdownMenuItem(value: BloodType.aPos, child: Text('Recipient: A+')),
                    DropdownMenuItem(value: BloodType.bNeg, child: Text('Recipient: B-')),
                    DropdownMenuItem(value: BloodType.bPos, child: Text('Recipient: B+')),
                    DropdownMenuItem(value: BloodType.abNeg, child: Text('Recipient: AB-')),
                    DropdownMenuItem(value: BloodType.abPos, child: Text('Recipient: AB+')),
                  ],
                  onChanged: (val) { if (val != null) setState(() => _selectedRecipientType = val); },
                ),
                _buildDropdownFilter<BloodComponent>(
                  theme: theme,
                  value: _selectedComponent,
                  items: const [
                    DropdownMenuItem(value: BloodComponent.all, child: Text('All components')),
                    DropdownMenuItem(value: BloodComponent.wholeBlood, child: Text('Whole Blood')),
                    DropdownMenuItem(value: BloodComponent.packedRbc, child: Text('Packed Red Blood Cells')),
                    DropdownMenuItem(value: BloodComponent.platelets, child: Text('Platelets')),
                    DropdownMenuItem(value: BloodComponent.plasma, child: Text('Fresh Frozen Plasma')),
                  ],
                  onChanged: (val) { if (val != null) setState(() => _selectedComponent = val); },
                ),
                _buildDropdownFilter<String>(
                  theme: theme,
                  value: _selectedStatus,
                  items: const [
                    DropdownMenuItem(value: 'All', child: Text('All statuses')),
                    DropdownMenuItem(value: 'Available', child: Text('Available')),
                    DropdownMenuItem(value: 'Reserved', child: Text('Reserved')),
                    DropdownMenuItem(value: 'Quarantined', child: Text('Quarantined')),
                    DropdownMenuItem(value: 'Dispatched', child: Text('Dispatched')),
                  ],
                  onChanged: (val) { if (val != null) setState(() => _selectedStatus = val); },
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Inventory Data Table with Admin Edit Action
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
                  columnSpacing: 24,
                  headingRowHeight: 48,
                  dataRowMaxHeight: 52,
                  headingRowColor: WidgetStateProperty.all(isDark ? theme.colorScheme.surface : Colors.grey.shade50),
                  columns: [
                    _headerColumn('Unit Barcode', theme),
                    _headerColumn('ABO/Rh', theme),
                    _headerColumn('Product Component', theme),
                    _headerColumn('Time Left', theme),
                    _headerColumn('Storage Bay', theme),
                    _headerColumn('Status', theme),
                    _headerColumn('Admin Action', theme),
                  ],
                  rows: filteredUnits.map((unit) {
                    return DataRow(
                      cells: [
                        DataCell(Text(unit.barcode, style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface))),
                        DataCell(Text(unit.bloodType, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface))),
                        DataCell(Text(unit.product, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.8)))),
                        DataCell(Text(unit.timeLeft, style: TextStyle(fontSize: 12, color: unit.timeLeft.contains('hours') ? Colors.orange.shade700 : theme.colorScheme.onSurface.withOpacity(0.7)))),
                        DataCell(Text(unit.storageBay, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.7)))),
                        DataCell(_buildStatusBadge(unit.status)),
                        DataCell(
                          ElevatedButton.icon(
                            onPressed: () => _showEditUnitModal(unit),
                            icon: const Icon(Icons.edit, size: 12),
                            label: const Text('Manage'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7A1C1E),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              textStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.colorScheme.onSurface.withOpacity(0.6)),
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
          icon: Icon(Icons.keyboard_arrow_down, size: 18, color: theme.colorScheme.onSurface.withOpacity(0.5)),
          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
          dropdownColor: theme.cardColor,
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;

    switch (status) {
      case 'Available':
        bgColor = const Color(0xFFE8F5E9);
        textColor = const Color(0xFF2E7D32);
        break;
      case 'Reserved':
        bgColor = const Color(0xFFFFF3E0);
        textColor = const Color(0xFFE65100);
        break;
      case 'Dispatched':
        bgColor = const Color(0xFFE1F5FE);
        textColor = const Color(0xFF0288D1);
        break;
      case 'Quarantined':
      default:
        bgColor = const Color(0xFFFFEBEE);
        textColor = const Color(0xFFC62828);
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Text(status, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor)),
    );
  }
}