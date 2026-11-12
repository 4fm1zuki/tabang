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
| `assets/images/content_drive.jpg` | [Bloodletting – Blood donation, Philippine Red Cross, SM City Baliuag 07](https://commons.wikimedia.org/wiki/File:09104jfBloodletting_Blood_donation_Philippine_Red_Cross_SM_City_Baliuagfvf_07.jpg) | CC0 | Judgefloro |
| `assets/images/drive_community.jpg` | [Bloodletting – Blood donation, Philippine Red Cross, SM City Baliuag 04](https://commons.wikimedia.org/wiki/File:09104jfBloodletting_Blood_donation_Philippine_Red_Cross_SM_City_Baliuagfvf_04.jpg) | CC0 | Judgefloro |

## Discover page photography

The Discover (Home) rail uses one photograph per seeded item, kept in a folder
per group. These files were supplied with the sources below; the licence column
records the terms the source states, so the team can replace anything that is
not cleared for redistribution before a public release.

| Bundled asset | Source | Licence / credit |
| --- | --- | --- |
| `assets/images/Blood Drives/Digos City Gym Blood Drive.jpg` | [Facebook post](https://www.facebook.com/photo?fbid=1060831086767305) | © respective owner - used with attribution |
| `assets/images/Blood Drives/Barangay Matti Health Drive.jpg` | [Facebook post](https://www.facebook.com/photo/?fbid=616910860479546) | © respective owner - used with attribution |
| `assets/images/Blood Drives/Cor Jesu College Campus Drive.jpg` | [Facebook post](https://www.facebook.com/photo/?fbid=930597580118390) | © respective owner - used with attribution |
| `assets/images/Blood Drives/Aplaya Community Drive.jpg` | [Facebook post](https://www.facebook.com/photo/?fbid=976350464147974) | © respective owner - used with attribution |
| `assets/images/Blood Drives/San Jose Community Bloodletting.jpg` | [Facebook post](https://www.facebook.com/photo.php?fbid=1381717860811720&type=3) | © respective owner - used with attribution |
| `assets/images/Announcements & Stories/A stranger's donation saved my daughter's life.jpg` | [iStock](https://media.istockphoto.com/id/1168842147/photo/japanese-mother-sitting-with-young-daughter-in-hospital-bed.jpg) | © iStock - stock licence |
| `assets/images/Announcements & Stories/daniel-article-1000x800px.png` | [Australian Red Cross Lifeblood](https://www.lifeblood.com.au/sites/default/files/inline-images/daniel-article-1000x800px.png) | © Australian Red Cross Lifeblood - used with attribution |
| `assets/images/Announcements & Stories/How Donation Helps the Whole Community.jpg` | [Pexels](https://images.pexels.com/photos/37191927/pexels-photo-37191927.jpeg) | Pexels licence |
| `assets/images/Learn & Prepare/Hydration First Before Donating.jpg` | [iStock](https://media.istockphoto.com/id/454273399/photo/pouring-water-from-bottle-into-glass-on-blue-background.jpg) | © iStock - stock licence |
| `assets/images/Learn & Prepare/Eat Iron-Rich Foods.jpg` | [Pinterest](https://i.pinimg.com/1200x/a0/ba/c1/a0bac1179fce112e0c349d4cdca20d2c.jpg) | © respective owner - source unverified |
| `assets/images/Learn & Prepare/Post-Donation Rest & Recovery.jpg` | [Pinterest](https://i.pinimg.com/736x/ce/9f/47/ce9f47cb6e0899bdd66b351c0805095b.jpg) | © respective owner - source unverified |
| `assets/images/Learn & Prepare/Basic Requirements = Age, Weight & Health.jpg` | [metrobathandtile.com](https://metrobathandtile.com/wp-content/uploads/bathroom-remodel-checklist.jpg) | © metrobathandtile.com - unrelated subject, must be replaced |
| `assets/images/Learn & Prepare/Can I Donate If I Got a Tattoo.jpg` | [ChronicleLive](https://i2-prod.chroniclelive.co.uk/article21904589.ece/ALTERNATES/s1200f/0_Coronavirus-Fri-Nov-27-2020.jpg) | © ChronicleLive - used with attribution |
| `assets/images/Learn & Prepare/How Often Can You Donate.jpg` | [Pinterest](https://i.pinimg.com/1200x/82/f4/9d/82f49d97a91592c23d6416f490c1d2c8.jpg) | © respective owner - source unverified |
| `assets/images/Learn & Prepare/Why TABANG Never Shows Real Names.jpg` | [Business Insider](https://i.insider.com/65f34ab9857f90b71522b4e4) | © Business Insider - used with attribution |
| `assets/images/Learn & Prepare/What to Bring on Donation Day.jpg` | [Donate Plasma CDN](https://cdn.prod.website-files.com/5f854ebf1a80ea53fd7df5da/67a2fbb7a16262019f19626f_donate-life-saving-plasma_main.jpeg) | © used with attribution |
| `assets/images/Learn & Prepare/Plan Your Recovery After Donation.jpg` | [Kajabi CDN](https://kajabi-storefronts-production.kajabi-cdn.com/kajabi-storefronts-production/blogs/30933/images/30dSVaBPR7mN2PqJpkDc_sleep-supports-holistic-healing.jpg) | © used with attribution |

The photographs are illustrative. They do not depict TABANG users or patients,
and the people shown have no connection to the simulated records in the app.

## Original TABANG artwork

These files are generated for TABANG by the scripts in `tools/`. They are the
project's own work and are released under the same CC0-style terms as the rest
of the prototype assets.

| Bundled asset | Title | Creator | Licence |
| --- | --- | --- | --- |
| `assets/branding/app_icon.png` | TABANG logo: blood drop, heart and hand | TABANG original artwork (`assets/logo.jpg`, generated by `tools/make_logo_assets.py`) | Original / CC0 |

## Profile portraits

`assets/images/avatars/avatar_001.png` through `avatar_048.png` are 48 unique
original portraits generated for TABANG by `tools/make_avatars.py`. No portrait
is reused across the seeded accounts. The UI identifies the individual file in
the hover credit (for example, *Profile illustration for Liza
(avatar_012.png)*) rather than showing a single generic avatar credit.

```bash
python tools/make_media_assets.py   # photographs and launcher icons
python tools/make_avatars.py        # 48 profile portraits
```

The source photographs are kept in this folder so the processed assets can be
regenerated. No image in this repository is fetched at runtime.
