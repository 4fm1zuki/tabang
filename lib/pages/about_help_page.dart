import 'package:flutter/material.dart';

class AboutHelpPage extends StatefulWidget {
  final bool isDark;

  const AboutHelpPage({super.key, this.isDark = false});

  @override
  State<AboutHelpPage> createState() => _AboutHelpPageState();
}

class _AboutHelpPageState extends State<AboutHelpPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _selectedCategory;

  static const Color primaryRed = Color(0xFFD32F2F);
  static const Color darkRedAccent = Color(0xFF4A1212);

  final List<Map<String, dynamic>> _faqCategories = [
    {
      'title': 'Getting Started',
      'icon': Icons.rocket_launch_outlined,
      'faqs': [
        {
          'q': 'How do I register as a blood donor on TABANG?',
          'a': 'Sign up using your basic contact details, select your blood type, and verify your location. Your profile will then be ready to accept emergency blood requests.'
        },
        {
          'q': 'Is TABANG completely free to use?',
          'a': 'Yes. TABANG strictly prohibits any sale or monetization of blood. All donations connected through the platform are voluntary and non-remunerated.'
        },
      ]
    },
    {
      'title': 'Donor Eligibility',
      'icon': Icons.favorite_outline_rounded,
      'faqs': [
        {
          'q': 'Who is eligible to donate blood?',
          'a': 'Donors must be at least 18 years old, weigh at least 50 kg (110 lbs), be in good general health, and pass standard pre-donation screening.'
        },
        {
          'q': 'How often can I donate blood?',
          'a': 'You can donate whole blood every 12 weeks (3 months). Platelet donors can donate more frequently depending on medical guidelines.'
        },
      ]
    },
    {
      'title': 'Urgent Requests',
      'icon': Icons.campaign_outlined,
      'faqs': [
        {
          'q': 'How do urgent blood request notifications work?',
          'a': 'When a recipient posts an urgent request, TABANG matches compatible blood types within proximity and sends real-time push alerts to eligible donors.'
        },
        {
          'q': 'What details are required when creating a blood request?',
          'a': 'You need to specify the patient name, hospital location, required blood type, unit quantity, and contact person.'
        },
      ]
    },
    {
      'title': 'Privacy & Safety',
      'icon': Icons.shield_outlined,
      'faqs': [
        {
          'q': 'Why do I see alias IDs like Donor #801 in chats?',
          'a': 'To protect donor privacy, TABANG uses anonymous identifiers in open chat threads until mutual contact agreement is established.'
        },
        {
          'q': 'What happens when I block a user?',
          'a': 'Blocked users cannot send or receive messages from you. To prevent abuse, a 48-hour cooldown applies before you can block a user again after unblocking them.'
        },
      ]
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isDark ? Colors.white : const Color(0xFF1F1F1F);
    final subTextColor = widget.isDark ? Colors.white70 : const Color(0xFF666666);
    final cardBg = widget.isDark ? const Color(0xFF242424) : Colors.white;
    final listBg = widget.isDark ? const Color(0xFF1C1C1C) : const Color(0xFFF9F9F9);
    final borderColor = widget.isDark ? const Color(0xFF383838) : const Color(0xFFE5E5E5);

    // Search and Filter logic
    final query = _searchQuery.toLowerCase();
    final List<Map<String, String>> matchingFaqs = [];

    for (var cat in _faqCategories) {
      if (_selectedCategory == null || _selectedCategory == cat['title']) {
        for (var faq in (cat['faqs'] as List<Map<String, String>>)) {
          final qMatch = faq['q']!.toLowerCase().contains(query);
          final aMatch = faq['a']!.toLowerCase().contains(query);
          if (query.isEmpty || qMatch || aMatch) {
            matchingFaqs.add({
              'category': cat['title'] as String,
              'q': faq['q']!,
              'a': faq['a']!,
            });
          }
        }
      }
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Styled Header Box
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: widget.isDark
                      ? [const Color(0xFF2C1414), cardBg]
                      : [primaryRed.withOpacity(0.08), cardBg],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryRed.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: primaryRed.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.help_center_rounded,
                          color: primaryRed,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Help & Support Center',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Find quick answers about blood donations, safety, and request tracking.',
                              style: TextStyle(
                                fontSize: 13,
                                color: subTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: listBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: TextStyle(fontSize: 14, color: textColor),
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Search help topics, keywords, or rules...',
                        hintStyle: TextStyle(color: subTextColor.withOpacity(0.7), fontSize: 13),
                        prefixIcon: const Icon(Icons.search_rounded, color: primaryRed, size: 20),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                          icon: Icon(Icons.clear, size: 18, color: subTextColor),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                              _searchQuery = '';
                            });
                          },
                        )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Category Chips Selection
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All Topics'),
                    selected: _selectedCategory == null,
                    selectedColor: primaryRed,
                    backgroundColor: cardBg,
                    labelStyle: TextStyle(
                      color: _selectedCategory == null ? Colors.white : textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedCategory = null);
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._faqCategories.map((cat) {
                    final isSelected = _selectedCategory == cat['title'];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: ChoiceChip(
                        avatar: Icon(
                          cat['icon'] as IconData,
                          size: 16,
                          color: isSelected ? Colors.white : primaryRed,
                        ),
                        label: Text(cat['title'] as String),
                        selected: isSelected,
                        selectedColor: primaryRed,
                        backgroundColor: cardBg,
                        labelStyle: TextStyle(
                          color: isSelected ? Colors.white : textColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                        onSelected: (selected) {
                          setState(() {
                            _selectedCategory = selected ? (cat['title'] as String) : null;
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // FAQ List Accordion
            Text(
              'Frequently Asked Questions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 12),

            if (matchingFaqs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: Center(
                  child: Text(
                    'No matching questions found.',
                    style: TextStyle(color: subTextColor, fontSize: 13),
                  ),
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: matchingFaqs.length,
                itemBuilder: (context, index) {
                  final faq = matchingFaqs[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Theme(
                      data: Theme.of(context).copyWith(
                        dividerColor: Colors.transparent,
                      ),
                      child: ExpansionTile(
                        iconColor: primaryRed,
                        collapsedIconColor: subTextColor,
                        title: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryRed.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                faq['category']!,
                                style: const TextStyle(
                                  color: primaryRed,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                faq['q']!,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                faq['a']!,
                                style: TextStyle(
                                  fontSize: 13,
                                  height: 1.5,
                                  color: subTextColor,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

            const SizedBox(height: 28),

            // Help Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: widget.isDark ? darkRedAccent.withOpacity(0.4) : primaryRed.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryRed.withOpacity(0.2)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.support_agent_rounded, size: 32, color: primaryRed),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Need emergency assistance?',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Our platform support team is available 24/7 for critical donation inquiries.',
                          style: TextStyle(fontSize: 12, color: subTextColor),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryRed,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Contact support initiated.')),
                      );
                    },
                    child: const Text('Contact Us', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}