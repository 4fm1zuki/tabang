# Image credits and licences

TABANG ships every photograph and illustration inside the application package,
so the interface works offline and the app makes no third-party image requests
at runtime. This file is the audit copy of `lib/core/image_credits.dart`, the
single registry the UI reads. Each displayed image gets its own visible caption
under the image and a hover/detail credit naming the exact file, creator,
licence and source link.

## Photography

| Bundled asset | Source (Wikimedia Commons) | Licence | Author / credit |
| --- | --- | --- | --- |
| `assets/images/hero_donation.jpg` | [Ramstein blood donation expands; saves lives (7395800)](https://commons.wikimedia.org/wiki/File:Ramstein_blood_donation_expands;_saves_lives_(7395800).jpg) | Public domain | U.S. Air Force photo by Tech. Sgt. Nicholas Alder |
| `assets/images/content_hydration.jpg` | [Boy drinks water from a glass at home](https://commons.wikimedia.org/wiki/File:Boy_drinks_water_from_glass_in_a_cozy_home_environment.jpg) | CC BY 2.0 | Shixart1985 |
| `assets/images/content_nutrition.jpg` | [Salad greens and vegetables – Cambridge, MA](https://commons.wikimedia.org/wiki/File:Salad_greens_and_vegetables_-_Cambridge,_MA.jpg) | CC0 | Daderot |
| `assets/images/content_recovery.jpg` | [Ramstein blood donation expands; saves lives (7395803)](https://commons.wikimedia.org/wiki/File:Ramstein_blood_donation_expands;_saves_lives_(7395803).jpg) | Public domain | U.S. Air Force photo by Tech. Sgt. Nicholas Alder |
| `assets/images/content_screening.jpg` | [U.S. Naval Hospital Guam phlebotomist draws blood](https://commons.wikimedia.org/wiki/File:US_Navy_120126-N-GE301-042_U.S._Naval_Hospital_Guam%27s_phlebotomist_Dio_Patague_draws_blood_from_the_arm_of_Hospital_Corpsman_1st_Class_Karla_Manuel.jpg) | Public domain | U.S. Navy photo by Mass Communication Specialist 2nd Class Gabrielle Blake |
| `assets/images/content_drive.jpg` | [Blood Donation Bag](https://commons.wikimedia.org/wiki/File:Blood_Donation_Bag.jpg) | CC BY-SA 4.0 | Bibeyjj |
| `assets/images/drive_community.jpg` | [Blood donation GIFT](https://commons.wikimedia.org/wiki/File:Blood_donation_GIFT.jpg) | CC BY-SA 4.0 | Ameyawiki |
| `assets/images/content_story.jpg` | [Philippine National Red Cross blood draw, Zamboanga](https://commons.wikimedia.org/wiki/File:US_Navy_060531-N-3931M-035_Jennifer_E._Marcos,_a_medical_technician_and_chapter_service_representative_for_the_Philippine_National_Red_Cross,_draws_blood.jpg) | Public domain | U.S. Navy photo by Photographer's Mate 1st Class Michael R. McCormick |
| `assets/images/content_privacy.jpg` | [Blood donor card japan 20141024](https://commons.wikimedia.org/wiki/File:Blood_donor_card_japan_20141024.jpg) | CC BY-SA 4.0 | Wikimedia Commons contributor |
| `assets/images/content_tattoo.jpg` | [Arm tattoo of Neptune](https://commons.wikimedia.org/wiki/File:Arm_tattoo_of_Neptune.jpg) | CC BY 2.0 | Tony Alter |
| `assets/images/content_donation_day.jpg` | [Blood donation process](https://commons.wikimedia.org/wiki/File:Blood_donation_process.jpg) | CC0 | Makysm |
| `assets/images/content_aftercare.jpg` | [After Plasma Donation](https://commons.wikimedia.org/wiki/File:After_Plasma_Donation.jpg) | CC BY-SA 3.0 | U3061292 |

The photographs are illustrative. They do not depict TABANG users or patients,
and the people shown have no connection to the simulated records in the app.

## Original TABANG artwork

These files are generated for TABANG by the scripts in `tools/`. They are the
project's own work and are released under the same CC0-style terms as the rest
of the prototype assets.

| Bundled asset | Title | Creator | Licence |
| --- | --- | --- | --- |
| `assets/branding/app_icon.png` | TABANG launcher icon | TABANG original artwork (`tools/make_media_assets.py`) | Original / CC0 |
| `assets/images/educational/edu_benefits.png` | One donation, three lives | TABANG original artwork (`tools/make_edu_art.py`) | Original / CC0 |
| `assets/images/educational/edu_help.png` | Donation supports patients and families | TABANG original artwork (`tools/make_edu_art.py`) | Original / CC0 |
| `assets/images/educational/edu_prepare.png` | Preparing for a donation | TABANG original artwork (`tools/make_edu_art.py`) | Original / CC0 |
| `assets/images/educational/edu_aftercare.png` | Rest and recovery after donating | TABANG original artwork (`tools/make_edu_art.py`) | Original / CC0 |
| `assets/images/educational/edu_facts.png` | Blood components and compatibility facts | TABANG original artwork (`tools/make_edu_art.py`) | Original / CC0 |
| `assets/images/educational/edu_eligibility.png` | Donor eligibility checklist | TABANG original artwork (`tools/make_edu_art.py`) | Original / CC0 |
| `assets/images/educational/drive_locator.png` | Find a nearby blood drive | TABANG original artwork (`tools/make_edu_art.py`) | Original / CC0 |

## Profile portraits

`assets/images/avatars/avatar_001.png` through `avatar_048.png` are 48 unique
original portraits generated for TABANG by `tools/make_avatars.py`. No portrait
is reused across the seeded accounts. The UI identifies the individual file in
the hover credit (for example, *Profile illustration for Liza
(avatar_012.png)*) rather than showing a single generic avatar credit.

```bash
python tools/make_media_assets.py   # photographs, privacy art and launcher icons
python tools/make_avatars.py        # 48 profile portraits
python tools/make_edu_art.py        # seven educational illustrations
```

The source photographs are kept in this folder so the processed assets can be
regenerated. No image in this repository is fetched at runtime.
