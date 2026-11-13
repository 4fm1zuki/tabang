# TABANG — AI Handoff Context

**Version:** 1.0  
**Baseline:** TABANG 2.0.0 base app  
**Last updated:** 2026-11-13  
**Purpose:** Give this file to another AI so it understands the whole TABANG project before changing anything.

> **How to use this file**
> 1. Paste this entire file into the AI conversation first.
> 2. If the AI has repository access, tell it to read the files named below before editing.
> 3. For backend work, also give it:
>    - `docs/backend/BACKEND_GUIDE.md`
>    - `docs/backend/TABANG_Backend_Guide.xlsx`
>    - `docs/backend/supabase_schema.sql`
> 4. Use the prompt at the end of this file as the first message.

---

## 1. Non-negotiable operating rules

1. **Inspect before editing.** Read the relevant files; do not guess APIs or field names.
2. **Never claim something works until `flutter analyze --no-pub` and `flutter test --no-pub` pass.**
3. **Do not add Firebase.** Firebase dependencies are unused scaffolding and will be removed/replaced by Supabase.
4. **Never put a Supabase `service_role` key in Flutter, web JS or a public repository.**
5. **Do not expose real names, emails or phone numbers** on community surfaces. Use aliases and `Donor #<id>` handles.
6. **Do not change demo credentials, seed counts, role rules or privacy rules** without updating tests and explaining the impact.
7. **Do not rebuild APKs or publish releases unless explicitly asked.**
8. **Preserve unrelated uncommitted work.** The working tree may contain deletions or edits made by the user.
9. **Use one data layer.** Domain data lives in `TabangRepository`; screens must not create their own duplicate stores.
10. **If a request is ambiguous, state the assumption and choose the smallest safe change.**

---

## 2. What TABANG is

**TABANG** stands for **Transfusion Access, Blood Availability and Network Guidance**.

It is a centralized donor-management and blood-request prototype for **Digos City, Davao del Sur**, built as a Senior High School research project at **Cor Jesu College, Inc.**

The app supports:

- community users / recipients posting blood requests
- donors browsing compatible requests and offering to donate
- chapter staff verifying requests, managing inventory and approving donor cards
- admins managing users, readiness targets and drives
- chat-first coordination with double-blind identity rules
- moderation, warnings, reports and blocks
- blood drives with staff proposal and admin approval
- public blood-bank stock, donor directory and city map
- a computed chapter readiness dashboard

**It is a simulated-data research prototype.** It is not a clinical system and is not connected to hospitals, Philippine Red Cross systems or live donor registries.

---

## 3. Current state

| Item | Status |
|---|---|
| Base app | Complete |
| Data layer | In-memory `TabangRepository`; resets on restart |
| Backend | **Not connected**; Supabase plan exists in `docs/backend/` |
| Tests | **210 tests**, all passing at the last check |
| Analyze | Clean at the last check |
| Android | Release APKs built (universal + per-ABI) |
| Web | Release web bundle built |
| Release | `v2.0.0`, tagged at `c54125c` |
| Web host | Static bundle intended for Cloudflare Pages |
| Backend guide | `docs/backend/` (committed) |
| Android signing | Debug key (research demo only) |

The app is deliberately **online-first but backend-free** in the base build. Do not imply that live synchronization exists yet.

---

## 4. Tech stack and commands

- Flutter **3.47.5**
- Dart **3.13.4**
- Material 3
- `flutter_map` + `latlong2` for the Digos map
- `file_picker` for request documents
- `crypto` for the prototype credential hash
- Firebase packages are present but **unused**

### Commands

```bash
flutter pub get
flutter run -d chrome
flutter run -d windows
flutter run -d android
flutter analyze --no-pub
flutter test --no-pub
flutter build apk --release
flutter build apk --release --split-per-abi
flutter build web --release
```

### Platforms

- Android: primary phone/tablet target, `minSdk 24`, package `ph.edu.cjc.tabang`
- Web: static Flutter build
- Windows/Linux: configured and supported
- iOS/macOS: configured but require a Mac to build

---

## 5. Demo accounts and roles

| Role | Email | Password |
|---|---|---|
| Donor | `juan.delacruz@tabang.app` | `donor1234` |
| Donor | `tere.santos@tabang.app` | `donor1234` |
| Donor (away) | `rafael.mendoza@tabang.app` | `donor1234` |
| Recipient | `maria.santos@tabang.app` | `recipient1234` |
| Community | `community@tabang.app` | `community1234` |
| Staff | `marco.villanueva@tabang.app` | `staff1234` |
| Admin | `admin@tabang.app` | `admin1234` |

### Roles

- `user` — Community User
- `donor` — Voluntary Donor
- `recipient` — Recipient / Patient Representative
- `staff` — Clinical Personnel
- `admin` — System Administrator

Staff and admin may manage the chapter console. Only admin may manage another staff/admin account, set readiness targets, or approve/reject/cancel drives. Nobody can self-register as staff/admin. The chapter organization account (`USR-CHAPTER`) is not a personal login.

---

## 6. Repository map

| Path | Responsibility |
|---|---|
| `lib/main.dart` | App root, theme mode, session routing, safe area |
| `lib/theme.dart` | M3 light/dark schemes, colours, typography, component themes |
| `lib/core/models.dart` | All domain models and enums |
| `lib/core/repository.dart` | The single in-memory data store, seed data, lifecycle rules, analytics |
| `lib/core/eligibility.dart` | Eligibility, cooldowns, ABO/Rh and component compatibility |
| `lib/core/auth.dart` | Prototype credential auth, self-registration, staff-created accounts |
| `lib/core/digos_geodata.dart` | Bundled 26-barangay topology |
| `lib/core/image_credits.dart` | Per-asset attribution registry |
| `lib/screens/auth/` | Login and registration |
| `lib/screens/donor/` | Donor/community shell, Home, Blood Bank, Find Donor, Requests, Messages, Donor Hub |
| `lib/screens/admin/` | Admin shell, Overview, Operations, Inventory, Drives, Users, Moderation |
| `lib/screens/shared/` | Profile, Settings, Guides & Help / About |
| `lib/widgets/` | Shared UI: cards, pills, dropdowns, map, dialogs, filters |
| `test/` | 210 behaviour tests |
| `docs/backend/` | Supabase schema, RLS, Realtime, sync guide and workbook |
| `android/`, `web/`, `ios/`, `macos/`, `linux/`, `windows/` | Platform scaffolding |

### Most important files

- `lib/core/models.dart` — source of truth for data shapes
- `lib/core/repository.dart` — source of truth for business rules and seed data
- `lib/core/eligibility.dart` — safety-critical matching rules
- `lib/widgets/common.dart` — shared `StatusPill`, `SurfaceCard`, tone helpers
- `lib/widgets/digos_vector_map.dart` — map rendering, pins, labels, controls
- `lib/widgets/blood_request_dialog.dart` — request submission and uploads
- `lib/widgets/request_review_dialogs.dart` — staff verify/reject dialogs
- `lib/screens/admin/operations_workspace_page.dart` — Map/Inventory/Drives switch
- `lib/screens/donor/requests_page.dart` — donor request board and details

---

## 7. Architecture and data flow

### Base app

```text
Flutter UI
   ↓
TabangRepository (in-memory singleton)
   ↓
models + eligibility + auth
```

Screens read the repository and listen for changes. `TabangRepository` notifies listeners after mutations. There is no server, no persistence and no cross-device synchronization in the base build.

### Planned backend

```text
Flutter UI
   ↓
Supabase Auth + PostgREST + Realtime + Storage
   ↓
Postgres with RLS and transactional RPCs
```

The backend plan uses:

- `auth.users` for credentials
- `profiles` for role/account state
- public projections: `donor_directory`, `blood_units_public`, `request_public`
- RPCs for every multi-row workflow
- Realtime subscriptions per screen
- private Storage bucket for request documents
- computed `chapter_metrics`, statistics views and thread views

Deep dive: `docs/backend/BACKEND_GUIDE.md`.

---

## 8. Domain model

### Core entities

| Entity | Key fields | Notes |
|---|---|---|
| `AppUser` | id, fullName, alias, email, phone, barangay, role, status, bloodType, birthDate, weightKg, lastDonationDate, lastDonationComponent, totalDonations, isAvailable, lastActiveAt, bloodCardVerified, shareBarangay, notify*, onboardingCompleted, photoAsset, allowedComponents | `alias` is public; real name/email/phone are staff-only |
| `BloodUnit` | barcode, bloodType, component, storageBay, status, collectedOn, expiresOn, reservedBy, reservationNote, reservedAt | Expiry is effective even if status was never changed |
| `RemovedUnitRecord` | unit, removedAt, removedById, restored | Inventory ledger |
| `AccountWarning` | id, userId, level, message, issuedById, issuedByAlias, issuedAt, acknowledgedAt | Max 3 active warnings |
| `BloodRequest` | id, requesterId, patientAlias, bloodType, component, unitsNeeded, hospital, barangay, urgency, createdAt, status, unitsFulfilled, source, note, documents, scheduledFor, postToDonorNetwork, reviewNote, reviewedById, assignedUnitIds | Starts awaiting verification |
| `RequestDocument` | kind, fileName, bytes, previewAsset, sizeBytes | `bytes` is only in memory; backend uses Storage |
| `RequestResponse` | id, requestId, donorId, donorAlias, createdAt, message, status | An offer, not a selection |
| `UserReport` | id, reporterId, reporterAlias, reportedUserId, reportedAlias, reason, details, createdAt, threadId, status | Persisted moderation queue |
| `ChatMessage` | id, senderId, senderAlias, text, sentAt, flag, flagReason, sentAsChapter | System notices use sender `system` |
| `ChatThread` | id, participantA/B, aliases, messages, identityRevealed, groupName, memberIds, memberReadAt, reveal requester, isMuted, unblockedAt, read markers | Direct, chapter or group |
| `DonorApplication` | id, userId, submittedAt, status, hasExistingCard, cardNumber, preferredVisit, note, requestedDocuments, staffNote | Medical interview is face-to-face |
| `BloodDrive` | id, title, venue, barangay, startsAt, endsAt, expectedDonors, isOpenForRegistration, photoAsset, approval, proposedById, reviewedById, reviewNote, lat, lng | Only approved drives are public |
| `ContentItem` | id, title, subtitle, body, tag, category, imageAsset | Home/Discover content |
| `AnalyticsSummary` | donationsToday, donationsThisMonth, registeredUsers, activeDonors, activeDrives, topBarangay, unitsAvailable, openRequests | Computed |
| `ReadinessTargets` | unitTarget, donorTarget, requestPressureCap, communityTarget | Admin-editable denominators |
| `ActivityEvent` | id, kind, actorId, actorAlias, subjectId, subjectAlias, summary, at | Audit feed and tab dots |
| `BloodTypeStat` | bloodType, donated, requested, balance | Computed |
| `BarangayStat` | barangay, donationCount, donorCount | Computed |
| `EligibilityResult` | isEligible, blocker, eligibleFrom, daysRemaining, donorType, summary | Computed eligibility |

### Enums

- `BloodType`: O−, O+, A−, A+, B−, B+, AB−, AB+
- `BloodComponent`: whole blood, packed RBC, platelets, plasma
- `UnitStatus`: available, reserved, quarantined, dispatched, expired
- `AccountStatus`: unverified, verified, warned, suspended
- `UserRole`: user, donor, recipient, staff, admin
- `RequestUrgency`: routine, urgent, critical
- `RequestStatus`: pending review, open, matched, fulfilled, rejected, cancelled
- `RequestSource`: blood bank, donor network
- `ResponseStatus`: pending, selected, declined, withdrawn
- `ReportStatus`: open, resolved, dismissed
- `ModerationFlag`: clean, flagged, inappropriate, spam
- `DonorApplicationStatus`: pending, documents requested, verified, rejected
- `DriveApproval`: pending, approved, rejected, cancelled
- `ContentCategory`: explore, tips, eligibility, drives, stories
- `ActivityKind`: donation, donation window, profile, avatar, verification, warning, suspension, application, report, request submitted, request verified, request rejected, request reopened, drive update, inventory, readiness targets
- `EligibilityBlocker`: none, cooldown, underage, overage, underweight, weight missing, suspended, unverified, unavailable, away, no blood type, restricted

---

## 9. Business rules

### Eligibility

A donor is eligible only when all are true:

- role is donor
- account is verified and blood card is verified
- not suspended
- blood type recorded
- age 18–65
- weight at least 50 kg
- manually available
- active within the last 30 days
- component is allowed by staff, when a restriction exists
- outside the component cooldown

Cooldowns:

- whole blood / packed RBC: 84 days
- platelets: 14 days
- plasma: 28 days

A missing weight blocks matching. An unverified donor never appears as matchable. An `available` bag past `expiresOn` is treated as expired.

### Compatibility

- Red cells: standard ABO/Rh matrix; O− universal donor, AB+ universal recipient
- Plasma: reverse ABO rule; AB plasma universal plasma donor, O plasma only to O
- Platelets: red-cell baseline in this prototype
- Component-aware compatibility is used by requests, donor responses and inventory filters

### Request lifecycle

1. Requester fills: patient alias, blood type, component, units (1–20), hospital, barangay, urgency, clinical note, 3 required documents, optional typing result, and a blood-bank slot.
2. Request starts `pendingReview`.
3. Staff verify → `open`; blood-bank requests may hold compatible units. Donor-network requests become visible to donors.
4. Donor responds → `pending` response.
5. Requester selects a donor only after **both sides have exchanged at least one human message**.
6. A donor can have only one active commitment.
7. When enough responses are selected, request becomes `matched`; remaining offers are declined.
8. Staff record fulfilment → `fulfilled`. Only staff/admin can fulfil.
9. Reject requires a reason. Rejection releases holds and declines pending offers.
10. Verification/rejection can be undone only from the expected state. Fulfilment can be reopened by staff.

### Inventory

- Staff receive stock; expiry is derived from component shelf life.
- Barcode is unique.
- A unit can be held by one person at a time.
- Holds are not transfusion orders; staff still release/cross-match.
- Expired bags cannot be returned to available stock.
- Removal creates a ledger record; restore refuses a barcode already back in use.
- Effective status always considers `expiresOn`.

### Drives

- Staff propose; drive starts `pending`.
- Only admin approves/rejects/cancels.
- Only approved drives reach donor surfaces and map pins.
- Every decision has an undo from the expected state.
- Donors can register interest; community users cannot.

### Warnings and suspension

- Staff/admin issue warnings with a specific message.
- Max 3 active warnings.
- Third warning suspends automatically.
- Reinstatement clears the active warning ladder.
- Removing a warning steps the ladder down; it never clears a staff suspension for another reason.

### Chat and privacy

- Aliases are public; real names/contact details only after bilateral reveal.
- `Donor #<id>` is the map/directory handle.
- Identity reveal is request → accept/decline.
- Blocking is symmetric for messaging and has a 48-hour re-block cooldown.
- Reports persist with category and optional details.
- Chapter account posts as the organization, never as a personal staff name.
- Staff room is a group thread for staff/admin only.
- Selection requires reciprocal human chat.

### Tab activity dots

Activity kinds light specific tab dots:

- home: donation, inventory, request verified
- find donor: verification, request verified
- requests: request submitted/verified/rejected
- blood bank: inventory
- donor hub: application, verification, warning, suspension, donation, donation window (personal only)
- overview: donation
- operations: request submitted/verified/rejected, inventory
- users: application, verification, warning, suspension, profile, avatar
- moderation: report

Messages use unread counts, not activity dots.

### Readiness

- `chapter_metrics` derives counts from live data.
- Readiness score is capped at 100%.
- Components: supply coverage, shelf life, donor capacity, community reach, request pressure.
- Admin edits the four denominators only; the score itself is never typed in.

---

## 10. Screen map

### Community/donor

- **Home** — hero, quick actions, upcoming drives, announcements/stories, learning cards, visit planner
- **Blood Bank** — stock grid, unit cards, reserve/release, request this unit
- **Find Donor** — map, barangay filter, donor directory, facilities, drives, draggable split
- **Requests** — open donor-network requests, Mine tab, Donate tab, filters, request details
- **Messages** — threads, unread markers, identity reveal, block/report, chapter thread
- **Donor Hub** — eligibility, next available date, donation history, availability, donor registration
- **Profile** — per-component eligibility, blood card, history, preferences
- **Settings** — theme, rails, availability, privacy, account
- **Guides & Help / About** — task guides, FAQ, about, credits, support thread

### Staff/admin

- **Overview** — readiness score, KPIs, exceptions, roles & permissions, recent activity
- **Operations** — Map / Inventory / Drives segmented workspace
  - Map: staff request queue, donor directory, request heat
  - Inventory: units, requests, booked slots, removed units
  - Drives: propose, approve/reject/cancel, restore
- **Messages** — same chat surface, staff room, chapter identity
- **Users** — accounts, donor applications, verification, warnings, suspension, donations
- **Moderation** — reports, flagged messages, muting, keyword management

---

## 11. Backend blueprint in one screen

The backend plan is complete in `docs/backend/`:

- **38 tables**
- **20 enums**
- **10 derived views**
- **365 column definitions**
- **282 model-coverage rows**
- **83 derived/pre-calculated value mappings**
- **70 Dart-to-Supabase migration mappings**
- **29 ID/cardinality/constraint rules**

### Table groups

- Identity: `profiles`, `profile_tab_seen`, `notifications`
- Reference/config: `barangays`, `facilities`, `blood_types`, `blood_components`, `document_requirements`, `donor_requirements`, `donor_screening_questions`, `chapter_settings`, `role_capabilities`, `tab_activity_rules`
- Donors: `donor_directory`, `donations`, `donor_applications`, `account_warnings`
- Inventory: `blood_units`, `blood_units_public`, `inventory_removals`, `request_units`
- Requests: `requests`, `request_public`, `request_documents`, `request_responses`, `request_status_history`
- Drives/content: `blood_drives`, `drive_interests`, `content_items`
- Messaging/moderation: `chat_threads`, `chat_thread_members`, `chat_messages`, `user_blocks`, `user_reports`, `activity_events`, `moderation_keywords`
- Reporting: `readiness_targets`, `chapter_metrics`

### Critical backend rules

- `auth.users` is the only credential store.
- `profiles` owns role/status.
- Public screens read projection tables, never base tables with PII.
- Multi-row workflows are RPCs.
- Realtime is a notification, not the initial load.
- Request documents go in a private Storage bucket.
- No service role in the client.
- UUIDs + legacy IDs; never `length + 1` IDs.
- Server time is UTC; display Asia/Manila.

### Backend files

- `docs/backend/BACKEND_GUIDE.md` — narrative and ERD
- `docs/backend/TABANG_Backend_Guide.xlsx` — 23-sheet workbook
- `docs/backend/supabase_schema.sql` — starter DDL and core RPCs

The SQL is a starter, not an applied migration. The RPC bodies for submit/select/apply/drive/block/report still need implementation.

---

## 12. Testing and quality gates

Before claiming a change is complete:

```bash
flutter analyze --no-pub
flutter test --no-pub
```

Current suite: **210 tests**. It covers:

- eligibility and ABO/Rh compatibility
- expiry and effective status
- request verification, rejection, undo and fulfilment
- inventory holds, release, removal and restore
- donor applications and warnings
- chat-first selection, fairness and identity reveal
- reports, blocks and moderation
- drive approval and undo
- tab activity dots
- map topology, offset, scale bar and light/dark style
- responsive phone/desktop layouts
- filters, dropdowns, status pills and shared cards

When changing a model, update tests and seed data together. When changing a UI contract, update the relevant widget test.

---

## 13. Coding conventions

- Material 3, warm crimson theme.
- Use shared widgets from `lib/widgets/common.dart`.
- Use `TabangSnackBar` for snackbars.
- Use `TabangDropdown` for filter/form dropdowns.
- Keep one data layer: `TabangRepository`.
- Use `copyWith` for model updates.
- Do not mutate public lists directly.
- Keep responsive thresholds consistent:
  - phone layout below ~760 px
  - desktop rail from ~1024 px
- Use `context.pagePadding`, `TabangSpace`, `TabangRadius`.
- Keep accessibility labels and tooltips.
- Preserve light/dark parity.
- Use aliases/public handles on community surfaces.
- Use `timestamptz` in the backend; local display only.
- Prefer small, focused widgets and tests.

---

## 14. Common tasks and where to change them

| Task | Start here |
|---|---|
| Change a card/pill | `lib/widgets/common.dart`, the specific card widget |
| Change request workflow | `lib/core/repository.dart`, `lib/screens/donor/requests_page.dart`, `lib/widgets/request_review_dialogs.dart` |
| Change eligibility | `lib/core/eligibility.dart` and `test/eligibility_test.dart` |
| Change inventory | `lib/screens/admin/inventory_management.dart`, `lib/core/repository.dart` |
| Change map | `lib/widgets/digos_vector_map.dart`, `lib/widgets/digos_map_pane.dart` |
| Change auth | `lib/core/auth.dart`, `lib/screens/auth/` |
| Change staff console | `lib/screens/admin/` |
| Change backend plan | `docs/backend/` |
| Change test expectations | `test/` |
| Update release | Only when explicitly asked; see README release artifacts |

---

## 15. Do not do these

- Do not add Firebase.
- Do not use a Supabase service-role key in the app.
- Do not expose full names, emails or phone numbers to community users.
- Do not create IDs with `length + 1`.
- Do not let a client set a role/status/total donation count directly.
- Do not split a multi-row workflow into separate client writes.
- Do not subscribe public screens to base tables containing PII.
- Do not rebuild or publish APKs unless asked.
- Do not commit unrelated user changes.
- Do not claim tests pass without running them.
- Do not treat the starter SQL as a production-tested migration.
- Do not implement clinical advice or real hospital integration.

---

## 16. Known gaps / next phase

- No live Supabase backend yet.
- No push notifications, voice calls, Google OAuth or production authentication.
- No profile-picture upload.
- No clinical screening; weight is self-reported.
- Donor medical-history answers are shown as chapter interview content but are not persisted.
- Android release uses the debug signing key.
- Web build is static; no server-side secrets.
- Firebase packages are unused and should be removed before/with the Supabase migration.
- The SQL starter still needs RPC bodies and tests against a real Supabase project.
- The chapter account must be seeded as a real auth user with `profiles.is_system = true`.

---

## 17. Ready-to-paste first prompt

```text
You are working on TABANG, a Flutter research prototype for blood donation in Digos City.

Read this entire context file first. Then:
1. Restate the five constraints most relevant to the task.
2. Inspect the files you intend to change.
3. Make the smallest safe change.
4. Run `flutter analyze --no-pub` and `flutter test --no-pub`.
5. Report exactly what changed, what passed, and any remaining risk.

Do not add Firebase, do not expose PII, do not use a service_role key in the client, and do not rebuild APKs or publish releases unless I explicitly ask.

Task:
[describe the task here]
```

---

## 18. Glossary

- **TABANG** — Transfusion Access, Blood Availability and Network Guidance
- **Chapter** — Philippine Red Cross – Davao del Sur Chapter
- **Donor handle** — `Donor #<id>`, the anonymous map/directory identity
- **Alias** — the public nickname; legal name is staff-only until bilateral reveal
- **Coordinating** — a donor already selected for another active request
- **Hold/reservation** — a temporary claim on a unit; not a transfusion order
- **Matched** — enough donors selected for a donor-network request
- **Fulfilled** — staff recorded the donation and closed the request
- **Projection** — a safe public table derived from private base tables
- **RPC** — a Postgres function that performs an atomic multi-row workflow
- **RLS** — Postgres row-level security
- **Realtime** — Supabase change notifications
- **Readiness score** — computed chapter capacity score, capped at 100%