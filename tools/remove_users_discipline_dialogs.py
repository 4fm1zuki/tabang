"""Remove the now-unused _confirmWarn / _confirmSuspend from the Users page.

Both discipline actions moved to Moderation, so the Users page no longer needs
its own warning and suspension dialogs. Removed by brace matching rather than by
hand, so the surrounding helpers are untouched.

Run from the repository root:

    python tools/remove_users_discipline_dialogs.py
"""

from __future__ import annotations

import os

ROOT = r"D:\Projects\New folder (2)\tabang"
PATH = os.path.join(ROOT, "lib", "screens", "admin", "user_management_page.dart")
METHODS = ("  void _confirmWarn(", "  void _confirmSuspend(")

with open(PATH, encoding="utf-8") as handle:
    text = handle.read()

for needle in METHODS:
    start = text.find(needle)
    if start == -1:
        print("not found:", needle.strip())
        continue
    brace = text.find("{", start)
    depth = 0
    index = brace
    while index < len(text):
        if text[index] == "{":
            depth += 1
        elif text[index] == "}":
            depth -= 1
            if depth == 0:
                break
        index += 1
    end = text.find("\n", index) + 1
    removed = text[start:end].count("\n")
    text = text[:start] + text[end:]
    print(f"removed {removed} lines for {needle.strip()}")

# The suspended marker on an account row is now a plain const pill.
text = text.replace(
    "          StatusPill('Suspended', tone: Tone.danger, dense: true),",
    "          const StatusPill('Suspended', tone: Tone.danger, dense: true),",
)

with open(PATH, "w", encoding="utf-8", newline="") as handle:
    handle.write(text)
print("done")
