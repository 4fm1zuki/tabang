"""Build TABANG_Demonstration_Guide.docx.

Structured around the reporter assignments: every section and sub-section names
its reporter, and each sub-section carries the same four one-line demonstration
targets (Purpose, Components, How to collect data, How it's made), written for a
general audience.

Run from the repository root:

    python tools/make_demo_guide.py

Edit this file with a UTF-8 aware editor (the text contains en/em dashes and
"Niño"); do not round-trip it through a PowerShell Get-Content/Set-Content pair,
which re-encodes it as ANSI.
"""

from __future__ import annotations

import os

import docx
from docx.shared import Pt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, "TABANG_Demonstration_Guide.docx")


def build() -> None:
    document = docx.Document()
    normal = document.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(11)
    normal.paragraph_format.space_after = Pt(3)

    def title(text: str) -> None:
        run = document.add_paragraph().add_run(text)
        run.bold = True
        run.font.size = Pt(20)

    def line(text: str) -> None:
        document.add_paragraph(text)

    def head(text: str, level: int = 1) -> None:
        document.add_heading(text, level=level)

    def bullets(items: list[str]) -> None:
        for item in items:
            document.add_paragraph(item, style="List Bullet")

    def section(title_text: str, reporter: str, items: list[str]) -> None:
        """One sub-section: the four demonstration targets, one line each."""
        head(f"{title_text} ({reporter})", level=2)
        bullets(items)

    def targets(
        title_text: str,
        reporter: str,
        purpose: str,
        components: str,
        data: str,
        made: str,
    ) -> None:
        section(
            title_text,
            reporter,
            [
                f"Purpose: {purpose}",
                f"Components: {components}",
                f"How to collect data: {data}",
                f"How it's made: {made}",
            ],
        )

    # ------------------------------------------------------------------ head
    title("TABANG \u2014 Demonstration Guide")
    line(
        "Transfusion Access, Blood Availability and Network Guidance | "
        "Digos City, Davao del Sur | Build 2.0.0"
    )
    line(
        "How to use this guide: keep it open while the app is on screen. Each "
        "numbered part belongs to one reporter, says what to show, and gives the "
        "four demonstration targets in one line each. Everything is written for "
        "a general audience \u2014 no technical words needed."
    )

    # ------------------------------------------------------- who presents
    head("Who presents what")
    bullets(
        [
            "Ni\u00f1o \u2014 Executive summary; 1. Access & Onboarding (Login, Registration).",
            "Sam \u2014 2. Community app: Home, Blood Bank, Find Donor.",
            "Hanz \u2014 2. Community app: Requests, Messages, Donor Hub.",
            "Lloyd \u2014 2. Community app: Profile, Settings, Guides & Help.",
            "Aeron \u2014 3. Staff console: Overview, Operations Map, Operations Inventory, Operations Drives.",
            "Kath \u2014 3. Staff console: Messages, Users, Moderation.",
            "Iverson \u2014 4. Admin: Readiness Targets, Staff & Account Management; 5. Role & Persona Matrix; 6. Technical Foundations.",
        ]
    )

    # ------------------------------------------------------- the four targets
    head("The four demonstration targets")
    line("Every section below answers the same four questions:")
    bullets(
        [
            "Purpose \u2014 why it exists, and the problem it removes.",
            "Components \u2014 the parts you can see on screen (buttons, lists, tabs).",
            "How to collect data \u2014 what information goes in, and how we gather feedback from the people testing it.",
            "How it's made \u2014 how it is built: language, framework, and the rules behind it.",
        ]
    )

    # ---------------------------------------------------------- evaluation
    head("How we collect data (SUS and SEIPS)")
    line("Everyone should be able to explain these two in one sentence.")
    bullets(
        [
            "SUS (System Usability Scale) \u2014 10 statements answered from 1 (strongly disagree) to 5 (strongly agree), turned into a 0\u2013100 score. About 68 is average; higher means easier to use. It takes two minutes, so anyone can answer.",
            "SEIPS (work-system check) \u2014 used with the clinical staff. It looks at the whole working environment (people, tasks, tools, organisation, surroundings) and asks whether TABANG lowers their workload, their steps and their mistakes.",
            "Who we ask: 35 people in Digos City \u2014 15 donors, 15 recipients or family, 5 clinical personnel, chosen on purpose because they already know the blood process.",
            "When and where: Academic Year 2026\u20132027, inside Digos City, as a single testing snapshot (cross-sectional).",
        ]
    )

    # =================================================== 0. exec summary
    head("Executive Summary (Ni\u00f1o)")
    bullets(
        [
            "Purpose: during an emergency a Digos City family has to call around to find blood; TABANG puts donors, requests and stock in one place.",
            "Components: one system for three users \u2014 the community, the Red Cross chapter staff, and the administrator.",
            "How to collect data: app-wide, all records are simulated; feedback comes from the SUS questionnaire and the SEIPS check.",
            "How it's made: a research prototype built with Flutter and Dart, running with no server; it needs only a basic phone (2 GB RAM, 500 kbps).",
        ]
    )

    # ================================================ 1. access
    head("1. Access & Onboarding (Ni\u00f1o)")
    targets(
        "1.1 Login",
        "Ni\u00f1o",
        "sign in and send each account to the right surface for its role.",
        "email and password fields, a demo account list for one-tap sign-in, and the sign-in button.",
        "the email and password typed in, checked against the credential store.",
        "a local salted SHA-256 store; the session is routed by role, and staff or admin accounts cannot self-register.",
    )
    targets(
        "1.2 Registration",
        "Ni\u00f1o",
        "create a new community account.",
        "a three-step wizard (identity; clinical details; barangay) that hands off to Login.",
        "full name, unique nickname, email, contact number, birth date, blood type, weight and barangay.",
        "nicknames must be unique and duplicate full names are refused; every self-registration is locked to the community role.",
    )

    # ================================================ 2. community
    head("2. Community Application (Sam \u00b7 Hanz \u00b7 Lloyd)")

    targets(
        "2.1 Home",
        "Sam",
        "the landing feed and the starting point for community users.",
        "quick actions (Request blood, Find a donor, Find a drive); rails for upcoming drives, announcements, stories and guides; a visit planner.",
        "reads the seeded drives, announcements, stories and articles; the drive rail shows one photo per drive.",
        "a single in-app snapshot feeds every rail, so anything staff change appears here immediately.",
    )
    targets(
        "2.2 Blood Bank",
        "Sam",
        "show the public blood stock and let users act on it.",
        "chapter banner, stock note, a stock grid by component and blood type, unit cards with a detail view, and a Request this unit entry point.",
        "unit records (product, storage bay, expiry, status) and a compatibility check for the user's blood type.",
        "a read-only public view over inventory; expired units are excluded, and requesting opens the documented request dialog pre-filled from the unit.",
    )
    targets(
        "2.3 Find Donor",
        "Sam",
        "find donors by area and blood type.",
        "the Digos City map (26 barangays), donor-density heat, drive and facility pins, a side panel with Donors / Facilities / Drives tabs, blood-type chips, a barangay filter and a draggable divider.",
        "donor records (barangay, blood type, eligibility) plus facility and drive locations; every donor shows as an alias such as Donor #003.",
        "hand-traced barangay geometry over OpenStreetMap base tiles (no API key); tapping a barangay filters the list instantly.",
    )
    targets(
        "2.4 Requests",
        "Hanz",
        "post a blood need and answer one.",
        "Requests tab (open requests), Mine tab (posted requests and their status), Donate tab (drives you can join), the request dialog with documents and slot booking, and the response dialog.",
        "patient alias, blood type, component, urgency, the required documents (doctor's form, transfusion slip, patient ID) and the booked blood-bank slot.",
        "requests start as Awaiting verification and need staff review; responses never consume a unit until the requester selects one.",
    )
    targets(
        "2.5 Messages",
        "Hanz",
        "let people coordinate without giving away their identity.",
        "thread list with search and sort, the conversation view, and the same screen the staff console uses.",
        "message text only; the thread keeps who wrote what and when.",
        "donors and patients stay as aliases until both sides agree to proceed; staff can reply as the official chapter identity.",
    )
    targets(
        "2.6 Donor Hub",
        "Hanz",
        "turn a community user into a verified donor.",
        "the opt-in form (blood type, birth date, weight), the verification status, and the donor's donation history and cooldown.",
        "the clinical details the user submits, confirmed by staff at the chapter.",
        "eligibility rules apply automatically \u2014 age, minimum weight, and the 12-week whole-blood interval \u2014 and the donor directory updates at once.",
    )
    targets(
        "2.7 Profile",
        "Lloyd",
        "let a user see and keep their own record.",
        "identity card with the chosen avatar, blood type, barangay and contact details, plus the donor summary when the account is a donor.",
        "the account's own stored details; the avatar picker offers the bundled portrait set.",
        "it reads the same repository record the staff console sees, so both sides always agree.",
    )
    targets(
        "2.8 Settings",
        "Lloyd",
        "let a user adjust how the app looks and behaves.",
        "theme (light or dark), compact navigation, sidebar pinning, and Sign out.",
        "the preferences chosen on this screen.",
        "preferences are held for the session and shared by both shells; signing out asks for confirmation first.",
    )
    targets(
        "2.9 Guides & Help",
        "Lloyd",
        "explain the app and answer common questions.",
        "the About TABANG story, the FAQ list, the feedback form, Open Messages, and the per-image credit cards.",
        "the FAQ answers, the feedback the user types, and the credits recorded for every bundled photo.",
        "feedback can open a real conversation with the chapter; the image credits come from the same registry the app renders from.",
    )

    # ================================================ 3. staff
    head("3. Staff Console (Aeron \u00b7 Kath)")

    targets(
        "3.1 Overview",
        "Aeron",
        "show the chapter's situation at a glance.",
        "readiness score, the activity log, donations versus requests per blood type, and shortcuts into Operations.",
        "aggregated counts from inventory, donations and requests \u2014 no personal medical detail.",
        "read-only summaries computed from the same records the rest of the app uses; the readiness score follows the chapter's own targets.",
    )
    targets(
        "3.2 Operations \u2014 Map",
        "Aeron",
        "work the request queue and see the chapter's workload on the map.",
        "the same map as Find Donor, a Requests / Donor density legend switch, panel tabs for Requests and Donors, blood-type chips, and the draggable divider.",
        "open requests with their documents, and the donor directory (barangay, blood type, eligibility, last donation).",
        "staff verify or reject a request with a written reason and can undo either; choosing donor density brings the donor directory forward.",
    )
    targets(
        "3.3 Operations \u2014 Inventory",
        "Aeron",
        "track every blood unit from collection to use or disposal.",
        'the unit list (newest first, with "collected N days ago"), status menus, Add unit, the unit detail sheet, and the Removed units ledger.',
        "blood type, component, storage bay, collection date, derived expiry, barcode and the current holder.",
        "expiry comes from each component's shelf life; removing, adding and restoring all offer Undo, and a restored barcode cannot clash with one already in use.",
    )
    targets(
        "3.4 Messages",
        "Kath",
        "answer the community from one inbox.",
        "the same conversation view the community app uses, opened straight from the staff rail.",
        "message text, and which conversation the chapter may reply to as the official identity.",
        "staff and the community share one thread per pair; staff can post as the chapter account instead of a personal alias.",
    )
    targets(
        "3.5 Users",
        "Kath",
        "manage every account and the donor-registration queue.",
        "search and filters, one card per account, and actions for Message, Record donation, Donation window, Verify, Warn and Suspend.",
        "account details, the pending donor registrations awaiting verification, and the moderation history per account.",
        "warn and suspend write to the account record; Message now opens the Messages tab so staff and community see the same screen.",
    )
    targets(
        "3.6 Moderation",
        "Kath",
        "keep conversations and reports within the rules.",
        "flagged threads with keyword matches, the user-report queue with Resolve and Dismiss, the flag-keyword list, and mute controls. It now lives as a tab inside Users.",
        "flagged messages and their matched keyword, plus the reports users file.",
        "three warnings suspend an account automatically; resolving or dismissing a report offers Undo back to the open queue.",
    )
    targets(
        "3.7 Operations \u2014 Drives",
        "Aeron",
        "create and manage the chapter's blood drives (added after the first draft).",
        "an Add drive form (title, venue, barangay, date, start and end time, expected donors, note), an Awaiting approval queue, the Scheduled list, and the Rejected and Cancelled lists.",
        "what the proposer enters, and the admin's decision with its reason.",
        "staff propose and only an admin approves, rejects or cancels; each step confirms first and offers Undo, and only approved drives appear to donors.",
    )

    # ================================================ 4. admin
    head("4. Admin & Governance (Iverson)")
    targets(
        "4.1 Readiness Targets",
        "Iverson",
        "let the chapter set its own goals and score against them.",
        "targets for units, donors, request pressure and community accounts, with the readiness score that follows them.",
        "the numbers the admin enters; the score is computed from live records.",
        "only an admin can change a target, and every change is written to the activity log.",
    )
    targets(
        "4.2 Staff & Account Management",
        "Iverson",
        "control who works in the console.",
        "the create-staff form, role and status controls, and the same account actions the Users page offers.",
        "the staff member's details and role assignment.",
        "only an admin may create or manage a staff account; a suspended account is removed from the donor directory and from eligibility at once.",
    )

    # ================================================ 5. roles
    head("5. Role & Persona Matrix (Iverson)")
    bullets(
        [
            "Purpose: one table that says who may do what, so no screen has to guess.",
            "Components: the five accounts \u2014 community user, donor, recipient, clinical staff, administrator \u2014 with the actions each one is allowed.",
            "How to collect data: the role stored on each account, set at registration or by an admin.",
            "How it's made: the app checks the role before every action and hides what the role cannot use, so a donor cannot approve a request and staff cannot approve a drive.",
        ]
    )

    # ================================================ 6. technical
    head("6. Technical Foundations (Iverson)")
    bullets(
        [
            "Purpose: explain, briefly, what the app is built with and why it needs no server.",
            "Components: the language and framework, the data store, the map, the privacy rules, and the builds we hand out.",
            "How to collect data: nothing is collected here \u2014 this is the summary of how everything else is stored and protected.",
            "How it's made: Flutter with Dart (one codebase for Android and web); no server and no database \u2014 an in-memory repository seeded at launch so every demo starts identically; eligibility, ABO/Rh compatibility and shelf-life expiry as in-app rules; keyless OpenStreetMap tiles over hand-traced barangay boundaries; aliases and double-blind chat by design (RA 10173); and Android APKs per processor plus a universal APK and a web build.",
        ]
    )

    document.save(TARGET)
    print("Wrote", TARGET)


if __name__ == "__main__":
    build()
