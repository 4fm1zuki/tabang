"""Build TABANG_Demonstration_Guide.docx.

A reading guide for the demo: one short line per point, so a reporter can glance
at it while presenting. Same look as the original document — Verdana throughout,
deep-red section headings (#8B0F1A), navy sub-headings (#1A2B4C), grey body
text, and a bold label in front of each line.

Run from the repository root:

    python tools/make_demo_guide.py

Edit this file with a UTF-8 aware editor (the text contains en/em dashes and
"Niño"); do not round-trip it through a PowerShell Get-Content/Set-Content pair,
which re-encodes it as ANSI.
"""

from __future__ import annotations

import os

import docx
from docx.shared import Pt, RGBColor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, "TABANG_Demonstration_Guide.docx")

# Research group, alphabetical by surname as supplied.
AUTHORS = [
    "BARON, HANZ EMMANUEL D.",
    "BRIONES, IVERSON D.",
    "CATALAN, AERON RODGE B.",
    "RECIMO, NI\u00d1O RHEYN F.",
    "ROLDAN, KATHERINE NICOLE E.",
    "SANCHEZ, LLOYD P.",
    "THAPA, SAMEERA P.",
]

FONT = "Verdana"
RED = RGBColor(0x8B, 0x0F, 0x1A)
NAVY = RGBColor(0x1A, 0x2B, 0x4C)
BODY = RGBColor(0x33, 0x33, 0x33)
MUTED = RGBColor(0x55, 0x55, 0x55)

# (heading, reporter, purpose, components, how data is collected, how it's made)
SECTIONS: list[tuple[str, str, str, str, str, str]] = [
    (
        "Executive Summary",
        "Ni\u00f1o",
        "one place for donors, requests and stock \u2014 no more calling around.",
        "one app, three users: community, chapter staff, admin.",
        "all records are simulated; feedback comes from SUS and SEIPS.",
        "Flutter + Dart, no server, runs on a basic phone.",
    ),
    (
        "1.1 Login",
        "Ni\u00f1o",
        "sign in; each role opens its own dashboard.",
        "email, password, demo account list, sign-in.",
        "the email and password typed in.",
        "local password check; the role decides where you land.",
    ),
    (
        "1.2 Registration",
        "Ni\u00f1o",
        "create a community account.",
        "three steps: identity, clinical details, barangay.",
        "name, nickname, email, contact, birth date, blood type, weight, barangay.",
        "nicknames stay unique; every self-signup is a community account.",
    ),
    (
        "2.1 Home",
        "Sam",
        "the landing page for the community.",
        "quick actions; rails for drives, stories and guides.",
        "seeded drives, stories and articles.",
        "one in-app snapshot feeds every rail.",
    ),
    (
        "2.2 Blood Bank",
        "Sam",
        "show the blood that is actually available.",
        "stock grid by type and component; unit details; Request this unit.",
        "unit records and a compatibility check.",
        "read-only view; expired units are hidden.",
    ),
    (
        "2.3 Find Donor",
        "Sam",
        "find donors by area and blood type.",
        "map, density heat, donor/facility/drive pins, chips, filters, divider.",
        "donor records, shown only as aliases (Donor #003).",
        "hand-traced barangays over OpenStreetMap tiles.",
    ),
    (
        "2.4 Requests",
        "Hanz",
        "post a need, and answer one.",
        "Requests / Mine / Donate tabs; request and response dialogs.",
        "type, component, urgency, documents, booked slot.",
        "staff verify first; a response only holds a unit when chosen.",
    ),
    (
        "2.5 Messages",
        "Hanz",
        "coordinate without giving away identity.",
        "thread list, conversation view.",
        "message text and timestamps.",
        "aliases until both agree; staff reply as the chapter.",
    ),
    (
        "2.6 Donor Hub",
        "Hanz",
        "turn a user into a verified donor.",
        "opt-in form, verification status, donation history and cooldown.",
        "blood type, birth date, weight \u2014 confirmed by staff.",
        "age, weight and the 12-week interval are enforced automatically.",
    ),
    (
        "2.7 Profile",
        "Lloyd",
        "see and keep your own record.",
        "avatar, identity details, donor summary.",
        "the account's own details.",
        "reads the same record the staff console sees.",
    ),
    (
        "2.8 Settings",
        "Lloyd",
        "change how the app looks.",
        "theme, compact navigation, pin sidebar, Sign out.",
        "the preferences picked here.",
        "kept for the session; signing out asks first.",
    ),
    (
        "2.9 Guides & Help",
        "Lloyd",
        "explain the app and answer questions.",
        "About TABANG, FAQ, feedback, Open Messages, photo credits.",
        "FAQ answers, typed feedback, image credits.",
        "feedback opens a real chat with the chapter.",
    ),
    (
        "3.1 Overview",
        "Aeron",
        "the chapter at a glance.",
        "readiness score, activity log, donations vs requests.",
        "counts from inventory, donations and requests.",
        "read-only summaries of the same records.",
    ),
    (
        "3.2 Operations \u2014 Map",
        "Aeron",
        "work the request queue on the map.",
        "request/donor heat, Requests and Donors tabs, chips, divider.",
        "requests with their documents; the donor directory.",
        "verify or reject with a reason \u2014 both can be undone.",
    ),
    (
        "3.3 Operations \u2014 Inventory",
        "Aeron",
        "track every blood unit.",
        "unit list (newest first), Add unit, details, Removed units.",
        "type, component, bay, collected date, expiry, holder.",
        "expiry from shelf life; add, remove and restore all offer Undo.",
    ),
    (
        "3.4 Messages",
        "Kath",
        "answer the community from one inbox.",
        "the same conversation view the community uses.",
        "message text and sender.",
        "one thread per pair; staff can post as the chapter.",
    ),
    (
        "3.5 Users",
        "Kath",
        "manage every account.",
        "search, filters, account cards, Message / Verify / Warn / Suspend.",
        "account details and pending donor registrations.",
        "warn and suspend change the account; Message opens the Messages tab.",
    ),
    (
        "3.6 Moderation",
        "Kath",
        "keep chats and reports within the rules.",
        "flagged threads, report queue, keywords, mute \u2014 now a tab inside Users.",
        "flagged messages and the reports users file.",
        "three warnings suspend an account; resolve and dismiss have Undo.",
    ),
    (
        "3.7 Operations \u2014 Drives",
        "Aeron",
        "create and manage the chapter's drives.",
        "Add drive form, Awaiting approval, Scheduled, Rejected, Cancelled.",
        "venue, barangay, date, time, expected donors, note.",
        "staff propose, admin approves; every step confirms and offers Undo.",
    ),
    (
        "4.1 Readiness Targets",
        "Iverson",
        "set the chapter's own goals.",
        "targets for units, donors, request pressure, accounts.",
        "the numbers the admin enters.",
        "admin only; every change is logged.",
    ),
    (
        "4.2 Staff & Account Management",
        "Iverson",
        "control who works in the console.",
        "create staff, role and status controls.",
        "staff details and role assignment.",
        "admin only; suspended accounts leave the donor directory.",
    ),
    (
        "5. Role & Persona Matrix",
        "Iverson",
        "one table for who may do what.",
        "five roles: community, donor, recipient, staff, admin.",
        "the role stored on each account.",
        "the app checks the role before every action.",
    ),
    (
        "6. Technical Foundations",
        "Iverson",
        "what it is built with, briefly.",
        "language, data store, map, privacy, builds.",
        "nothing collected here \u2014 just how data is stored.",
        "Flutter + Dart; no server; seeded in-memory data; OSM map; APKs and web.",
    ),
]

# Group heading that precedes each sub-section, with the reporters who present it.
GROUPS: dict[str, str] = {
    "1.1": "1. Access & Onboarding (Ni\u00f1o)",
    "2.1": "2. Community Application (Sam \u00b7 Hanz \u00b7 Lloyd)",
    "3.1": "3. Staff Console (Aeron \u00b7 Kath)",
    "4.1": "4. Admin & Governance (Iverson)",
}

FINAL_ANSWERS = [
    (
        "Purpose?",
        "One place for donors, requests and stock, so nobody has to call "
        "around. For the community, the chapter staff and the administrator.",
    ),
    (
        "Components?",
        "One app, three surfaces: the community app, the staff console, and "
        "admin governance. The role matrix decides who may do what.",
    ),
    (
        "How to collect data?",
        "In-app records; SUS for everyone (10 statements, 0\u2013100, 68 = "
        "average) and SEIPS for clinical staff; 35 respondents in Digos City.",
    ),
    (
        "How it's made?",
        "Flutter with Dart, no server: one codebase for Android and web, seeded "
        "in-memory data, in-app eligibility, compatibility and expiry rules.",
    ),
]


def build() -> None:
    document = docx.Document()

    def style(name: str, size: float, colour: RGBColor, bold: bool = False) -> None:
        target = document.styles[name]
        target.font.name = FONT
        target.font.size = Pt(size)
        target.font.bold = bold
        target.font.color.rgb = colour

    style("Normal", 10.5, BODY)
    style("List Bullet", 10, BODY)
    style("Heading 1", 15, RED, bold=True)
    style("Heading 2", 12, NAVY, bold=True)

    def run(paragraph, text: str, size: float, colour: RGBColor, bold=False):
        piece = paragraph.add_run(text)
        piece.font.name = FONT
        piece.font.size = Pt(size)
        piece.font.color.rgb = colour
        piece.font.bold = bold
        return piece

    def cover() -> None:
        top = document.add_paragraph()
        run(top, "TABANG", 34, RED, bold=True)
        top.paragraph_format.space_after = Pt(0)

        sub = document.add_paragraph()
        run(
            sub,
            "Transfusion Access, Blood Availability and Network Guidance",
            12,
            NAVY,
        )
        sub.paragraph_format.space_after = Pt(0)

        kind = document.add_paragraph()
        run(kind, "Demonstration Guide", 14, BODY, bold=True)
        kind.paragraph_format.space_after = Pt(0)

        where = document.add_paragraph()
        run(
            where,
            "Digos City, Davao del Sur  \u00b7  Build 2.0.0  \u00b7  "
            "Seven reporters",
            10,
            MUTED,
        )

    def note(text: str) -> None:
        paragraph = document.add_paragraph()
        run(paragraph, text, 10.5, BODY)
        paragraph.paragraph_format.space_after = Pt(6)

    def heading(text: str, level: int = 1) -> None:
        paragraph = document.add_heading(level=level)
        paragraph.add_run(text)
        for piece in paragraph.runs:
            piece.font.name = FONT
            piece.font.size = Pt(15 if level == 1 else 12)
            piece.font.bold = True
            piece.font.color.rgb = RED if level == 1 else NAVY
        paragraph.paragraph_format.space_before = Pt(10)
        paragraph.paragraph_format.space_after = Pt(2)

    def bullet(label: str | None, value: str) -> None:
        paragraph = document.add_paragraph(style="List Bullet")
        if label:
            run(paragraph, label + " ", 10, BODY, bold=True)
        run(paragraph, value, 10, MUTED if label else BODY)
        paragraph.paragraph_format.space_after = Pt(1)

    # ------------------------------------------------------------------ cover
    cover()
    note(
        "Read straight down your own parts. Every section gives the same four "
        "lines: Purpose, Components, How to collect data, How it's made."
    )

    heading("Research group")
    for author in AUTHORS:
        bullet(None, author)

    heading("Who presents what")
    for name, parts in (
        ("Ni\u00f1o", "Executive summary; 1.1 Login; 1.2 Registration."),
        ("Sam", "2.1 Home; 2.2 Blood Bank; 2.3 Find Donor."),
        ("Hanz", "2.4 Requests; 2.5 Messages; 2.6 Donor Hub."),
        ("Lloyd", "2.7 Profile; 2.8 Settings; 2.9 Guides & Help."),
        ("Aeron", "3.1 Overview; 3.2 Map; 3.3 Inventory; 3.7 Drives."),
        ("Kath", "3.4 Messages; 3.5 Users; 3.6 Moderation."),
        ("Iverson", "4. Admin; 5. Role Matrix; 6. Technical; 7. Final answers."),
    ):
        bullet(f"{name} \u2014", parts)

    heading("How we collect data")
    for label, value in (
        ("SUS \u2014", "10 statements, 1 to 5, scored 0\u2013100; 68 is average."),
        ("SEIPS \u2014", "for clinical staff: does the whole work system improve?"),
        ("Who \u2014", "35 in Digos City: 15 donors, 15 recipients, 5 staff."),
        ("When \u2014", "Academic Year 2026\u20132027, one testing snapshot."),
    ):
        bullet(label, value)

    # --------------------------------------------------------------- sections
    for index, (title, reporter, purpose, components, data, made) in enumerate(
        SECTIONS
    ):
        group_key = title.split(" ")[0]
        if group_key in GROUPS and (index == 0 or True):
            groups_before = GROUPS.pop(group_key, None)
            if groups_before:
                heading(groups_before)
        heading(f"{title} ({reporter})", level=2)
        bullet("Purpose:", purpose)
        bullet("Components:", components)
        bullet("How to collect data:", data)
        bullet("How it's made:", made)

    # --------------------------------------------------------- final answers
    heading("7. Demonstration Targets \u2014 Final Answers (Iverson)")
    note("Read these last, after everyone has shown their part.")
    for label, value in FINAL_ANSWERS:
        bullet(label, value)

    document.save(TARGET)
    print("Wrote", TARGET)


if __name__ == "__main__":
    build()
