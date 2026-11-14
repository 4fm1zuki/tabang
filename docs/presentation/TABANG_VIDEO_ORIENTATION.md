# TABANG — Video Orientation Guide & Script

**Format:** screen-recorded product orientation with voiceover  
**Length:** 7–9 minutes (target 8:00)  
**Audience:** classmates, panelists, chapter staff, and general viewers who need to understand what TABANG does without a technical lecture  
**Tone:** clear, calm, professional; explain the purpose before the buttons

---

## 1. Video specification

| Item | Recommendation |
|---|---|
| Aspect ratio | 16:9 |
| Resolution | 1920 × 1080 |
| Frame rate | 30 fps |
| Audio | One clean voice track; light background music at −24 dB under the voice |
| Captions | Burned-in or uploaded `.srt`; include the demo account labels |
| Recording | Screen recording of the web build, browser at 100–110% zoom |
| Cursor | Visible, slow, deliberate movements; no rapid circling |
| Notifications | Off; close chat/email before recording |
| Data | Simulated demo accounts only; no real patient information |
| Privacy | Never show real names, emails, phone numbers, or uploaded document content |

### Before recording

1. Run the web build or desktop build.
2. Sign in as the donor demo account.
3. Confirm the demo data is reset to its seed state.
4. Set the browser to a clean window with no personal tabs.
5. Prepare the staff and admin tabs in separate windows for quick switching.
6. Have the narration script open on a second screen or printed.
7. Record a 10-second test for audio level and cursor visibility.

### During recording

- Pause for one beat after each screen change.
- Say the **purpose** of a screen before listing its controls.
- Do not read every label; point to the three or four that matter.
- Keep one idea per sentence.
- When showing a private document, stop at the frame and explain the boundary; do not open the file.

### After recording

- Trim dead air and login typing.
- Add lower-third labels for each section.
- Add a subtle highlight around the control being discussed.
- Caption the demo accounts and the "simulated data" disclaimer.
- Watch once with sound off to check that the visuals still tell the story.

---

## 2. Storyboard and narration script

### 0:00–0:30 — Opening

**Visual:** TABANG login screen; slow push-in on the brand panel.  
**On-screen text:** TABANG — Transfusion Access, Blood Availability and Network Guidance.

**Narration:**

> TABANG is a blood-donation coordination system designed for Digos City. It connects people who need blood, people who can donate, and the chapter staff who verify and manage the process.
>
> This is a research prototype. It uses simulated records, not real patient data, and it does not connect to a live hospital or Philippine Red Cross system.

### 0:30–1:10 — The problem and the idea

**Visual:** Home screen after donor login; quick actions and the upcoming-drives rail.  
**On-screen text:** One shared view of need, stock, donors, and chapter decisions.

**Narration:**

> Blood coordination usually breaks into separate conversations: a request here, a donor list there, and a chapter that has to verify everything by hand.
>
> TABANG puts those pieces in one place. A requester can post a documented request. A donor can see compatible needs and offer to help. Staff can verify the documents, hold stock, and record the donation. Everyone sees the same records, and the privacy rules stay the same on every screen.

### 1:10–2:05 — The donor and community view

**Visual:** Home → Blood Bank → Find Donor map → Requests board.  
**On-screen text:** Browse stock · Find donors · See verified requests.

**Narration:**

> This is the community side. The Home page gives three direct actions: request blood, find a donor, or find a drive.
>
> Blood Bank shows the chapter's current stock by component and blood type. A community member can inspect a unit, but a hold is not a transfusion order; staff still confirm the clinical release.
>
> Find Donor opens the Digos City map. Donors appear as anonymous handles such as “Donor #001,” not real names. Barangays, facilities, and drives can be filtered from the same map.
>
> The Requests board only shows requests that chapter staff have verified. An unverified submission stays private to its requester and staff.

### 2:05–3:05 — Posting a request and the privacy boundary

**Visual:** Requests → Request blood dialog; scroll through documents and slot; show the submitted card; open the privacy notice on another user’s request.  
**On-screen text:** Documented request · Chapter verification · Private uploads.

**Narration:**

> A request is more than a text post. The requester uploads the doctor's request form, the transfusion slip, and the patient ID, then books one of the chapter's published blood-bank slots.
>
> The request starts as “Awaiting verification.” Staff inspect the files and confirm the slot before the request is broadcast.
>
> The medical documents, the clinical note, and the chapter's review note are visible only to the requester and chapter staff. Another donor can see the need, the hospital, the barangay, and the urgency, but cannot open someone else's uploads. That boundary is enforced in the interface and in the planned backend rules.

### 3:05–4:15 — The staff operations view

**Visual:** Staff login → Overview → Operations map → Inventory → request verification → booked slots.  
**On-screen text:** Verify · Hold stock · Record the donation.

**Narration:**

> Staff land on the chapter console. The Overview gives a readiness score, supply and donor indicators, and the actions that need attention.
>
> Operations combines the map, inventory, and drives. On the map, staff see the request queue, the donor directory, and a request heat layer by barangay.
>
> In Inventory, staff receive units, track expiry, place or release holds, and work the request queue. Verifying a request checks the uploaded documents and the booked slot, and a blood-bank request can hold compatible units at that moment.
>
> Booked slots and removed units stay in their own queues, so nothing disappears from the record. Every stock move can be traced and, where appropriate, undone.

### 4:15–5:05 — Drives, users, and moderation

**Visual:** Drives tab → Add drive → Users → warning/verification → Moderation queue.  
**On-screen text:** Staff propose · Admin approves · Accountability is recorded.

**Narration:**

> Staff can propose a blood drive, but only an admin can approve, reject, or cancel it. An approved drive reaches the donor Home page, the drive list, and the map pins.
>
> User management lets staff verify blood cards, issue warnings, suspend or reinstate accounts, and record donations. The warning ladder is capped at three, and reinstatement clears the active count.
>
> Moderation holds flagged messages and user reports. Staff can clear or escalate a flag, mute a thread, or resolve a report with the reporter's explanation attached.

### 5:05–6:00 — Messaging, identity, and fairness

**Visual:** Messages → open a coordination thread → identity reveal prompt → report/block controls.  
**On-screen text:** Chat first · Mutual reveal · One active commitment.

**Narration:**

> Coordination happens in Messages. People start with aliases. Real names and contact details appear only after both sides agree to reveal them.
>
> A requester can select a donor only after both people have exchanged a real message. This prevents a request from being filled by a name on a list with no human coordination.
>
> A donor who is already committed to one active request is marked “Coordinating” and cannot be reserved twice. Reporting and blocking are available in the same thread, and a block is symmetric for messaging.

### 6:00–7:00 — What is happening behind the interface

**Visual:** Diagram or calm shot of the app with a simple layered overlay: Flutter → data layer → Supabase plan.  
**On-screen text:** One source of truth · Role-based access · Live updates.

**Narration:**

> In this build, the data layer is simulated in memory, so the demo resets when the app restarts. The next phase moves the same model to Supabase.
>
> The backend plan uses Postgres for the records, row-level security for access, transactional functions for workflows such as verifying a request or holding a unit, and Realtime so two devices see the same update.
>
> Public screens read safe projections: a donor directory without contact details, public stock without holder identity, and verified requests without private notes. Staff screens use the full records. That is how the interface stays simple without weakening the privacy boundary.

### 7:00–7:50 — Closing

**Visual:** Return to the Home screen or a clean title card.  
**On-screen text:** TABANG — a clearer path from need to donation.

**Narration:**

> TABANG is not a replacement for clinical judgment or a live blood-service system. It is a coordination prototype: documented requests, verified donors, visible stock, and an auditable chapter workflow.
>
> The goal is simple. Make the next step clear for the person who needs blood, the person who can give it, and the chapter that has to make it safe.
>
> Thank you.

---

## 3. Optional short cut (2:30)

If the panel asks for a shorter version, use:

1. **0:00–0:20** — What TABANG is and the simulated-data disclaimer.
2. **0:20–0:50** — The community view: stock, map, verified requests.
3. **0:50–1:25** — The documented request and the privacy boundary.
4. **1:25–2:00** — Staff verification, inventory holds and drives.
5. **2:00–2:20** — Messaging and the chat-first selection rule.
6. **2:20–2:30** — Backend direction and closing.

Use the same narration, trimmed to one sentence per section.

---

## 4. Final presenter checklist

- [ ] Demo accounts are listed in the description or opening slide.
- [ ] The words “simulated data” appear on screen and in the narration.
- [ ] No real names, emails, phone numbers, or uploaded documents are visible.
- [ ] The request privacy boundary is shown, not just described.
- [ ] Staff and admin actions are distinguished.
- [ ] The video explains **why** before **how**.
- [ ] Captions are accurate.
- [ ] The video ends with the limitations and the next phase, not a sales claim.
- [ ] A 2:30 cut exists for time-limited presentations.
- [ ] The final file is named `TABANG_Orientation_2.1.0.mp4`.

---

## 5. Suggested description

> TABANG is a simulated-data blood-donation coordination prototype for Digos City. This orientation walks through the community request flow, the donor map and stock view, chapter verification, inventory holds, blood drives, privacy boundaries, and the planned Supabase backend. No real patient data is used.  
> Demo accounts are listed in the app's README.  
> Built with Flutter; designed for Android and the web.