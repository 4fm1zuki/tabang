import 'package:flutter/material.dart';
import 'donor_data_sidebar/donor_data.dart';
import 'donor_data_sidebar/slide_bar.dart';
import 'donor_data_sidebar/map_view.dart';

class FindDonorPage extends StatefulWidget {
  final ThemeMode themeMode;
  final ValueChanged<ThemeMode> onThemeChanged;

  const FindDonorPage({
    super.key,
    required this.themeMode,
    required this.onThemeChanged,
  });

  @override
  State<FindDonorPage> createState() => FindDonorPageState();
}

class FindDonorPageState extends State<FindDonorPage> {
  String selectedBloodType = 'ALL';
  String? selectedBarangay;
  bool isPanelOpen = false;
  bool isFullscreen = false;

  final TransformationController _transformationController = TransformationController();
  final TextEditingController _searchController = TextEditingController();

  final List<String> bloodTypes = ['ALL', 'O-', 'O+', 'A-', 'A+', 'B-', 'B+', 'AB-', 'AB+'];

  void _zoomIn() {
    final Matrix4 matrix = _transformationController.value.clone();
    matrix.scale(1.2);
    _transformationController.value = matrix;
  }

  void _zoomOut() {
    final Matrix4 matrix = _transformationController.value.clone();
    matrix.scale(0.8);
    _transformationController.value = matrix;
  }

  void _toggleFullscreen() {
    setState(() {
      isFullscreen = !isFullscreen;
    });
  }

  void _onBarangayTap(String barangayName) {
    setState(() {
      selectedBarangay = barangayName;
      _searchController.text = barangayName;
      isPanelOpen = true;
    });
  }

  void _closePanel() {
    setState(() {
      isPanelOpen = false;
      selectedBarangay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF292929) : Colors.white;
    const primaryRed = Color(0xFFD32F2F);

    final filteredDonors = DonorData.mockDonors.where((donor) {
      final matchesBlood = selectedBloodType == 'ALL' || donor['bloodType'] == selectedBloodType;
      final matchesBarangay = selectedBarangay == null ||
          donor['location']!.toLowerCase().contains(selectedBarangay!.toLowerCase());
      return matchesBlood && matchesBarangay;
    }).toList();

    return Scaffold(
      body: Stack(
        children: [
          // SEPARATED MAP COMPONENT
          Positioned.fill(
            child: Container(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F4F1),
              child: BarangayMapView(
                selectedBarangay: selectedBarangay,
                selectedBloodType: selectedBloodType,
                onBarangaySelected: _onBarangayTap,
                themeMode: widget.themeMode,
              ),
            ),
          ),

          // FLOATING SEARCH & BLOOD TYPE CHIPS
          Positioned(
            top: 20,
            left: 25,
            width: 520,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 42,
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 8, offset: const Offset(0, 2)),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Row(
                            children: [
                              const Icon(Icons.search, size: 20, color: Color(0xFF444444)),
                              const SizedBox(width: 8),
                              Expanded(
                                child: TextField(
                                  controller: _searchController,
                                  onSubmitted: (val) => _onBarangayTap(val),
                                  decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    hintText: 'Search barangay (e.g., Kapatagan, Matti)...',
                                    hintStyle: TextStyle(fontSize: 13),
                                    isDense: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () => _onBarangayTap('Matti'),
                      icon: const Icon(Icons.my_location, size: 16, color: Colors.white),
                      label: const Text('Near Me', style: TextStyle(color: Colors.white, fontSize: 13)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryRed,
                        minimumSize: const Size(95, 42),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        elevation: 3,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: bloodTypes.map((type) {
                      final isSelected = selectedBloodType == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(
                            type,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              color: isSelected ? Colors.white : theme.colorScheme.onSurface,
                            ),
                          ),
                          selected: isSelected,
                          selectedColor: primaryRed,
                          backgroundColor: cardColor,
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(15),
                            side: BorderSide(color: isSelected ? primaryRed : Colors.transparent),
                          ),
                          onSelected: (bool selected) {
                            setState(() {
                              selectedBloodType = type;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),

          // TOP-RIGHT MAP CONTROLS (+, -, FULLSCREEN)
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            top: 20,
            right: isPanelOpen ? 370 : 25,
            child: Column(
              children: [
                _mapControlButton(Icons.add, _zoomIn, isDark, cardColor),
                const SizedBox(height: 8),
                _mapControlButton(Icons.remove, _zoomOut, isDark, cardColor),
                const SizedBox(height: 8),
                _mapControlButton(
                  isFullscreen ? Icons.fullscreen_exit : Icons.fullscreen,
                  _toggleFullscreen,
                  isDark,
                  cardColor,
                ),
              ],
            ),
          ),

          // SLIDE-OUT DONOR PANEL
          SlidePanel(
            isOpen: isPanelOpen,
            onClose: _closePanel,
            donors: filteredDonors,
          ),
        ],
      ),
    );
  }

  Widget _mapControlButton(IconData icon, VoidCallback onPressed, bool isDark, Color cardColor) {
    return Container(
      height: 38,
      width: 38,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, size: 20),
        onPressed: onPressed,
        padding: EdgeInsets.zero,
      ),
    );
  }
}