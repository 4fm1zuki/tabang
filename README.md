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
- No map key: the barangay geometry and all photography are bundled. The
  OpenStreetMap raster base (HOT style, no mountain-peak symbols) loads when a
  network is available, and the complete vector map still renders on the paper
  background without it

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
| Donor | `juan.delacruz@tabang.app` | `donor1234` |
| Donor | `tere.santos@tabang.app` | `donor1234` |
| Donor (away, 47 days inactive) | `rafael.mendoza@tabang.app` | `donor1234` |
| Recipient | `maria.santos@tabang.app` | `recipient1234` |
| Community | `community@tabang.app` | `community1234` |
| Staff | `marco.villanueva@tabang.app` | `staff1234` |
| Admin | `admin@tabang.app` | `admin1234` |

The staff and admin sign-ins are the people behind the official chapter
account: when they reply to a user thread it appears as
*Philippine Red Cross — Davao del Sur Chapter* with a verified badge, never as
a personal name. Administrative roles are seeded only. Self-registration always
creates a community account: new users can request blood and browse donors
immediately,
then opt in to donating through **Donor Hub → Register as a donor**. The
upgrade asks for blood type, birth date and weight; the account stays
unverified until chapter staff check the donor's blood card. `AuthService`
rejects `UserRole.admin` and `UserRole.staff` self-registration even if the UI
were bypassed.

---

## What the app does

### Donor / recipient surface

- **Home** (the first navigation destination, home icon) — one compact toolbar,
  then horizontal rails for upcoming blood drives, announcements and stories,
  and short learning cards, ending with a visit planner. Quick actions are
  *Request blood*, *Find donors near you* and *Find a drive* (which scrolls the
  feed to the drives rail). The urgent
  shortage callout lives on Blood Bank and the map, not here. Credit text is
  no longer printed under feed cards — attribution appears in the article and
  drive details after a card is tapped, and original TABANG artwork is not
  credited at all. A mouse wheel scrolls a rail only after that rail is
  clicked; moving the pointer off the rail releases that focus immediately, so
  the page scrolls vertically again.
- **Blood Bank** — the chapter banner, a one-line stock note, a public stock
  grid by component and blood type, then a *card list* of units (product,
  storage, expiry, status) that reflows one to three columns and highlights on
  hover. The full record — unit ID, storage, dates and who holds it — opens on
  selection; the barcode graphic itself belongs to the staff inventory and the
  holder of a reserved bag is only named to staff. Community members do not
  place one-tap holds: **Request this unit** opens the documented request
  dialog seeded with the unit's component and type, and staff attach the hold
  when they verify the request. The page also books an **appointment with
  blood** (blood type, patient name, donation type, patient
  hospital and ward, amount and slot). A hold is not a transfusion order:
  chapter staff still cross-match and confirm release.
- **Find Donor** — the Digos City map: `flutter_map` renders OpenStreetMap
  raster tiles (the HOT humanitarian style, chosen because the standard Carto
  style scatters brown mountain-peak triangles across the Digos highlands)
  under an inverse mask that hides everything outside the city, and
  the 26-barangay topology from the standalone `map/` project ships locally in
  `lib/core/digos_geodata.dart` (75 shared topological arcs that stitch into the
  barangays plus the city perimeter, so no mapping SDK or API key is involved).
  The base keeps the standalone map project's warm, low-contrast street
  template, so roads, water, buildings and land use show through while
  farmland hatching and baked-in place names are muted. The
  raster template alone is nudged down-right (`DigosVectorMap.baseMapOffset`)
  so its streets sit better under the hand-traced cutouts; the vector layers
  never move. The nudge is calibrated at `baseMapOffsetZoom` and scales with
  the camera, so it tracks the streets at every zoom. Whole-tile shifts are
  fetched directly and only the sub-tile remainder is translated, which keeps
  the shift correct at street level without an oversized tile canvas. The
  pins follow the same displacement: facility and venue seeds hold their real
  OpenStreetMap coordinates, and `DigosVectorMap.toMapFrame` rebases them into
  the nudged map frame so a hospital pin lands on the hospital building and a
  drive pin on its barangay hall — not half a kilometre away. Every
  TABANG
  layer is drawn on top locally, so the map still reads when tiles cannot load:
  a translucent warm-crimson donor-density ramp (4–78% opacity, so streets stay
  readable), a deep-crimson selection wash, tappable drop-shaped **drive pins at
  their venue coordinates** (multiple drives in one barangay are staggered, and
  a drive sharing a facility's venue gets a fixed geographic offset — never a
  zoom-dependent screen-space nudge, so pins do not jump while zooming),
  dedicated **hospital and PRC chapter
  pins**, and haloed barangay labels rebuilt on every camera change. Exactly
  like the standalone map, every one of the 26 names is drawn at its barangay's
  representative point — no label is ever dropped when the view zooms out — and
  the font grows as the user zooms in, which separates the crowded Poblacion
  names. Drive and hospital pins scale down at wide views so the city does not
  drown in markers, and every seed pin is a representative point inside its own
  barangay, never outside the city outline.
  A **metric scale bar** shows distance; one fit-city control (corner-bracket
  icon) re-frames the whole city in the pane; `+`/`−` step the zoom within
  10.5–18; the map style follows the app theme, with a desktop-only toggle that
  overrides it for the visit. A **Live** pill and an unread badge flag new
  activity, and a donor already coordinating an active request stays visible
  with a **coordinating** badge rather than disappearing from the map. The map
  opens framed to the whole city
  instead of falling back to street level. Map panels fade while the map is
  being touched and return when the gesture ends; a layers button hides them for
  an unobstructed view, and the phone control stack is reduced to 30 px buttons
  with a compact single-line legend to keep the map visible. The side panel has
  three tabs — **Donors**, **Facilities** (hospitals and the PRC chapter, tap to
  jump to the pin) and **Drives** (show on map, details, and for donors a jump
  to Requests). Donors appear only as anonymous **`Donor #<id>`** handles, the
  signed-in donor is excluded from their own results, and blood-type chips keep
  clear of the control stack. Tapping a barangay filters the donor list; tapping
  a donor card moves the map to the barangay that donor is from (not just a
  highlight). Over the map the cursor switches to a pointing hand whenever a
  barangay is under the mouse, so "click a region to select it" is discoverable.
  The map credit reads `© OpenStreetMap contributors · HOT style`.
- **Donor Hub** — a dedicated donor tab with eligibility window, next available
  date, donation history and availability controls. Availability is managed two
  ways: the manual **Directory availability** switch hides a donor on demand,
  and TABANG also marks any donor **away** automatically after 30 days with no
  app activity, even while the switch is on. Posting or answering a request,
  sending a message, flipping the switch, or the one-tap **I'm active** button
  all refresh the timer; signing in alone does not, so a returning donor sees
  the away notice and chooses to come back. Registration is
  **face-to-face**, so the app only records intent and the two eligibility
  inputs the chapter cannot verify remotely — date of birth and weight — plus
  whether the applicant already holds a PRC donor card (with an optional card
  number) and an optional visit day. The registration opens the official
  chapter thread immediately, so the applicant can talk to the chapter and
  receives document requests and verification updates there. The
  medical interview, examination, blood typing and screening stay on the PRC
  interview sheet at the chapter; the account becomes a donor immediately but
  stays *unverified*, and the eligibility engine will not match an unverified
  donor until staff verifies the card on site. Donors see a verification card
  with what chapter staff asked for, and keep one-tap access to requests and
  messages because donating and needing blood are not mutually exclusive.
- **Requests** — anyone, including a donor, can post a blood request, but
  submission is a documented workflow, not a button. The requester ticks the
  document checklist (doctor's request form, transfusion slip, hospital
  patient ID, optional typing result) and books one of the chapter's published
  blood-bank slots (Mon–Fri 8–11 AM and 1–3 PM, Sat 8–11 AM); the dialog also
  checks participating-facility stock and explains each urgency as a response
  window (critical = same day, urgent = 24–48 h, routine = planned). The
  request starts as **Awaiting verification** and is invisible to donors until
  chapter staff verify it or reject it with a written reason the requester can
  read. Donors get three tabs — **Requests** (open donor-network requests their
  blood type and component can serve, with their own posted request excluded),
  **Mine** (requests they posted, the review status and rejection reason, donor
  responses and the booked slot) and **Donate** (the drives they can join,
  their eligibility window and what to bring). Every card has a **⋯ menu with
  View details** for the full record, and the response dialog shares the donor's
  anonymous **`Donor #<id>`** handle rather than their nickname. **Chat comes
  first:** the requester must exchange a real, reciprocal human message with a
  donor before selection is enabled, and a system notice does not count. Only
  the requester selects donors — staff verify and fulfil, but never choose the
  donor. Selection is also fair: a donor already selected for another open
  request is flagged **coordinating**, stays visible in the response list, and
  cannot be silently reserved twice until the first request closes.
- **Messages** — double-blind coordination threads, bilateral identity reveal
  (request then accept), a **Seen** marker on the newest own message the other
  participant has read, block/unblock with a 48-hour re-block cooldown,
  persisted reports to staff with a required reason and an optional free-text
  explanation, and the **chapter support thread** created by the Help page's
  feedback form. Unread counters mark new chat activity in the rail, bottom bar
  and Find Donor; opening a thread clears it immediately. The chapter thread is an organization identity, not
  a person: it shows the Philippine Red Cross — Davao del Sur Chapter name, a
  blue verified tick and an info card, and it never exposes a staff member's
  real name. Registering as a donor opens that thread automatically, and every
  staff decision on the application (documents requested, verified, not
  accepted) posts an official update there. The conversation list can be sorted
  **Most recent** or **Alphabetical (A–Z)**; the chapter sorts alongside people
  in both modes.
- **Profile** — a per-component eligibility view with multi-select chips:
  checking whole blood, packed red cells, platelets and plasma together shows a
  separate cooldown row for each component, so one donation type no longer hides
  the others. The page also carries blood-card verification state, blood type,
  weight, last donation component and notification preferences. Availability is
  set once, in Settings and Donor Hub, rather than repeated here.
- **Settings** — appearance (light is the default, dark is explicit), slim
  navigation rails, donor availability, privacy/data and account sections, each
  with a contextual `?` help tip. The sidebar itself is pinned or unpinned from
  the pin control in the rail header, not from Settings.
- **Guides & Help** — a separate destination with task guides (donating,
  requesting, messaging, Home, profile/donor registration and settings),
  a **left-aligned FAQ** (each question is a bubble above its answer, both
  reading left-to-right and sorted A→Z per category) and **About TABANG**, a
  platform
  summary with SDG alignment, safety commitments, known gaps and photo credits.
  A **Message chapter staff** card sends a question, data correction or
  feedback into a real support thread with the chapter, which is also where the
  acknowledgement lands.

### Staff / admin surface

- **Overview** — a KIN-SCORE-style hierarchy: one weighted readiness score
  explicitly capped at **100% max**, built from five labelled components
  (supply coverage, shelf-life, donor capacity, community reach and request
  pressure) that recalculate live whenever units, requests, registered users or
  active donors change. Every bar names its actual count against a stated
  planning target (`10 of 32 units`), the KPI cards repeat those targets, and a
  **Details** button opens the weights, targets and method behind the total.
  Primary KPI cards with progress bars, supply/community detail and supporting
  exceptions all read the same repository snapshot, and an explicit **Roles &
  permissions** card spells out what Clinical Personnel and System
  Administrators can each do. A **Recent transfusions & account changes** card
  lists the latest audit entries with date and actor, and **View all** filters
  them between transfusions and account changes. The open-requests and
  low-stock cards deep-link into the Operations workspace, and **User
  management** opens with the donor registrations awaiting staff — card on
  file, planned visit, notes — where each one can be verified, returned for
  documents or not accepted. On phones and small tablets the staff console uses
  the same bottom-bar shell as the community app; the icon rail is desktop-only.
- **Operations** — one destination for the operational work that used to be
  split between Map and Inventory. A collapsible inner sidebar switches views on
  wide windows, and a segmented control does the same on narrow ones. The map
  is the same Digos template with a legend switch between the amber
  **open-request heat layer** and the **donor-density heatmap** the community
  map uses. Tapping a barangay scopes the side panel to eligible donors,
  pending registrations, open requests with responders, and donor applications
  waiting for review. The city-wide queue puts requests **Awaiting
  verification** first: staff open the details, confirm the document checklist
  and booked slot with **Verify and open** (blood-bank requests also attach the
  compatible unit holds), or **Reject** with a written reason. Staff mark
  requests fulfilled and jump to user management, but they do not select
  donors — that stays with the requester.
- **Inventory** — the second Operations view. Units are a compact list with a
  **Details** button and a status-menu; the full record opens with the barcode
  graphic, the holder's name (staff-only information) and a **Remove unit**
  action for discarded or mislabelled bags. A one-line legend explains
  Available, Reserved, Quarantined and Expired. Staff receive new stock with
  **Add unit** (blood type, component, storage bay, collection date, optional
  barcode; expiry is derived from the component shelf life), change unit
  status, release a held bag back to available stock after screening, monitor
  effective expiry pressure, confirm booked **appointments** in a dedicated
  queue, and work the request queue. Only staff/admin can mark a request
  fulfilled.
- **Messages** — staff and admins use the community chat surface and can start
  a new conversation with another staff member or any community user; unread
  counters stay live across the console.
- **Users** — create walk-in accounts with fixed-choice fields and a one-time
  temporary password, verify blood cards, issue a warning with a recorded
  reason (the count is capped at three, a third warning suspends automatically,
  suspended accounts cannot be warned again, and reinstating an account clears
  the count), suspend and reinstate donor and recipient accounts, and record a
  completed donation with its component. Clicking a user opens a staff/admin-only record with contact
  details, standing, history and that account's recent activity; from there
  staff can message the user or correct the **donation window** after a
  transfusion without counting another donation. Staff cannot manage their own
  account, another staff account, or an admin; only an admin can manage another
  staff member or add staff.
- **Moderation** — review flagged messages, clear or escalate flags, mute
  threads, resolve or dismiss the persisted user-report queue with the
  reporter's free-text explanation attached, and **reply** from the console:
  staff answer the official chapter threads under the organization identity,
  while person-to-person coordination threads stay read-only. Threads are
  listed most-recent first.

---

## Paper alignment

| Paper requirement | Implementation in this build |
|---|---|
| Recipient checks compatible stock before posting to the donor network (p.8/21) | `BloodRequestDialog` calls `TabangRepository.compatibleUnitsFor`. Stock present → blood-bank or donor-network branch; no stock → donor-network branch only. |
| ABO/Rh compatibility matching (p.9/11) | `Compatibility` implements the red-cell matrix and inverse recipient sets. The request board, donor directory and inventory filters use it. |
| Component-aware compatibility and cooldowns (p.11) | `EligibilityEngine` uses 84 days for whole blood/packed RBC, 14 days for platelets, and 28 days for plasma. Plasma uses the reverse ABO rule; platelets use the red-cell baseline in this prototype. |
| Read-only inventory visibility (SEIPS, p.11) | The donation history and public stock are read-only. Community users may place a time-limited hold, but dispatch, quarantine, cross-matching, expiry and final reservation release remain staff actions. |
| Double-blind messaging and privacy (p.34) | The map and donor directory show only a stable `Donor #<id>` handle; messaging shows the nickname. Real names and contact details appear only after a bilateral reveal request is accepted. Selection requires a reciprocal human chat first. |
| Reports, blocks and moderation (p.12/24) | Reports persist in the repository with a required reason and optional free-text details, and appear in the staff queue with both. Blocking disables messaging in both directions and enforces a 48-hour re-block cooldown. |
| Expiry-aware inventory (p.15) | `BloodUnit.effectiveStatus` marks expired stock even if its stored status is still `available`; expired units are excluded from usable stock, compatibility counts and expiring-soon lists. |
| Donor eligibility: age 18–65, weight, availability, standing (p.17) | `EligibilityEngine` enforces the rules; registration computes exact age, rejects donors outside 18–65, and requires a self-reported weight. Donors below 50 kg or without a recorded weight are blocked from matching. |
| Registration fields (p.22) | A three-step community-account wizard collects full name, unique nickname, email, contact number, birth date, blood type, weight and barangay. Everything is persisted; the nickname is the only public identity. Donor status is a separate opt-in upgrade in Donor Hub. |
| Email credential authentication (p.28) | Salted SHA-256 credential store, session routing by role, and no self-service admin/staff registration. |
| Request lifecycle and staff-only fulfilment | Donor-network: open → matched (after chat-first selection) → fulfilled (staff/admin only). A donor already committed to one active request cannot be selected for another until it closes. Blood-bank: staff process the request and fulfil it directly. Cancellation is guarded; fulfilled/cancelled requests cannot be re-opened or fulfilled twice. |
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
| Push notifications | **Not implemented.** Home shows in-app summaries; delivery requires a deployed backend and notification service. |
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
│   ├── digos_geodata.dart     # 75 shared arcs → 26 barangays + city ring
│   └── image_credits.dart     # per-asset provenance registry
├── widgets/
│   ├── common.dart            # shared UI kit, HelpTip, progress bars
│   ├── photo.dart             # TabangPhoto + visible PhotoCredit
│   ├── digos_vector_map.dart  # OSM base, heat fills, pins, labels, controls
│   └── blood_request_dialog.dart # stock-first request flow
└── screens/
    ├── auth/                  # login, community registration
    ├── donor/                 # DonorShell + Home, Blood Bank, Map,
    │                          # Requests, Messages, Donor Hub
    ├── admin/                 # AdminShell + Overview, Operations (map/inventory),
    │                          # Messages, Users, Moderation
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
`AuthService._validateAlias`, and is the handle used in messaging and community
surfaces. The map and donor directory go further and show only a stable
anonymous `Donor #<id>` token, because browsing a public map should not expose
even a friendly alias. The immutable `USR-…` ID stays internal for audit trails,
blocks and lifecycle rules, and real names appear only in staff tools or after a
bilateral reveal. A nickname may not simply repeat the legal name the anonymity
rule is protecting.

**Onboarding is progressive, the layout is responsive.** Every account starts
as a community user, and a role-specific welcome guide (`showWelcomeGuide`)
explains the three things to do first. Donor status is a separate,
reversible-by-staff upgrade in Donor Hub, not a signup fork. Layout adapts by
width — below 1024 px the sidebar becomes an M3 bottom navigation bar and the
map stacks above the donor list; from 1024 px up the sidebar is the default
navigation, expanded and pinnable, with hover-open still available after
unpinning, and the classic side-by-side splits. On phones the bottom bar slides
down out of the way while the page scrolls toward its end and returns on any
scroll up or tab change, and it pins itself at the top or the bottom of the page
so navigation is never stranded at the end of a list; when the destinations do
not fit, the bar scrolls horizontally instead of overflowing. Settings adds a
**slim navigation rails** switch, **off by default** (turning it on drops
bottom-bar labels and keeps the side rail at icon width). The desktop rail is
controlled by the **pin in its header**: pinning reopens the full labelled rail
and leaves slim mode, while turning slim mode on unpins the sidebar, so the two
never contradict each other. The Settings switch mirrors its value locally so it
responds even when Settings is a pushed phone route.
`MaterialApp.builder` wraps the navigator in `SafeArea`, so
status-bar and gesture insets are never painted
over. **Light is the default theme**; dark is an explicit choice in Settings,
the system theme option is gone, and the map style follows whichever theme is
active.

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
on the admin Overview page from the underlying records, so the readiness
score, KPI cards and tables beneath them always agree. Every readiness bar
shows the actual count against a stated chapter planning target (for example
`10 of 32 units`), not a bare percentage, and the **Details** button opens the
weights and targets behind the total out of 100%.

**Staff can review what changed.** `TabangRepository.activityLog` records every
recorded transfusion, donation-window correction, verification, warning,
suspension and self-service profile/avatar edit with its actor, subject and
timestamp. The Overview shows the latest entries with **View all** filters
(All / Transfusions / Account changes), and each user record in User management
lists that account's own recent activity.

**Attribution matches the file.** `lib/core/image_credits.dart` is the single
per-asset registry. `TabangPhoto` looks up the exact asset for its hover tooltip,
and `PhotoCredit` prints the same author and licence visibly under the image.
The About tab renders the full registry with source links. There is no generic
"public domain" footer that could drift away from the file being shown.

**The map has one visual language.** A sequential warm-crimson ramp encodes
available donors, with a legend; selection uses deep brand tones plus a
contrasting outline, never the blue that previously meant both "selected" and
"water". The OpenStreetMap base (HOT style) is pushed through the standalone map
project's warm template, so streets, water, buildings and land use stay revealed
while its baked-in names are muted and the standard style's mountain-peak
triangles never appear; TABANG's own
labels all sit on their barangay's representative point and never disappear as
the view widens. The base now follows the
active theme — the same `invert + hue-rotate` dark recipe keeps water blue and
parks green instead of collapsing the raster to black — and the desktop style
button can still hold a manual override for the visit. The zoom buttons,
scale bar and collapsible donor pane are explicit controls rather than gestures.

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
tablets, web and desktop, and its light/dark map style follows the app theme,
so the map darkens with the system; desktop users can still override it for the
visit with the style button.

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
used only where they add context: the login brand panel, the Home hero,
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

The 26 barangays of Digos City come from the standalone `map/` project
(`map/lib/data/digos_geodata.dart`) and are ported unchanged into
`lib/core/digos_geodata.dart`. The data is 75 shared topological arcs: each
barangay is a sequence of arc indices, and the outer city perimeter is the
documented arc sequence `cityArcs` wound clockwise for the inverse mask.
Stitching from shared arcs means an internal border is drawn once, two
neighbouring barangays can never disagree about where the line is, and the city
outline is exactly the previous map's outline. No mapping SDK, network request
or API key is needed for the shapes.

The older `assets/maps/digos_barangays.geojson`, the PSA/NAMRIA extract and the
`tools/` SVG/GADM scripts remain in the repository as provenance, but the app
no longer loads them.

**Accuracy.** The arcs are a schematic trace of the city suitable for an
academic, non-commercial prototype with attribution. They are not survey-grade:
do not use them for navigation, land titles or service boundaries. For a real
deployment, replace the embedded data with PSA or LGU boundary data.

---

## No map key required

No mapping SDK and no API key are involved. Find Donor's geometry comes from
`lib/core/digos_geodata.dart`, and the OpenStreetMap raster tiles used as the
base layer (served in the HOT humanitarian style, which draws no peak symbols)
need no key, account or referrer restriction; the required credit
(`© OpenStreetMap contributors · HOT style`) is drawn on the map. For a fully offline
deployment the tile layer can be switched
off with one flag (`DigosVectorMap.tilesEnabled`), which leaves the complete
vector map running on the paper background. The only deployment signing caveat
left is the Android release keystore, which the research team must supply before
distributing an APK outside the group.

---

## Bundled imagery

Every photograph and illustration is a local Flutter asset. The app makes no
image request at runtime, so the interface still works with the network switched
off and there is no third-party image host to configure or pay for.

| Surface | Asset |
|---|---|
| Login brand panel, Home hero | `assets/images/hero_donation.jpg` |
| Hydration and nutrition articles | `content_hydration.jpg`, `content_nutrition.jpg` |
| Recovery, screening and drive articles | `content_recovery.jpg`, `content_screening.jpg`, `content_drive.jpg` |
| Privacy article | `content_privacy.jpg` |
| Recipient story | `content_story.jpg` |
| Donor spotlight and drive cards | `drive_community.jpg`, `content_drive.jpg` |
| Educational illustrations | `assets/images/educational/edu_*.png` (7 originals) |
| Profile portraits | `assets/images/avatars/avatar_001.png` … `avatar_048.png` |
| App icon / PWA icons | `assets/branding/app_icon.png` |
| Chapter emblem | `assets/branding/prc_logo.png` (Philippine Red Cross; public domain/PD-ineligible, symbol use regulated by the Geneva Conventions) |

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

**126 tests** cover:

- **Seed data** — exactly 15 currently eligible donors (plus two deliberately
  away donors), 15 recipients, the community demo account, and a unique bundled
  avatar per seeded user.
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
- **Request verification** — a submission without documents or outside the
  published blood-bank schedule is refused; requests stay hidden from donors
  until staff verify them; rejection carries a written reason; verifying a
  blood-bank request holds the assigned units for the requester.
- **Request lifecycle** — compatible/ineligible/duplicate responses, blood-bank
  requests rejecting donor responses, requester-only selection, chat-first
  selection (one-sided chat is refused until both people send a message),
  selection authorization,
  selection-time eligibility rechecks, thread creation, leftover offers being
  declined, cross-request donor fairness (a committed donor cannot be reserved
  twice), staff-only fulfilment, and cancellation guards.
- **Inventory holds and appointments** — a unit can be held once, a second
  person cannot claim it, only its holder can release it, appointments start
  pending, requesters cannot confirm their own slot, and staff confirmation
  works.
- **Privacy and safety** — bilateral reveal accept/decline, persisted reports
  with a trimmed free-text explanation, per-participant unread/read markers,
  symmetric blocking, and the 48-hour re-block cooldown.
- **Donation recording** — component capture, component-specific cooldown, and
  a staff donation-window correction that does not increment the donation count.
- **Warnings and drives** — warnings cap at three, a third warning suspends,
  suspended accounts cannot be warned again, reinstatement resets the count,
  and only donor accounts can join a drive list.
- **Chapter activity log** — the seeded feed covers transfusions and account
  changes; recorded donations, donation-window corrections and profile/avatar
  changes each append an entry, per-user filtering returns only that account's
  events, and a signed-in staff session is attributed as the actor.
- **Automatic away availability** — a donor inactive for 30+ days is blocked
  with the `away` reason and never reaches the directory; `markActive` clears
  it, and the seed keeps exactly 15 eligible donors alongside the two
  deliberate away cases.
- **Chapter identity and staff stock** — a donor registration opens exactly one
  official chapter thread and status decisions post updates there; a donor
  verified from the queue is matchable because birth date and weight were
  captured; staff can add stock with the expiry derived from the component
  shelf life; community actors are refused stock additions and status changes.
- **Donor authoring and anonymity** — a donor can post a request that another
  donor can serve, and both the response alias and the map/directory handle are
  `Donor #<id>` tokens that never expose the nickname or legal name.
- **Account creation and privacy** — nickname uniqueness and full-name
  rejection, community-only self-registration, the donor upgrade path,
  staff/admin privilege rules for walk-in accounts, generated temporary
  passwords that authenticate, and the onboarding flag.
- **Donor registration** — a submitted registration interest (with or without
  an existing donor card) becomes a *pending* application, an unverified donor
  is never matched by the eligibility engine, staff can request documents
  without closing the application, and verifying flips the blood card, the
  account status and the open queue at once.
- **Interface widgets** — Home leads with its section rails, photo credit
  chips resolve for every bundled photograph and open the licence/source dialog
  (original artwork is deliberately uncredited), empty states render the vector
  illustration, every content item resolves to a bundled photo, the
  hero/feed/dialog mount those photos, a missing asset falls back to the themed
  placeholder, a narrow PageHeader stays a single compact line with its
  description in the tooltip, and the Digos vector map mounts all 26 barangays
  with tiles disabled (so no HTTP runs in tests), keeps its overlay controls in
  the wide desktop layout including the fit-city button, shrinks the phone
  control stack, and selects a barangay on tap. The Donor Hub additionally
  renders the automatic-away notice and clears it through the **I'm active**
  action, the staff Operations map renders its request layer and switches to
  the donor-density heatmap from the legend, the Operations workspace moves
  between its Map and Inventory views and collapses its inner sidebar, staff
  chat starts a new conversation from search, a user record opens its
  staff-only details and donation-window editor, the readiness score states its
  100% maximum with per-bar targets and a **Details** dialog, the Overview lists
  recent transfusions and account changes with a working filter, the avatar
  picker keeps the staff and community sets apart, the chapter mark ships the
  bundled Red Cross emblem, Settings switches mirror their values immediately
  (enabling slim rails unpins the sidebar), and the sidebar pin reopens the
  full rail from slim mode.
  Inventory exposes Add unit plus the appointment queue, and the phone bottom
  bar pins itself at the end of a scroll instead of staying hidden.
- **Narrow-screen layout** — Home, Blood Bank (including unit selection and
  the appointment dialog) and Overview render at a 360 × 780 phone viewport
  without overflow; the unit list reflows to one column and the appointment
  dialog stacks its fields.
- **Sidebar** — the Settings pin collapses or reopens the desktop rail, each
  rail item's icon stays dead-centre in its pill (the regression that left the
  selection accent bar pushing icons off-centre), and the compact pin control
  remains under the logo so an unpinned donor or admin rail can be pinned open
  again. The map style also follows the active theme, and the rebased pins stay
  on their OSM buildings under the nudged raster. Unread badges clear live when
  a conversation is read, and the phone bar scrolls instead of overflowing.
- **Barangay canonicalisation** — parenthetical stripping, case/punctuation
  normalisation, and round-tripping all 26 names.
- **Map topology** — all 75 shared arcs stitch 26 complete barangay rings and
  the 60 internal border arcs, so a truncated arc table cannot crash the map.
- **Map pin stability** — a drive pin resolves to the same coordinate on every
  call (no zoom-dependent screen-space nudging), and a drive sharing a
  facility's venue receives a fixed south-east offset.

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
