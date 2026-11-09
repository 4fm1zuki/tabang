/// Per-asset provenance for every image bundled with TABANG.
///
/// The prototype deliberately ships all photography and artwork inside the
/// application package: there are no runtime image requests and therefore no
/// third-party service can silently swap the picture behind a credit. This
/// registry is the single lookup used by [TabangPhoto], the article dialogs and
/// the About & Help credits panel, so a displayed credit always matches the
/// file being rendered.
library;

class ImageCredit {
  const ImageCredit({
    required this.asset,
    required this.title,
    required this.author,
    required this.license,
    required this.kind,
    this.sourceUrl,
  });

  final String asset;
  final String title;
  final String author;
  final String license;

  /// `photo`, `illustration`, `avatar` or `icon`.
  final String kind;
  final String? sourceUrl;

  String get short => '$title · $author · $license';

  String get compact => '$author · $license';

  bool get isOriginal =>
      kind == 'avatar' || kind == 'illustration' || kind == 'icon';
}

const String kAvatarDirectory = 'assets/images/avatars/';
const String kEducationalDirectory = 'assets/images/educational/';

const List<ImageCredit> kImageCredits = [
  ImageCredit(
    asset: 'assets/images/hero_donation.jpg',
    title: 'Ramstein blood donation expands; saves lives',
    author: 'Tech. Sgt. Nicholas Alder, U.S. Air Force',
    license: 'Public domain',
    kind: 'photo',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Ramstein_blood_donation_expands;_saves_lives_(7395800).jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_hydration.jpg',
    title: 'Boy drinks water from a glass at home',
    author: 'Shixart1985',
    license: 'CC BY 2.0',
    kind: 'photo',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Boy_drinks_water_from_glass_in_a_cozy_home_environment.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_nutrition.jpg',
    title: 'Salad greens and vegetables, Cambridge, MA',
    author: 'Daderot',
    license: 'CC0',
    kind: 'photo',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Salad_greens_and_vegetables_-_Cambridge,_MA.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_recovery.jpg',
    title: 'Applying the bandage after a blood donation',
    author: 'Tech. Sgt. Nicholas Alder, U.S. Air Force',
    license: 'Public domain',
    kind: 'photo',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Ramstein_blood_donation_expands;_saves_lives_(7395803).jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_screening.jpg',
    title: 'U.S. Naval Hospital Guam phlebotomist draws blood',
    author:
        'Mass Communication Specialist 2nd Class Gabrielle Blake, U.S. Navy',
    license: 'Public domain',
    kind: 'photo',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:US_Navy_120126-N-GE301-042_U.S._Naval_Hospital_Guam%27s_phlebotomist_Dio_Patague_draws_blood_from_the_arm_of_Hospital_Corpsman_1st_Class_Karla_Manuel.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_drive.jpg',
    title: 'A donated bag of blood held at a collection session',
    author: 'Bibeyjj',
    license: 'CC BY-SA 4.0',
    kind: 'photo',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Blood_Donation_Bag.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/drive_community.jpg',
    title: 'Blood donation camp with donors resting on beds',
    author: 'Ameyawiki',
    license: 'CC BY-SA 4.0',
    kind: 'photo',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Blood_donation_GIFT.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_story.jpg',
    title: 'Philippine National Red Cross blood draw, Zamboanga',
    author: "Photographer's Mate 1st Class Michael R. McCormick, U.S. Navy",
    license: 'Public domain',
    kind: 'photo',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:US_Navy_060531-N-3931M-035_Jennifer_E._Marcos,_a_medical_technician_and_chapter_service_representative_for_the_Philippine_National_Red_Cross,_draws_blood.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_privacy.jpg',
    title: 'Anonymised blood donor card with name and number redacted',
    author: 'Wikimedia Commons contributor',
    license: 'CC BY-SA 4.0',
    kind: 'photo',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Blood_donor_card_japan_20141024.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_tattoo.jpg',
    title: 'Tattooed upper arm',
    author: 'Tony Alter',
    license: 'CC BY 2.0',
    kind: 'photo',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Arm_tattoo_of_Neptune.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_donation_day.jpg',
    title: 'Needle in place during a blood donation',
    author: 'Makysm',
    license: 'CC0',
    kind: 'photo',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Blood_donation_process.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_aftercare.jpg',
    title: 'Resting the arm after a plasma donation',
    author: 'U3061292',
    license: 'CC BY-SA 3.0',
    kind: 'photo',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:After_Plasma_Donation.jpg',
  ),
  ImageCredit(
    asset: 'assets/branding/app_icon.png',
    title: 'TABANG launcher icon',
    author: 'TABANG original artwork (tools/make_media_assets.py)',
    license: 'Original / CC0',
    kind: 'icon',
  ),
  ImageCredit(
    asset: 'assets/branding/prc_logo.png',
    title: 'Philippine Red Cross emblem',
    author: 'Philippine Red Cross',
    license: 'Public domain (PD-ineligible)',
    kind: 'icon',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Logo_Philippine_Red_Cross.svg',
  ),
  ImageCredit(
    asset: '${kEducationalDirectory}edu_benefits.png',
    title: 'One donation, three lives',
    author: 'TABANG original artwork (tools/make_edu_art.py)',
    license: 'Original / CC0',
    kind: 'illustration',
  ),
  ImageCredit(
    asset: '${kEducationalDirectory}edu_help.png',
    title: 'Donation supports patients and families',
    author: 'TABANG original artwork (tools/make_edu_art.py)',
    license: 'Original / CC0',
    kind: 'illustration',
  ),
  ImageCredit(
    asset: '${kEducationalDirectory}edu_prepare.png',
    title: 'Preparing for a donation',
    author: 'TABANG original artwork (tools/make_edu_art.py)',
    license: 'Original / CC0',
    kind: 'illustration',
  ),
  ImageCredit(
    asset: '${kEducationalDirectory}edu_aftercare.png',
    title: 'Rest and recovery after donating',
    author: 'TABANG original artwork (tools/make_edu_art.py)',
    license: 'Original / CC0',
    kind: 'illustration',
  ),
  ImageCredit(
    asset: '${kEducationalDirectory}edu_facts.png',
    title: 'Blood components and compatibility facts',
    author: 'TABANG original artwork (tools/make_edu_art.py)',
    license: 'Original / CC0',
    kind: 'illustration',
  ),
  ImageCredit(
    asset: '${kEducationalDirectory}edu_eligibility.png',
    title: 'Donor eligibility checklist',
    author: 'TABANG original artwork (tools/make_edu_art.py)',
    license: 'Original / CC0',
    kind: 'illustration',
  ),
  ImageCredit(
    asset: '${kEducationalDirectory}drive_locator.png',
    title: 'Find a nearby blood drive',
    author: 'TABANG original artwork (tools/make_edu_art.py)',
    license: 'Original / CC0',
    kind: 'illustration',
  ),
];

final Map<String, ImageCredit> _creditsByAsset = {
  for (final credit in kImageCredits) credit.asset: credit,
};

/// Look up the credit for [asset]. Avatar files receive an individual entry
/// named after the file so every portrait is still identifiable on its own.
ImageCredit? creditForAsset(String? asset, {String? label}) {
  if (asset == null || asset.isEmpty) return null;
  final exact = _creditsByAsset[asset];
  if (exact != null) return exact;

  if (asset.startsWith(kAvatarDirectory)) {
    final file = asset.split('/').last;
    return ImageCredit(
      asset: asset,
      title: label == null
          ? 'Profile illustration $file'
          : 'Profile illustration for $label ($file)',
      author: 'TABANG original artwork (tools/make_avatars.py)',
      license: 'Original / CC0',
      kind: 'avatar',
    );
  }

  return null;
}

/// Credits for the photographic content collection, in display order.
List<ImageCredit> get photoCredits =>
    kImageCredits.where((c) => c.kind == 'photo').toList(growable: false);

/// Credits for the original educational illustrations.
List<ImageCredit> get illustrationCredits => kImageCredits
    .where((c) => c.kind == 'illustration')
    .toList(growable: false);
