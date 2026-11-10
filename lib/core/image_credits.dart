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
