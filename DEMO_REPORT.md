# TABANG — Demonstration Guide

A simple, complete list of the sections (features) and subsections to walk through during the demo, with staff and admin surfaces included.

## Demonstration Targets

For **every section**, the reporter covers these four points:

- **Purpose** — why the feature exists.
- **Components** — the parts and subsections on screen.
- **How to collect data** — what information the feature gathers/uses and how.
- **How it's made** — how it is built (data source, rules, technology).

---

## 1. Access & Onboarding

### 1.1 Login
- Purpose: sign in and route each account to the right surface.
- Components: email/password fields, demo account list (tap to autofill), sign-in button.
- How to collect data: email + password, checked against the credential store.
- How it's made: local salted SHA-256 credential store; session routed by role.

### 1.2 Registration
- Purpose: create a community account.
- Components: 3-step wizard, success handoff to Login.
- How to collect data: full name, unique nickname, email, contact number, birth date, blood type, weight, barangay.
- How it's made: validation for unique nickname and full-name rejection; new accounts are always community; admin/staff self-registration is blocked.

---

## 2. Community App

### 2.1 Home
- Purpose: the landing feed and starting point for community users.
- Components: quick actions (Request blood, Find a donor, Find a drive); rails for upcoming drives, announcements, stories, learning cards; visit planner.
- How to collect data: reads seeded announcements, stories, drives and articles.
- How it's made: single repository snapshot feeding all rails.

### 2.2 Blood Bank
- Purpose: show public blood stock and let users act on it.
- Components: chapter banner, stock note, stock grid by component × blood type, unit card list, unit detail view.
- How to collect data: unit records (product, storage, expiry, status); compatible stock check.
- How it's made: read-only public view over inventory; expired units excluded; request dialog seeded from the unit.

### 2.3 Find Donor
- Purpose: locate donors by area and blood type.
- Components: Digos City map, donor-density heat, drive/hospital/chapter pins, side panel (Donors / Facilities / Drives tabs), blood-type chips, barangay filter, draggable divider.
- How to collect data: donor records (barangay, blood type, eligibility), facility seeds, drive seeds.
- How it's made: bundled barangay geometry (26 barangays) + optional OSM base tiles; anonymous `Donor #<id>` handles only.

### 2.4 Requests
- Purpose: post and serve blood requests.
- Components: Requests tab (open requests), Mine tab (posted requests + status), Donate tab (joinable drives); request dialog with document uploads and slot booking; response dialog.
- How to collect data: uploaded documents (doctor's form, transfusion slip, patient ID; typing result optional), blood type, component, urgency, booked slot.
- How it's made: request lifecycle (Awaiting verification → Verified → Matched → Fulfilled); chat-first selection; requester-only selection; staff fulfilment.

### 2.5 Messages
- Purpose: coordinate between requester and donor, and with the chapter.
- Components: conversation list, thread view, composer, identity reveal request, report dialog, block/unblock.
- How to collect data: text messages, reveal requests, reports with reason and optional details.
- How it's made: double-blind threads; bilateral reveal; chapter support thread with verified badge; 48-hour re-block cooldown; seen markers and unread counters.

### 2.6 Donor Hub
- Purpose: the donor's own tools.
- Components: eligibility window, next available date, donation history, availability controls, Register as a donor, verification card.
- How to collect data: blood type, birth date, weight, PRC donor card (optional number), visit day.
- How it's made: eligibility engine (age 18–65, weight ≥50 kg, per-component cooldowns); auto-away after 30 days; unverified donors are not matched until staff verify.

### 2.7 Profile
- Purpose: personal account and eligibility summary.
- Components: per-component eligibility chips with cooldown rows, blood-card verification state, blood type, weight, last donation component, notification preferences.
- How to collect data: donor record and donation history.
- How it's made: reads the same repository snapshot; per-component cooldown computed live.

### 2.8 Settings
- Purpose: personal display and account preferences.
- Components: appearance (light default / dark explicit), slim navigation rails toggle, donor availability, privacy/data, account section.
- How to collect data: user choices (theme, rails, availability).
- How it's made: preferences applied live; availability syncs with Donor Hub.

### 2.9 Guides & Help (About TABANG)
- Purpose: educate users and provide support.
- Components: task guides, FAQ (A→Z per category), About TABANG (summary, SDG alignment, safety commitments, known gaps, photo credits), Message chapter staff card.
- How to collect data: help content; feedback/question sent into a real support thread.
- How it's made: static guide content plus a live chapter support thread.

---

## 3. Staff Console

### 3.1 Overview
- Purpose: chapter readiness at a glance.
- Components: readiness score (capped at 100%), five weighted components (supply coverage, shelf-life, donor capacity, community reach, request pressure), KPI cards, Roles & permissions card, recent transfusions & account changes, user-management deep-link.
- How to collect data: live counts of units, requests, registered users, active donors.
- How it's made: score computed live from repository data (never entered by hand); Details shows weights and targets.

### 3.2 Operations — Map
- Purpose: operational view of requests and registrations.
- Components: same map surface as Find Donor, Requests / Donor-density heat switch, side panel (Requests / Registrations tabs), barangay scoping.
- How to collect data: request counts per barangay, registrations.
- How it's made: shared map engine; Awaiting-verification requests shown first.

### 3.3 Operations — Inventory
- Purpose: manage blood units and the request queue.
- Components: unit list with Details and status menu, barcode graphic, holder name, Remove unit, Removed units ledger, Add unit, booked-slot queue, request queue.
- How to collect data: blood type, component, storage bay, collection date, optional barcode.
- How it's made: expiry derived from component shelf life; remove/restore with Undo; held bags released after screening; staff-only actions.

### 3.4 Messages
- Purpose: staff communication.
- Components: community chat surface, staff room group conversation, start new conversation.
- How to collect data: messages, chapter-identity replies.
- How it's made: staff posts under personal alias; replies to community users default to chapter identity; per-member read markers.

### 3.5 Users
- Purpose: manage accounts and donations.
- Components: walk-in account creation, blood-card verification, warnings, suspend/reinstate, donation recording, account record view.
- How to collect data: fixed-choice fields, temporary password, warning reason, donation component/dates.
- How it's made: warnings capped at three (third auto-suspends); privilege rules enforced (staff cannot manage themselves, other staff, or admins; only an admin manages staff).

### 3.6 Moderation
- Purpose: keep conversations safe.
- Components: flagged messages, clear/escalate, mute threads, user-report queue, console reply.
- How to collect data: flags, reports with required reason and optional free-text explanation.
- How it's made: reports persist in the repository; replies to official chapter threads use the organization identity; person-to-person threads are read-only.

---

## 4. Admin & Governance

### 4.1 Readiness & Targets
- Purpose: tune the chapter's planning model.
- Components: Set targets, weights and targets (Details), Use defaults, restore defaults.
- How to collect data: supply units, eligible donors, request-pressure cap, registered accounts.
- How it's made: admin-only; validated; every change written to the activity log.

### 4.2 Staff & Account Management
- Purpose: control who can do what.
- Components: add/manage staff, Roles & permissions card.
- How to collect data: staff account details.
- How it's made: only an admin can add or manage staff; no admin can be created in-app.

---

## 5. Roles (Personas)

For each role, cover: who they are, what they can do, and the demo account.

- **Base User (Community)** — requests blood, browses donors, messages, opts in to donating.
- **Donor** — eligibility, availability, donation history, responds to requests, joins drives.
- **Donor — Away** — auto-marked away after 30 days inactive; returns via I'm active.
- **Recipient** — posts requests, reviews donors, selects after chat; fulfilled by staff.
- **Staff (Clinical Personnel)** — verifies, fulfils, manages inventory and users, moderates.
- **Admin (System Administrator)** — everything staff can do, plus targets and staff management.

---

## 6. App Sources & Foundation

- **Technology:** Flutter/Dart; map, auth, file upload and hashing libraries.
- **Source layout:** core (models, eligibility, repository, auth, geodata, credits), widgets, screens, tests, tools.
- **Data source:** simulated in-memory records, seeded at launch, reset on restart; no live backend.
- **Map data:** bundled 26-barangay geometry; optional keyless OSM base.
- **Assets:** all images bundled locally with individual credits.
- **Quality:** analyze, 153 tests, release web build.
- **Scope & gaps:** simulated data only; some paper items not implemented (OAuth, backend, calls, uploads, push).
