import 'package:flutter/material.dart';
import '../widgets/edit_profile_dialog.dart';

class ProfilePage extends StatefulWidget {
  final bool isDark;

  const ProfilePage({super.key, required this.isDark});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  // User State
  String displayName = "Iverson D. Briones";
  String phone = "+63 912 345 6789";
  String bloodType = "O+";
  String barangay = "Zone 1 (Pob.)";
  String initials = "IB";
  bool isAvailableForDonation = true;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final cardBg = widget.isDark ? const Color(0xFF242424) : Colors.white;
    final borderColor = widget.isDark ? const Color(0xFF383838) : const Color(0xFFE0E0E0);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==========================================
            // HEADER
            // ==========================================
            Text(
              'Profile',
              style: TextStyle(
                fontFamily: 'Georgia',
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 20),

            // ==========================================
            // MAIN HERO PROFILE CARD
            // ==========================================
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFF4A1212),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        initials,
                        style: const TextStyle(
                          color: Color(0xFFD32F2F),
                          fontWeight: FontWeight.bold,
                          fontSize: 26,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 20),

                  // Name & Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'briones.iverson@guest.com',
                          style: TextStyle(
                            fontSize: 13,
                            color: textColor.withOpacity(0.6),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFD32F2F).withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Blood Type: $bloodType',
                            style: const TextStyle(
                              color: Color(0xFFD32F2F),
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Edit Button
                  OutlinedButton.icon(
                    onPressed: _openEditModal,
                    icon: const Icon(Icons.edit_outlined, size: 16),
                    label: const Text('Edit Profile'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: textColor,
                      side: BorderSide(color: borderColor),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==========================================
            // STATS ROW
            // ==========================================
            Row(
              children: [
                _buildStatCard('Total Donations', '4', Icons.volunteer_activism, cardBg, borderColor, textColor),
                const SizedBox(width: 16),
                _buildStatCard('Last Donated', 'Aug 14, 2025', Icons.calendar_today_outlined, cardBg, borderColor, textColor),
                const SizedBox(width: 16),
                _buildStatCard('Status', isAvailableForDonation ? 'Eligible' : 'Unavailable', Icons.verified_user_outlined, cardBg, borderColor, textColor),
              ],
            ),

            const SizedBox(height: 28),

            // ==========================================
            // CONTACT & LOCATION DETAILS
            // ==========================================
            _buildSectionTitle('Contact & Location Details', textColor),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  _buildListTile(Icons.phone_outlined, 'Contact Number', phone, textColor, borderColor),
                  _buildListTile(Icons.location_on_outlined, 'Barangay / Location', '$barangay, Digos City', textColor, borderColor),
                  SwitchListTile(
                    secondary: Icon(Icons.event_available_outlined, color: textColor.withOpacity(0.7)),
                    title: Text('Available for Emergency Donation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
                    subtitle: Text('Allow nearby hospitals to see your donor availability', style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.55))),
                    value: isAvailableForDonation,
                    activeColor: const Color(0xFFD32F2F),
                    onChanged: (val) {
                      setState(() {
                        isAvailableForDonation = val;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ==========================================
            // ACCOUNT SETTINGS & ACTIONS
            // ==========================================
            _buildSectionTitle('Account Actions', textColor),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Colors.blueAccent),
                    title: Text('Edit Profile Details', style: TextStyle(color: textColor, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: _openEditModal,
                  ),
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: Colors.orangeAccent),
                    title: Text('Change Password', style: TextStyle(color: textColor, fontSize: 14)),
                    trailing: const Icon(Icons.chevron_right, size: 20),
                    onTap: () {},
                  ),
                  Divider(height: 1, color: borderColor),
                  ListTile(
                    leading: const Icon(Icons.logout, color: Colors.redAccent),
                    title: const Text('Sign Out', style: TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
                    onTap: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Opens the modal overlay from image screenshot
  void _openEditModal() {
    EditProfileDialog.show(
      context,
      currentName: displayName,
      currentPhone: phone,
      currentBloodType: bloodType,
      currentBarangay: barangay,
      currentInitials: initials,
      onSave: (updatedData) {
        setState(() {
          displayName = updatedData['name'] ?? displayName;
          phone = updatedData['phone'] ?? phone;
          bloodType = updatedData['bloodType'] ?? bloodType;
          barangay = updatedData['barangay'] ?? barangay;

          // Re-calculate initials if name changed
          final parts = displayName.trim().split(' ');
          if (parts.length >= 2) {
            initials = "${parts[0][0]}${parts[1][0]}".toUpperCase();
          } else if (parts.isNotEmpty && parts[0].isNotEmpty) {
            initials = parts[0][0].toUpperCase();
          }
        });
      },
    );
  }

  Widget _buildSectionTitle(String title, Color textColor) {
    return Text(
      title,
      style: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: textColor.withOpacity(0.85),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color bg, Color border, Color textColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: const Color(0xFFD32F2F)),
            const SizedBox(height: 12),
            Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.55))),
          ],
        ),
      ),
    );
  }

  Widget _buildListTile(IconData icon, String title, String subtitle, Color textColor, Color borderColor) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon, color: textColor.withOpacity(0.7)),
          title: Text(title, style: TextStyle(fontSize: 11, color: textColor.withOpacity(0.55))),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textColor)),
        ),
        Divider(height: 1, color: borderColor),
      ],
    );
  }
}