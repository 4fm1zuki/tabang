import 'package:flutter/material.dart';

class SlidePanel extends StatelessWidget {
  final bool isOpen;
  final VoidCallback onClose;
  final List<Map<String, String>> donors;

  const SlidePanel({
    super.key,
    required this.isOpen,
    required this.onClose,
    required this.donors,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final panelBg = isDark ? const Color(0xFF232323) : const Color(0xFFE8E8E8);
    final borderColor = isDark ? const Color(0xFF444444) : const Color(0xFFCCCCCC);
    final titleColor = isDark ? Colors.grey.shade300 : const Color(0xFF555555);

    return AnimatedPositioned(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      top: 20,
      bottom: 20,
      right: isOpen ? 25 : -360, // SLIDES IN/OUT VIA POSITIONED ABSOLUTE OVERLAY
      width: 330,
      child: Container(
        decoration: BoxDecoration(
          color: panelBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 16,
              offset: const Offset(-4, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // PANEL HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'AVAILABLE BLOOD',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                        color: titleColor,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: onClose,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ),

            // DONOR CARDS LIST
            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                itemCount: donors.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  return _buildDonorCard(donors[index], isDark);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDonorCard(Map<String, String> donor, bool isDark) {
    final cardBg = isDark ? const Color(0xFF333333) : const Color(0xFFDCDCDC);
    final cardBorder = isDark ? const Color(0xFF4A4A4A) : const Color(0xFFC0C0C0);
    final headingColor = isDark ? Colors.grey.shade200 : const Color(0xFF444444);
    final bodyColor = isDark ? Colors.grey.shade400 : const Color(0xFF555555);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cardBorder, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ALIAS: ${donor['alias']}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: headingColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Last Donation: ${donor['lastDonated']}',
            style: TextStyle(fontSize: 12, color: bodyColor, height: 1.3),
          ),
          Text(
            'No. of Donations: ${donor['totalDonations']}',
            style: TextStyle(fontSize: 12, color: bodyColor, height: 1.3),
          ),
          Text(
            'Verified since: ${donor['verifiedSince']}',
            style: TextStyle(fontSize: 12, color: bodyColor, height: 1.3),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: SizedBox(
              height: 28,
              child: ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: isDark ? const Color(0xFF222222) : const Color(0xFFF0F0F0),
                  foregroundColor: isDark ? Colors.grey.shade300 : const Color(0xFF333333),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(
                      color: isDark ? const Color(0xFF555555) : const Color(0xFFB0B0B0),
                    ),
                  ),
                ),
                child: const Text(
                  'Contact Now',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}