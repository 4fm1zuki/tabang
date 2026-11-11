import 'package:flutter/material.dart';

import '../../core/eligibility.dart';
import '../../core/image_credits.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../../theme.dart';
import '../../widgets/layout.dart';
import '../../widgets/common.dart';
import '../../widgets/onboarding.dart';
import '../../widgets/photo.dart';

/// Guides, FAQ and About TABANG.
///
/// Three distinct jobs, three tabs:
///  * **Guides** are task-based walkthroughs for donating, requesting,
///    messaging, Discover, profile setup and settings.
///  * **FAQ** keeps the short reference answers aligned with the rules the app
///    actually enforces.
///  * **About** is the platform summary, with SDG alignment and per-image
///    credits as supporting content rather than the headline.
class AboutHelpPage extends StatefulWidget {
  const AboutHelpPage({super.key, this.onOpenMessages});

  /// Opens the Messages tab, where the chapter support thread lives.
  final VoidCallback? onOpenMessages;

  @override
  State<AboutHelpPage> createState() => _AboutHelpPageState();
}

class _AboutHelpPageState extends State<AboutHelpPage> {
  final TabangRepository _repo = TabangRepository.instance;
  final TextEditingController _search = TextEditingController();

  int _tab = 0;
  String _query = '';
  String? _openCategory;
  String? _openGuide;

  AppUser? get _user => _repo.currentUser;

  static const _guides = <_Guide>[
    _Guide(
      title: 'Donating blood',
      icon: Icons.volunteer_activism_outlined,
      summary: 'Eligibility, preparation and what happens on donation day.',
      steps: [
        'Open Donor Hub and check your eligibility. The card shows your blood type, cooldown and next available date.',
        'Prepare: sleep well, eat a normal meal within four hours, drink water, and bring a valid ID and donor card.',
        'Book an appointment at the blood bank, or walk in at a scheduled mobile drive. Appointments guarantee a screening slot, not a specific bag.',
        'A nurse checks your haemoglobin, blood pressure, weight and health questionnaire. The screening nurse makes the final eligibility call.',
        'The draw takes about 8–12 minutes. One bag can be separated into red cells, platelets and plasma.',
        'Rest for ten minutes, have a snack, keep the bandage on for four hours, and avoid heavy lifting for the rest of the day.',
      ],
      tip:
          'Whole blood and red cells need 12 weeks between donations. TABANG '
          'enforces the interval automatically, so you cannot accidentally '
          'double-book yourself.',
    ),
    _Guide(
      title: 'Requesting blood',
      icon: Icons.add_circle_outline,
      summary: 'Check the bank first, then coordinate with compatible donors.',
      steps: [
        'Open Requests and tap New request. Start with a patient alias — never the real patient name.',
        'Choose the blood type, component, units, hospital, barangay and urgency. TABANG checks participating inventory as you type.',
        'If compatible stock exists, submit to the blood bank for staff processing. If stock is short, post to the donor network.',
        'Donors respond with an offer. Review their alias, blood type and eligibility, then open a conversation.',
        'Chat first. Selection is only enabled after both sides have exchanged a real message — a system notice does not count.',
        'After the donation, chapter staff verify and mark the request fulfilled. A request is never fulfilled automatically.',
      ],
      tip:
          'A request is not a reservation. Blood-bank staff still cross-match '
          'and confirm release, and a donor offer is not a guaranteed unit '
          'until the donation is recorded.',
    ),
    _Guide(
      title: 'Messaging safely',
      icon: Icons.forum_outlined,
      summary: 'Alias-only chat, bilateral reveal, reporting and blocking.',
      steps: [
        'Open Messages and choose a conversation. Other users only see your nickname, never your full name or address.',
        'Ask about availability, hospital logistics and timing. Keep clinical details minimal until both sides agree to reveal identities.',
        'Tap the identity control to request a reveal. Real names and contact details appear only after the other participant accepts.',
        'Never solicit or offer payment. Paid blood donation is prohibited and messages demanding payment are flagged for moderation.',
        'Use the flag icon to report harassment, spam or paid-blood solicitation. Staff review reports in the admin console.',
        'If a conversation becomes unsafe, block the user. Blocking stops messaging for both sides and a 48-hour cooldown applies before re-blocking.',
      ],
      tip:
          'TABANG staff will never ask for your password or a one-time code in '
          'chat. Do not share either with anyone.',
    ),
    _Guide(
      title: 'Using Home',
      icon: Icons.explore_outlined,
      summary:
          'Find announcements, donation drives and short educational guides.',
      steps: [
        'Start with the four quick actions: Request or donate, Find donation sites, Messages, and Quick guide.',
        'Use the search field for a symptom, topic or drive. Results update as you type.',
        'Browse categories for donation tips, eligibility, drives and stories. Each category is a horizontal rail you can scroll.',
        'Open a blood drive for its venue, schedule and expected donors, then book an appointment if you want a screening slot.',
        'Open any card to read the article, see its safety note and view the exact image credit under the photo.',
      ],
      tip:
          'The urgent-shortage callout lives on Blood Bank and the map, not '
          'Home. Stock alerts belong beside the inventory they describe.',
    ),
    _Guide(
      title: 'Profile & donor registration',
      icon: Icons.badge_outlined,
      summary: 'Your alias identity, donor upgrade and availability controls.',
      steps: [
        'Open Profile to review your alias, barangay, blood type and account status. Your full name is never public.',
        'New accounts start as community users. You can request blood and browse donors immediately.',
        'When you are ready to donate, open Donor Hub and choose Register as a donor. Enter your blood type, birth date and weight.',
        'Chapter staff verify your blood card before you appear in the donor directory. Until then your profile stays unverified.',
        'Use the availability switch in Donor Hub or Settings to hide from the directory. TABANG still hides you during cooldown.',
        'Every profile illustration is original TABANG artwork. Hover any image to see its individual credit.',
      ],
      tip:
          'Donating and needing blood are not mutually exclusive. Donors can '
          'still create a request for a patient.',
    ),
    _Guide(
      title: 'Settings & accessibility',
      icon: Icons.settings_outlined,
      summary: 'Theme, notification summaries, privacy and safe-area layout.',
      steps: [
        'Open Settings from the account menu or the desktop rail. Light is the default; Dark applies immediately.',
        'Dark mode keeps secondary text readable instead of simply inverting the palette.',
        'Notification switches choose which updates appear in your Home summary.',
        'Donors can hide from the directory and hide their barangay without changing their account status.',
        'The app reserves system status-bar and gesture insets, so titles and the bottom bar never sit under the clock or home indicator.',
        'The map keeps a light base even in dark mode, with a separate map-style toggle for dimming streets and labels.',
      ],
      tip:
          'If text looks too small, raise the device text size. TABANG layouts '
          'wrap controls instead of clipping them.',
    ),
  ];

  static final _categories = <_FaqCategory>[
    const _FaqCategory(
      title: 'Getting started',
      icon: Icons.rocket_launch_outlined,
      faqs: [
        _Faq(
          'How do I register as a blood donor on TABANG?',
          'Create a community account with your full name, an alias, email, '
              'contact number and barangay. Your alias is what other users '
              'see. When you are ready, open Donor Hub and choose Register as '
              'a donor to add your blood type, birth date and weight. A chapter '
              'staff member verifies your blood card before your profile is '
              'marked verified.',
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
              'Turn request alerts off in Settings if you only want to check '
              'the board yourself.',
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
              'your alias, optional message and eligibility, then must chat '
              'with you before selecting a donor. Selection opens a private '
              'coordination thread. Only chapter staff can mark the request '
              'fulfilled after the donation is recorded.',
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
          'Open the conversation, tap the flag icon, choose a reason and add '
              'an explanation of what happened. The report appears in the '
              'chapter staff queue, where staff can resolve or dismiss it. Paid '
              'blood solicitation is the most serious category and is reviewed '
              'first.',
        ),
        _Faq(
          'Is paid blood donation allowed?',
          'No. Soliciting payment for blood is prohibited under RA 7719 and '
              'TABANG policy. Messages containing payment demands are flagged '
              'automatically for moderation.',
        ),
        _Faq(
          'Can I reserve a blood unit from the public inventory?',
          'You can place a hold on a usable unit from Blood Bank. A hold is '
              'not a transfusion order: chapter staff still cross-match and '
              'confirm release, and holds expire with the unit. Selecting a bag '
              'never bypasses clinical screening.',
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
              'cropped and graded for the interface. Each image carries its own '
              'credit under the photo, on hover and in the About tab. Original '
              'illustrations and avatars were generated for TABANG.',
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

  List<_FaqCategory> get _filteredFaq {
    if (_query.trim().isEmpty) return _categories;
    final q = _query.toLowerCase();
    final result = <_FaqCategory>[];
    for (final category in _categories) {
      final matches = category.faqs
          .where(
            (f) =>
                f.question.toLowerCase().contains(q) ||
                f.answer.toLowerCase().contains(q),
          )
          .toList();
      if (matches.isNotEmpty) {
        result.add(
          _FaqCategory(
            title: category.title,
            icon: category.icon,
            faqs: matches,
          ),
        );
      }
    }
    return result;
  }

  List<_Guide> get _filteredGuides {
    if (_query.trim().isEmpty) return _guides;
    final q = _query.toLowerCase();
    return _guides
        .where(
          (g) =>
              g.title.toLowerCase().contains(q) ||
              g.summary.toLowerCase().contains(q) ||
              g.steps.any((s) => s.toLowerCase().contains(q)),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final user = _user;
    return SingleChildScrollView(
      padding: context.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The help "?" sits beside the title on every width; the generic
          // PageHeader stacks actions under the title on phones.
          const Row(
            children: [
              Expanded(
                child: PageHeader(
                  title: 'Guides & Help',
                  subtitle: 'Task walkthroughs, quick answers and the story behind TABANG.',
                ),
              ),
              HelpTip(
                title: 'How to use this page',
                message:
                    'Guides are step-by-step instructions. FAQ holds short '
                    'reference answers. About explains the platform, its '
                    'research context, SDG alignment and image credits.',
              ),
            ],
          ),
          const SizedBox(height: TabangSpace.lg),

          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 0,
                icon: Icon(Icons.menu_book_outlined, size: 16),
                label: Text('Guides'),
              ),
              ButtonSegment(
                value: 1,
                icon: Icon(Icons.quiz_outlined, size: 16),
                label: Text('FAQ'),
              ),
              ButtonSegment(
                value: 2,
                icon: Icon(Icons.info_outline, size: 16),
                label: Text('About'),
              ),
            ],
            selected: {_tab},
            showSelectedIcon: false,
            onSelectionChanged: (selection) => setState(() {
              _tab = selection.first;
              _query = '';
              _search.clear();
            }),
          ),
          const SizedBox(height: TabangSpace.lg),

          if (_tab != 2) ...[
            SizedBox(
              width: context.isPhone ? double.infinity : 420,
              child: TextField(
                controller: _search,
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(fontSize: 12.5),
                decoration: InputDecoration(
                  hintText: _tab == 0 ? 'Search guides' : 'Search help topics',
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
            const SizedBox(height: TabangSpace.lg),
          ],

          if (_tab == 0)
            _buildGuides(context, user)
          else if (_tab == 1)
            _buildFaqs(context)
          else
            _buildAbout(context),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ guides

  Widget _buildGuides(BuildContext context, AppUser? user) {
    final guides = _filteredGuides;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_query.isEmpty) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(TabangSpace.lg),
            decoration: BoxDecoration(
              gradient: TabangGradients.forContext(context),
              borderRadius: BorderRadius.circular(TabangRadius.md),
              border: Border.all(
                color: TabangColors.crimson.withValues(alpha: 0.2),
              ),
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 620;
                final copy = Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TabangColors.crimson,
                        borderRadius: BorderRadius.circular(TabangRadius.sm),
                      ),
                      child: const Icon(
                        Icons.school_outlined,
                        size: 20,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(width: TabangSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'New here?',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: context.textColor,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Start with the three things that matter, then '
                            'come back to a task guide when you need it.',
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.5,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final action = FilledButton.tonalIcon(
                  onPressed: user == null
                      ? null
                      : () => showWelcomeGuide(context, user, markSeen: false),
                  icon: const Icon(Icons.play_circle_outline, size: 16),
                  label: const Text('Open welcome guide'),
                );
                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      copy,
                      const SizedBox(height: TabangSpace.md),
                      action,
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: TabangSpace.lg),
                    action,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: TabangSpace.xl),
        ],
        if (guides.isEmpty)
          const EmptyState(
            icon: Icons.search_off,
            title: 'No guides match',
            message: 'Try a broader word, or switch to the FAQ tab.',
          )
        else
          for (final guide in guides) _buildGuideCard(context, guide),
      ],
    );
  }

  Widget _buildGuideCard(BuildContext context, _Guide guide) {
    final open = _openGuide == guide.title || _query.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.md),
      child: SurfaceCard(
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(TabangRadius.md),
              onTap: () =>
                  setState(() => _openGuide = open ? null : guide.title),
              child: Padding(
                padding: const EdgeInsets.all(TabangSpace.lg),
                child: Row(
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: context.isDark
                            ? TabangColors.crimson.withValues(alpha: 0.18)
                            : TabangColors.crimsonSoft,
                        borderRadius: BorderRadius.circular(TabangRadius.sm),
                      ),
                      child: Icon(
                        guide.icon,
                        size: 19,
                        color: TabangColors.crimson,
                      ),
                    ),
                    const SizedBox(width: TabangSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            guide.title,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w700,
                              color: context.textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            guide.summary,
                            style: TextStyle(
                              fontSize: 12,
                              height: 1.45,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: TabangSpace.sm),
                    HelpTip(title: guide.title, message: guide.tip, size: 18),
                    Icon(
                      open ? Icons.expand_less : Icons.expand_more,
                      size: 20,
                      color: context.textMuted,
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutCubic,
              child: open
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(
                        TabangSpace.lg,
                        0,
                        TabangSpace.lg,
                        TabangSpace.lg,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          const SizedBox(height: TabangSpace.sm),
                          for (var i = 0; i < guide.steps.length; i++)
                            _stepRow(context, i + 1, guide.steps[i]),
                          const SizedBox(height: TabangSpace.sm),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(TabangSpace.md),
                            decoration: BoxDecoration(
                              color: context.isDark
                                  ? TabangColors.gold.withValues(alpha: 0.13)
                                  : TabangColors.goldSoft,
                              borderRadius: BorderRadius.circular(
                                TabangRadius.sm,
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.tips_and_updates_outlined,
                                  size: 15,
                                  color: TabangColors.gold,
                                ),
                                const SizedBox(width: TabangSpace.sm),
                                Expanded(
                                  child: Text(
                                    guide.tip,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      height: 1.55,
                                      color: context.textColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stepRow(BuildContext context, int number, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: TabangSpace.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.surfaceAlt,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '$number',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                color: context.textMuted,
              ),
            ),
          ),
          const SizedBox(width: TabangSpace.sm),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.6,
                color: context.textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --------------------------------------------------------------------- FAQ

  Widget _buildFaqs(BuildContext context) {
    final categories = _filteredFaq;
    if (categories.isEmpty) {
      return const EmptyState(
        icon: Icons.search_off,
        title: 'No help topics match',
        message: 'Try a different word, or switch to the Guides tab.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Straight to a human: the chapter support thread accepts system
        // questions, data corrections and feedback. Admin-side users reply to
        // that thread in Moderation, so they do not get a second send form
        // addressed to themselves.
        if (_repo.currentUser?.role.isAdminSide != true) ...[
          _buildFeedbackCard(context),
          const SizedBox(height: TabangSpace.lg),
        ],
        for (final category in categories) _buildCategory(context, category),
      ],
    );
  }

  Widget _buildFeedbackCard(BuildContext context) {
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.support_agent_outlined,
                size: 19,
                color: TabangColors.crimson,
              ),
              const SizedBox(width: TabangSpace.sm),
              Expanded(
                child: Text(
                  'Still stuck? Message the PRC chapter',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                    color: context.textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Send a question about the app, a data correction, or feedback — '
            'it opens a private thread with the chapter, the same place donor '
            'coordination happens. Staff replies during office hours.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: context.textMuted,
            ),
          ),
          const SizedBox(height: TabangSpace.md),
          Wrap(
            spacing: TabangSpace.sm,
            runSpacing: TabangSpace.sm,
            children: [
              FilledButton.icon(
                onPressed: () => _showFeedbackDialog(context),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Send feedback'),
              ),
              if (widget.onOpenMessages != null)
                OutlinedButton.icon(
                  onPressed: widget.onOpenMessages,
                  icon: const Icon(Icons.forum_outlined, size: 16),
                  label: const Text('Open Messages'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showFeedbackDialog(BuildContext context) async {
    final categories = <String>[
      'System issue',
      'Data correction',
      'Feedback or suggestion',
      'Report a problem',
    ];
    final controller = TextEditingController();
    var category = categories.first;
    String? error;

    final sent = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Message the chapter'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: category,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'What is this about?',
                    isDense: true,
                  ),
                  items: categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) =>
                      setDialogState(() => category = v ?? category),
                ),
                const SizedBox(height: TabangSpace.md),
                TextField(
                  controller: controller,
                  maxLines: 4,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Message',
                    hintText: 'Describe it as plainly as you can',
                    isDense: true,
                  ),
                ),
                if (error != null) ...[
                  const SizedBox(height: TabangSpace.sm),
                  Text(
                    error!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: TabangColors.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              onPressed: () {
                if (controller.text.trim().length < 5) {
                  setDialogState(
                    () => error = 'Please write at least a short sentence.',
                  );
                  return;
                }
                Navigator.pop(dialogContext, true);
              },
              icon: const Icon(Icons.send_outlined, size: 16),
              label: const Text('Send'),
            ),
          ],
        ),
      ),
    );

    if (sent != true) {
      controller.dispose();
      return;
    }

    final user = _repo.currentUser;
    final thread = user == null
        ? null
        : _repo.sendStaffFeedback(
            userId: user.id,
            category: category,
            message: controller.text.trim(),
          );
    controller.dispose();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            thread == null
                ? 'The chapter thread is unavailable right now.'
                : 'Sent to chapter staff. Their reply appears in Messages.',
          ),
          action: thread == null || widget.onOpenMessages == null
              ? null
              : SnackBarAction(
                  label: 'Open',
                  onPressed: widget.onOpenMessages!,
                ),
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
                    Icon(category.icon, size: 17, color: TabangColors.crimson),
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
                    StatusPill(
                      '${category.faqs.length}',
                      tone: Tone.neutral,
                      dense: true,
                    ),
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
                  children: [
                    // Deterministic order: questions are sorted A→Z inside
                    // each category so the list does not look shuffled.
                    for (final faq
                        in ([...category.faqs]..sort(
                          (a, b) => a.question.toLowerCase().compareTo(
                            b.question.toLowerCase(),
                          ),
                        )))
                      _buildFaq(context, faq),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// One FAQ entry: the question sits on the left and the TABANG answer below
  /// it. Both blocks read left-to-right so the FAQ scans like a document
  /// instead of a chat log.
  Widget _buildFaq(BuildContext context, _Faq faq) {
    return Padding(
      padding: const EdgeInsets.only(top: TabangSpace.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _faqAvatar(
                context,
                background: context.surfaceAlt,
                border: context.border,
                child: Icon(
                  Icons.person_outline,
                  size: 15,
                  color: context.textMuted,
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaceAlt,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(3),
                      topRight: Radius.circular(TabangRadius.md),
                      bottomLeft: Radius.circular(TabangRadius.md),
                      bottomRight: Radius.circular(TabangRadius.md),
                    ),
                    border: Border.all(color: context.border),
                  ),
                  child: Text(
                    faq.question,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                      color: context.textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 36),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Answers are indented one step past the question so the two
              // blocks read as a document, not as two stacked left edges.
              const SizedBox(width: 46),
              Flexible(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 14, 10),
                  decoration: BoxDecoration(
                    color: context.isDark
                        ? TabangColors.crimson.withValues(alpha: 0.18)
                        : TabangColors.crimsonSoft,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(TabangRadius.md),
                      topRight: Radius.circular(3),
                      bottomLeft: Radius.circular(TabangRadius.md),
                      bottomRight: Radius.circular(TabangRadius.md),
                    ),
                    border: Border.all(
                      color: TabangColors.crimson.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Text(
                    faq.answer,
                    // Document-style copy: answers stay left-aligned even
                    // though the bubble is offset toward the chapter avatar.
                    textAlign: TextAlign.left,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.55,
                      color: context.textColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _faqAvatar(
                context,
                background: TabangColors.crimson,
                border: TabangColors.crimson,
                child: const Icon(
                  Icons.volunteer_activism,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _faqAvatar(
    BuildContext context, {
    required Color background,
    required Color border,
    required Widget child,
  }) {
    return Container(
      width: 26,
      height: 26,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        shape: BoxShape.circle,
        border: Border.all(color: border),
      ),
      child: child,
    );
  }

  // ------------------------------------------------------------------- about

  Widget _buildAbout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          padding: EdgeInsets.all(
            context.isPhone ? TabangSpace.lg : TabangSpace.xl,
          ),
          decoration: BoxDecoration(
            gradient: TabangGradients.brand,
            borderRadius: BorderRadius.circular(TabangRadius.lg),
            // A bright rim keeps the card from reading as a bare gradient
            // wash against the page background.
            border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            boxShadow: [
              BoxShadow(
                color: TabangColors.crimsonDark.withValues(alpha: 0.24),
                blurRadius: 26,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                    ),
                    child: const ClipOval(
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: TabangPhoto(
                          'assets/branding/app_icon.png',
                          semanticLabel: 'TABANG logo',
                          creditLabel: 'TABANG logo',
                          fallbackIcon: Icons.water_drop,
                          fallbackIconSize: 22,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: TabangSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'TABANG',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.4,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Transfusion Access, Blood Availability and '
                          'Network Guidance',
                          style: TextStyle(
                            fontSize: 12.5,
                            height: 1.4,
                            color: Colors.white.withValues(alpha: 0.84),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: TabangSpace.lg),
              Text(
                'A centralized donor-management and blood-availability '
                'platform for Digos City, Davao del Sur. TABANG connects '
                'voluntary donors, recipient representatives and chapter staff '
                'in one coordinated, alias-first network.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.65,
                  color: Colors.white.withValues(alpha: 0.92),
                ),
              ),
              const SizedBox(height: TabangSpace.md),
              const Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _AboutChip('Voluntary & unpaid'),
                  _AboutChip('RA 7719 aligned'),
                  _AboutChip('RA 10173 privacy'),
                  _AboutChip('Offline-first'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: TabangSpace.xl),

        _aboutSection(
          context,
          'What the platform does',
          'Four connected pieces, not four separate apps.',
          [
            const _Pillar(
              Icons.verified_user_outlined,
              'Verified donor directory',
              'Chapter staff verify blood cards. Community users browse by '
                  'barangay and blood type, and see only nicknames.',
            ),
            const _Pillar(
              Icons.map_outlined,
              'Availability map',
              '26 Digos barangays, donor density, blood-drive pins, streets '
                  'and landmarks. The map works offline.',
            ),
            const _Pillar(
              Icons.forum_outlined,
              'Chat-first coordination',
              'Recipients must exchange a real message with a donor before '
                  'selection. Identity reveals are bilateral.',
            ),
            const _Pillar(
              Icons.inventory_2_outlined,
              'Inventory & appointments',
              'Live stock by component, unit holds, appointment requests, and '
                  'staff-only fulfilment after clinical screening.',
            ),
          ],
        ),
        const SizedBox(height: TabangSpace.xl),

        _aboutSection(
          context,
          'Safety and privacy commitments',
          'The rules the prototype actually enforces.',
          [
            const _Pillar(
              Icons.lock_outline,
              'Alias-only public identity',
              'Real names and exact addresses stay private. Staff see identity '
                  'only for care coordination; users need a bilateral reveal.',
            ),
            const _Pillar(
              Icons.health_and_safety_outlined,
              'No paid blood',
              'Voluntary, non-remunerated donation only. Payment solicitation '
                  'in chat is flagged for moderation.',
            ),
            const _Pillar(
              Icons.fact_check_outlined,
              'Clinical re-checks',
              'Eligibility, stock and account status are re-checked at selection '
                  'and fulfilment. A hold is never a transfusion order.',
            ),
            const _Pillar(
              Icons.people_outline,
              'Human moderation',
              'Reports, blocks, warnings and suspensions are stored and handled '
                  'by chapter staff, not automated takedowns.',
            ),
          ],
        ),
        const SizedBox(height: TabangSpace.xl),

        _aboutSection(
          context,
          'How it fits the study',
          'Aligned with SDG 3 and SDG 9, and bounded as a prototype.',
          [
            const _Pillar(
              Icons.favorite_outline,
              'SDG 3 · Good health',
              'Shortens the path from an identified need to a compatible, '
                  'willing donor and supports safer, planned transfusions.',
            ),
            const _Pillar(
              Icons.hub_outlined,
              'SDG 9 · Innovation',
              'Demonstrates a low-cost, offline-capable digital health '
                  'infrastructure for a municipal blood network.',
            ),
            const _Pillar(
              Icons.science_outlined,
              'Simulated data',
              'All donors, recipients, units and appointments are simulated. '
                  'No hospital, PRC or EHR system is connected.',
            ),
            const _Pillar(
              Icons.school_outlined,
              'Research context',
              'A Senior High School research project at Cor Jesu College, Inc., '
                  'Digos City, Davao del Sur.',
            ),
          ],
        ),
        const SizedBox(height: TabangSpace.xl),

        _buildCredits(context),

        const SizedBox(height: TabangSpace.xl),
        _aboutSection(context, 'Known gaps', 'Documented rather than hidden.', [
          const _Pillar(
            Icons.key_outlined,
            'Production authentication',
            'Google OAuth 2.0 and production password KDF/release signing '
                'are not wired in this build.',
          ),
          const _Pillar(
            Icons.cloud_outlined,
            'Backend services',
            'Supabase/PostgreSQL, push notifications and multi-facility '
                'inventory require a deployed service.',
          ),
          const _Pillar(
            Icons.mic_none_outlined,
            'Voice calls',
            'Chat is text-only. Voice calling is out of scope for the '
                'prototype.',
          ),
          const _Pillar(
            Icons.photo_camera_outlined,
            'Profile uploads',
            'Profile pictures are original bundled illustrations; user upload '
                'and moderation are not implemented.',
          ),
        ]),
        const SizedBox(height: TabangSpace.xl),

        Center(
          child: Text(
            'TABANG · Cor Jesu College, Inc. · Digos City · 2026\n'
            'Built as a research prototype. Not a medical device and not a '
            'substitute for clinical judgement.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.7,
              color: context.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _aboutSection(
    BuildContext context,
    String title,
    String subtitle,
    List<Widget> children,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: context.textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: TextStyle(fontSize: 12.5, color: context.textMuted),
        ),
        const SizedBox(height: TabangSpace.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 820 ? 2 : 1;
            const gap = TabangSpace.md;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final child in children)
                  SizedBox(width: width, child: child),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _buildCredits(BuildContext context) {
    // Only photographs need attribution. Avatars, educational artwork and the
    // app icon are original TABANG artwork with no external author, so they are
    // not listed and no file paths are shown to users.
    final photos = kImageCredits.where((c) => c.kind == 'photo').toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Photo credits',
          style: TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
            color: context.textColor,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Every photograph is bundled locally and credited to its author. '
          'Tap a credit for the licence and source.',
          style: TextStyle(fontSize: 12.5, color: context.textMuted),
        ),
        const SizedBox(height: TabangSpace.md),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth > 820 ? 2 : 1;
            const gap = TabangSpace.md;
            final width =
                (constraints.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (final credit in photos)
                  SizedBox(width: width, child: _creditCard(context, credit)),
              ],
            );
          },
        ),
        const SizedBox(height: TabangSpace.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(TabangSpace.md),
          decoration: BoxDecoration(
            color: context.surfaceAlt,
            borderRadius: BorderRadius.circular(TabangSpace.sm),
          ),
          child: Text(
            'Profile portraits and educational illustrations are original '
            'TABANG artwork, so there is no external credit to list.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: context.textMuted,
            ),
          ),
        ),
      ],
    );
  }

  Widget _creditCard(BuildContext context, ImageCredit credit) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      onTap: () => _showCreditDialog(context, credit),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.horizontal(
              left: Radius.circular(TabangRadius.md - 1),
            ),
            child: SizedBox(
              width: 92,
              height: 92,
              child: TabangPhoto(
                credit.asset,
                semanticLabel: credit.title,
                fallbackIcon: Icons.image_outlined,
                fallbackIconSize: 24,
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(TabangSpace.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    credit.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      height: 1.3,
                      color: context.textColor,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${credit.author} · ${credit.license}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.35,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(6),
            child: Icon(Icons.open_in_new, size: 13, color: context.textMuted),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreditDialog(BuildContext context, ImageCredit credit) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(credit.title),
        content: SizedBox(
          width: 460,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(TabangRadius.sm),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: TabangPhoto(
                      credit.asset,
                      semanticLabel: credit.title,
                      fallbackIcon: Icons.image_outlined,
                      fallbackIconSize: 30,
                    ),
                  ),
                ),
                const SizedBox(height: TabangSpace.md),
                Text(
                  'Creator: ${credit.author}\nLicence: ${credit.license}',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.55,
                    color: context.textMuted,
                  ),
                ),
                if (credit.sourceUrl != null) ...[
                  const SizedBox(height: 8),
                  SelectableText(
                    credit.sourceUrl!,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.45,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _Guide {
  const _Guide({
    required this.title,
    required this.icon,
    required this.summary,
    required this.steps,
    required this.tip,
  });

  final String title;
  final IconData icon;
  final String summary;
  final List<String> steps;
  final String tip;
}

class _Pillar extends StatelessWidget {
  const _Pillar(this.icon, this.title, this.body);

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: context.isDark
                  ? TabangColors.crimson.withValues(alpha: 0.17)
                  : TabangColors.crimsonSoft,
              borderRadius: BorderRadius.circular(TabangRadius.xs),
            ),
            child: Icon(icon, size: 17, color: TabangColors.crimson),
          ),
          const SizedBox(width: TabangSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: context.textColor,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.55,
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
}

class _AboutChip extends StatelessWidget {
  const _AboutChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(TabangRadius.pill),
        border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
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
