import 'package:flutter/material.dart';

import '../../core/eligibility.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';

/// About & Help.
///
/// FAQ content is preserved from the original build but corrected: the
/// previous version said donors must be 18 in one entry and 17 in another, and
/// gave both 56-day and 12-week donation intervals. Both now match the rules
/// the app actually enforces in [EligibilityEngine].
class AboutHelpPage extends StatefulWidget {
  const AboutHelpPage({super.key});

  @override
  State<AboutHelpPage> createState() => _AboutHelpPageState();
}

class _AboutHelpPageState extends State<AboutHelpPage> {
  final TextEditingController _search = TextEditingController();
  String _query = '';
  String? _openCategory;

  static final _categories = <_FaqCategory>[
    const _FaqCategory(
      title: 'Getting started',
      icon: Icons.rocket_launch_outlined,
      faqs: [
        _Faq(
          'How do I register as a blood donor on TABANG?',
          'Create an account with your full name, an alias, your email, '
              'contact number, birth date, blood type and barangay. Your alias '
              'is what other users see. A chapter staff member verifies your '
              'blood donor card before your profile is marked verified.',
        ),
        _Faq(
          'Is TABANG free to use?',
          'Yes. TABANG strictly prohibits the sale or monetisation of blood. '
              'All donations coordinated through the platform are voluntary '
              'and non-remunerated, in line with RA 7719.',
        ),
        _Faq(
          'Why is my real name hidden?',
          'Under RA 10173, health information is sensitive personal data. '
              'TABANG shows aliases in the directory and in chat. A participant '
              'can request an identity reveal; real names and contact details '
              'appear only after the other participant accepts. Declining or '
              'ignoring the request leaves both parties anonymous.',
        ),
      ],
    ),
    _FaqCategory(
      title: 'Donor eligibility',
      icon: Icons.favorite_outline,
      faqs: [
        _Faq(
          'Who is eligible to donate blood?',
          'Donors must be between ${EligibilityEngine.minimumAge} and '
              '${EligibilityEngine.maximumAge} years old, weigh at least '
              '${EligibilityEngine.minimumWeightKg.toInt()} kg, be in good '
              'general health, and pass the pre-donation screening.',
        ),
        const _Faq(
          'How often can I donate?',
          'Whole blood and packed red cells: every 12 weeks. Platelets: every '
              '2 weeks. Plasma: every 4 weeks. TABANG enforces these intervals '
              'automatically — your profile shows a live countdown and you '
              'cannot respond to a request while in cooldown.',
        ),
        const _Faq(
          'What happens if I try to donate during cooldown?',
          'The app blocks the response and tells you the exact date you become '
              'eligible again. This protects your iron stores and red cell '
              'volume, and matches the three-month lock used by comparable '
              'national systems.',
        ),
      ],
    ),
    const _FaqCategory(
      title: 'Urgent requests',
      icon: Icons.campaign_outlined,
      faqs: [
        _Faq(
          'How does TABANG decide between the blood bank and the donor '
          'network?',
          'When a recipient creates a request, the dialog checks the public '
              'inventory for compatible units of the selected component. If '
              'stock exists, the recipient can submit the request to the blood '
              'bank for staff processing or post it to the donor network. If '
              'no compatible stock exists, the only route offered is the donor '
              'network.',
        ),
        _Faq(
          'How do urgent blood request notifications work?',
          'Donor-network requests appear on the Requests board of donors whose '
              'blood type and component are compatible and who are currently '
              'eligible. Requests are ranked critical, urgent, then routine. '
              'This build shows in-app summaries; push delivery is a documented '
              'gap that requires a deployed backend.',
        ),
        _Faq(
          'What details are required when creating a request?',
          'A patient reference (a token, not the real name), a participating '
              'facility, blood type, component, number of units, barangay, '
              'urgency level and an optional clinical note.',
        ),
        _Faq(
          'What happens after I respond to a request?',
          'Your response is an offer, not a fulfilled unit. The requester sees '
              'your alias, optional message and eligibility, then selects a '
              'donor. Selection creates a private coordination thread. Only '
              'chapter staff can mark the request fulfilled after the donation '
              'is recorded.',
        ),
        _Faq(
          'What does "compatible donors available" mean?',
          'It is the count of donors whose ABO/Rh type can safely give the '
              'requested component and who are not in cooldown or otherwise '
              'ineligible. Red cells use the standard ABO/Rh table; plasma uses '
              'the reverse ABO rule. O- is the universal red-cell donor; AB+ is '
              'the universal red-cell recipient.',
        ),
      ],
    ),
    const _FaqCategory(
      title: 'Safety & moderation',
      icon: Icons.shield_outlined,
      faqs: [
        _Faq(
          'What happens when I block a user?',
          'Messaging is disabled for both participants in that conversation '
              'while either party has blocked the other. To prevent harassment '
              'and retaliatory blocking, a 48-hour cooldown applies before you '
              'can block the same user again after unblocking them. Blocking '
              'does not delete an existing report.',
        ),
        _Faq(
          'How do I report a user?',
          'Open the conversation, tap the flag icon, and choose a reason. The '
              'report is stored and appears in the chapter staff reports queue, '
              'where staff can resolve or dismiss it. Paid blood solicitation '
              'is the most serious category and is reviewed first.',
        ),
        _Faq(
          'Is paid blood donation allowed?',
          'No. Soliciting payment for blood is prohibited under RA 7719 and '
              'TABANG policy. Messages containing payment demands are flagged '
              'automatically for moderation.',
        ),
        _Faq(
          'Can I reserve a blood unit from the public inventory?',
          'No. The public inventory is read-only, matching the study\'s SEIPS '
              'requirement. Chapter staff manage reservations, dispatch, '
              'quarantine and expiry from the admin console. Recipients request '
              'blood instead of reserving a specific bag.',
        ),
      ],
    ),
    const _FaqCategory(
      title: 'About this build',
      icon: Icons.info_outline,
      faqs: [
        _Faq(
          'Is TABANG connected to real hospital data?',
          'No. This build runs entirely on simulated donor records, inventory '
              'and request workflows, as specified in the study scope. It is '
              'not connected to live blood service databases, hospital '
              'electronic health records, or Philippine Red Cross systems.',
        ),
        _Faq(
          'Where do the barangay boundaries come from?',
          'The map uses an approximate boundary set generated for '
              'demonstration purposes. Official PSA or LGU boundary data should '
              'replace it before any real deployment.',
        ),
        _Faq(
          'Where do the photos in the app come from?',
          'Every photograph is bundled with the app, so TABANG works offline '
              'and never contacts a third-party image service at runtime. The '
              'photos are public-domain or CC0 images from Wikimedia Commons, '
              'cropped and graded for the interface. Source links, authors and '
              'licences are recorded in tools/image_sources/CREDITS.md and in the '
              'project README. The privacy card art and launcher icon are '
              'original artwork drawn by tools/make_media_assets.py.',
        ),
        _Faq(
          'What is TABANG an acronym for?',
          'Transfusion Access, Blood Availability and Network Guidance. Some '
              'pages in the source paper shorten the last word to "Analytics"; '
              'this build follows the official title on the cover and '
              'acknowledgement pages.',
        ),
        _Faq(
          'What is not implemented in this build?',
          'Google OAuth, the Supabase/PostgreSQL backend, voice calls, '
              'profile-picture upload, push notifications and multi-facility '
              'stock are documented gaps. The prototype uses simulated data and '
              'does not connect to PRC, hospital or EHR systems. See the README '
              'for the full alignment matrix.',
        ),
      ],
    ),
  ];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<_FaqCategory> get _filtered {
    if (_query.trim().isEmpty) return _categories;
    final q = _query.toLowerCase();
    final result = <_FaqCategory>[];
    for (final category in _categories) {
      final matches = category.faqs
          .where((f) =>
              f.question.toLowerCase().contains(q) ||
              f.answer.toLowerCase().contains(q))
          .toList();
      if (matches.isNotEmpty) {
        result.add(_FaqCategory(
          title: category.title,
          icon: category.icon,
          faqs: matches,
        ));
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final categories = _filtered;

    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'About & Help',
            subtitle:
                'How TABANG works, who can donate, and how your data is handled.',
          ),
          const SizedBox(height: TabangSpace.xl),

          SizedBox(
            width: 380,
            child: TextField(
              controller: _search,
              onChanged: (v) => setState(() => _query = v),
              style: const TextStyle(fontSize: 12.5),
              decoration: InputDecoration(
                hintText: 'Search help topics',
                isDense: true,
                prefixIcon: const Icon(Icons.search, size: 17),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close, size: 15),
                        onPressed: () {
                          _search.clear();
                          setState(() => _query = '');
                        },
                      ),
              ),
            ),
          ),
          const SizedBox(height: TabangSpace.xl),

          if (categories.isEmpty)
            const EmptyState(
              icon: Icons.search_off,
              title: 'No help topics match',
              message: 'Try a different word, or browse the categories below.',
            )
          else
            ...categories.map((c) => _buildCategory(context, c)),

          const SizedBox(height: TabangSpace.xl),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ABOUT TABANG',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: TabangSpace.sm),
                Text(
                  'Transfusion Access, Blood Availability and Network Guidance '
                  'is a centralized donor management system developed for '
                  'Digos City, Davao del Sur, as a Senior High School research '
                  'project at Cor Jesu College, Inc.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.65,
                    color: context.textColor,
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                Text(
                  'Aligned with SDG 3 (Good Health and Well-being) and SDG 9 '
                  '(Industry, Innovation and Infrastructure).',
                  style: TextStyle(
                    fontSize: 11,
                    height: 1.6,
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: TabangSpace.sm),
                Text(
                  'Photography: public domain / CC0, bundled locally from '
                  'Wikimedia Commons. Credits: tools/image_sources/CREDITS.md.',
                  style: TextStyle(
                    fontSize: 10.5,
                    height: 1.5,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategory(BuildContext context, _FaqCategory category) {
    final open = _openCategory == category.title || _query.isNotEmpty;

    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.lg),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(TabangRadius.md),
              onTap: () => setState(() {
                _openCategory = open ? null : category.title;
              }),
              child: Padding(
                padding: const EdgeInsets.all(TabangSpace.lg),
                child: Row(
                  children: [
                    Icon(category.icon,
                        size: 17, color: TabangColors.crimson),
                    const SizedBox(width: TabangSpace.md),
                    Expanded(
                      child: Text(
                        category.title,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: context.textColor,
                        ),
                      ),
                    ),
                    StatusPill('${category.faqs.length}',
                        tone: Tone.neutral, dense: true),
                    const SizedBox(width: TabangSpace.sm),
                    Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      size: 18,
                      color: context.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            if (open)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  TabangSpace.lg,
                  0,
                  TabangSpace.lg,
                  TabangSpace.lg,
                ),
                child: Column(
                  children: category.faqs
                      .map((f) => _buildFaq(context, f))
                      .toList(),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaq(BuildContext context, _Faq faq) {
    return Container(
      margin: const EdgeInsets.only(top: TabangSpace.sm),
      padding: const EdgeInsets.all(TabangSpace.md),
      decoration: BoxDecoration(
        color: context.surfaceAlt,
        borderRadius: BorderRadius.circular(TabangRadius.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            faq.question,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: context.textColor,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            faq.answer,
            style: TextStyle(
              fontSize: 11.5,
              height: 1.65,
              color: context.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}
class _FaqCategory {
  const _FaqCategory({
    required this.title,
    required this.icon,
    required this.faqs,
  });

  final String title;
  final IconData icon;
  final List<_Faq> faqs;
}

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}
