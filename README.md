# TABANG

**Transfusion Access, Blood Availability and Network Guidance**

A centralized donor management system for Digos City, Davao del Sur. Built as a
Senior High School research project at Cor Jesu College, Inc.

> **This is a simulated-data research prototype.** It runs entirely on synthetic
> donor records, inventory and request workflows. It is not connected to live
> blood-service databases, hospital electronic health records, or Philippine Red
> Cross systems. See [Scope](#scope) below.

> **Title note.** The paper's cover and acknowledgement pages use *Transfusion
> Access, Blood Availability and Network Guidance*. Two body pages abbreviate
> the last word as "Analytics"; this build follows the official title.

---

## Quick start

Requirements:

- Flutter **3.47.0 or newer** (tested with Flutter 3.47.5)
- Dart **3.13.0 or newer** (tested with Dart 3.13.4)
- No map key and no network: the Digos map and all photography are bundled

```bash
flutter pub get
flutter run -d chrome      # or: -d windows, -d android
```

Run the checks used for this build:

```bash
flutter analyze
flutter test
flutter build web --release
```

There is no backend to start. The repository is seeded in memory at launch and
resets when the process restarts. Supabase is intentionally **not** a
dependency in this build; an unused client would imply a live connection that
does not exist.

### Demo accounts

Sign in with any of these. The login screen lists them too; click a row to
autofill.

| Role | Email | Password |
|---|---|---|
| Donor | `iverson.briones@tabang.app` | `donor1234` |
| Donor | `tere.santos@tabang.app` | `donor1234` |
| Recipient | `maria.santos@tabang.app` | `recipient1234` |
| Community | `community@tabang.app` | `community1234` |
| Staff | `staff@tabang.app` | `staff1234` |
| Admin | `admin@tabang.app` | `admin1234` |

Administrative roles are seeded only. Self-registration always creates a
community account: new users can request blood and browse donors immediately,
then opt in to donating through **Donor Hub → Register as a donor**. The
upgrade asks for blood type, birth date and weight; the account stays
unverified until chapter staff check the donor's blood card. `AuthService`
rejects `UserRole.admin` and `UserRole.staff` self-registration even if the UI
were bypassed.

---

## What the app does

### Donor / recipient surface

- **Discover** — one compact toolbar, then horizontal rails for upcoming blood
  drives, announcements and stories, and short learning cards, ending with a
  visit planner. The urgent shortage callout lives on Blood Bank and the map,
  not here. Blood-drive cards open venue, schedule and expected-donor details,
  and every photograph carries a visible author/licence chip: tap or long-press
  the chip for the exact file and source link. Original TABANG artwork shows no
  external source because it has none.
- **Blood Bank** — the chapter banner, a one-line stock note, a public stock
  grid by component and blood type, then a *card list* of units (product,
  storage, expiry, status) that reflows one to three columns and highlights on
  hover. The full record — unit ID, storage, dates and who holds it — opens on
  selection; the barcode graphic itself belongs to the staff inventory. Community
  users can place or release a *hold* on a usable unit and book an
  **appointment with blood** (blood type, patient name, donation type, patient
  hospital and ward, amount and slot). A hold is not a transfusion order:
  chapter staff still cross-match and confirm release.
- **Find Donor** — the Digos City vector map, adopted from the standalone
  `digos_barangay_map` project: `flutter_map` renders OpenStreetMap base tiles
  behind an inverse mask that hides everything outside the city, and the
  barangay topology ships locally in `lib/core/digos_geodata.dart` (26
  barangays stitched from 75 shared border arcs plus the outer city ring, so no
  mapping SDK or API key is involved). Every TABANG layer is drawn on top
  locally, so the map still reads when tiles cannot load: a warm-crimson donor
  density ramp, tappable blood-drive pins with counts, haloed barangay labels
  that thin out at city-wide zoom, and a gold selection. The palette was
  re-coloured from the map project's green/teal scheme to the app's crimson,
  maroon and gold set. A single compass control re-frames the full north-up
  city, `+`/`−` step the zoom, the light/dark map style is independent of the
  app theme, and OpenStreetMap attribution is shown on the canvas. Blood-type
  chips keep clear of the control stack. Tapping a barangay filters the donor
  list; the donor pane expands/collapses explicitly, and each card offers
  Message and Requests actions.
- **Donor Hub** — a dedicated donor tab with eligibility window, next available
  date, donation history and availability controls. Community users fill up a
  **donor registration form** here: personal data, the medical-history
  checklist from the PRC Blood Donor Interview Sheet, and the donor
  declaration. The account becomes a donor immediately but stays *unverified*
  — the eligibility engine will not match an unverified donor — and staff
  verifies the blood card after the in-person interview, examination, blood
  typing and screening. Donors see a verification card with what chapter staff
  has requested, and keep one-tap access to requests and messages because
  donating and needing blood are not mutually exclusive.
- **Requests** — a recipient posts a request; the dialog first checks
  participating-facility stock and explains what each urgency level means
  (critical = now, urgent = 24–48 h, routine = planned). If compatible stock
  exists, the request can go to the blood bank; otherwise it is posted to the
  donor network. Donors see only requests their blood type and component can
  serve, and only while they are eligible; every card has a **⋯ menu with View
  details** for the full record. Donors also get a second **Donate** tab with
  the drives they can join, their eligibility window and what to bring.
  **Chat comes first:** the requester must exchange a real, reciprocal human
  message with a donor before selection is enabled, and a system notice does
  not count.
- **Messages** — double-blind coordination threads, bilateral identity reveal
  (request then accept), block/unblock with a 48-hour re-block cooldown, and
  persisted reports to staff.
- **Profile** — per-component eligibility view, blood-card verification state,
  availability, blood type, weight, last donation component, and notification
  preferences.
- **Settings** — appearance (system/light/dark), notification summaries, donor
  availability, privacy/data and account sections, each with a contextual `?`
  help tip.
- **Guides & Help** — a separate destination with task guides (donating,
  requesting, messaging, Discover, profile/donor registration and settings),
  searchable FAQs and **About TABANG**, which is a platform summary with SDG
  alignment, safety commitments, known gaps and per-image credits as supporting
  content.

### Staff / admin surface

- **Statistics** — a KIN-SCORE-style hierarchy: one weighted readiness score
  with a gauge and four labelled subscores, primary KPI cards with progress
  bars, supply/community detail, then supporting exceptions. Every figure is
  computed from the repository. **User management** opens with the donor
  registrations awaiting staff, where each form can be read, verified,
  returned for documents or not accepted.
- **Inventory** — units are a tappable list; selecting one opens the full
  record including the barcode graphic and the name of the person holding it.
- **Inventory** — change unit status, monitor effective expiry pressure, confirm
  holds and appointments, and work the request queue. Only staff/admin can mark
  a request fulfilled.
- **Users** — create walk-in accounts with fixed-choice fields and a one-time
  temporary password, verify blood cards, issue warnings, suspend and reinstate
  donor and recipient accounts, and record a completed donation with its
  component. Staff cannot manage their own account, another staff account, or
  an admin; only an admin can manage another staff member or add staff.
- **Moderation** — review flagged messages, clear or escalate flags, mute
  threads, and resolve or dismiss the persisted user-report queue.

---

## Paper alignment

| Paper requirement | Implementation in this build |
|---|---|
| Recipient checks compatible stock before posting to the donor network (p.8/21) | `BloodRequestDialog` calls `TabangRepository.compatibleUnitsFor`. Stock present → blood-bank or donor-network branch; no stock → donor-network branch only. |
| ABO/Rh compatibility matching (p.9/11) | `Compatibility` implements the red-cell matrix and inverse recipient sets. The request board, donor directory and inventory filters use it. |
| Component-aware compatibility and cooldowns (p.11) | `EligibilityEngine` uses 84 days for whole blood/packed RBC, 14 days for platelets, and 28 days for plasma. Plasma uses the reverse ABO rule; platelets use the red-cell baseline in this prototype. |
| Read-only inventory visibility (SEIPS, p.11) | The donation history and public stock are read-only. Community users may place a time-limited hold, but dispatch, quarantine, cross-matching, expiry and final reservation release remain staff actions. |
| Double-blind messaging and privacy (p.34) | Users see aliases. Real names/contact details appear only after a bilateral reveal request is accepted. Selection requires a reciprocal human chat first. |
| Reports, blocks and moderation (p.12/24) | Reports persist in the repository and appear in the staff queue. Blocking disables messaging in both directions and enforces a 48-hour re-block cooldown. |
| Expiry-aware inventory (p.15) | `BloodUnit.effectiveStatus` marks expired stock even if its stored status is still `available`; expired units are excluded from usable stock, compatibility counts and expiring-soon lists. |
| Donor eligibility: age 18–65, weight, availability, standing (p.17) | `EligibilityEngine` enforces the rules; registration computes exact age, rejects donors outside 18–65, and requires a self-reported weight. Donors below 50 kg or without a recorded weight are blocked from matching. |
| Registration fields (p.22) | A three-step community-account wizard collects full name, unique nickname, email, contact number, birth date, blood type, weight and barangay. Everything is persisted; the nickname is the only public identity. Donor status is a separate opt-in upgrade in Donor Hub. |
| Email credential authentication (p.28) | Salted SHA-256 credential store, session routing by role, and no self-service admin/staff registration. |
| Request lifecycle and staff-only fulfilment | Donor-network: open → matched (after chat-first selection) → fulfilled (staff/admin only). Blood-bank: staff process the request and fulfil it directly. Cancellation is guarded; fulfilled/cancelled requests cannot be re-opened or fulfilled twice. |
| Appointment with blood | `DonationAppointment` records patient name, blood type, component, hospital, ward, units and slot. Requesters book; staff confirm. A slot does not allocate a specific bag. |
| Image attribution | Every bundled file has its own entry in `lib/core/image_credits.dart`, a visible caption under the image and a hover/detail credit with title, author, licence and source URL. |
| SUS / SEIPS evaluation (external) | The app supplies the workflow and criteria; the SUS/SEIPS surveys are conducted externally and are not embedded. |
| Simulated data only, no live PRC/EHR integration | The repository is in-memory synthetic data. No live integration exists. |

### Known gaps against the paper

| Paper reference | Status |
|---|---|
| Google OAuth 2.0 (p.28) | **Not implemented.** Requires a provisioned OAuth client. Email credential auth is fully functional. |
| Supabase/PostgreSQL backend (p.27) | **Not implemented.** The app uses the in-memory repository; no Supabase client is shipped. |
| Voice calls (p.24) | **Not implemented.** Messaging works; the call affordance is absent rather than dead. |
| Profile picture upload (p.26) | **Not implemented.** No image-picker dependency. |
| Push notifications | **Not implemented.** Discover shows in-app summaries; delivery requires a deployed backend and notification service. |
| Multi-facility inventory | **Partial.** The app has a participating-facility list and a request-source branch, but no per-facility stock ledger or inter-facility transfer workflow. |
| Clinical screening | **Not implemented.** Weight is self-reported and there is no pre-donation physical examination, hemoglobin check, or clinician clearance. The app enforces the recorded eligibility rules only. |
| Production authentication | **Prototype only.** Credentials are salted and SHA-256 hashed in memory; a production system needs a persistent store, a memory-hard password KDF, rate limiting, and TLS. |
| Production release signing | **Prototype only.** Android release builds use the debug key; replace it before distributing an APK. |
| Desktop map support | **Supported.** The Digos map is a Flutter canvas, so Find Donor works on Windows, Linux and macOS without a fallback. |

---

## Architecture

```
lib/
├── main.dart                  # root; routes on session state, wraps navigator in SafeArea
├── theme.dart                 # M3 schemes, gradients, component themes
├── core/
│   ├── models.dart            # domain models, expiry, holds, appointments
│   ├── eligibility.dart       # component compatibility + cooldown engine
│   ├── repository.dart        # in-memory store, seed data, lifecycle, analytics
│   ├── auth.dart              # credential auth, role gating, donor upgrade
│   └── image_credits.dart     # per-asset provenance registry
├── widgets/
│   ├── common.dart            # shared UI kit, HelpTip, progress bars
│   ├── photo.dart             # TabangPhoto + visible PhotoCredit
│   └── blood_request_dialog.dart # stock-first request flow
└── screens/
    ├── auth/                  # login, community registration
    ├── donor/                 # DonorShell + Discover, Blood Bank, Map,
    │                          # Requests, Messages, Donor Hub
    ├── admin/                 # AdminShell + Statistics, Inventory, Users, Moderation
    └── shared/                # Settings, Profile, Guides & Help / About
```

### Key design decisions

**One data layer.** `TabangRepository` is the only place seed data lives. Donor,
recipient and staff surfaces read the same objects and stay in sync through a
listener.

**Eligibility is enforced, not displayed.** `EligibilityEngine` computes
cooldowns from `lastDonationDate` against per-component intervals. Donors in
cooldown are excluded from the directory and cannot respond to requests.
Recording a donation stores the component so the profile and audit trail are
consistent.

**Expiry is effective, not cosmetic.** A bag whose `expiresOn` has passed is
treated as expired even if its stored status was never changed. It is excluded
from available stock, compatible-unit counts and shortage calculations.

**The request lifecycle is explicit.** Donor responses are offers. Only the
requester (or staff) can select a response, and only after both sides have
exchanged a real human message; opening a thread or a system notice is not
enough. Selection creates one coordination thread and, once enough donors are
selected, moves a donor-network request to `matched`. Blood-bank requests are
processed by staff and can be fulfilled directly. Only staff/admin can mark a
request `fulfilled`; donor-network requests must be matched first. Cancelled and
fulfilled requests are terminal.

**Holds are not transfusions.** A community user can place a hold on a usable
unit so two people cannot claim the same bag, and can release it. Staff still
cross-match and confirm the release, and holds expire with the unit. The public
inventory never becomes an ordering system.

**Privacy is bilateral.** Aliases are the default identity. A reveal request
must be accepted by the other participant; declining or ignoring it leaves both
parties anonymous. Reports persist and blocking is symmetric for messaging.

**The public identity is a nickname, never the User ID.** A raw ID is
correlatable and unfriendly, while nicknames alone risk impersonation — so
TABANG combines both: the nickname is unique, case-insensitively enforced by
`AuthService._validateAlias`, and is the only handle shown on community
surfaces. The immutable `USR-…` ID stays internal for audit trails, blocks and
lifecycle rules, and real names appear only in staff tools or after a bilateral
reveal. A nickname may not simply repeat the legal name the anonymity rule is
protecting.

**Onboarding is progressive, the layout is responsive.** Every account starts
as a community user, and a role-specific welcome guide (`showWelcomeGuide`)
explains the three things to do first. Donor status is a separate,
reversible-by-staff upgrade in Donor Hub, not a signup fork. Layout adapts by
width — below 1024 px the sidebar becomes an M3 bottom navigation bar and the
map stacks above the donor list; from 1024 px up the sidebar is the default
navigation, expanded and pinnable, with hover-open still available after
unpinning, and the classic side-by-side splits. `MaterialApp.builder` wraps the
navigator in `SafeArea`, so status-bar and gesture insets are never painted
over. The theme starts in **light** mode; dark and system-follow are explicit
choices in Settings.

**Accounts can be created at the chapter desk.** Staff register walk-in donors
and patient representatives from User management. Every field is a fixed choice
or an obvious text box; TABANG generates a temporary password, shows it once,
and stores only its hash. Privilege rules are enforced in `AuthService`: staff
create community accounts only, an admin may add staff, and nobody can create
an admin from inside the app.

**Role authorization is server-side-style, not just visual.** Staff cannot
manage themselves, other staff, or admins. Only an admin can manage another
staff member. Fulfilment checks the actor's role in the repository.

**Analytics are computed.** `TabangRepository.summary()` derives every figure
on the admin statistics page from the underlying records, so the readiness
score, KPI cards and tables beneath them always agree.

**Attribution matches the file.** `lib/core/image_credits.dart` is the single
per-asset registry. `TabangPhoto` looks up the exact asset for its hover tooltip,
and `PhotoCredit` prints the same author and licence visibly under the image.
The About tab renders the full registry with source links. There is no generic
"public domain" footer that could drift away from the file being shown.

**The map has one visual language.** A sequential warm-crimson ramp encodes
available donors, with a legend; selection uses deep brand tones plus a
contrasting outline, never the blue that previously meant both "selected" and
"water". The base stays light in dark mode (with an independent map toggle)
because cartography reads better on a light surface, and the compass, zoom
buttons and collapsible donor pane are explicit controls rather than gestures.

### Performance and reliability

**No maps SDK, so no platform view.** The original build used
`google_maps_flutter`; its web platform view threw
`Maps cannot be retrieved before calling buildView!` while switching tabs and
froze the page. The map now uses `flutter_map` (pure Flutter — no platform
view, no API key) with the barangay geometry bundled in
`lib/core/digos_geodata.dart`. Only the base tile image comes from
OpenStreetMap, and tile failures are swallowed: the city mask, barangays,
donor density, labels and drive pins are all local, so an offline device still
gets a working map on the paper background. It renders identically on phones,
tablets, web and desktop, and keeps an independent light/dark map style because
the app theme should not decide how legible the street network is.

**Shell pages stay alive.** `DonorShell` and `AdminShell` keep each visited page
in a lazy `IndexedStack`, so switching tabs no longer rebuilds the page or
recreates the map. Filters, scroll positions and form state survive navigation.

**Heavy work is cached.** The stitched barangay rings, internal border arcs and
city ring are computed once and shared between map page instances, and the
request board uses a sliver list so only the cards on screen are built.

**Empty states are illustrated with vectors; photography is reserved for
people-facing content.** `TabangIllustration` draws each empty scene from theme
colours with a radial wash whose alpha reaches zero at the edges, so the art
blends into the surrounding card in light and dark mode, stays crisp at any
density, and adds no download weight. `EmptyState` uses it wherever a full
illustration helps; dense admin tables keep the compact icon variant. Photos are
used only where they add context: the login brand panel, the Discover hero,
article and drive cards, their dialogs, and the identity headers. Every one is
credited individually; the 48 profile portraits and seven educational
illustrations are original TABANG artwork.

---

## Scope

Per the study's stated limitations, this build:

- runs exclusively on **simulated data**;
- does **not** connect to live donor registries, hospital EHR systems, or
  Philippine Red Cross inventory;
- is **not** a replacement for authorized blood-service procedures;
- does not claim clinical validity for its component/cooldown rules. Those
  rules are simplified for the prototype and must be reviewed by a licensed
  blood-service professional before any real use.

### Barangay boundaries

`assets/maps/digos_barangays.geojson` holds the 26 barangays of Digos City. The
geometry comes from the project's own vector map, `tools/digos_city_source.svg`
(line-work export with no fills or names), which `tools/svg_to_barangays.py`
polygonises:

1. every border polyline joins a shared node graph,
2. each face of the planar graph becomes a barangay polygon,
3. faces are named by matching their reference point against the GADM 4.1
   (`gadm41_PHL_3`) centroids recorded in the script, and
4. the result is written in `[lng, lat]` so the app projection, hit testing and
   scale bar stay accurate.

```bash
python tools/svg_to_barangays.py
```

`tools/extract_digos_barangays.py` remains as a fallback that rebuilds the same
asset directly from GADM if the SVG is ever replaced.

**Licence and accuracy.** The SVG export and the GADM reference are suitable
for academic, non-commercial use with attribution; GADM may not be
redistributed commercially. Neither is survey-grade: do not use these shapes
for navigation, land titles or service boundaries. For real deployment, replace
the asset with PSA or LGU boundary data and keep the file contract — a
`FeatureCollection` with one `NAME_3` property per feature.

---

## No map key required

No mapping SDK and no API key are involved. Find Donor's geometry comes from
`lib/core/digos_geodata.dart` (adopted from the standalone map project), and
the OpenStreetMap raster tiles used as the base layer need no key, account or
referrer restriction — the required attribution is drawn on the map. For a
fully offline deployment the tile layer can be switched off with one flag
(`DigosVectorMap.tilesEnabled`), which leaves the complete vector map running
on the paper background. The only deployment signing caveat left is the
Android release keystore, which the research team must supply before
distributing an APK outside the group.

---

## Bundled imagery

Every photograph and illustration is a local Flutter asset. The app makes no
image request at runtime, so the interface still works with the network switched
off and there is no third-party image host to configure or pay for.

| Surface | Asset |
|---|---|
| Login brand panel, Discover hero | `assets/images/hero_donation.jpg` |
| Hydration and nutrition articles | `content_hydration.jpg`, `content_nutrition.jpg` |
| Recovery, screening and drive articles | `content_recovery.jpg`, `content_screening.jpg`, `content_drive.jpg` |
| Privacy article | `content_privacy.jpg` |
| Recipient story | `content_story.jpg` |
| Donor spotlight and drive cards | `drive_community.jpg`, `content_drive.jpg` |
| Educational illustrations | `assets/images/educational/edu_*.png` (7 originals) |
| Profile portraits | `assets/images/avatars/avatar_001.png` … `avatar_048.png` |
| App icon / PWA icons | `assets/branding/app_icon.png` |

`TabangPhoto` (`lib/widgets/photo.dart`) is the single image surface. It loads
with `Image.asset`, fades in on first paint, and falls back to a themed gradient
with the relevant icon if an asset is missing — so a stripped-down build never
shows Flutter's red error box or an unstable layout. Every display is paired
with a visible `PhotoCredit` line and a hover credit that names the actual file,
creator and licence. The photo is paired with a scrim in the hero and login
views to keep white copy legible.

**Licences.** Every source photograph is public domain or CC0; original
artwork is TABANG's own. Source URLs, authors and licence details are recorded
in [`tools/image_sources/CREDITS.md`](tools/image_sources/CREDITS.md) and in the
About tab's per-image credit cards. The source files are kept in
`tools/image_sources/`; regenerate the cropped, graded assets and all platform
launcher icons with:

```bash
python tools/make_media_assets.py
```

Profile portraits and educational art are regenerated with
`tools/make_avatars.py` and `tools/make_edu_art.py`. The photographs are illustrative:
they do not depict TABANG users or patients, and the people shown have no
connection to the simulated records.

---

## Tests

```bash
flutter test
```

**73 tests** cover:

- **Seed data** — exactly 15 currently eligible donors, 15 recipients, the
  community demo account, and a unique bundled avatar per seeded user.
- **ABO/Rh compatibility matrix** — universal donor/recipient properties,
  per-type donor sets, and the inverse relationship between `donorsFor` and
  `recipientsFor`.
- **Component-aware compatibility** — plasma's reverse ABO rule, platelet
  baseline, and per-component donor sets.
- **Cooldown enforcement** — boundary conditions, per-component intervals,
  suspension, availability, age limits, underweight/missing weight, and missing
  blood type.
- **Expiry handling** — effective status, exclusion from available stock, and
  prevention of reviving an expired bag as available.
- **Request lifecycle** — compatible/ineligible/duplicate responses, blood-bank
  requests rejecting donor responses, chat-first selection (one-sided chat is
  refused until both people send a message), selection authorization,
  selection-time eligibility rechecks, thread creation, leftover offers being
  declined, staff-only fulfilment, and cancellation guards.
- **Inventory holds and appointments** — a unit can be held once, a second
  person cannot claim it, only its holder can release it, appointments start
  pending, requesters cannot confirm their own slot, and staff confirmation
  works.
- **Privacy and safety** — bilateral reveal accept/decline, persisted reports,
  symmetric blocking, and the 48-hour re-block cooldown.
- **Donation recording** — component capture and component-specific cooldown.
- **Account creation and privacy** — nickname uniqueness and full-name
  rejection, community-only self-registration, the donor upgrade path,
  staff/admin privilege rules for walk-in accounts, generated temporary
  passwords that authenticate, and the onboarding flag.
- **Donor registration** — a submitted form becomes a *pending* donor
  application, an unverified donor is never matched by the eligibility engine,
  staff can request documents without closing the application, and verifying
  flips the blood card, the account status and the open queue at once.
- **Interface widgets** — Discover leads with its section rails, visible photo
  credit chips resolve for every content image, tapping one opens the full
  provenance dialog, empty states render the vector illustration, every content
  item resolves to a bundled photo, the hero/feed/dialog mount those photos, a
  missing asset falls back to the themed placeholder, a narrow PageHeader stays
  a single compact line with its description in the tooltip, and the Digos
  vector map mounts all 26 barangays with tiles disabled (so no HTTP runs in
  tests), keeps its overlay controls in the wide desktop layout, and selects a
  barangay on tap.
- **Narrow-screen layout** — Discover, Blood Bank (including unit selection and
  the appointment dialog) and Statistics render at a 360 × 780 phone viewport
  without overflow; the unit list reflows to one column and the appointment
  dialog stacks its fields.
- **Sidebar** — unpinning the desktop rail collapses it to the icon-only
  layout, and each rail item's icon stays dead-centre in its pill (the
  regression that left the selection accent bar pushing icons off-centre).
- **Barangay canonicalisation** — parenthetical stripping, case/punctuation
  normalisation, and round-tripping all 26 names.

`flutter analyze` is clean for this build.

---

## Build targets

| Platform | Status |
|---|---|
| Web | ✅ builds and runs (`flutter build web --release`) |
| Android | ✅ debug APK builds; verified package `ph.edu.cjc.tabang`, `minSdk 24`, target SDK 36, `INTERNET` permission |
| Windows | ✅ configured; the offline Digos map works natively |
| Linux | ✅ configured; the offline Digos map works natively |
| iOS / macOS | ⚠️ requires a Mac to compile; bundle ID `ph.edu.cjc.tabang`; not built by the proponents |

Android release builds currently use the debug signing key. This is documented
in `android/app/build.gradle.kts` and is not suitable for public distribution.

Android is intentionally pinned to **AGP 8.13.2 / Gradle 8.14.3 / Kotlin
2.4.0**. Flutter 3.47's Gradle plugin still casts AGP 9's new DSL extension to
the legacy type, so AGP 9.1.0 fails at configuration time. Revisit this pin when
Flutter's Gradle plugin completes the AGP 9 migration; the app code itself does
not depend on AGP 8. Kotlin incremental compilation is disabled in
`android/gradle.properties` because the Pub cache (`C:`) and this project
(`D:`) are on different Windows drive roots, which makes Kotlin's incremental
cache fail while closing its path tables.

---

## Alignment

SDG 3 (Good Health and Well-being) and SDG 9 (Industry, Innovation and
Infrastructure).

Built with Flutter. The Digos City map's geometry is bundled in-app
(`lib/core/digos_geodata.dart`) — no mapping SDK and no API key.
