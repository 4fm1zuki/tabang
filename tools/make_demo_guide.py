"""Build TABANG_Demonstration_Guide.docx.

A short, plain-language demo script: what TABANG is, the four demonstration
targets (Purpose / Components / How to collect data / How it is made), how the
evaluation data is collected (SUS and SEIPS, in simple terms), what it is built
with, and a screen-by-screen walkthrough for the reporter to follow.

Run from the repository root:

    python tools/make_demo_guide.py
"""

from __future__ import annotations

import os

import docx
from docx.shared import Pt

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TARGET = os.path.join(ROOT, "TABANG_Demonstration_Guide.docx")


def build() -> None:
    document = docx.Document()

    # Small, readable body text: this is read aloud while the app is on screen.
    normal = document.styles["Normal"]
    normal.font.name = "Calibri"
    normal.font.size = Pt(11)
    normal.paragraph_format.space_after = Pt(4)

    def title(text: str) -> None:
        run = document.add_paragraph().add_run(text)
        run.bold = True
        run.font.size = Pt(20)

    def heading(text: str) -> None:
        document.add_heading(text, level=1)

    def sub(text: str) -> None:
        document.add_heading(text, level=2)

    def line(text: str) -> None:
        document.add_paragraph(text)

    def bullets(items: list[str]) -> None:
        for item in items:
            document.add_paragraph(item, style="List Bullet")

    def numbered(items: list[str]) -> None:
        for item in items:
            document.add_paragraph(item, style="List Number")

    # ------------------------------------------------------------------ head
    title("TABANG — Demonstration Guide")
    line(
        "Transfusion Access, Blood Availability and Network Guidance | "
        "Digos City, Davao del Sur | Build 2.0.0"
    )
    line(
        "How to use this guide: keep it open while the app is on screen. Each "
        "part says what to show and the one or two sentences to say about it. "
        "Everything here is written for a general audience — no technical words "
        "are required."
    )

    # -------------------------------------------------------------- purpose
    heading("1. Purpose — what TABANG is, in plain words")
    bullets(
        [
            "During an emergency, a family in Digos City has to call around to "
            "find blood. TABANG puts that in one place: who can donate, who "
            "needs blood, and what the blood bank still has.",
            "It serves three kinds of users from one system: the community "
            "(donors and recipients), the Red Cross chapter staff, and the "
            "administrator who oversees the chapter.",
            "It is a school research prototype. All people, requests and blood "
            "units shown are simulated — no real patient records, hospital "
            "records or Red Cross databases are used (Data Privacy Act, RA 10173).",
            "It is built to run on an ordinary phone: 2 GB of RAM and a 500 kbps "
            "connection are enough.",
        ]
    )

    # -------------------------------------------------------------- targets
    heading("2. The four demonstration targets")
    line("For every screen we cover, the reporter answers these four questions:")
    bullets(
        [
            "Purpose — why this screen exists, and the problem it removes.",
            "Components — the parts you can see on screen (buttons, lists, tabs).",
            "How to collect data — what information goes in, and how we gather "
            "feedback from the people testing it (SUS and SEIPS; explained below).",
            "How it's made — how the app is built: language, framework, and the "
            "rules behind it.",
        ]
    )

    # ----------------------------------------------------------- data
    heading("3. How we collect data")
    sub("3.1 Feedback from the people who test it")
    bullets(
        [
            "SUS (System Usability Scale) — a short questionnaire of 10 "
            "statements, each answered from 1 (strongly disagree) to 5 (strongly "
            "agree). The answers become a score from 0 to 100; about 68 is the "
            "average, and higher means easier to use. It takes two minutes, so "
            "anyone can answer it.",
            "SEIPS (work-system check) — used with the clinical staff. Instead of "
            "only asking \"is it easy?\", it looks at the whole working "
            "environment: the people, their tasks, the tools, the organisation "
            "and the surroundings — and asks whether TABANG reduces their "
            "workload, their steps, and their mistakes.",
            "Who we ask: 35 people in Digos City — 15 blood donors, 15 "
            "recipients or family representatives, and 5 clinical personnel, "
            "chosen on purpose (purposive sampling) because they already know "
            "the blood process.",
            "When and where: during Academic Year 2026–2027, inside Digos City, "
            "as a single snapshot of testing (cross-sectional).",
        ]
    )
    sub("3.2 Data the app itself collects")
    bullets(
        [
            "Accounts: name, nickname, email, contact number, birth date, blood "
            "type, weight and barangay — captured once at registration.",
            "Requests: the patient's alias, blood type, component, urgency, the "
            "required documents (doctor's form, transfusion slip, patient ID) "
            "and the booked blood-bank slot.",
            "Donations and stock: each collected unit records the type, "
            "component, storage bay, collection date and expiry; every donation "
            "updates the donor's next-eligible date.",
            "Participation: who joined a drive's chapter list, so staff know "
            "who to expect.",
        ]
    )

    # ------------------------------------------------------------ how made
    heading("4. How it's made")
    bullets(
        [
            "Language and framework: Flutter with Dart — one codebase that "
            "builds both the Android app and the web version.",
            "Architecture: no server and no database. A single in-memory "
            "repository ships inside the app, seeded at launch, so every "
            "demonstration starts from the same state and resets on restart.",
            "Rules inside the app: donor eligibility with donation cooldown "
            "timers, ABO/Rh and component compatibility matching, and unit "
            "expiry based on each component's shelf life.",
            "Map: hand-traced barangay boundaries (26 barangays) drawn over "
            "OpenStreetMap base tiles — no API key and no paid map service.",
            "Privacy by design: donors appear as aliases (Donor #003), and "
            "messages stay double-blind until both sides agree to proceed.",
            "Builds we hand out: an Android APK per processor (arm64, armv7, "
            "x86_64) plus a universal APK that works on any device, and a web "
            "build for browsers.",
        ]
    )

    # ------------------------------------------------------------- script
    heading("5. Demonstration walkthrough")
    line("Follow this order. Say the bolded line, then show the screen.")

    sub("5.1 Community side (sign in as the donor demo account)")
    numbered(
        [
            "Login — \"One account, and the app opens the right dashboard for "
            "that role.\" Tap a demo account to fill it in.",
            "Home — \"The landing page: upcoming drives, announcements, stories "
            "and guides, plus three quick actions.\"",
            "Blood Bank — \"What the chapter has right now, by blood type and "
            "component. A user can start a request from a unit.\"",
            "Find Donor — \"A map of Digos City.\" Switch the heat between donor "
            "density and requests, tap a barangay, and open a donor card to see "
            "eligibility, donations and last donation.",
            "Requests — \"Post a need.\" Show the documents, the booked slot and "
            "the status. Also show joining a drive's chapter list (and the "
            "confirmation that appears before leaving it).",
            "Messages — \"Aliases only, until both sides agree.\"",
            "Donor Hub — \"Opt in to become a donor; the 12-week cooldown is "
            "tracked automatically.\"",
        ]
    )

    sub("5.2 Staff console (sign in as the staff account)")
    numbered(
        [
            "Overview — \"The chapter at a glance: readiness score, recent "
            "activity, and donations versus requests per blood type.\"",
            "Operations ▸ Map — \"The same map, with the chapter's workload.\" "
            "Show the request queue: open a request, check documents, Verify or "
            "Reject with a reason (both offer Undo), then switch the legend to "
            "donor density to bring up the donor directory.",
            "Operations ▸ Inventory — \"Every unit, newest first, with expiry and "
            "how long ago it was collected.\" Add a unit, then remove one and "
            "restore it with Undo.",
            "Operations ▸ Drives — \"This is where a drive is created.\" Tap Add "
            "drive, fill in venue, barangay, date, time and expected donors, and "
            "send it for approval — then undo it to show withdrawal.",
            "Messages — \"The same conversation view the community sees.\"",
            "Users — \"Every account, with warn and suspend, and the report "
            "queue with Undo.\"",
        ]
    )

    sub("5.3 Administrator")
    numbered(
        [
            "Operations ▸ Drives — approve or reject the drive proposed in 5.2 "
            "(\"staff propose, the admin decides\"), then cancel a scheduled "
            "drive and restore it. Every step asks for confirmation first.",
            "Readiness & targets — \"The chapter sets its own goals, and the "
            "score follows them.\"",
            "Users — \"Only an admin can create or manage staff accounts.\"",
        ]
    )

    # --------------------------------------------------------------- close
    heading("6. What we say at the end")
    bullets(
        [
            "One system, three users, no server to maintain, and it works on a "
            "basic phone.",
            "Every action that could hurt someone by accident — approving a "
            "drive, rejecting a request, closing a report, signing out — asks "
            "first and offers an undo.",
            "What we ask of the people testing it: the 10-item SUS "
            "questionnaire, and for staff, the SEIPS work-system check.",
        ]
    )

    document.save(TARGET)
    print("Wrote", TARGET)


if __name__ == "__main__":
    build()
