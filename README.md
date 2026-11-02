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
| Staff | `staff@tabang.app` | `staff1234` |
| Admin | `admin@tabang.app` | `admin1234` |

Administrative roles are seeded only. Self-registration is restricted to donor
and recipient — `AuthService.register` rejects `UserRole.admin` and
`UserRole.staff` even if the UI were bypassed.

---

## What the app does

### Donor / recipient surface

- **Discover** — four obvious quick actions (donate/request, donation sites,
  messages, guide), the shortage banner, an in-app notification summary, a
  photographic hero and content grid, and upcoming drive cards with their own
  imagery.
- **Blood Bank** — read-only public inventory with component, blood-type,
  status and expiry filters; ABO/Rh recipient-compatibility filtering; and the
  shared blood-request dialog. Recipients cannot reserve a specific bag.
- **Find Donor** — an offline, interactive map of all 26 Digos City barangays,
  drawn with a `CustomPainter` over the bundled GeoJSON. Barangays are shaded
  crimson by available-donor count and labelled at the visual centre of each
  area; the selected barangay turns blue so the two states never read as the
  same thing. Tapping one filters the donor list, the mouse cursor shows the
  map is clickable, and the donor sidebar collapses to give the map the full
  pane on phones. Names for the small city-proper barangays appear as you zoom
  in, keeping the default view uncluttered. No API key, no tile traffic, and it
  works on phones, tablets, web and desktop alike.
- **Requests** — a recipient posts a request; the dialog first checks
  participating-facility stock. If compatible stock exists, the request can go
  to the blood bank; otherwise it is posted to the donor network. Donors see
  only requests their blood type and component can serve, and only while they
  are eligible. A donor response is an offer; the requester selects a donor,
  which creates a private coordination thread.
- **Messages** — double-blind coordination threads, bilateral identity reveal
  (request then accept), block/unblock with a 48-hour re-block cooldown, and
  persisted reports to staff.
- **Profile** — per-component eligibility view, blood-card verification state,
  availability, blood type, weight, last donation component, and
  privacy/notification preferences.
- **Settings / About & Help** — appearance, notification preferences, privacy
  controls, the replayable welcome guide, and FAQ content that matches the
  implemented rules.

### Staff / admin surface

- **Overview** — supply, donor engagement and barangay analytics computed from
  the repository, including expiry-aware inventory counts.
- **Inventory** — change unit status, monitor effective expiry pressure, and
  work the request queue. Only staff/admin can mark a request fulfilled.
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
| Read-only inventory visibility (SEIPS, p.11) | The donor/recipient Blood Bank page is read-only. Reservations, dispatch, quarantine and expiry remain staff actions. |
| Double-blind messaging and privacy (p.34) | Users see aliases. Real names/contact details appear only after a bilateral reveal request is accepted. |
| Reports, blocks and moderation (p.12/24) | Reports persist in the repository and appear in the staff queue. Blocking disables messaging in both directions and enforces a 48-hour re-block cooldown. |
| Expiry-aware inventory (p.15) | `BloodUnit.effectiveStatus` marks expired stock even if its stored status is still `available`; expired units are excluded from usable stock, compatibility counts and expiring-soon lists. |
| Donor eligibility: age 18–65, weight, availability, standing (p.17) | `EligibilityEngine` enforces the rules; registration computes exact age, rejects donors outside 18–65, and requires a self-reported weight. Donors below 50 kg or without a recorded weight are blocked from matching. |
| Registration fields (p.22) | A three-step wizard collects full name, unique nickname, email, contact number, birth date, blood type, weight, barangay and role. Everything is persisted; the nickname is the only public identity. |
| Email credential authentication (p.28) | Salted SHA-256 credential store, session routing by role, and no self-service admin/staff registration. |
| Request lifecycle and staff-only fulfilment | Donor-network: open → matched (requester selects enough donors) → fulfilled (staff/admin only). Blood-bank: staff process the request and fulfil it directly. Cancellation is guarded; fulfilled/cancelled requests cannot be re-opened or fulfilled twice. |
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
├── main.dart                  # root; routes on session state
├── theme.dart                 # design tokens + ThemeData
├── core/
│   ├── models.dart            # domain models, expiry, responses, reports
│   ├── eligibility.dart       # component compatibility + cooldown engine
│   ├── repository.dart        # in-memory store, seed data, lifecycle, analytics
│   └── auth.dart              # credential auth, role gating, exact-age check
├── widgets/
│   ├── common.dart            # shared UI kit
│   └── blood_request_dialog.dart # stock-first request flow
└── screens/
    ├── auth/                  # login, register
    ├── donor/                 # donor shell + Discover, Blood Bank, Find Donor,
    │                          # Requests, Messages
    ├── admin/                 # admin shell + Overview, Inventory, Users, Moderation
    └── shared/                # settings, profile, about & help
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
requester (or staff) can select a response. Selection creates one coordination
thread and, once enough donors are selected, moves a donor-network request to
`matched`. Blood-bank requests are processed by staff and can be fulfilled
directly. Only staff/admin can mark a request `fulfilled`; donor-network
requests must be matched first. Cancelled and fulfilled requests are terminal.

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

**Onboarding is progressive, the layout is responsive.** Every account gets the
same single interface: four obvious quick actions lead the Discover feed, and a
role-specific welcome guide (`showWelcomeGuide`) explains the three things to do
first. Layout adapts by width — phones stack the map above the donor list and
show chats and moderation as one pane at a time; tablets and desktops keep the
side-by-side splits.

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
on the admin overview from the underlying records, so KPI cards agree with the
tables beneath them.

### Performance and reliability

**No maps SDK, so no platform view.** The original build used
`google_maps_flutter`; its web platform view threw
`Maps cannot be retrieved before calling buildView!` while switching tabs and
froze the page. The map is now a plain Flutter canvas over the bundled GeoJSON,
which removed the dependency, the API key, the tile traffic, the desktop
fallback and the freeze in one step.

**Shell pages stay alive.** `DonorShell` and `AdminShell` keep each visited page
in a lazy `IndexedStack`, so switching tabs no longer rebuilds the page or
recreates the map. Filters, scroll positions and form state survive navigation.

**Heavy work is cached.** Parsed GeoJSON boundaries are shared between map page
instances, the polygon set is rebuilt only when boundaries, donor counts or the
selected barangay change, and the request board uses a sliver list so only the
cards on screen are built.

**Empty states are illustrated with vectors; photography is reserved for
people-facing content.** `TabangIllustration` draws each empty scene from theme
colours with a radial wash whose alpha reaches zero at the edges, so the art
blends into the surrounding card in light and dark mode, stays crisp at any
density, and adds no download weight. `EmptyState` uses it wherever a full
illustration helps; dense admin tables keep the compact icon variant. Photos are
used only where they add context: the login brand panel, the Discover hero,
article cards and their dialogs, and the drive strip.

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

The app does not call any mapping service. Find Donor renders
`assets/maps/digos_barangays.geojson` directly, so there is no API key to rotate,
no referrer restriction to configure and no tile bill. The only deployment
signing caveat left is the Android release keystore, which the research team
must supply before distributing an APK outside the group.

---

## Bundled imagery

Every photograph is a local Flutter asset. The app makes no image request at
runtime, so the interface still works with the network switched off and there is
no third-party image host to configure or pay for.

| Surface | Asset |
|---|---|
| Login brand panel, Discover hero | `assets/images/hero_donation.jpg` |
| Hydration and nutrition articles | `content_hydration.jpg`, `content_nutrition.jpg` |
| Recovery, screening and drive articles | `content_recovery.jpg`, `content_screening.jpg`, `content_drive.jpg` |
| Privacy article | `content_privacy.jpg` |
| Recipient story | `content_story.jpg` |
| Donor spotlight and drive cards | `drive_community.jpg`, `content_drive.jpg` |
| App icon / PWA icons | `assets/branding/app_icon.png` |

`TabangPhoto` (`lib/widgets/photo.dart`) is the single image surface. It loads
with `Image.asset`, fades in on first paint, and falls back to a themed gradient
with the relevant icon if an asset is missing — so a stripped-down build never
shows Flutter's red error box or an unstable layout. The photo is paired with a
scrim in the hero and login views to keep white copy legible.

**Licences.** Every source photograph is public domain or CC0. Source URLs,
authors and licence details are recorded in
[`tools/image_sources/CREDITS.md`](tools/image_sources/CREDITS.md) and repeated
in About & Help. The source files are kept in `tools/image_sources/`; regenerate
the cropped, graded assets and all platform launcher icons with:

```bash
python tools/make_media_assets.py
```

The generated privacy card art and app icon are original artwork from that
script. The photographs are illustrative: they do not depict TABANG users or
patients, and the people shown have no connection to the simulated records.

---

## Tests

```bash
flutter test
```

**63 tests** cover:

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
  requests rejecting donor responses, selection authorization, selection-time
  eligibility rechecks, thread creation, leftover offers being declined,
  staff-only fulfilment, and cancellation guards.
- **Privacy and safety** — bilateral reveal accept/decline, persisted reports,
  symmetric blocking, and the 48-hour re-block cooldown.
- **Donation recording** — component capture and component-specific cooldown.
- **Account creation and privacy** — nickname uniqueness and full-name
  rejection, staff/admin privilege rules for walk-in accounts, generated
  temporary passwords that authenticate, and the onboarding flag.
- **Interface widgets** — Discover leads with its quick actions above the feed,
  empty states render the vector illustration, every content item resolves to a
  bundled photo, the hero/feed/dialog mount those photos, a missing asset falls
  back to the themed placeholder, a narrow PageHeader stacks its actions so the
  title stays readable, and the offline Digos map loads its real
  boundaries, mounts the painter, keeps its overlay controls in the wide desktop
  layout, and selects a barangay on tap.
- **Barangay canonicalisation** — parenthetical stripping, case/punctuation
  normalisation, and round-tripping all 26 names.

`flutter analyze` is clean for this build.

---

## Build targets

| Platform | Status |
|---|---|
| Web | ✅ builds and runs (`flutter build web --release`) |
| Android | ✅ debug APK builds; verified package `ph.edu.cjc.tabang`, `minSdk 24`, target SDK 36, `INTERNET` permission |
| Windows | ✅ configured; map falls back to the barangay directory |
| Linux | ✅ configured; map falls back to the barangay directory |
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

Built with Flutter. The Digos City map is rendered entirely in-app from bundled
GeoJSON — no mapping SDK and no API key.
