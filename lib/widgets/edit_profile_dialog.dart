import 'package:flutter/material.dart';

class EditProfileDialog extends StatefulWidget {
  final String currentName;
  final String currentPhone;
  final String currentBloodType;
  final String currentBarangay;
  final String currentInitials;
  final Function(Map<String, String>) onSave;

  const EditProfileDialog({
    super.key,
    required this.currentName,
    required this.currentPhone,
    required this.currentBloodType,
    required this.currentBarangay,
    required this.currentInitials,
    required this.onSave,
  });

  /// Helper method to display the dialog easily
  static Future<void> show(
      BuildContext context, {
        required String currentName,
        required String currentPhone,
        required String currentBloodType,
        required String currentBarangay,
        required String currentInitials,
        required Function(Map<String, String>) onSave,
      }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => EditProfileDialog(
        currentName: currentName,
        currentPhone: currentPhone,
        currentBloodType: currentBloodType,
        currentBarangay: currentBarangay,
        currentInitials: currentInitials,
        onSave: onSave,
      ),
    );
  }

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late String _selectedBloodType;
  late String _selectedBarangay;

  final List<String> _bloodTypes = ['O+', 'O-', 'A+', 'A-', 'B+', 'B-', 'AB+', 'AB-'];
  final List<String> _barangays = [
    'Zone 1 (Pob.)',
    'Zone 2 (Pob.)',
    'Zone 3 (Pob.)',
    'Kapatagan',
    'Matti',
    'Tres de Mayo',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.currentName);
    _phoneController = TextEditingController(text: widget.currentPhone);
    _selectedBloodType = widget.currentBloodType;
    _selectedBarangay = _barangays.contains(widget.currentBarangay)
        ? widget.currentBarangay
        : _barangays.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialogBg = isDark ? const Color(0xFF212121) : const Color(0xFFF7F7F7);
    final fieldBg = isDark ? const Color(0xFF181818) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade700;
    final borderColor = isDark ? const Color(0xFF383838) : const Color(0xFFD0D0D0);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: dialogBg,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Container(
        width: 440,
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Title
            Text(
              'Edit profile',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 24),

            // Profile Avatar with Camera Badge
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 110,
                    height: 110,
                    decoration: const BoxDecoration(
                      color: Color(0xFFE54B3C),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        widget.currentInitials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                  InkWell(
                    onTap: () {
                      // Image picker logic
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF2E2E2E) : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: borderColor, width: 1.5),
                      ),
                      child: Icon(
                        Icons.camera_alt_outlined,
                        size: 18,
                        color: textColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            // Display Name Input
            _buildCustomTextField(
              controller: _nameController,
              label: 'Display name',
              fieldBg: fieldBg,
              borderColor: borderColor,
              textColor: textColor,
              subtextColor: subtextColor,
            ),
            const SizedBox(height: 14),

            // Contact Number Input
            _buildCustomTextField(
              controller: _phoneController,
              label: 'Contact number',
              fieldBg: fieldBg,
              borderColor: borderColor,
              textColor: textColor,
              subtextColor: subtextColor,
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 14),

            // Blood Type and Barangay Dropdowns
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: _buildDropdownField(
                    label: 'Blood Type',
                    value: _selectedBloodType,
                    items: _bloodTypes,
                    onChanged: (val) => setState(() => _selectedBloodType = val!),
                    fieldBg: fieldBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: _buildDropdownField(
                    label: 'Barangay',
                    value: _selectedBarangay,
                    items: _barangays,
                    onChanged: (val) => setState(() => _selectedBarangay = val!),
                    fieldBg: fieldBg,
                    borderColor: borderColor,
                    textColor: textColor,
                    subtextColor: subtextColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: borderColor, width: 1),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  onPressed: () {
                    widget.onSave({
                      'name': _nameController.text,
                      'phone': _phoneController.text,
                      'bloodType': _selectedBloodType,
                      'barangay': _selectedBarangay,
                    });
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark ? Colors.white : Colors.black,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCustomTextField({
    required TextEditingController controller,
    required String label,
    required Color fieldBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: subtextColor)),
          TextField(
            controller: controller,
            keyboardType: keyboardType,
            style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
            decoration: const InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.only(top: 4, bottom: 2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required Color fieldBg,
    required Color borderColor,
    required Color textColor,
    required Color subtextColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: fieldBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 11, color: subtextColor)),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isDense: true,
              isExpanded: true,
              dropdownColor: fieldBg,
              style: TextStyle(fontSize: 14, color: textColor, fontWeight: FontWeight.w500),
              icon: Icon(Icons.arrow_drop_down, color: subtextColor),
              onChanged: onChanged,
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}