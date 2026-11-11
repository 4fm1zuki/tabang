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

const List<ImageCredit> kImageCredits = [
  ImageCredit(
    asset: 'assets/images/hero_donation.jpg',
    title: 'Ramstein blood donation expands; saves lives',
    author: 'Tech. Sgt. Nicholas Alder, U.S. Air Force',
    license: 'Public domain',
    kind: 'photo',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:Ramstein_blood_donation_expands;_saves_lives_(7395800).jpg',
  ),

  // ---- blood drive photographs ------------------------------------------
  // One photograph per seeded drive, shown on the Discover rail and in the
  // drive dialog. Sourced from the Digos City drive posts listed at each URL.
  ImageCredit(
    asset: 'assets/images/Blood Drives/Digos City Gym Blood Drive.jpg',
    title: 'Digos City Gym blood drive',
    author: 'Digos City blood drive post (Facebook)',
    license: '© respective owner — used with attribution',
    kind: 'photo',
    sourceUrl: 'https://www.facebook.com/photo?fbid=1060831086767305',
  ),
  ImageCredit(
    asset: 'assets/images/Blood Drives/Barangay Matti Health Drive.jpg',
    title: 'Barangay Matti health drive',
    author: 'Digos City blood drive post (Facebook)',
    license: '© respective owner — used with attribution',
    kind: 'photo',
    sourceUrl: 'https://www.facebook.com/photo/?fbid=616910860479546',
  ),
  ImageCredit(
    asset: 'assets/images/Blood Drives/Cor Jesu College Campus Drive.jpg',
    title: 'Cor Jesu College campus blood drive',
    author: 'Digos City blood drive post (Facebook)',
    license: '© respective owner — used with attribution',
    kind: 'photo',
    sourceUrl: 'https://www.facebook.com/photo/?fbid=930597580118390',
  ),
  ImageCredit(
    asset: 'assets/images/Blood Drives/Aplaya Community Drive.jpg',
    title: 'Aplaya community blood drive',
    author: 'Digos City blood drive post (Facebook)',
    license: '© respective owner — used with attribution',
    kind: 'photo',
    sourceUrl: 'https://www.facebook.com/photo/?fbid=976350464147974',
  ),
  ImageCredit(
    asset: 'assets/images/Blood Drives/San Jose Community Bloodletting.jpg',
    title: 'San Jose community bloodletting',
    author: 'Digos City blood drive post (Facebook)',
    license: '© respective owner — used with attribution',
    kind: 'photo',
    sourceUrl:
        'https://www.facebook.com/photo.php?fbid=1381717860811720&type=3',
  ),

  // ---- announcement and story photographs -------------------------------
  ImageCredit(
    asset:
        "assets/images/Announcements & Stories/A stranger's donation saved my daughter's life.jpg",
    title: "A stranger's donation saved my daughter's life",
    author: 'iStock',
    license: '© iStock — stock licence',
    kind: 'photo',
    sourceUrl:
        'https://media.istockphoto.com/id/1168842147/photo/japanese-mother-sitting-with-young-daughter-in-hospital-bed.jpg',
  ),
  ImageCredit(
    asset:
        'assets/images/Announcements & Stories/daniel-article-1000x800px.png',
    title: 'Meet Mark: 50th blood donation milestone',
    author: 'Australian Red Cross Lifeblood',
    license: '© Australian Red Cross Lifeblood — used with attribution',
    kind: 'photo',
    sourceUrl:
        'https://www.lifeblood.com.au/sites/default/files/inline-images/daniel-article-1000x800px.png',
  ),
  ImageCredit(
    asset:
        'assets/images/Announcements & Stories/How Donation Helps the Whole Community.jpg',
    title: 'How donation helps the whole community',
    author: 'Pexels',
    license: 'Pexels licence',
    kind: 'photo',
    sourceUrl:
        'https://images.pexels.com/photos/37191927/pexels-photo-37191927.jpeg',
  ),

  // ---- learn and prepare article photographs ----------------------------
  ImageCredit(
    asset:
        'assets/images/Learn & Prepare/Hydration First Before Donating.jpg',
    title: 'Hydration first before donating',
    author: 'iStock',
    license: '© iStock — stock licence',
    kind: 'photo',
    sourceUrl:
        'https://media.istockphoto.com/id/454273399/photo/pouring-water-from-bottle-into-glass-on-blue-background.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/Learn & Prepare/Eat Iron-Rich Foods.jpg',
    title: 'Eat iron-rich foods',
    author: 'Pinterest',
    license: '© respective owner — source unverified',
    kind: 'photo',
    sourceUrl:
        'https://i.pinimg.com/1200x/a0/ba/c1/a0bac1179fce112e0c349d4cdca20d2c.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/Learn & Prepare/Post-Donation Rest & Recovery.jpg',
    title: 'Post-donation rest and recovery',
    author: 'Pinterest',
    license: '© respective owner — source unverified',
    kind: 'photo',
    sourceUrl:
        'https://i.pinimg.com/736x/ce/9f/47/ce9f47cb6e0899bdd66b351c0805095b.jpg',
  ),
  ImageCredit(
    asset:
        'assets/images/Learn & Prepare/Basic Requirements = Age, Weight & Health.jpg',
    title: 'Basic requirements: age, weight and health',
    author: 'metrobathandtile.com',
    license: '© metrobathandtile.com — replace, unrelated subject',
    kind: 'photo',
    sourceUrl:
        'https://metrobathandtile.com/wp-content/uploads/bathroom-remodel-checklist.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/Learn & Prepare/Can I Donate If I Got a Tattoo.jpg',
    title: 'Can I donate if I got a tattoo?',
    author: 'ChronicleLive',
    license: '© ChronicleLive — used with attribution',
    kind: 'photo',
    sourceUrl:
        'https://i2-prod.chroniclelive.co.uk/article21904589.ece/ALTERNATES/s1200f/0_Coronavirus-Fri-Nov-27-2020.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/Learn & Prepare/How Often Can You Donate.jpg',
    title: 'How often can you donate?',
    author: 'Pinterest',
    license: '© respective owner — source unverified',
    kind: 'photo',
    sourceUrl:
        'https://i.pinimg.com/1200x/82/f4/9d/82f49d97a91592c23d6416f490c1d2c8.jpg',
  ),
  ImageCredit(
    asset:
        'assets/images/Learn & Prepare/Why TABANG Never Shows Real Names.jpg',
    title: 'Why TABANG never shows real names',
    author: 'Business Insider',
    license: '© Business Insider — used with attribution',
    kind: 'photo',
    sourceUrl:
        'https://i.insider.com/65f34ab9857f90b71522b4e4?width=1000&format=jpeg&auto=webp',
  ),
  ImageCredit(
    asset:
        'assets/images/Learn & Prepare/What to Bring on Donation Day.jpg',
    title: 'What to bring on donation day',
    author: 'Donate Plasma (Webflow CDN)',
    license: '© used with attribution',
    kind: 'photo',
    sourceUrl:
        'https://cdn.prod.website-files.com/5f854ebf1a80ea53fd7df5da/67a2fbb7a16262019f19626f_donate-life-saving-plasma_main.jpeg',
  ),
  ImageCredit(
    asset:
        'assets/images/Learn & Prepare/Plan Your Recovery After Donation.jpg',
    title: 'Plan your recovery after donation',
    author: 'Kajabi CDN',
    license: '© used with attribution',
    kind: 'photo',
    sourceUrl:
        'https://kajabi-storefronts-production.kajabi-cdn.com/kajabi-storefronts-production/blogs/30933/images/30dSVaBPR7mN2PqJpkDc_sleep-supports-holistic-healing.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_hydration.jpg',
    title: 'Still mineral water poured into a glass',
    author: 'Walter J. Pilsak, Waldsassen',
    license: 'CC BY-SA 3.0',
    kind: 'photo',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:Stilles_Mineralwasser.jpg',
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
    title: 'Bloodletting and blood donation, Philippine Red Cross, Baliuag',
    author: 'Judgefloro',
    license: 'CC0',
    kind: 'photo',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:09104jfBloodletting_Blood_donation_Philippine_Red_Cross_SM_City_Baliuagfvf_07.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/drive_community.jpg',
    title: 'Blood donation drive at a mall activity centre, Baliuag',
    author: 'Judgefloro',
    license: 'CC0',
    kind: 'photo',
    sourceUrl: 'https://commons.wikimedia.org/wiki/File:09104jfBloodletting_Blood_donation_Philippine_Red_Cross_SM_City_Baliuagfvf_04.jpg',
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
    title: 'Blood donor registration desk, Philippine Red Cross, Baliuag',
    author: 'Judgefloro',
    license: 'CC0',
    kind: 'photo',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:09104jfBloodletting_Blood_donation_Philippine_Red_Cross_SM_City_Baliuagfvf_08.jpg',
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
    title: 'Blood donation beds at a Philippine Red Cross drive, Baliuag',
    author: 'Judgefloro',
    license: 'CC0',
    kind: 'photo',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:09104jfBloodletting_Blood_donation_Philippine_Red_Cross_SM_City_Baliuagfvf_03.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_community.jpg',
    title: 'Registration and screening at a community blood drive, Baliuag',
    author: 'Judgefloro',
    license: 'CC0',
    kind: 'photo',
    sourceUrl:
        'https://commons.wikimedia.org/wiki/File:09104jfBloodletting_Blood_donation_Philippine_Red_Cross_SM_City_Baliuagfvf_14.jpg',
  ),
  ImageCredit(
    asset: 'assets/images/content_aftercare.jpg',
    title: 'Dugtong Buhay Caravan blood donation, Bulacan',
    author: 'Philippine Red Cross',
    license: '© Philippine Red Cross — used with attribution',
    kind: 'photo',
    sourceUrl: 'https://redcross.org.ph/2023/05/30/prc-and-rmns-dugtong-buhay-caravan-draws-blood-donors-in-bulacan/',
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
